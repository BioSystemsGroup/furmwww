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
#import <objectbase/Swarm.h>

@interface RootSwarm : Swarm
{
  const char *swarmName;
}
- setName: (const char *)n;
- (const char *)getName;
@end
