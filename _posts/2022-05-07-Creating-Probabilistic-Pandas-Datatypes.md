---
layout: single
category: blog
tags: 
  - python 
  - pandas
---

Imagine you're doing some kind of tabluar data work in Pandas, but rather than work with the same old concrete types, you're working with some kind of uncertainty. Perhaps you have a benchmark suite and it does lots of microbenchmarks like this:

    {% highlight python linenos %}
    import random
    
    my_list = [random.randint(0,10) for _ in range(1000)]
    
    def sum_list(x: List[str]) -> float:
        return sum(x){% endhighlight %}

    %timeit sum_list(my_list)
    6.29 µs ± 125 ns per loop (mean ± std. dev. of 7 runs, 100,000 loops each)

(Putting it in the same terms, 6.29 µs ± 0.125 µs)

If I have a bunch of different files and I benchmark each of them, then I'll have a group of independent random measurements. If I want to sum them up, I could just sum the means, but what if I want to estimate the uncertainty of the whole sum? **Let's create a new datatype that works in Pandas!**

One possible solution is to create a `Distribution` datatype which can be computed upon in Pandas like a normal Numpy number. Internally this object could exist a number of ways, but let's discuss an **`AnalyticNormal`** type which interacts with other values by dint of some simple rules.


A Normal distribution is parameterized by two values, a mean $$\mu$$ and a standard deviation $$\sigma$$. We can write that a random variable $$X$$ is distributed normally according to the parameters like so:


$$X \sim N(\mu,\sigma)$$


All the operations we will want to define will exist in terms of these two parameters, so let's create a class that stores them as instance variables:

    {% highlight python linenos %}
    class Normal(Distribution):

      def __init__(self, mu, sigma):
        self.mu = float(mu)
        self.sigma = float(sigma){% endhighlight %}


Maybe somehow I have a few benchmarks with no uncertainty, that is, they're just floats, and I want to sum them up with my uncertain measurements. The easiest operation we can define is interaction with floating point numbers, which for some constant $$b$$ follows the rule


$$\begin{aligned} X &\sim N(\mu, \sigma)\\ 
X +b &\sim N(\mu + b, \sigma)\end{aligned}$$


This requires a double underscore or "dunder" method to be added, `__add__`. Adding other types will require different rules, so let's make sure we catch just numbers:


    {% highlight python linenos %}
    def __add__(self, other):
      if isinstance(other, numbers.Number):
        return Normal(mu + other, sigma)
      else:
        raise NotImplementedError{% endhighlight %}


We will ask `__add__` to do more later so let's separate concerns by creating a `constant_add` function:


    {% highlight python linenos %}
    def __add__(self, other):
      if isinstance(other, numbers.Number):
        return self.constant_add(other)
      else:
        raise NotImplementedError

    def constant_add(self, b: number.Number):
      return Normal(self.mu+b, self.sigma){% endhighlight %}


Let's try out our new method:

    {% highlight python %}
    > Normal(0,1) + 3
    <__main__.Normal at 0x130423d30>{% endhighlight %}


It looks like it worked, but the interpreter doesn't know how to print a representation of the object. Let's fix that.


    {% highlight python linenos %}
    def __repr__(self) -> str:
      descr_str = f"N({np.round(self.mu,2)},{np.round(self.sigma,2)})"

      return descr_str{% endhighlight %}

<!-- -->

    {% highlight python linenos %}
    > Normal(0,1) + 3
    N(3.0,1.0){% endhighlight %}


Nice!


Now, we've taught a `Normal` how to add to itself a float, but what if we have an operation that goes the other way?


    {% highlight python linenos %}
    > 3 + Normal(0,1)
    ---------------------------------------------------------------------------
    TypeError                                 Traceback (most recent call last)
    Input In [30], in <cell line: 1>()
    ----> 1 3+Normal(0,3)


    TypeError: unsupported operand type(s) for +: 'int' and 'Normal'{% endhighlight %}


`Normal` has a method to handle an `int`, but `int` doesn't have a method to handle a normal. While we probably could extend `int` to handle our case, there's a better way: the reverse add or `__radd__` dunder.


Addition is commutative so we can just re-order the operation. We don't even need to screen for types because our existing `__add__` method already handles that.


    {% highlight python linenos %}
    def __radd__(self, other):
      return self.__add__(other){% endhighlight %}

<!-- -->

    {% highlight python linenos %}
    > 3 + Normal(0,1)
    N(3.0,1){% endhighlight %}


Implementing arithmetic operators opens the door to treating them like garden-variety numbers in Pandas. For instance now we can do something like


    {% highlight python linenos %}
    > pd.Series([Normal(1,1),2,3])
    
    0    N(1.0,1.0)
    1             2
    2             3
    dtype: object

    > pd.Series([Normal(1,1),2,3]).sum()
    N(6.0,1.0){% endhighlight %}


Let's add a method so we can add normals to each other. Recall for independent normals


$$\begin{align}X &\sim N(\mu_x, \sigma_x)\\
Y &\sim N(\mu_y, \sigma_y)\\
X+Y &\sim N(\mu_x + \mu_y, \sqrt({\sigma_x^2 + \sigma_y^2}))\end{align}$$


so we can write


{% highlight python linenos %}
def normal_add(self, other):
  new_sigma = np.sqrt(self.sigma**2 + other.sigma**2)
  return Normal(mu=(self.mu + other.mu), sigma=new_sigma){% endhighlight %}


and we can set that up inside our `__add__`:

{% highlight python linenos %}
def __add__(self, other):
  if isinstance(other, numbers.Number):
    return self.constant_add(other)
  elif isinstance(other, Normal):
    return self.normal_add(other)
  else:
    raise NotImplementedError{% endhighlight %}


and now we can add normals:

```
> pd.Series([Normal(1,1), Normal(1,2), Normal(1,3)]).sum()

N(3.0,3.74)
```

One last thing we may want is to use our datatype for grouping. Let's try it:

{% highlight python linenos %}
foo = pd.Series([AnalyticNormal(1,2), AnalyticNormal(1,2),AnalyticNormal(2,3)])
bar = pd.Series([1,2,3])
df = pd.DataFrame({'f':foo,'b':bar})
df.groupby('f')['b'].sum(){% endhighlight %}

    File pandas/_libs/hashtable_class_helper.pxi:5394, in pandas._libs.hashtable.PyObjectHashTable.factorize()
    
    File pandas/_libs/hashtable_class_helper.pxi:5310, in pandas._libs.hashtable.PyObjectHashTable._unique()
    
    TypeError: unhashable type: 'AnalyticNormal'

Welp.

The problem here is that pandas can't tell what elements of the groupby key are unique, because they're not **hashable**. This essentially means they can't be reduced to unique integers. We need to implement that, and also some comparison functions like `__lt__`.


{% highlight python linenos %}
def __hash__(self):
    return hash((self.mu, self.sigma))

def __lt__(self, other):
    if isinstance(other, numbers.Number):
        return self.to_mean() < other
    elif isinstance(other, Normal):
        return self.mu < other.mu
    else:
        raise NotImplementedError
{% endhighlight %}

See what we get when we use our new function:


{% highlight python linenos %}
AnalyticNormal(1,2).__hash__()
{% endhighlight %}
`-3550055125485641917`

Our full class now looks like this:

{% highlight python linenos %}
class AnalyticNormal(Normal):
    def __init__(self, mu, sigma):
        assert sigma >= 0, "cannot be ngative"
        super().__init__(mu,sigma)
        
    def __eq__(self, other):
        if isinstance(other, numbers.Number):
            return self.mu == other
        elif isinstance(other, Normal):
            return (self.mu == other.mu) and (self.sigma == other.sigma)
        else:
            raise NotImplementedError

    def __repr__(self):
        descr_str = f"N({np.round(self.mu,2)},{np.round(self.sigma,2)})"
        return descr_str
    
    def __hash__(self):
        return hash((self.mu, self.sigma))
    
    def __lt__(self, other):
        if isinstance(other, numbers.Number):
            return self.to_mean() < other
        elif isinstance(other, Normal):
            return self.mu < other.mu
        else:
            raise NotImplementedError
{% endhighlight %}

and if we try our groupby again:

{% highlight python linenos %}
foo = pd.Series([AnalyticNormal(1,2), AnalyticNormal(1,2),AnalyticNormal(2,3)])
bar = pd.Series([1,2,3])
df = pd.DataFrame({'f':foo,'b':bar})
df.groupby('f')['b'].sum(){% endhighlight %}

    f
    N(1.0,2.0)    3
    N(2.0,3.0)    3
    Name: b, dtype: int64

Success!

There are a lot of other arithmetic operators needed for general Pandas use, including
* `__add__`
* `__radd__`
* `__floordiv__`
* `__truediv__`
* `__mul__`
* `__rmul__`
* `__sub__`
* `__rsub__`
* `__repr__`
* `__eq__`
* `__ne__`
* `__ge__`
* `__gt__`
* `__lt__`
* `__le__`
the implementation of which will be left as an exercise to the reader. I've also implemented a few more for convenience including `quantile` to get the `q`th quantile of the distribution, `confidence_interval` to get `x%` CI and a few more. 

Have fun! 



