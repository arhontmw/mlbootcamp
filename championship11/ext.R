jgc <- function() 
  .jcall("java/lang/System", method = "gc")

unnameMatrix = function (XX) 
  as.matrix(unname(data.matrix(XX)))

extendCols = function (XX, idxes=NULL, pairs=F) {
  if (is.vector(idxes)) {
    XX = XX[, which(1 == idxes)]
  }
  
  if (is.logical(pairs) && pairs || length(pairs) > 1) {
    sz = ncol(XX)
    for(i in 1:sz) {
      for(j in 1:sz) {
        if (i == j)
          next
        if (i > j)
          XX = cbind(XX, XX[, i] * XX[, j])
        XX = cbind(XX, XX[, i] / (XX[, j] - min(XX[, j] + 1)))
      }
    }
    if (length(pairs) > 1) {
      XX = XX[, which(1 == pairs)]
    }
  }
  
  XX
}

extendXYCols = function (XL, idxes, pairs) {
  X = XL[, -ncol(XL), drop=F]
  Y = XL[, ncol(XL), drop=F]
  X = extendCols(X, idxes, pairs)
  cbind(X, Y)
}

eext = function (X) {
  R = matrix(NA, nrow=nrow(X), ncol=0)
  for(i in 1:nrow(gl.mat)) {
    thr = gl.mat$threshold[i]
    col = gl.mat$col[i]
    R = cbind(ifelse(X[, col] < thr, 0, 1), R)
  }
  R
}

my.extendedColsTrain = function (XL, trainFunc, idxes=NULL, extra=F, pairs=F, newdata=NULL) {
  featuresNumber = ncol(XL) - 1
  
  if (extra)
    XL = cbind(XL[,-ncol(XL)], eext(XL), XL[,ncol(XL)])
  
  XL = extendXYCols(XL, idxes, pairs)
  
  proc = function (X) {
    if (is.null(X))
      return(X)
    
    if (ncol(X) != featuresNumber)
      stop('invalid number of columns')
    
    if (extra)
      X = cbind(X, eext(X))
    
    X = extendCols(X, idxes, pairs)
    X
  }
  model = trainFunc(XL, newdata=proc(newdata))
  
  function (X) model(proc(X))
}

my.normalizedTrain = function (XL, trainFunc, newdata=NULL) {
  m = ncol(XL) - 1
  means = rep(NA, m)
  sds = rep(NA, m)
  for (j in 1:m) {
    means[j] = mean(XL[, j])
    sds[j] = sd(XL[, j])
    XL[, j] = (XL[, j] - means[j]) / sds[j]
  }
  
  proc = function (X) {
    if (is.null(X))
      return(X)
    
    for (j in 1:m)
      X[, j] = (X[, j] - means[j]) / sds[j]
    X
  }
  
  model = trainFunc(XL, newdata=proc(newdata))
  function (X) model(proc(X))
}

my.log = function(x, base=exp(1)) {
  for(i in 1:length(x)) {
    if (x[i] > 0)
      x[i] = log(x[i], base)
    else if (x[i] < 0)
      x[i] = -log(-x[i], base)
  }
  x
}

my.roundAns = function (X, ans) {
  if (is.vector(ans)) {
    nrows = length(ans) / nrow(X)
    mat = matrix(ans, nrow=nrows, byrow=F)
  } else {
    nrows = ncol(ans)
    mat = matrix(c(as.matrix(ans)), nrow=nrows, byrow=T)
  }
  
  if (length(ans) == nrow(X)) {
    print(c(min(ans), max(ans)))
    ans = pmax(0, pmin(nrows - 1, round(ans)))
    return( ans )
  }
  
  foreach(x=mat, .combine=c) %do% { 
    which.max(x) - 1 
  }
}

my.roundedTrain = function (XL, trainFunc, newdata=NULL) {
  model = trainFunc(XL, newdata=newdata)
  function (X) {
    ans = model(X)
    my.roundAns(X, ans)
  }
}

my.checkedRangeTrain = function (XL, trainFunc, newdata=NULL) {
  model = trainFunc(XL, newdata=newdata)
  function (X) {
    ans = model(X)
    if (is.vector(ans))
      stop('unsupported')
    
    for(col in 1:ncol(X)) {
      mn = min(XL[, col])
      mx = max(XL[, col])
      len = mx - mn
      alpha = 0.0
      mx = mx + len * alpha
      mn = mn - len * alpha
      ans[which(X[, col] < mn | X[, col] > mx), col] = 0
    }
    ans
  }
}