/*
 * ISL - One dimensional flow space
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#include <float.h>
#include <assert.h>
#import "FlowTube.h"
#import <LocalRandom.h>
#import "Sinusoid.h"
@implementation FlowTube


/*
 * state change methods
 */

- (id) flow
{

  [Telem debugOut: 3 printf: "[%s(%p) -flow] -- begin",
         [[self getClass] getName], self];

  // if back or forward, move coreFlowRate

  float rnd = [uDblDist getDoubleWithMin: 0.0F withMax: 1.0+FLT_MIN];
  if (rnd <= backProb) {
    [Telem debugOut: 6 printf: "[%s(%p) -flow] -- flowing core backwards by %d.\n",
           [[self getClass] getName], self, flowRate];
    [self flowBackward];
  } else if (rnd <= fwdProb) {
    [self flowForward];
  } // else if rnd <= identProb, do nothing

  return self;
}


- (void) flowBackward
{

  [Telem debugOut: 3 printf: "[%s(%p) -flowBackward] -- begin",
         [[self getClass] getName], self];

  // only do the predecessor logic if coreFlowRate < ysize
  if ( flowRate < length ) {

    // extract the lists at the inlet
    unsigned yNdx = 0U;
    id <List> displacedLists = [List create: ftScratchZone];
    for ( yNdx=0 ; yNdx<flowRate ; yNdx++ ) {
      [displacedLists addLast: [tube atOffset: yNdx]];
    }

    // bubble back the rest of the lists
    for ( yNdx=flowRate ; yNdx<length ; yNdx++ ) {
      [tube atOffset: yNdx - flowRate put: [tube atOffset: yNdx]];
    }

    // place empty displaced lists in the slots near the outlet
    for ( yNdx=length-flowRate ; yNdx<length ; yNdx++ ) {
      [tube atOffset: yNdx put: [displacedLists removeFirst]];
    }

    // place the objects in the displaced lists in near the inlet
    id <ListIndex> disNdx = [displacedLists listBegin: ftScratchZone];
    yNdx = 0U;
    id <List> list = nil;
    while ( [disNdx getLoc] != End &&
            ( (list = [disNdx next]) != nil) ) {
      [_parent slice: [list getCount] solutesFrom: list to: [tube atOffset: yNdx]];
      yNdx++;
    }
    [disNdx drop]; disNdx = nil;

    [displacedLists drop]; displacedLists = nil;

  } // end flowRate < length

}

- (BOOL) outflow: (Solute *) s
{ 

  [Telem debugOut: 3 printf: "[%s(%p) -outflow: %s(%p)] -- begin",
         [[self getClass] getName], self, [[s getClass] getName], s];

  return [_parent findOutFlowFor: s];
}

- (void) flowForward
{

  id <List> list = nil;

  [Telem debugOut: 4 printf: "[%s(%p) -flowForward] -- begin\n", 
	 [[self getClass] getName], self];

  if (flowRate < length) {
    
    // extract the lists at the outlet
    int yNdx = 0U;
    id <List> displacedLists = [List create: ftScratchZone];
    for ( yNdx=length-flowRate ; yNdx<length ; yNdx++ ) {
      [displacedLists addLast: [tube atOffset: yNdx]];
    }

    // bubble down the rest of the lists
    for ( yNdx=length-1-flowRate ; yNdx>=0 ; yNdx-- ) {
      [tube atOffset: yNdx+flowRate put: [tube atOffset: yNdx]];
    }

    // place the displaced lists at the inlet
    for ( yNdx=0 ; yNdx<flowRate ; yNdx++ ) {
      [tube atOffset: yNdx put: [displacedLists atOffset: yNdx]];
    }

    // find a home for all solute in the displaced lists
    id <List> goneList = [List create: scratchZone];
    unsigned disNdx = 0U;
    for ( disNdx=0U ; disNdx<[displacedLists getCount] ; disNdx++ ) {
      list = [displacedLists atOffset: disNdx];
      if (list == nil) raiseEvent(InternalError, "missing displaced list.\n");

      id sol = nil;

//       if (duplicates(list))
// 	[Telem debugOut: 0 printf: "displaced list %s:%d(%p) contains duplicates\n",
// 	       [[list getClass] getName], list];

      int solNdx = 0;
      for ( solNdx=0 ; solNdx<[list getCount] ; solNdx++ ) {
        sol = [list atOffset: solNdx];
        if (sol == nil) break;

        // try to relocate each solute
//        if ( ![goneList contains: sol] // avoid re-processing the same solute twice
//             && [self outflow: sol]) {
	if ([self outflow: sol]) {
	  [Telem debugOut: 6 printf: "found outflow for %s(%p)\n",
		 [[sol getClass] getName], sol];
          [goneList addLast: sol];
        }
      }

      // of the ones we relocated, clear them from the displaced list
      id <ListIndex> goneNdx = [goneList listBegin: ftScratchZone];
      while ( ( [goneNdx getLoc] != End ) &&
              ( ( sol = [goneNdx next]) != nil) ) {
	[Telem debugOut: 6 printf: "[%s(%p) -flowForward] -- removing %s(%p) from %s(%p)\n",
	       [[self getClass] getName], self, [[sol getClass] getName], sol,
	       [[list getClass] getName], list];
        if ([list remove: sol] == nil)
	  [Telem debugOut: 6 printf: "%s(%p) not in %s(%p)\n",
		 [[sol getClass] getName], sol, [[list getClass] getName], list];
      }
      [goneNdx drop]; goneNdx = nil;
      [goneList removeAll];

      // everything left in this displaced list goes to the last list
      if ( [list getCount] > 0 ) {
// 	if (duplicates(list))
// 	  raiseEvent(InternalError, "%s(%p) has duplicates\n",
// 		     [[list getClass] getName], list);
// 	if (duplicates([tube atOffset: length-1]))
// 	  raiseEvent(InternalError, "%s(%p)->tube[%d] has duplicates\n",
// 		     [[self getClass] getName], self, length-1);
	[Telem debugOut: 6 printf: "[%s(%p) -flowForward] -- slicing %d "
	       "solute from displaced list %d to tube at %d\n",
	       [[self getClass] getName], self, [list getCount], disNdx, length-1];
        [_parent slice: [list getCount] solutesFrom: list to: [tube atOffset: length-1]];
      }

    } // end loop over displaced lists
    [displacedLists drop]; displacedLists = nil;
    [goneList drop]; goneList = nil;

    
  } else { // find an outlet for all the solute

    id <Index> tubeNdx = [tube begin: ftScratchZone];
    id <List> goneList = [List create: ftScratchZone];
    while (( [tubeNdx getLoc] != End) &&
           ((list = [tubeNdx next]) != nil) ) {
      id <ListIndex> solNdx = [list listBegin: ftScratchZone];
      id sol = nil;

      while ( ([solNdx getLoc] != End) &&
              ( ( sol = [solNdx next] ) != nil) ) {
        // try to relocate each solute but don't do any sol twice
        if ([self outflow: sol]) {
	  if ([goneList contains: sol])
	    raiseEvent(InternalError, "[%s(%p) -flowForward] -- "
		       "goneList already contains %s(%p)\n",
		       [[self getClass] getName], self, [[sol getClass] getName], sol);
          [goneList addLast: sol];
        }
      }
      [solNdx drop]; solNdx = nil;

      // of the ones we relocated, clear them from the displaced list
      id <ListIndex> goneNdx = [goneList listBegin: ftScratchZone];
      while ( ( [goneNdx getLoc] != End ) &&
              ( ( sol = [goneNdx next]) != nil) ) {
	id obj = [list remove: sol];
	if ([list contains: obj])
	  raiseEvent(InternalError, "[%s(%p) -flowForward] -- "
		     "%s(%p) remains in %s(%p) even after being removed.\n",
		     [[self getClass] getName], self, [[obj getClass] getName],
		     obj, [[list getClass] getName], list);

      }
      [goneNdx drop]; goneNdx = nil;
      [goneList removeAll];
      // everything left in list stays put
    }
    [tubeNdx drop]; tubeNdx = nil;
    [goneList drop]; goneList = nil;

  }

  [Telem debugOut: 4 printf: "[%s(%p) -flowForward] -- End\n", [[self getClass] getName], self];

}

- (void) storeObject: (id) anObject at: (unsigned) y
{
  assert(anObject != nil && 0 <= y && y < length);
  id <List> l = [tube atOffset: y];
  if ([l contains: anObject]) 
    raiseEvent(InternalError, "[%s(%p) -storeObject: %s(%p) at: %d] -- "
	       "%s(%p) already contains that solute\n",
	       [[self getClass] getName], self, [[anObject getClass] getName], 
	       anObject, y, [[l getClass] getName], l);
  [l addLast: anObject];

}

- (id) removeObject: (id) anObject at: (unsigned) y
{
  assert( 0 <= y && y < length );
  id <List> l = [tube atOffset: y];
  id obj = [l remove: anObject];
  if ([l contains: anObject]) 
    raiseEvent(InternalError, "[%s(%p) -removeObject: %s(%p) at: %d] -- "
	       "%s(%p) still contains that solute even after being removed\n",
	       [[self getClass] getName], self, [[anObject getClass] getName], 
	       anObject, y, [[l getClass] getName], l);
  return obj;
}


/*
 * measurement methods
 */

- (unsigned) countObjects
{
  unsigned count=0U;
  unsigned i=0U;
  for ( i=0 ; i<[tube getCount] ; i++) {
    id <List> list = (id <List>)[tube atOffset: i];
    if (list != nil)
      count += [list getCount];
  }
  return count;
}

- (unsigned) getHolesAtY: (unsigned) y {
  assert ( 0 <= y && y < [tube getCount]);
  return (area - [[tube atOffset: y] getCount]);
}

- (int) getPosOfObject: (id) anObject
{
  int lNdx = 0;
  for ( lNdx=0 ; lNdx<length ; lNdx++ ) {
    if ([[tube atOffset: lNdx] contains: anObject])
      break;
  }
  return lNdx;
}


/*
 * setup methods
 */

+ create: (id <Zone>) aZone length: (unsigned) l
flowRate: (unsigned) r area: (unsigned) a
{
  assert( l > 0U && r >= 0U && a > 0U);
  FlowTube *obj = [super createBegin: aZone];
  obj->ftScratchZone = [Zone create: aZone];
  obj->length = l;
  obj->tube = [Array create: aZone setCount: l];
  obj->flowRate = r;
  obj->area = a;
  int yNdx = 0U;
  for ( yNdx=0 ; yNdx<l ; yNdx++ ) {
    id <List> a = [List createBegin: aZone];
    [a setReplaceOnly: YES];
    a = [a createEnd];
    [obj->tube atOffset: yNdx put: a];
  }
  return [obj createEnd];
}

- setBackProb: (float) bp fwdProb: (float) fp stayProb: (float) sp
{
  assert (bp + fp + sp < 1.0F+FLT_MIN);
  backProb = bp;
  fwdProb = fp;
  stayProb = sp;
  return self;
}

- setParent: p {
  assert ( p!=nil );
  _parent = (Sinusoid *)p;
  return self;
}

- (void) describe: outputCharStream withDetail: (short int) d
{
  [outputCharStream catC: "bileCanal:("];
  unsigned bileCount = 0U;
  int i=0;
  for ( i=0 ; i<[tube getCount] ; i++ )
    bileCount += [((id <List>)[tube atOffset: i]) getCount];
  [outputCharStream catC: [Integer intStringValue: bileCount]];
  [outputCharStream catC: ")"];
}

// - (void) describe: outputCharStream withDetail: (short int) d
// {
//   id <OutputStream> os = outputCharStream;
//   [os catC: [[self getClass] getName]];
//   [os catC: " length = "]; [os catC: [Integer intStringValue: length]];
//   [os catC: " ("];
//   int lNdx = 0;
//   unsigned numObjects = 0U;
//   for ( lNdx=0 ; lNdx<length ; lNdx++ ) {
//     numObjects += [[tube atOffset: lNdx] getCount];
//   }
//   [os catC: [Integer intStringValue: numObjects]];
//   [os catC: " objects)"];
// }
@end

