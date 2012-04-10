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
#import "FlowSpace.h"
#import "ESpace.h"
#import "FlowTube.h"

@interface SinusoidalSpace: FlowSpace
{
@public
  //  id <Array> core;    // the core of the tube
  FlowTube *core;
  //  unsigned coreFlowRate;
  //  unsigned coreArea;
  unsigned volume;
  double jumpProb;   // prob a solute will jump from core 2 rim or vice versa
  MiddleSpace *outSpace;
}
- jump2Core;
- jump2Rim;
- (void) setCoreFlowRate: (unsigned) cfr;
- add: (id <List>) il toCoreAtY: (unsigned) y;
+ (unsigned) calcAreaFromCirc: (unsigned) c;
- (unsigned) calcParaboloid;
- (unsigned) calcVolumeFromCirc: (unsigned) c andLength: (unsigned) h;
- (unsigned) getVolume;
- (void) setOutSpace: (MiddleSpace *)oSpace;

@end
