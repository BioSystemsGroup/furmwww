/*
 * IPRL - Cell object
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "Solute.h"
#import "Binder.h"
#import <LocalRandom.h>
#import "Cell.h"
#import "protocols.h"
#import "../ExperAgent.h"
@implementation Cell

- (void) step
{
  Solute *s = nil;
  Binder *b = nil;
  step = getCurrentTime(); 

  // handle bindings
  id <List> uSRemoves = nil;
  id <ListIndex> sNdx = [unboundSolute listBegin: scratchZone];
  while ( ([sNdx getLoc] != End)
          && ( (s = [sNdx next]) != nil) ) {
    if ([unboundBinders getCount] > 0 ) {

      b = [unboundBinders atOffset: [uUnsDist
                                      getUnsignedWithMin: 0
                                      withMax: [unboundBinders getCount]-1]];

      double attachDraw = [uDblDist getDoubleWithMin: 0.0F
                                    withMax: 1.0F];
      // if s is non-nil, not a metabolite, and no other b is attached to it
      if (s != nil 
	  && (strcmp([[s getType] getName], "Metabolite") != 0)
          && attachDraw < bindProb) {

        [Telem debugOut: 3 printf: "%s(%p) -- binding <%s(%p), %s(%p)>, attachDraw = %lf, bindProb = %f\n",
               [[self getClass] getName], self, 
               [[b getClass] getName], b,
               [[s getClass] getName], s, attachDraw, bindProb];


        [b attachTo: s];
          
        //[self scheduleBinder: b toReleaseAt: step+[b getBindCycles]];
        [self scheduleBinder: b toReleaseAt: step+bindCycles];
          
        [bound at: b insert: s];
        // schedule to remove this b from unboundBinders
        if (uSRemoves == nil) uSRemoves = [List create: scratchZone];
        [uSRemoves addLast: s];
        [unboundBinders remove: b];
      }
    } // end if ([unboundBinders getCount] > 0 ) {
  } // end loop over unbound solute
  [sNdx drop]; sNdx = nil;

  // do the actual removal safely
  if (uSRemoves != nil) {
    sNdx = [uSRemoves listBegin: scratchZone];
    while ( ([sNdx getLoc] != End)
	    && ( (s = [sNdx next]) != nil) ) {
      [unboundSolute remove: s];
    }
    [sNdx drop]; sNdx = nil;
    [uSRemoves removeAll];
    [uSRemoves drop]; uSRemoves = nil;
  }

}

- (id) setParent: (id) p
{
  _parent = p;
  return self;
}
- setNumber: (int) n
{
  myNumber = n;
  return self;
}
- (void) setBindingProb: (float) bp
{
  assert( 0.0F <= bp && bp <= 1.0F);
  bindProb = bp;
}


- (int) getNumber
{
  return myNumber;
}

- (id) getMobileObject
{
  id obj = nil;
  if ([unboundSolute getCount] > 0) {
    obj = [unboundSolute getFirst];
  }
  return obj;
}

- (id) removeMobileObject: (id) anObj
{
  id obj = nil;

  if ( solute != nil ) {
    id <SoluteTag> anObjType = [anObj getType];

    if ([anObjType isMembraneCrossing]) { 
     obj = [solute remove: anObj];
      if ([unboundSolute contains: anObj])
        [unboundSolute remove: anObj];
    }
  }
  return obj;
}

- (BOOL) putMobileObject: (id) anObj
{
  BOOL retVal = NO;
  if ( solute == nil )
    solute = [List create: [self getZone]];

  id <SoluteTag> anObjType = [anObj getType];

  if ([anObjType isMembraneCrossing]) {
    [solute addLast: anObj];
    [self addToUnboundSolute: anObj];
    retVal = YES;
  }
  // return YES for success
  return retVal;
}

- (id <Map>) countMobileObjects: (id <Zone>) aZone
{
  static id <Symbol> boundSymbol = nil;
  if (boundSymbol == nil) 
    boundSymbol = [Symbol create: globalZone setName: "Bound"];

  if (solute == nil)
    solute = [List create: [self getZone]];

  id <Map> count = nil;
  count = [DMM countConstituents: solute createIn: aZone];

  // add in an entry showing the number of bound mobile objects
  if (count != nil && [bound getCount] > 0)
    [count at: boundSymbol
           insert: [Integer create: aZone setInt: [bound getCount]]];

  return count;
}

- (void) putBinder: (id) e
{
  assert(e != nil);
  [binders addLast: e];
  [unboundBinders addLast: e];
  [e setParentCell: self];
}

- (id) removeBinder: (id) e
{
  assert(e != nil);
  if ([unboundBinders contains: e])
    [unboundBinders remove: e];
  return [binders remove: e];
}

- createEnd
{
  Cell *obj = [super createEnd];
  obj->solute = [List create: [self getZone]];
  obj->unboundSolute = [List create: [self getZone]];
  obj->bound = [Map create: [self getZone]];
  obj->binders = [List create: [self getZone]];
  obj->unboundBinders = [List create: [self getZone]];
  obj->bindProb = 0.5F;
  obj->_removeList_ = [List create: [self getZone]];

  // dynamic schedule for handling binder activity
  // activated in the ArtModel's activity later.
  obj->cellSchedule = [[[Schedule createBegin: [self getZone]] setAutoDrop: YES] createEnd];
  
  return obj;
}

- (void) createBindersMin: (unsigned) min max: (unsigned) max
           withBindCycles: (unsigned) bc
{
  assert(min > 0);
  assert(max >= min);
  assert(bc >= 0);
  bindCycles = bc;
  unsigned numBinders = [uUnsDist getUnsignedWithMin: min withMax: max];
  int ndx = 0L;
  for ( ndx=0 ; ndx<numBinders ; ndx++ ) {
    Binder * b = [Binder create: [self getZone]];
    //[b setBindCycles: bc];
    [self putBinder: b];
  }
}
- (void) releaseSolute: (id) s From: (id) b
{

  [Telem debugOut: 3 printf: "%s::releaseSolute: %s(%p) From: %s(%p) -- begin\n",
         [[self getClass] getName], [[s getClass] getName], s, [[b getClass] getName], b];

  id released = [b releaseSolute];
  if (released != nil) {
    // and re-list the binder as available
    [unboundBinders addLast: b];
    // release this solute
    [bound removeKey: b];
    [self addToUnboundSolute: released];
  }

  [Telem debugOut: 3 printf: "%s::releaseSoluteFrom: %s(%p) -- end\n",
         [[self getClass] getName], [[b getClass] getName], b];

}

- (void) scheduleBinder: (id) b toReleaseAt: (unsigned) t
{
  [cellSchedule at: t
    createActionTo: self 
                message: M(releaseSolute:From:): [b getAttachedSolute] : b];
}

- (void) activateScheduleIn: (id) aSwarmContext
{
  [cellSchedule activateIn: aSwarmContext];
}


- (void) addToUnboundSolute: (id) addObj
{ // Wrapper for unboundSolute list -- raise error if parameter isn't a Solute!
  if ([addObj isKindOf: [Solute class]])
    [unboundSolute addLast: addObj];
  else
    raiseEvent(InternalError, "addToUnboundSolute -- %s is not Solute", [[addObj getClass] getName]); 
}



@end

