/*
 * IPRL - Double wrapper
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
#import "Double.h"

compare_t double_compare ( Double *obj1, Double *obj2 )
{
   compare_t retVal = (compare_t) 0;
  if (obj1 == nil || obj2 == nil) retVal = (compare_t) 0xffffffff;
  if ([obj1 getDouble] < [obj2 getDouble]) retVal = (compare_t) -1;
  if ([obj1 getDouble] > [obj2 getDouble]) retVal = (compare_t) 1;
  return retVal;
}

@implementation Double
PHASE(Creating)
+ create: (id <Zone>) aZone setDouble: (double) value
{
  Double *obj;
  obj = [Double createBegin: aZone];
  obj->val = value;
  obj = [obj createEnd];
  return obj;
}
PHASE(Using)
+ (char *) doubleStringValue: (double) d
{
  char *buff = (char *)[scratchZone alloc: 14*sizeof(char)];
  sprintf(buff, "%13lf", d);
  return buff;
}
- setDouble: (double) value {
  val=value;
  return self;
}
- (double) getDouble {
  return val;
}
- (char *) doubleStringValue {
  return [Double doubleStringValue: val];
}

- (void)addDouble: (double) value
{
  val += value;
}
- (void)divideDouble: (double) value 
{
  assert(value != 0.0);
  val /= value;
}
- copy: (id <Zone>) aZone 
{
  return [aZone copyIVars: self];
}
@end

