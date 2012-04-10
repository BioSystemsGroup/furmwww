/*
 * IPRL - Lobule Specification
 *
 * Copyright 2003-2008 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
//#import <objectbase/SwarmObject.h>
#import "../RootObject.h"
#import <collections.h>
@interface LobuleSpec: RootObject
{
@public
  unsigned numZones; 
  unsigned *nodesPerZone;
  unsigned **edges;
}
+createBegin: (id <Zone>) aZone;
@end
