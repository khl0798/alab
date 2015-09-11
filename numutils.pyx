#!/usr/bin/env python

# Copyright (C) 2015 University of Southern California and
#                          Nan Hua
# 
# Authors: Nan Hua
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

__author__ = 'N.H.'

import numpy as np
cimport numpy as np 
cimport cython   

#==============================from mirnylib numutils=====================
#See details in Imakaev et al. (2012)
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
@cython.nonecheck(False)
def ultracorrectSymmetricWithVector(x,v = None,M=None,diag = -1, 
                                    tolerance=1e-5):
  """Main method for correcting DS and SS read data. Possibly excludes diagonal.
  By default does iterative correction, but can perform an M-time correction"""
  if M == None:
    M = 599
  totalBias = np.ones(len(x),np.float32)    
  if v == None: v = np.zeros(len(x),np.float32)  #single-sided reads    
  #x = np.array(x,np.double,order = 'C')
  cdef np.ndarray[np.float32_t, ndim = 2] _x = x
  cdef np.ndarray[np.float32_t, ndim = 1] s 
  v = np.array(v,np.float32,order = "C")        
  cdef int i , j, N
  N = len(x)       
  for iternum in xrange(M):         
    s0 = np.sum(_x,axis = 1)         
    mask = [s0 == 0]            
    v[mask] = 0   #no SS reads if there are no DS reads here        
    nv = v / (totalBias * (totalBias[mask==False]).mean())
    s = s0 + nv
    for dd in xrange(diag + 1):   #excluding the diagonal 
      if dd == 0:
        s -= np.diagonal(_x)
      else:
        dia = np.array(np.diagonal(_x,dd))                
        s[dd:] = s[dd:] -  dia
        s[:len(s)-dd] = s[:len(s)-dd] - dia 
    s = s / np.mean(s[s0!=0])        
    s[s0==0] = 1
    s -= 1
    s *= 0.8
    s += 1   
    totalBias *= s
         
    for i in range(N):
      for j in range(N):
        _x[i,j] = _x[i,j] / (s[i] * s[j])
       
    if M == 599:
      if np.abs(s-1).max() < tolerance:
        #print "IC used {0} iterations".format(iternum+1)
        break

                         
  #corr = totalBias[s0!=0].mean()  #mean correction factor
  #x  = x * corr * corr #renormalizing everything
  #totalBias /= corr
  return _x
#=====================================================================
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
@cython.nonecheck(False)
def diagnorm(A,countzero = False,norm = True):
    """ This function is to diagnol normalize matrix, 
        countzero defines if we want to count zero values when calculate diagnol mean or not
    """
    cdef int i,j,N,offset
    N = len(A)
    cdef np.ndarray[np.float32_t, ndim = 2] _A = A
    cdef np.ndarray[np.float32_t, ndim = 1] diagMean  = np.empty(N,np.float32)
    cdef np.ndarray[np.float32_t, ndim = 1] diagSum   = np.empty(N,np.float32)
    cdef np.ndarray[np.float32_t, ndim = 1] diagCount = np.empty(N,np.float32)
    for offset in range(N):
        diag = np.diagonal(_A,offset)
        if countzero:
            diagSum[offset]   = diag.sum()
            diagMean[offset]  = diag.mean()
            diagCount[offset] = len(diag)
        else:
            mask = np.flatnonzero(diag)
            if len(diag[mask]) == 0:
                diagSum[offset]   = 0
                diagMean[offset]  = 0
                diagCount[offset] = 0
            else:
                diagMean[offset]  = diag[mask].mean()
                diagSum[offset]   = diag[mask].sum()
                diagCount[offset] = len(diag[mask])
    if norm:
        for i in range(N):
            for j in range(N):
                offset = abs(i-j)
                if diagMean[offset] != 0:
                    _A[i,j] = _A[i,j] / diagMean[offset]
  
    return _A,diagMean,diagSum,diagCount

#======================================================
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
@cython.nonecheck(False)
def neighbourFmaximization(A,fmax):
    cdef int i,j,N,minfmax
    cdef np.ndarray[np.float32_t, ndim=2] _A = A 
    N = len(_A)
    for i in range(N):
        for j in range(N):
            minfmax = min(fmax[i],fmax[j])
            if (minfmax != 0) and (_A[i,j] != 0):
                _A[j,i] = _A[i,j] = min(_A[i,j]/minfmax, 1.0)
            else:
                _A[i,j] = _A[j,i] = 0
    return _A

#======================
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
@cython.nonecheck(False)
def powerLawSmooth(matrix,target,w=3,s=3,p=3):
    """
        Power law smoothing function
        Given a matrix and a tuple (x,y), compute the smoothed value of (x,y)
        Parameters
        ----------
        matrix: numpy 2D array
        target: tuple of (x,y)
        w:      int of the window size, the smoothing is computed using target +/- w
        s:      weight of the location deviation
        p:      power of the location deviation
    """
    cdef int x,y = target
    cdef int matrix_x,matrix_y = matrix.shape
    cdef float csum = 0.0
    cdef float divider = 0.0
    cdef int i,j
    cdef np.ndarray[np.float32_t, ndim=2] _matrix = matrix
    for i in range(max(-w,-x),min(w+1,matrix_x-x)):
        for j in range(max(-w,-y),min(w+1,matrix_y-y)):
            decay = 1 / (abs(s*i) ** p + abs(s*j) ** p + 1.0)
            csum += _matrix[x+i,y+j] * decay
            #print i,j
            divider += decay
  
    return csum/divider

#=====================
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.cdivision(True)
@cython.nonecheck(False)
def generateSummaryMatrix(A,summaryBinStart,summaryBinEnd,top):
    cdef int i,j,N
    cdef float bound
    N = len(summaryBinStart)
    cdef np.ndarray[np.float32_t, ndim=2] _A = A
    cdef np.ndarray[np.float32_t, ndim=2] X = np.empty((N,N),np.float32)
    for i in range(N):
        print "Filling X[%d] from A[%d] to A[%d]" % (i,summaryBinStart[i],summaryBinEnd[i]-1)
        for j in range(i,N):
            submatrix = _A[summaryBinStart[i]:summaryBinEnd[i],summaryBinStart[j]:summaryBinEnd[j]]
            bound = np.percentile(submatrix,100-top)
            X[i,j] = X[j,i] = np.mean(submatrix[submatrix >= bound])
  
    return X
#=======================
  