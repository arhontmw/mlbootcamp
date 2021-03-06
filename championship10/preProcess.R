getPreProcessedData = function (XL) {
  XL = XL[do.call(order, as.data.frame(XL)), ]
  n = nrow(XL)
  m = ncol(XL) - 1
  cnt = 1
  removed = rep(F, n)
  XA = matrix(NA, 0, m + 1)
  for (i in 2:(n+1)) {
    if (i > n || sum(XL[i, -(m + 1)] == XL[i - 1, -(m + 1)]) != m) {
      if (cnt > 15) {
        idxes = (i-cnt):(i-1)
        answers = XL[idxes, m + 1]
        o = sum(answers == 1)
        removed[idxes] = T
        
        prob = o / length(answers)
        prob = max(1/length(answers), min(prob, 1-1/length(answers)))
        XA = rbind(XA, c(XL[i - 1, -(m + 1)], prob))
      }
      cnt = 1
    } else {
      cnt = cnt + 1
    }
  }
  
  XL2 = XA
  for (i in 1:nrow(XL2))
    XL2[i, m + 1] = round(XL2[i, m + 1])
    
  list(
    XA = XA,
    XL = rbind(XL[!removed, ], XL2)
  )
}

correctPreProcessedAnswers = function (XL, X, Y) {
  XA = getPreProcessedData(XL)$XA
  for (i in 1:nrow(X)) {
    for (j in 1:nrow(XA)) {
      if (all(XA[j, -ncol(XA)] == X[i, ])) {
        Y[i] = XA[j, ncol(XA)]
        break
      }
    }
  }
  Y
}