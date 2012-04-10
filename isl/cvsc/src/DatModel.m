/*
 * IPRL - Data Model
 *
 * Copyright 2003-2007 - Regents of the University of California, San
 * Francisco.
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

#import "DatModel.h"
#import <Double.h>
#import <activity.h>
#import <collections.h>
#import <random.h>
#import <modelUtils.h>

@implementation DatModel  

+ createBegin: aZone
{
  DatModel *obj;
  obj = [super createBegin: aZone];

  obj->modelName = (const char *)nil;
  obj->cycle = 0U;
  obj->cycleLimit = 1000U;
  obj->dataActions = nil;
  obj->dataSchedule = nil;
  obj->dataNdx = 0U;
  obj->numObservations = 0U;
  obj->labels = nil;

  return obj;
}

- createEnd
{
  return [super createEnd];
}

// These methods provide access to the objects inside the DatModel.
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

- (id) _getTime_
{
  return [self subclassResponsibility: @selector(_getTime_)];
}

- (float) getTime {
  id time_p = nil;
  float time_f=0xffffffff;

  time_p = [self _getTime_];
  if (time_p != nil)
    time_f = *((float *)time_p);

  [[self getZone] free: time_p];

  return time_f;
}

- (id <List>) getLabels
{
  return labels;
}
/**
 * getOutputFractions - get all the columns in the data
 */
- (id <Map>) getOutputFractions
{
  return [self subclassResponsibility: @selector(getOutputFractions)];
}

/**
 * getOutputFraction - get just the first column in the data
 */
- (float) getOutputFraction 
{
  return [self subclassResponsibility: @selector(getOutputFraction)], NAN;
}

- (id <List>) getOutputNames {
  return labels;
}

// just for compliance with the other models -- should survive drop
- (id <Map>) getOutputs
{
  return [self subclassResponsibility: @selector(getOutputs)];
}


#import <float.h>
- (id <Map>) getOutputsInterpolatedAt: (float) tmid
{
  return [self subclassResponsibility: @selector(getOutputsInterpolatedAt:)];
}


- (int) _loadData_
{
  return [self subclassResponsibility: @selector(_loadData_)], -1;
}

- (id) buildObjects {
  return [self subclassResponsibility: @selector(buildObjects)];
}

- buildActions
{
  // Create the list of simulation actions. 

  [Telem debugOut: 1 print: "DatModel::buildActions()\n"];
  dataActions = [ActionGroup create: self];
  
  [dataActions createActionTo: self message: M(step)];
  [dataActions createActionTo: self message: M(checkToStop)];
  
  // Then we create a schedule that executes the dataActions. 
  
  dataSchedule = [Schedule createBegin: self];
  [dataSchedule setRepeatInterval: 1];
  dataSchedule = [dataSchedule createEnd];
  [dataSchedule at: 0 createAction: dataActions]; 
  
  return self;
}


- activateIn: swarmContext
{
  [super activateIn: swarmContext];
  [dataSchedule activateIn: self];
  return [self getActivity];
}

- step
{
  cycle++;
  dataNdx++; // careful when subclassing
  return self;
}

- stepUntilTimeIs: (float) t
{
  id <Symbol> status=(id)nil;

  [Telem debugOut: 3 printf: "[DatModel -stepUntilTimeIs: %f] -- begin\n", t];

  status = [[self getActivity] getStatus];
  
  while ( (status != Terminated) && 
          (status != Completed) )
    {
      id nextTime = nil;
      nextTime = [self _getTime_];
      if (*((float *)nextTime) <= t) {

        [[self getActivity] nextAction];

        status = [[self getActivity] getStatus];
        [[self getZone] free: nextTime];
      } else {
        [[self getZone] free: nextTime];
        break;
      }
    } 
  return self;
}

- checkToStop
{
  // if we're done with the data file, end
  if (dataNdx >= numObservations)
    [[self getActivity] terminate];
  return self;
}

- (void)drop
{
  
  [dataActions deleteAll];
  //[dataActions drop];
  [dataSchedule deleteAll];
  //[dataSchedule drop];
  if (labels != nil) {
    [labels deleteAll];
    [labels drop];
  }
  [super drop];
}

@end

