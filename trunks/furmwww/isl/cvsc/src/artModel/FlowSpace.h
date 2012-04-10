/*
 * IPRL - Space with a flow field
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <space/Grid2d.h>
#import <collections.h>
#import <modelUtils.h>
#import <Vector.h>
#import "Solute.h"
@interface FlowSpace: Grid2d <Describe>
{
@public
  const char *spaceName;
  id <Grid2d> flow;   // the vector space dictating the flow
  id <Map> posMap;    // the reverse lookup for object positions
  VectorMoore *defaultFlowVector;
  id <Map> fixedObjMap;
  id <Map> mobileObjMap;
  id <Map> containerObjMap;

@protected
  id _parent;   // my parent
  id <Zone> fsScratchZone;

  // for png snapshots
  BOOL snapOn;
  gdImagePtr pngImg;
  id <List> pngColors;
  int white, black;
}
- setParent: p;
- (void) putObject: (id) anObject atX: (unsigned)x Y: (unsigned)y;
- (Vector2d *) getPosOfObject: anObject;
- setFlowFromTurbo: (double) pv;
- flow;
- blocked_flow: (BOOL) recirculate;
- (id) removeObjectAtX: (unsigned) x Y: (unsigned) y;
- (void) storeObject: (id) anObject in: (id <Map>) objMap atX: (unsigned) x Y: (unsigned) y;
- (BOOL) putMobileObject: (id) anObject atX: (unsigned) x Y: (unsigned) y;
- (void) putContainerObject: (id) anObject atX: (unsigned) x Y: (unsigned) y;
- (void) putFixedObject: (id) anObject container: (BOOL) c atX: (unsigned) x Y: (unsigned) y;
- (BOOL) isMobile: (id) obj;
- (id <Map>) countMobileObjects: (id <Zone>) aZone;
- (id <List>) listFlowSourcePoints: (id <Zone>) aZone;
- (id <List>) listFlowTargetPoints;
- (Vector2d *) getNewPosFor: obj atX: (unsigned) x Y: (unsigned) y;
- (id <List>) getObjects;
- (id <Map>) getPositionMap;
- (id <List>) getOpenPoints;
- (id <Map>) getMobileObjMap;

- (void) describe: outputCharStream withDetail: (short int) d;  
- (void) setSnaps: (BOOL) s;
- (gdImagePtr) takeSnapshot;
- setName: (const char *)n;
- (const char *)getName;

@end
