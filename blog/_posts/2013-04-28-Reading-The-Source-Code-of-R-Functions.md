---
layout: post_blog
title: Reading the Source Code of R Functions
---

Often times I'll find myself wanting to look at the source code of a function, and with R being the open-source language that it is I can often simply type the name of a function, e.g. colnames produces

    function (x, do.NULL = TRUE, prefix = "col") 
    {
    	if (is.data.frame(x) && do.NULL) 
                return(names(x))
            dn <- dimnames(x)
            if (!is.null(dn[[2L]])) 
                dn[[2L]]
            else {
                nc <- NCOL(x)
                if (do.NULL) 
                    NULL
                else if (nc > 0L) 
                    paste0(prefix, seq_len(nc))
                else character()
            }
        }
    <bytecode: 0x9e02f78>
    <environment: namespace:base>

and it's laid bare. Not always however. Recently (to pick an example) I tried to figure out what was inside 'svymean' from the 'survey' package. 

    > svymean
    function (x, design, na.rm = FALSE, ...) 
    {
        .svycheck(design)
        UseMethod("svymean", design)
    }

Well that isn't helpful. Not all is lost though. Sometimes you have internal C or Fortran functions in there like with 'sample' (from base R):

    > sample
    function (x, size, replace = FALSE, prob = NULL) 
    {
        if (length(x) == 1L && is.numeric(x) && x >= 1) {
            if (missing(size)) 
                size <- x
            .Internal(sample(x, size, replace, prob))
        }
        else {
            if (missing(size)) 
                size <- length(x)
            x[.Internal(sample(length(x), size, replace, prob))]
        }
    }
    <bytecode: 0x0000000010504cf0>
    <environment: namespace:base>

In here, where it calls 

    .Internal(sample(x, size, replace, prob))

it's literally invoking a C funcion called `sample`, and you need to download R's source code (or the source package if it's not in base) and find the relevant C files. Fortunately, the `sampling` package is all in R. So what then?

To give namespaces a full treatment would take much text (which can be found in the [R Manual](http://cran.r-project.org/doc/manuals/R-exts.html#Package-namespaces)) but it's enough here to say that to keep packages from overwriting functions and variables in memory each can have a 'full address', e.g. survey:::svymean rather than just svymean, just in case I was using svymean as a variable or something else. 

Sometimes it can be enough to specify the namespace if the function isn't 'exported' into the main memory namespace, e.g. 

    survey:::svymean

but it's possible you end up where you started:

    function (x, design, na.rm = FALSE, ...) 
    {
        .svycheck(design)
        UseMethod("svymean", design)
    }
    <environment: namespace:survey>

Another thing then to try is to see if your function actually has a number of methods, that is if it's being overloaded and will run different code based on its inputs. In that case you can check for methods with methods():

    methods(svymean)
    [1] svymean.DBIsvydesign*   svymean.ODBCsvydesign*  svymean.pps*           
    [4] svymean.survey.design*  svymean.survey.design2* svymean.svyrep.design* 
    [7] svymean.twophase*       svymean.twophase2*    
    
       Non-visible functions are asterisked

Now we're getting somewhere! That ouptut has the line

       Non-visible functions are asterisked

and indeed 

    svymean.pps

doesn't return anything. However, if we namespace it _and_ call the proper method,

    > survey:::svymean.pps
    function (x, design, na.rm = FALSE, deff = FALSE, ...) 
    {
        if (inherits(x, "formula")) {
            mf <- model.frame(x, model.frame(design), na.action = na.pass)
            xx <- lapply(attr(terms(x), "variables")[-1], function(tt) model.matrix(eval(bquote(~0 + 
                .(tt))), mf))
            cols <- sapply(xx, NCOL)
    ....
    ....
        return(average)
    }
    <environment: namespace:survey>

Success!
