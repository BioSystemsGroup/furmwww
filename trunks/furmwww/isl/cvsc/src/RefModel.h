/*
 * IPRL - Reference Model
 *
 * Copyright 2003-2008 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

//#import <objectbase/Swarm.h>
#import "RootSwarm.h"

#import <space.h>

@interface RefModel: RootSwarm
{
  id _parent;
  unsigned cycle;
  unsigned cycleLimit;
  id refActions;
  id refSchedule;

  id <List> outLabels;
  id <Map> bolusContents;

  double epsilon;

  // ECD parameters
  double k1;
  double k2;
  double ke;
  double dispersionNumber;
  double transitTime;
  double bolusMass;
  double perfusateFlow;
  double radialToAxialM2SFlow;
  double radialToAxialS2MFlow;
  double startTime;
  double stopTime;
  double timeIncrement;

}

+ createBegin: aZone;
- createEnd;

- (id) setParent: (id) p;
- (unsigned)getCycle;
- setCycleLimit: (unsigned) cl;
- setEpsilon: (double) e;
- (void)setBolusContents: (id <Map>) bc;
- (float) getTime;
- (double) getOutputFraction;
- (id <List>) getOutputNames;
- (id <Map>) getOutputs;

- setTimeStart: (double) start increment: (double) inc;
- setParmK1: (double) v1 k2: (double) v2 ke: (double) v3 
       disp: (double) disp transit: (double) tt mass: (double) mass
       flow: (double) pf r2am2s: (double) a r2as2m: (double) b;

- step;
- stepUntilTimeIs: (float) t;

- buildObjects;
- buildActions;
- activateIn: swarmContext;

@end


