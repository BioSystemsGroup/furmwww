/*
 * ISL - PVT - Portal Vein Tract object
 *
 * Copyright 2008-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "Solute.h"
#import "PVT.h"
@implementation PVT

/**
 * decrements all the timers for the solutes held in the PVT
 *
 * This method might be placed on the schedule in the future if a) we
 * create a PVT for each zone I SS (which is proper) and/or b) we want
 * to experiment with the execution order of the timer.
 */
- (void) decrementAll {
  id <MapIndex> sNdx = [solutes mapBegin: scratchZone];
  id val = nil;
  id key = nil;
  while ([sNdx getLoc] != End
         && ((val = [sNdx next: &key]) != nil)) {
    id <Integer> timer = (id <Integer>)val;
    [timer setInt: [timer getInt] - 1];
  }
}

- (id <List>) whichCanBeMoved: (id <List>) candidates {
  id <List> approved = [List create: [self getZone]];
  id <ListIndex> cNdx = [candidates listBegin: scratchZone];
  Solute * candidate = nil;
  while ([cNdx getLoc] != End
         && ((candidate = ((Solute *)[cNdx next])) != nil) ) {
    Integer * timer = [solutes at: candidate];

    // if it's not in there, add it
    if (timer == nil) {
      timer = [Integer create: [self getZone]
		       setInt: [[candidate getType] getBufferDelay]];
      [solutes at: candidate insert: timer];
    }
    if ([timer getInt] <= 0)
      // add it to the list that can go
      [approved addLast: candidate];
  }
  [cNdx drop]; cNdx = nil;
  return approved;
}

- (void) removeSolutes: (id <List>) moved {
  id s = nil;
  id <ListIndex> mNdx = [moved listBegin: scratchZone];
  while ( ([mNdx getLoc] != End
           && ((s = [mNdx next]) != nil) )) {
    if ([solutes removeKey: s] == nil)
      [Telem debugOut: 6 printf: "[%s(%p) -removeSolutes: %s(%p)] -- "
             "%s(%p) not in PVT->solutes map.\n",
             [[self getClass] getName], self, 
	     [[moved getClass] getName], moved, [[s getClass] getName], s];
  }
  [mNdx drop]; mNdx = nil;
}

- createEnd
{
  PVT *obj = [super createEnd];
  obj->solutes = [Map create: [obj getZone]];
  return obj;
}
@end
