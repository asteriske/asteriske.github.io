---
layout: post_blog
title: Till&eacute;'s Method for Unequal Probability Sampling Without Replacement
---
   
In sampling from a population, oftentimes one will find that different subclasses of population members occur with different probability, and so it's useful to have a vector of these probabilites, one corresponding to each population member.
   
Unequal probability is a bit nuanced when sampling without replacement. Because these probabilities are relative, once you permanently remove a sampled item from the population you then need to recalculate the entire probability vector to reflect the new relationships, *e.g.*, removing the second element from a vector with probabilities $(.2,.2,.2,.4)$ would produce a new vector with probabilities $(.25,.25,.5)$. Alternatively, if you remove the fourth element, these probabilities become $(.33,.33,.33)$. So not only do you need to compute new values every draw, but the order of the draws can affect the nature of the sample.
   
Till&eacute; (1996) suggested a new method in which the probabilities are easy to caclulate and draw order doesn't matter. Say we want to select $n$ units from population $U$. First, we generate an initial probability vector of values $\pi(i\|k)$, the probability of drawing a unit $i$ given sample size $k$. The values are proportional to the positive values $x_i$ ($i \in U$) of some auxiliary variable $x$, and are calculated as: 
<div>$$\pi(i\vert k) = \frac{kx_i}{\sum_{i \in U} x_i} (i\in U)$$</div>
If $\pi(i\|k) >= 1$, then set $\pi(i\|k) = 1$, and the procedure is repeated until all $\pi(i\|k) \in$ $\[0,1\]$. 
   
After generating this initial vector, the first selection step is conducted, and (because it's counted backward) we call this step $k = (N-1)$. A unit is selected from $U$ with probability $1-\pi(i\|N-1)$.
   
Each subsequent step is subtly different. At the beginning of step $k$, the sample is composed of $k+1$ units. The vector of probabilities is recalculated as above with the remaining unselected units, and a unit is selected from the sample with probability $$r_{ki} = 1-\frac{\pi(i\vert k)}{\pi(i\vert k+1)}$$ After selection, only $k$ units are now in the sample. Because we're selecting $n$ total units, the procedure stops at the end of step $n$.
