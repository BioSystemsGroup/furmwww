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
#import "../RootObject.h"
#import <modelUtils.h>
@interface FlowTube: RootObject <Describe>
{
@public
  const char *spaceName;
  id <Array> tube;
  unsigned length;
  unsigned flowRate;
  unsigned area;
  // probabilities a solute will move back, fwd, or stay still
  float backProb, fwdProb, stayProb;

@protected
  id _parent;   // my parent
  id <Zone> ftScratchZone;

}
+ create: (id <Zone>) aZone length: (unsigned) l
flowRate: (unsigned) r area: (unsigned) a;
- setBackProb: (float) bp fwdProb: (float) fp stayProb: (float) sp;
- setParent: p;
- (int) getPosOfObject: anObject;
- (unsigned) getHolesAtY: (unsigned) y;
- flow;
- (void) flowBackward;
- (void) flowForward;
- (id) removeObject: (id) anObject at: (unsigned) y;
- (void) storeObject: (id) anObject at: (unsigned) y;
- (unsigned) countObjects;

- (void) describe: outputCharStream withDetail: (short int) d;  

@end
