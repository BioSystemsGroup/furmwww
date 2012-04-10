/*
 * IPRL/BBB - Transporter object
 *
 * Copyright 2004-2005 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "Transporter.h"
#import "BbbCell.h"
#import "FlowSpace.h"

@implementation Transporter
/*
+ create: aZone parentCell: (id) pCell parentSpace: (id) pSpace targetSpace: (id) tSpace
{
  Transporter *obj = [super createBegin: aZone];
  //obj->parent_cell = pCell;
  obj->parent = pCell;
  obj->parent_space = pSpace;
  obj->target_space = tSpace;
  obj = [obj createEnd];
  return obj;
}
*/

- createEnd
{
  Transporter *obj = [super createEnd];
  obj->transporterSchedule = [[[Schedule createBegin: [self getZone]] setAutoDrop: YES] createEnd];
  [transporterSchedule activateIn: nil];
  //obj->parent_cell = nil;
  obj->parent = nil;
  obj->parent_space = nil;
  obj->target_space = nil;
  bounded = NO;
  return obj;
}

- (BOOL) bindTo: (id) sObj forOut: (BOOL) dir tgtX: (int) t_x tgtY: (int) t_y
{
  BOOL retVal = NO;

  assert(sObj != nil);

  if ([self isAvailable]) {
    // for now only checks for membrane crossing, but can add/remove variety of checks here
    id <SoluteTag> solType = [sObj getType];
    if ([solType isMembraneCrossing]) {
      tgtSolute = sObj;
      occupied = YES;
      transport_dir = dir;
      target_x = t_x;
      target_y = t_y;
      retVal = YES;

    }
  }
  return retVal;
}

- (void) releaseSolute
{

  [Telem debugOut: 3 printf: "%s::releaseSolute -- begin\n",
         [[self getClass] getName]];

  assert(tgtSolute != nil);

  if (transport_dir && bounded) {

    /*
    if (side_loc) {
      [Telem debugOut: 5 printf: 
               "Transporter::releaseSolute OUT to %s(%p) at (%d, %d)\n", 
             [target_space getName],
             target_space, target_x, target_y];
    }
    */

    FlowSpace *fsp = target_space;
    // transporting out to target space
    id obj = [fsp getObjectAtX: target_x Y: target_y];
    if (obj == nil) {
      if ([fsp putMobileObject: tgtSolute atX: target_x Y: target_y]) {
        tgtSolute = nil;
        occupied = NO;
        return;
      }
    }
    else if ([fsp->containerObjMap contains: obj] || 
             [obj conformsTo: @protocol(ContainerObj)]) {
      id <ContainerObj> cObj = obj;
      if ([cObj putMobileObject: tgtSolute]) {
        tgtSolute = nil;
        occupied = NO;
        return;
      }
    }
    else if ([fsp isMobile: obj]) {
      // there is another solute at the target spot, so wait some
      [self scheduleRelease];
    }
    else {
      // put it back to parent cell
      //if ([parent_cell putMobileObject: tgtSolute fromSide: side_loc]) {
      if ([parent putMobileObject: tgtSolute fromSide: side_loc]) {
        tgtSolute = nil;
        occupied = NO;
      }
      // NOTE: transporter becomes unavailable forever if it fails to
      //    put solute back into cell
    }
  }

  else {

    /*
    if (side_loc) {
      //Vector2d *v = [((FlowSpace *)parent_space)->posMap at: parent_cell];
      Vector2d *v = [((FlowSpace *)parent_space)->posMap at: parent];
      [Telem debugOut: 5 printf: 
               "Transporter::releasesolute IN to %s(%p) at (%d, %d)\n", 
      //       [[parent_cell getClass] getName],
             [[parent getClass] getName],
      //       parent_cell, [v getX], [v getY]];
             parent, [v getX], [v getY]];
    }
    */

    // transporting into parent cell and space
    // side_loc is needed here for BbbCell so that it knows which side
    //    it should put the solute
    // If parent cell doesn't need that, then this should be changed
    //    for generic use
    //if ([parent_cell putMobileObject: tgtSolute fromSide: side_loc]) {
    if ([parent putMobileObject: tgtSolute fromSide: side_loc]) {
      tgtSolute = nil;
      occupied = NO;
    }
  }


  [Telem debugOut: 3 printf: "%s::releaseSolute -- end\n",
         [[self getClass] getName]];


  return;
}

- (void) scheduleRelease 
{
  unsigned time = getCurrentTime();

  //[transporterSchedule at: (unsigned) (time + bindCycles) createActionTo: self message: M(releaseSolute)];
  [transporterSchedule at: (unsigned) (time + parent->bindCycles) createActionTo: self message: M(releaseSolute)];

}

- (BOOL) isAvailable
{
  // later could add arguments for distinguishing different solutes
  return (!occupied);
}

- (BOOL) isBound
{
  return bounded;
}

- (id) getParentSpace
{
  return parent_space;
}

- (id) getTargetSpace
{
  return target_space;
}

- (BOOL) getTransportDirection 
{
  return transport_dir;
}

- (int) getTargetX
{
  return target_x;
}

- (int) getTargetY
{
  return target_y;
}

- (void) setParentCell: (id) pCell parentSpace: (id) pSpace targetSpace: (id) tSpace
{
  assert(pCell != nil);
  assert(pSpace != nil);

  //parent_cell = pCell;
  _parent = pCell;
  parent_space = pSpace;
  target_space = tSpace;

  return;
}

- (void) setParentSpace: (id) pSpace 
{
  parent_space = pSpace;
  return;
}

- (void) setTargetSpace: (id) tSpace 
{
  target_space = tSpace;
  return;
}

- (void) setSideLocation: (BOOL) loc
{
  side_loc = loc;
}

- (void) activateScheduleIn: (id) aSwarmContext
{
  [transporterSchedule activateIn: aSwarmContext];
}

- (void) setBounded: (BOOL) bnd
{
  bounded = bnd;
}

@end
