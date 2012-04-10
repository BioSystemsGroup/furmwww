/*
 * IPRL - Vas object
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

#import "FlowLink.h"
#import "Solute.h"
#import "Vas.h"

#import <modelUtils.h>
#import <LocalRandom.h>

id <Symbol> In, Out;

@implementation Vas

// runtime methods

- stepPhysics
{
  [Telem debugOut: 3 printf: "%s::stepPhysics -- enter\n", 
         [[self class] getName]];

  /*
   * handle solute and created metabolite
   */
  id <Map> before=nil, after=nil;

  [self updateSoluteCount];

  if ( (pumpedMap != nil) 
       && ([pumpedMap getCount] > 0) ) {
    [pumpedMap deleteAll];
    [pumpedMap drop]; pumpedMap = nil;
  }

  before = [DMM countConstituents: solutes createIn: scratchZone];
  int pumpedNumber = [self pumpSolutes];
  [Telem debugOut: 5 printf: "pumpedNumber = %d\n", pumpedNumber];
  after = [DMM countConstituents: solutes createIn: scratchZone];

  /*
   * amount pumped = amount before pumping minus amount after
   */
  pumpedMap = [StatCalculator subtractMap: after from: before];

  if (after != nil) {
    [after deleteAll];
    [after drop]; after = nil;
  }
  if (before != nil) {
    [before deleteAll];
    [before drop]; before = nil;
  }

  [Telem debugOut: 3 printf: "%s::stepPhysics -- exit\n",
         [[self class] getName]];

  return self;
}

- (unsigned) calcCC
{
  id <ListIndex> edgeNdx;
  FlowLink *fl;
  unsigned myCC = 0;

  if ( flow == Out ) {
    _cc_ = perfusateFlux;
  } else {
    edgeNdx = [toList listBegin: [self getZone]];
    while ( ([edgeNdx getLoc] != End)
            && ((fl = [edgeNdx next]) != nil) ) {
      myCC += [fl getCC];
    }
    [edgeNdx drop]; edgeNdx = nil;
  
    _cc_ = myCC;
    _ccNeedsUpdate_ = NO;
  }

  return _cc_;
}

/*
 * [Vas -updateSoluteCount] - creates new solute to pump in (if this
 * is an inflow) and measures old solute received from the sinusoids.
 */
static int solCount=0L;
- updateSoluteCount
{
  unsigned ndx;

  if(createdSolute != nil) [createdSolute removeAll];

  if (flow == In && soluteFlux > 0) {
    // create flux new solute objects -- later, we'll recycle retired
    id <List> tmpSolutes = [List create: scratchZone];
    Solute *newSol;
    id <SoluteTag> sType = nil;
    id <Double> ratio = nil;
    id <MapIndex> bcNdx = nil;

    if (bolusContents == nil)
      raiseEvent(InternalError, 
                 "Vas::updateSoluteCount() -- bolusContents == nil!!!\n");
    if ([bolusContents getCount] <= 0L)
      raiseEvent(InternalError,
                 "Vas::updateSoluteCount() -- bolusContente is empty!\n");


    // create a list
    bcNdx = [bolusContents mapBegin: scratchZone];
    while ( ([bcNdx getLoc] != End)
            && ((ratio = [bcNdx next: &sType]) != nil) ) {
      unsigned total = soluteFlux * [ratio getDouble];
      for ( ndx=0 ; ndx<total ; ndx++ ) {
        newSol = [Solute create: [self getZone]];
        [newSol setNumber: solCount];
        solCount++;
        [newSol setType: sType];

        // increment totals
        id <Integer> solAmount = [totalSolute at: sType];
        if (solAmount == nil)
          [totalSolute at: sType 
                       insert: [Integer create: [self getZone] 
                                        setInt: 1]];
        else
          [[totalSolute at: sType] increment];
        totalSoluteCreated++;

        [tmpSolutes addLast: newSol];
      }
    }
    createdSolute = [tmpSolutes copy:scratchZone];
    [bcNdx drop]; bcNdx = nil;

    // transfer the elements from the tmp list to the real list
    [self slice: [tmpSolutes getCount] solutesFrom: tmpSolutes to: solutes];

    [tmpSolutes drop]; tmpSolutes = nil;
    
    [Telem debugOut: 5
           printf: "Vas::updateSoluteCount() New solute created.  soluteFlux = %d\n",
           soluteFlux];

  } else  if (flow == Out) {
    if (totalSolute != nil) { [totalSolute drop]; totalSolute = nil; }
    totalSolute = [DMM countConstituents: retiredSolute createIn: [self getZone]];
    totalSoluteRetired = [retiredSolute getCount];

    /*
     * bile is handled separately
     */
    unsigned bileCurr = [bile getCount];
    bileFlux = bileCurr - bilePred;
    bilePred = bileCurr;
  }

  return self;
}

- (id <List>)getCreatedSolutes
{
   return createdSolute;
}

#define USE_PVT YES
/*
 * pumpSolutes - slices the solutes list and pushes that subset
 *               either into the sinusoids or out of the system.
 */
- (int) pumpSolutes
{
  unsigned numTaken=0;
  unsigned old=0, new=0;

  old = [solutes getCount];

  // no need to do all this if there's nothing to pump
  if (old <= 0U) return 0; 

  if (flow == In) {
    if (USE_PVT) {
      // first decrement timers for the solute in the PVT
      [pvt decrementAll];
      // get a list of the ones we can move
      id <List> freeSolutes = [pvt whichCanBeMoved: solutes];

      id <List> moved = [self distributeSolutesFrom: freeSolutes];

      numTaken = [moved getCount];
      [pvt removeSolutes: moved];

      // take the moved solutes out of the main data struct
      list_subtract(solutes, moved, YES);

      [moved drop]; moved = nil;
      [freeSolutes drop]; freeSolutes = nil;
    } else {
      //numTaken += [self distributeSolutesFrom: solutes];
      id <List> taken = [self distributeSolutesFrom: solutes];
      numTaken = [taken getCount];
      [taken removeAll]; [taken drop]; taken = nil;
    }
  } else if (flow == Out) {

    numTaken = 
      [self slice: perfusateFlux solutesFrom: solutes to: retiredSolute];

  } else 
   raiseEvent(InvalidOperation, 
               "Flow direction for this Vas has not been set.");

  new = [solutes getCount];

  if ( numTaken != old-new )
    raiseEvent(InternalError, "%s(%d:%p) -- numTaken != old-new: perfusateFlux = %d, numTaken = %d, old = %d, new = %d\n",
               [[self getClass] getName], myNumber, self, perfusateFlux, numTaken, old, new);
  return numTaken;
}

- (id <List>) takeSolutesFrom: (id <List>) fl {
  unsigned numTaken=0;
  id <List> taken = [fl copy: scratchZone];

  // rule for how many solutes go transfer
  numTaken = [self slice: [self getCC] solutesFrom: fl to: solutes];

  // remove the solute left in fl from the original fl
  list_subtract(taken, fl, YES);

  return taken;
}

/*
 * override from LiverNode so that bile solute isn't mixed with 
 * central vein solute
 */
- (void) takeMetabolite: (Solute *) m
{
  [Telem debugOut: 3 printf: "[%s(%p) -takeMetabolite: %s(%p)] -- |bile| = %d\n",
         [[self getClass] getName], self, [[m getClass] getName], m, [bile getCount]];
  [bile addLast: m];
}

- stepBioChem {
  return self;
}

// observation methods
- (void) describe: outputCharStream withDetail: (short int) d
{
  char buffer[82];
  id <OutputStream> os = outputCharStream;

  sprintf(buffer, "%s:%d (type = %s, |solutes| = %3d, %s = %3d, |bile| = %3d)\n", 
          [[self class] getName],
          myNumber, [flow getName], [solutes getCount], 
          (flow == In ? "|totalSoluteCreated|" : "|retiredSolute|"),
          (flow == In ? totalSoluteCreated : totalSoluteRetired),
	  [bile getCount]);
  [os catC: buffer];

  if (totalSolute != nil && d > 1) {
    id <Symbol> type = nil;
    id <Integer> val = nil;
    id <MapIndex> tNdx = [totalSolute mapBegin: scratchZone];
    while (([tNdx getLoc] != End)
           && ( (val = [tNdx next: &type]) != nil) ) {
      if (type == nil) 
        raiseEvent(InternalError, 
                   "%s(%p)::describe() -- totalSolute contains bad data.\n",
                   [[self class] getName], self);
      [os catC: [type getName]];
      [os catC: (flow == In ? 
                 " created = " : 
                 " retired = ")];
      [os catC: [val intStringValue]]; [os catC: " "];
    }
    [os catC: "\n"];
    [tNdx drop]; tNdx = nil;
  } // else do nothing
}

- (void) setSnaps: (BOOL) s
{
  // do nothing for now -- later use this to generate texture for Vasa
}
- (void) writeToPNG
{
  // do nothing for now -- later use this to generate texture for Vasa
}

- (id <Map>) getAmountMetabolized
{
  return nil; // no metabolization in generic Vasa
}

// accessor methods

/**
 * [Vas -getFlux] returns a map <Symbol, Integer> of the solute pumped
 * through the Vas during this cycle.
 */
- (id <Map>) getFlux
{
  return pumpedMap;
}

- (unsigned) getBileFlux
{
  return bileFlux;
}

- (id <List>) getRetiredSolutes
{
  return retiredSolute;
}

// construction methods

+ create: (id <Zone>) zone flow: (id <Symbol>) flowDir 
perfFlux: (unsigned) pf solFlux: (unsigned) sf
{
  Vas *newObj;
  newObj = [self createBegin: zone];
  newObj->flow = flowDir;
  /*
   * perfusateFlux - 
   *    This is in units of perfusate particles per step.  But,
   *    under the assumption that perfusate is everywhere, it's 
   *    really "potential grid points" per step.  The parent of 
   *    the vasa must translate from things like:
   *        litres/second => holes/step
   *        moles/second  => particles/step
   */
  newObj->perfusateFlux=pf;  // holes/second
  newObj->soluteFlux=sf;   // units per step
  newObj = [newObj createEnd];
  return newObj;
}

+ createBegin: aZone
{
  Vas *newObj;
  newObj = [super createBegin: aZone];
  newObj->totalSoluteCreated=0U;
  newObj->totalSoluteRetired=0U;
  newObj->totalSolute = [Map create: aZone];
  newObj->pumpedMap = nil;
  newObj->retiredSolute = [List create: aZone];
  newObj->perfusateFlux=10U;
  newObj->pvt = [PVT create: aZone];
  newObj->bile = [List create: aZone];
  newObj->bilePred = 0U;
  newObj->bileFlux = 0U;
  return newObj;
}

- setFlow: (id <Symbol>) flowDir
{
  flow = flowDir;
  return self;
}

- setPerfFlux: (unsigned) pf
{
  perfusateFlux = pf;
  return self;
}

/*
 * setSoluteFlux:withContents: -- defines the attributes (number of
 * solute particles, constituent types and ratios) for the bolus
 * injection
 */
- setSoluteFlux: (unsigned) sf withContents: (id <Map>) bc
{
  [Telem debugOut: 5 printf: "Vas::setSoluteFlux() soluteFlux = %d\n",sf];

  assert(bc != nil);
  soluteFlux=sf;

  assert([bc getCount] > 0L);
  bolusContents = bc;

  return self;
}

@end

