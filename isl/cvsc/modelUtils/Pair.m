/*
 * Pair
 * 
 * Copyright 2003 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#undef NDEBUG
#include <assert.h>
#include "Pair.h"
@implementation Pair
+ create: aZone setFirst: f second: s
{
  Pair *obj=nil;
  obj = [super createBegin: aZone];
  [obj setFirst: f];
  [obj setSecond: s];
  return [obj createEnd];
}

- setFirst: f
{
  assert(f != nil);
  first = f;
  return self;
}
- getFirst
{
  return first;
}
- setSecond: s
{
  assert(s != nil);
  second = s;
  return self;
}
- getSecond
{
  return second;
}
- (void) deleteMembers
{
  [first drop];
  [second drop];
}
@end
