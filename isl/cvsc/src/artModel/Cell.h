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
#import <collections.h>
#import <modelUtils.h>  // for Comparable and Tag
#import "protocols.h" // for ContainerObj
//#import <objectbase/SwarmObject.h>
#import "../RootObject.h"

@interface Cell : RootObject <ContainerObj, Comparable>
{
@public
  int myNumber;
  id <List> solute;
  id <List> unboundSolute;
  id <List> binders;
  unsigned bindCycles;
  id <Map> bound;   // the current binder-solute (key = binder) couplings
  id <List> unboundBinders;
  float bindProb;
  unsigned step;  // set in step method
@protected
  id _parent;
  id <List> _removeList_;

  // dynamic schedule for releasing bound solute
  id <Schedule> cellSchedule;
}
- (void) step;
//- (void) iterateBound;

- (void) putBinder: (id) e;
- (id) removeBinder: (id) e;

- (int) getNumber;
- (id) setParent: (id) p;
- setNumber: (int) n;
- (void) setBindingProb: (float) bp;

- (id) getMobileObject;
- (id) removeMobileObject: (id) anObj;
- (BOOL) putMobileObject: (id) anObj;
- (id <Map>) countMobileObjects: (id <Zone>) aZone;

- (void) createBindersMin: (unsigned) min max: (unsigned) max
           withBindCycles: (unsigned) bc;
- (void) releaseSolute: (id) s From: (id) b;

- (void) scheduleBinder: (id) b toReleaseAt: (unsigned) t;
- (void) activateScheduleIn: (id) aSwarmContext;

- (void) addToUnboundSolute: (id) addObj;
@end
