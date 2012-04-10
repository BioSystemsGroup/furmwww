/*
 * IPRL - Root Swarm - common ancestor for all swarms
 *
 * Copyright 2008 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * 
 */
#import "RootSwarm.h"
@implementation RootSwarm
- setName: (const char *)n {
  swarmName = n;
  return self;
}
- (const char *)getName { return swarmName; }
- createEnd
{
  RootSwarm *obj;
  obj = [super createEnd];
  obj->swarmName = [[obj getClass] getName];
  return obj;
}
@end
