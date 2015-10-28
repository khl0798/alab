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

# Prerequests:
# IMP 2.4 is required for this module

__author__ = 'N.H.'

import numpy as np
import IMP
import IMP.core
import IMP.container
import IMP.algebra

def beadDistanceRestraint(model,chain,bead1,bead2,dist,kspring=1):
    """
        get distance upper bound restraint to bead1 and bead2
        Return restraint 
        Parameters:
        -----------
        model:      IMP.Model class
        chain:      IMP.container.ListSingletonContainer class
        bead1,bead2:bead id
        dist:       distance upper bound
        kspring:    harmonic constant k
    """
    restraintName = "Consecutive Bead (%d,%d):%f" % (bead1,bead2,dist)
    ds = IMP.core.SphereDistancePairScore(IMP.core.HarmonicUpperBound(dist,kspring))
    pr = IMP.core.PairRestraint(model,ds,(chain.get_particles()[bead1],chain.get_particles()[bead2]),restraintName)
    return pr

def consecutiveDistanceByProbability(r1,r2,p,xcontact=2):
    """
        Upper bound distance constraints for consecutive domains
        return surface to surface distance.
        parameters:
        -----------
        r1,r2:     Radius for beads
        p:         Probability for contact
        xcontact:  scaling of (r1+r2) where a contact is defined. By default, 
                   center to center distance D = 2*(r1+r2) is defined as contact.
    """
    if p > 0:
        d = (r1+r2)*(1. + (xcontact**3-1)/p)**(1./3.)
    else:
        d = 100*(r1+r2) # just a big number
    return d-r1-r2 # surface to surface distance

def addConsecutiveBeadRestraints(model,chain,probmat,beadrad,lowprob=0.1):
    """
        calculate distance constraints to consecutive beads
        Parameters:
        -----------
        model:      IMP.Model class
        chain:      IMP.container.ListSingletonContainer class
        probmat:    alab.matrix.contactmatrix class for probablility matrix
        beadrad:    list like, radius of each bead
        lowprob:    Min probility for consecutive beads
    """
    consecRestraints = []
    nbead = len(probmat)
    for i in range(nbead-1):
        if probmat.idx[i]['chrom'] != probmat.idx[i+1]['chrom']:
            continue
        p = max(probmat.matrix[i,i+1],lowprob)
        b1 = i;b2 = i+1
        b3 = b1 + nbead
        b4 = b2 + nbead
        #calculate upper bound for consecutive domains
        consecDist = consecutiveDistanceByProbability(beadrad[b1],beadrad[b2],p)
           
        # set k = 10 to be strong interaction
        rs1 = beadDistanceRestraint(model,chain,b1,b2,consecDist,kspring=10) 
        rs2 = beadDistanceRestraint(model,chain,b3,b4,consecDist,kspring=10) 
           
        #push restraint into list
        consecRestraints.append(rs1)
        consecRestraints.append(rs2)
        
        if i>0 and probmat.idx[i]['chrom'] == probmat.idx[i-1]['chrom'] and probmat.idx[i]['flag']!="domain" and probmat.idx[i-1]!="gap":
            p = max(probmat.matrix[i-1,i+1],lowprob)
            b1 = i-1;b2 = i+1
            b3 = b1 + nbead
            b4 = b2 + nbead
            consecDist = consecutiveDistanceByProbability(beadrad[b1],beadrad[b2],p)
            rs1 = beadDistanceRestraint(model,chain,b1,b2,consecDist,kspring=10) 
            rs2 = beadDistanceRestraint(model,chain,b3,b4,consecDist,kspring=10) 
            consecRestraints.append(rs1)
            consecRestraints.append(rs2)
        #---
    #-------
    
    return consecRestraints


        
        
          