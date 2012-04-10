/*
 * IPRL - Reference Model
 *
 * Copyright 2003-2005 - Regents of the University of California, San Francisco.
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
#include <float.h>

#import <activity.h>
#import <collections.h>

#import "RefModel.h"
#import <Double.h>

#import <modelUtils.h>

@implementation RefModel  

+ createBegin: aZone
{
  RefModel *obj;

  obj = [super createBegin: aZone];

  obj->cycle = 0U;
  obj->cycleLimit = 1000U;
  obj->epsilon = FLT_MIN;
  obj->k1 = 0.03F;
  obj->k2 = 0.01F;
  obj->ke = 0.1F;
  obj->dispersionNumber = 0.265F; // D_N
  obj->transitTime = 6.35F; // T = L/v
  obj->bolusMass = 1.0F;  // M -- normalized
  obj->perfusateFlow = 0.312F; // Q
  obj->radialToAxialM2SFlow = 0.00654F; // a = f/V_1
  obj->radialToAxialS2MFlow = 0.0248F; // b = f/V_2
  obj->startTime = 7.F;
  obj->stopTime = 60.F;
  obj->timeIncrement = 0.1F;
  obj->bolusContents = nil;
  return obj;
}

- createEnd
{
  return [super createEnd];
}

- (id) setParent: (id) p {
  assert(p!=nil);
  _parent = p;
  return self;
}
- (unsigned)getCycle
{
   return cycle;
}

- setCycleLimit: (unsigned) cl {
  assert(cl > 1);
  cycleLimit = cl;
  return self;
}

- setEpsilon: (double) e {
  epsilon = e;
  return self;
}

- setTimeStart: (double) start increment: (double) inc
{
  assert(start >= 0.0F);
  assert(inc > 0.0F);
  startTime = start;
  timeIncrement = inc;
  return self;
}

- setParmK1: (double) v1 k2: (double) v2 ke: (double) v3 
       disp: (double) disp transit: (double) tt mass: (double) mass
       flow: (double) pf r2am2s: (double) a r2as2m: (double) b
{
  [Telem debugOut: 4 printf: "refModel::setParam: tt=%d \n",tt];
  assert(mass > 0.0F);
  assert(tt > 0.0F);
  k1 = v1;
  k2 = v2;
  ke = v3;
  dispersionNumber = disp;
  transitTime = tt;
  bolusMass = mass;
  perfusateFlow = pf;
  radialToAxialM2SFlow = a;
  radialToAxialS2MFlow = b;
  return self;
}

- (void) setBolusContents: (id <Map>) bc
{
  assert([bc getCount] > 0);
  if (bolusContents != nil) [bolusContents drop];
  bolusContents = [Map create: self];
  id v=nil, k=nil;
  id <MapIndex> bcNdx = [bc mapBegin: scratchZone];
  while (([bcNdx getLoc] != End) &&
         ((v = [bcNdx next: &k]) != nil)) {
    [bolusContents at: [k copy: self] insert: [v copy: self]];
  }
  [bcNdx drop];
} 

#include "refModel/liver_model.h"
- (float) getTime {
  return (float)get_current_time();
}

- (double) getOutputFraction {
  return get_current_cout();
}

- (double) getExtractedOutputFraction {
  return get_current_extracted_cout();
}

- (id <List>) getOutputNames 
{
  return outLabels;
}

// should survive drop
- (id <Map>) getOutputs
{
  id <Map> newOuts = [Map create: globalZone];
  [newOuts at: [String create: globalZone setC: "Time"] 
           insert: [Double create: globalZone
                           setDouble: [self getTime]]];

  // install the solute-specific fractions
  id <Tag> key=nil;
  id <Integer> val=nil;
  id <MapIndex> bcNdx = [bolusContents mapBegin: globalZone];

  if ([bcNdx getLoc] != End) {
     
     if ( (val = [bcNdx next: &key]) != nil ) {
        [newOuts at: [String create: globalZone setC: [key getName]]
             insert: [Double create: globalZone setDouble: [self getOutputFraction]]];
        [Telem debugOut: 4 printf: "newOuts : name %s val %e\n", 
               [key getName], [self getOutputFraction]];
     }
  
     if ( (val = [bcNdx next: &key]) != nil ) {
       [newOuts at: [String create: globalZone setC: [key getName]]
           insert: [Double create: globalZone setDouble:   
                             [self getExtractedOutputFraction]]];
     }
  }
  
  [bcNdx drop];
  
  return newOuts;
}

- step {

  cycle++;
  ecd_step();
  [Telem monitorOut: 1 print: "\n"];
  [Telem monitorOut: 1 printf: "%s:  %f   %e   %e\n",
         [self getName],[self getTime],[self getOutputFraction],[self getExtractedOutputFraction]]; 
  return self;
}

- stepUntilTimeIs: (float) t
{
  id <Symbol> status=(id)nil;

  status = [[self getActivity] getStatus];

  while (status != Completed && status != Terminated) {
    if ([self getTime] <= t) {
//       (strcmp(swarm_version,"2.1.1") == 0 ? 
//        [[self getActivity] next] :
//        [[self getActivity] nextAction]);
      [[self getActivity] nextAction];
      status = [[self getActivity] getStatus];
    } else break;
  }
  return self;
}

- buildObjects
{
  //int argc;
  //char **argv;

  outLabels = [List create: self];
  [outLabels addLast: [String create: self setC: "outputFraction"]];

  //argc=1;
  //argv = (char **)calloc(1,sizeof(char*));
  //argv[0] = "sinusoid";
  ecd_init(startTime, stopTime, timeIncrement, k1, k2, ke, 
	   dispersionNumber, transitTime, bolusMass, 
	   perfusateFlow, radialToAxialM2SFlow, 
	   radialToAxialS2MFlow);
  return self;
}


- buildActions
{
  // Create the list of simulation actions. 

  refActions = [ActionGroup create: self];
  
  [refActions createActionTo: self message: M(step)];
  [refActions createActionTo: self message: M(checkToStop)];
  
  // Then we create a schedule that executes the modelActions. 
  
  refSchedule = [Schedule createBegin: self];
  [refSchedule setRepeatInterval: 1];
  refSchedule = [refSchedule createEnd];
  [refSchedule at: 0 createAction: refActions]; 
  
  return self;
}


- activateIn: swarmContext
{
  [super activateIn: swarmContext];
  [refSchedule activateIn: self];

  return [self getActivity];
}

double refModelOutputMax=FLT_MIN;  // because we start at 0
- checkToStop
{
  if ([self getOutputFraction] < epsilon
      && refModelOutputMax > epsilon)
    [[self getActivity] terminate];
  return self;
}

- (void)drop {
  [bolusContents deleteAll];
  [bolusContents drop];
  bolusContents = nil;
  ecd_destroy();
  [super drop];
}

@end
