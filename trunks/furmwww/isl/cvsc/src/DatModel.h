/*
 * IPRL - Data Model
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

@interface DatModel: RootSwarm
{
  id _parent;
  const char *modelName;
  unsigned cycle;
  unsigned cycleLimit;
  id dataActions;
  id dataSchedule;
  
  unsigned dataNdx;  // pointing to the current record in the data

  int numObservations;
  id <List> labels;

}

- (id) setParent: (id) p;
- (unsigned)getCycle;
- setCycleLimit: (unsigned) cl;
- (float) getTime;
- (id <List>) getLabels;
- (float) getOutputFraction;
- (id <Map>) getOutputFractions;
- (id <List>) getOutputNames;  // returns list of Strings
- (id <Map>) getOutputs;  // <name, value>
- (id <Map>) getOutputsInterpolatedAt: (float) tmid;

+ createBegin: aZone;
- createEnd;

- step;
- stepUntilTimeIs: (float) t;
- buildObjects;
- buildActions;
- activateIn: swarmContext;

@end


