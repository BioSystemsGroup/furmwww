/*
 * IPRL/BBB - Transporter object
 *
 * Copyright 2004 - Regents of the University of California, San Francisco.
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

#import "Binder.h"

@interface Transporter: Binder
{
  //id parent_cell;
  id parent_space;
  id target_space;
  BOOL transport_dir; // NO is into cell, YES is out of cell
  BOOL side_loc; // NO is luminal, YES is abluminal - needed for BbbCell to handle internal cell gradient
  BOOL bounded; // NO means bound to e.g. membrane, YES means not bound in place
  int target_x, target_y;
  id <Schedule> transporterSchedule;
}

// + create: aZone parentCell: (id) pCell parentSpace: (id) pSpace targetSpace: (id) tSpace;
- (BOOL) bindTo: (id) sObj forOut: (BOOL) dir tgtX: (int) t_x tgtY: (int) t_y;
- (void) releaseSolute;
- (BOOL) isAvailable;
- (BOOL) isBound;
- (id) getParentSpace;
- (id) getTargetSpace;
- (BOOL) getTransportDirection;
- (int) getTargetX;
- (int) getTargetY;
- (void) setParentCell: (id) pCell parentSpace: (id) pSpace targetSpace: (id) tSpace;
- (void) setParentSpace: (id) pSpace;
- (void) setTargetSpace: (id) tSpace;
- (void) setSideLocation: (BOOL) loc;
- (void) setBounded: (BOOL) bnd;
- (void) activateScheduleIn: (id) aSwarmContext;
- (void) scheduleRelease;
@end
