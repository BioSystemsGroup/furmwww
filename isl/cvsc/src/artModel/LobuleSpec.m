/*
 * IPRL - Lobule Specification
 *
 * Copyright 2003 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "LobuleSpec.h"
#import <modelUtils.h>
@implementation LobuleSpec

+createBegin: (id <Zone>) aZone
{
  LobuleSpec *newObj = [super createBegin: aZone];
  unsigned ndx=0L;
  unsigned ndx2=0L;

  newObj->numZones = 5L;
  newObj->nodesPerZone = 
    (unsigned *)[aZone alloc: newObj->numZones*sizeof(unsigned)];
  for ( ndx=0L ; ndx<newObj->numZones ; ndx++ )
    newObj->nodesPerZone[ndx] =  30L/(1L+ndx);

  newObj->edges = (unsigned **)[aZone alloc: newObj->numZones*sizeof(unsigned *)];
  for ( ndx=0 ; ndx <newObj->numZones ; ndx++ ) {
    newObj->edges[ndx] = 
      (unsigned *)[aZone alloc: newObj->numZones*sizeof(unsigned)];
    for ( ndx2=ndx ; ndx2<newObj->numZones ; ndx2++ ) {
      if (ndx == ndx2)
        newObj->edges[ndx][ndx2] = 10L/(1L+ndx);
      else
        newObj->edges[ndx][ndx2] = newObj->nodesPerZone[ndx2]/2L;
    }
  }
  return newObj;
}
@end
