/*
 * SinusoidalSpace - Data structure indexing solute inside a
 * Sinusoidal Segment
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <assert.h>
#include <math.h>
#include <float.h>
#import <collections.h>
#import <simtools.h>
#import <modelUtils.h>
#import <LocalRandom.h>
#import "Sinusoid.h"
#import "SinusoidalSpace.h"
@implementation SinusoidalSpace

- createEnd
{
  SinusoidalSpace * obj = [super createEnd];
  obj->jumpProb = 0.05;
  obj->core = [FlowTube create: [self getZone] length: obj->ysize
                        flowRate: 3U 
                        area: [SinusoidalSpace calcAreaFromCirc: obj->xsize]];
  [obj->core setParent: self];

  obj->volume = [obj calcVolumeFromCirc: obj->xsize andLength: obj->ysize];
  return obj;
}

- (void) setOutSpace: (MiddleSpace *) oSpace 
{
  self->outSpace = oSpace;
}

- add: (id <List>) il toCoreAtY: (unsigned) y {
  id obj=nil;
  id <ListIndex> inNdx = [il listBegin: scratchZone];
  //  id <List> yList = [core atOffset: y];

  while ( ([inNdx getLoc] != End) 
          && ((obj = [inNdx next]) != nil)) {
    //    [yList addLast: obj];
    [core storeObject: obj at: y];
  }
  [inNdx drop]; inNdx = nil;
  return self;
}

#define PROBV_MAX_ITER 5
- setFlowFromTurbo: (double) pv
{
  unsigned count=0;
  unsigned gridNdx=hold;
  double epsilon=0.0001;
  VectorMoore *newFlowVec=nil;
  double probH=NAN, probC=NAN, probHGivenNotC=NAN, delta=NAN;


  newFlowVec = [VectorMoore create: [self getZone]];
  [newFlowVec setProbVFromTurbo: pv];

  // modify the probabilities in the flow space to accomodate for core

  // first estimate of probH
  [Telem debugOut: 6 printf: "SinusoidalSpace::setFlowFromTurbo: pobV[hold]=%f \n",newFlowVec->probV[hold]];
  probH = newFlowVec->probV[hold];
  assert(probH <= 1.0F);
  assert(probH >= 0.0F);

  // first estimate of probC
  probC = probH;
  while (count < PROBV_MAX_ITER) {
    // calc conditional prob P(h|~c)
    [Telem debugOut: 6 printf: "SinusoidalSpace::setFlowFromTurbo: probC=%f, probH=%f  \n",probC,probH];
    probHGivenNotC = probH * (1.0F - probC);
    assert(probHGivenNotC <= 1.0F);
    assert(probHGivenNotC >= 0.0F);

    delta = fabs(probC - probHGivenNotC);

    if (delta < epsilon) break;
    // new probC
    probC = probHGivenNotC;
    // new probV sharing delta over moore neighborhood
    probH -= delta/9.0L;
    count++;
  }
  for ( gridNdx=hold ; gridNdx<=southEast ; gridNdx++ ) {
    newFlowVec->probV[gridNdx] -= delta/9.0L;
  }
  jumpProb = probC;

  if (count >= PROBV_MAX_ITER) {
    [WarningMessage 
      raiseEvent: "%s(%p)::setFlowFromTurbo:ProbV adj for did not converge.",
      [[self class] getName], self];
    // reset to default
    [newFlowVec setProbVFromTurbo: pv];
  }

  defaultFlowVector = newFlowVec;
  [flow fastFillWithObject: defaultFlowVector];
  [core setBackProb: newFlowVec->probV[north] 
        fwdProb: newFlowVec->probV[south]
        stayProb: newFlowVec->probV[hold]];
  return self;
}

/*
 * flow() -- apply the vector at each point in "flow" to the object
 *           at each point in our lattice.
 */
- flow
{
  [self jump2Core];
  [self jump2Rim];
  [super flow];
  [core flow];

  return self;
}

/*
 * jump2Core() -- for each solute check against probability to go to core
 */
- jump2Core
{
  Vector2d *posVec=nil;
  Solute *solute=nil;
  double rnd=NAN;
  id <List> gridRemoval=[List create: scratchZone];
  id <ListIndex> rmNdx=nil;
  id <MapIndex> solNdx = [posMap mapBegin: scratchZone];

  while (([solNdx getLoc] != End) 
         && ((posVec = (Vector2d *)[solNdx next: &solute]) != nil)) {
    rnd = [uDblDist getDoubleWithMin: 0.0F withMax: 1.0+FLT_MIN];
    if (rnd <= jumpProb) {
      unsigned soluteY = posVec->y;
      // put it in core at y
      //      [[core atOffset: soluteY] addLast: solute];
      [core storeObject: solute at: soluteY];
      // schedule for removal from grid to keep PosMap safe
      [gridRemoval addLast: solute];
    }
  }
  [solNdx drop]; solNdx = nil;

  rmNdx = [gridRemoval listBegin: scratchZone];
  while (([rmNdx getLoc] != End)
         && ((solute = [rmNdx next]) != nil) ) {
    unsigned soluteX, soluteY;
    posVec = [posMap at: solute];
    soluteX = posVec->x;
    soluteY = posVec->y;
    // remove it from grid -- careful!  this drops the vector    
    // ignore the return, it's now indexed by the core
    [self removeObjectAtX: soluteX Y: soluteY];
  }
  [rmNdx drop]; rmNdx = nil;
  [gridRemoval drop]; gridRemoval = nil;

  return self;
}

- jump2Rim
{
  unsigned coreNdx=0;
  id <List> options = [List create: scratchZone];
  Solute *solute=nil;

  for ( coreNdx=0 ; coreNdx < ysize-1 ; coreNdx++ ) {
    id <List> yList = [core->tube atOffset: coreNdx];
    // take the first circ/area elements of a permutation
    id <List> jumping = [List create: scratchZone];
    id <ListIndex> jumpNdx=nil;
    unsigned nearRim=0;
    float c2a = xsize/core->area;
    if (c2a > 1.0) c2a = 1.0;
    nearRim = c2a * [yList getCount];    
    [NSelect select: nearRim from: yList into: jumping];
    jumpNdx = [jumping listBegin: scratchZone];
    while (([jumpNdx getLoc] != End)
           && ((solute = [jumpNdx next]) != nil)) {
      double rnd = [uDblDist getDoubleWithMin: 0.0 withMax: 1.0+FLT_MIN];

      if (rnd < jumpProb) {
        // try to find a place to move it to
        unsigned long xndx=0;
        // assemble a collection of empty x-spots
        for ( xndx=0 ; xndx<xsize ; xndx++ ) {
          if ([self getObjectAtX: xndx Y: coreNdx] == nil) {
            [options addLast: (void *)xndx];
          }
        }
        if ([options getCount] > 0) {
          unsigned newX;
          // pick a random empty spot
          newX = (unsigned)(unsigned long)
            [options atOffset: [uUnsDist getUnsignedWithMin: 0 
                                         withMax: [options getCount]-1]];
          // and move the solute there
          [yList remove: solute];
          [self putMobileObject: solute atX: newX Y: coreNdx];
          [options removeAll];
        }
      } // else do nothing
    }
    [jumping drop]; jumping = nil;
    [jumpNdx drop]; jumpNdx = nil;
  }
  [options drop]; options = nil;
  return self;
}






- (void) setCoreFlowRate: (unsigned) cfr
{
  assert (cfr >= 1);
  core->flowRate = cfr;
}



/*
 * pass to my parent (a Sinusoid/LiverNode) if called on me
 */
- (unsigned) slice: (unsigned) n solutesFrom: (id <List>) fl to: (id <List>) tl
{
  return [_parent slice: n solutesFrom: fl to: tl];
}
- (BOOL) findOutFlowFor: obj
{
  return [_parent findOutFlowFor: obj];
}



+ (unsigned) calcAreaFromCirc: (unsigned) c {
  unsigned retVal;
  if ( c <= 4.0*M_PI) return 1U; // minimum is 1
  double val = pow((double)c,2.0)/(4.0*M_PI);
  if ( (val-floor(val)) <= 0.5) retVal = (unsigned)floor(val);
  else retVal = (unsigned) ceil(val);
  return retVal;
}  

- (unsigned) calcParaboloid {
  double vol = M_PI
    * pow((double)[SinusoidalSpace calcAreaFromCirc: xsize],2.0) 
    * (double)ysize/2.0;
  if (vol-floor(vol) <= 0.5) vol=floor(vol);
  else vol=ceil(vol);
  return (unsigned)vol;
}

/*
 * calcVolume()
 *
 */
- (unsigned) calcVolumeFromCirc: (unsigned) c andLength: (unsigned) h {
  unsigned retVal;
  double val = pow((double)c,2.0)/(4.0*M_PI);
  val = val*(double)h;
  if ( (val-floor(val)) <= 0.5) retVal = (unsigned)floor(val);
  else retVal = (unsigned) ceil(val);
  return retVal;
}

- (unsigned) getVolume {
  return volume;
}

- (void) describe: outputCharStream withDetail: (short int) d
{
  id <OutputStream> os = outputCharStream;
  id <Integer> tmpInt = [Integer create: scratchZone setInt: 0L];
  [os catC: "\tsSpace.solute: (core:"];

  // get number of solute in the core
  unsigned coreCount = [core countObjects];
  [os catC: [[tmpInt setInt: coreCount] intStringValue]];

  [os catC: ", rim:"];
  [os catC: [[tmpInt setInt: [posMap getCount]] intStringValue]];
  [os catC: ") "];

  [tmpInt drop]; tmpInt = nil;
}

@end
