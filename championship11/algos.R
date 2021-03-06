my.set.seed = function(seed) {
  my.tmp.nextSeed <<- sample(1:10^5, 1)
  set.seed(seed)
}

my.restore.seed = function() {
  set.seed(my.tmp.nextSeed) 
}

my.boot = function (XLL, train, aggregator, iters=10, rowsFactor=0.3, replace=F, nthread=1) {
  n = nrow(XLL)
  
  if (nthread > 1) {
    cl <- makeCluster(nthread)
    registerDoParallel(cl)
  }
  
  algos = foreach(it=1:iters, .export=my.dopar.exports, .packages=my.dopar.packages) %do% {
    sampleIdxes = sample(n, rowsFactor*n, replace=replace)
    
    XK = XLL[-sampleIdxes, ]
    XL = XLL[sampleIdxes, ]  
    
    if (it %% 20 == 0)
      gc()
    
    train(XL, XK)
  }
  
  if (nthread > 1) {
    stopCluster(cl)
  }
  
  if (is.character(aggregator) || is.factor(aggregator)) {
    do.call(as.character(aggregator), list(algos))
  } else if (is.function(aggregator)) {
    aggregator(algos)
  } else {
    stop('invalid aggregator type')
  }
}

error.accuracy = function (act, pred) {
  mean(act != pred)
}

validation.tqfold.enumerate = function (callback, XLL, folds=5, iters=10) {
  resamples = matrix(NA, nrow=iters, ncol=nrow(XLL))
  for (i in 1:iters) {
    resamples[i, ] = sample(nrow(XLL))
  }
  
  for (it in 1:iters) {
    perm = resamples[it, ]
    for (fold in 1:folds) {
      foldLength = floor(nrow(XLL) / folds)
      foldStart = (fold - 1) * foldLength
      foldEnd = foldStart + foldLength - 1
      
      controlIdxes = perm[foldStart:foldEnd]
      XK = XLL[controlIdxes, ]
      XL = XLL[-controlIdxes, ]  
      
      callback(XL, XK, it, fold)
    }
  }
}

validation.tqfold = function (XLL, teachFunc, folds=5, iters=10, verbose=F, use.newdata=F, seed=0) {
  XKerr = c()
  
  nrows = length(unique(XLL[, ncol(XLL)]))
  tmp.errorMat <<- matrix(0, nrows, nrows)
  draw = function() {
    if (verbose) {
      df = expand.grid(act = 0:(nrows - 1), pred = 0:(nrows - 1))
      df$value <- c(tmp.errorMat)
      df$color <- c(ifelse(diag(nrows) == 1, 'f', 'o'))
      
      g <- (ggplot(df, aes(act, pred, colour=color)) 
            + geom_point(aes(size = value)) 
            + theme_bw() 
            + theme(legend.position="none")
            + xlab("Actual") 
            + ylab("Prediction")
            + scale_colour_manual(breaks=df$color, values=c("black", "green", "red"))
            + scale_size_continuous(range=c(10,30))
            + geom_text(aes(label=value, color=rep('black', nrows^2)))
      )
      print(g)
    }
  }
  
  validation.tqfold.enumerate(function (XL, XK, it, fold) {
    if (seed > 0) {
      set.seed(seed)
      #seed <<- 0
    }
    
    act = XK[, ncol(XL)]
    if (use.newdata) {
      algo = teachFunc(XL, newdata=XK[, -ncol(XL)])
      pred = algo(XK[, -ncol(XL)])
    } else {
      algo = teachFunc(XL)
      pred = algo(XK[, -ncol(XL)])
    }
    
    e = error.accuracy(act, pred)
    
    for(i in 1:length(act)) {
      tmp.errorMat[act[i] + 1, pred[i] + 1] <<- tmp.errorMat[act[i] + 1, pred[i] + 1] + 1
    }
    
    XKerr <<- c(XKerr, e)
    
    if (verbose)
      print(paste0('tqfold ', it, '-', fold, '/', iters, '-', folds, ' cur=', e, ' mean=', mean(XKerr), ' sd=', sd(XKerr)))
    
    draw()
    
  }, XLL, folds=folds, iters=iters)
  
  XKerr
}

my.gridSearch = function (XLL, teach, grid, folds=7, iters=6, verbose=F, use.newdata=F, folds.seed=777, train.seed=2) {
  minE = 1e10
  for (i in 1:nrow(grid)) {
    params = grid[i, ]
    
    my.set.seed(folds.seed)
    e = mean(validation.tqfold(XLL, teach(params), folds=folds, iters=iters, verbose=verbose, use.newdata=use.newdata, seed=train.seed))
    my.restore.seed()
    params$ACCURACY = e
    
    print(params)
    
    if (e < minE) {
      minE = e
      selParams = params
    }
    gc()
  }
  print('-------------------------------')
  print(selParams)
}