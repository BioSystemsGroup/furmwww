/*
 * IPRL - Vas object
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#import "LiverNode.h"
#import "PVT.h"
extern id <Symbol> In, Out;
@interface Vas: LiverNode
{
@public
  id <Symbol> flow;
  unsigned perfusateFlux;  // holes/step or volume/step
  unsigned soluteFlux;     // particles/step
  id <Map> bolusContents;  // solute types & ratios (owned by ArtModel)
  id <List> retiredSolute;
  id <List> createdSolute;

  id <Map> totalSolute; 
  unsigned totalSoluteCreated; // convenience for |totalSolute|
  unsigned totalSoluteRetired; // convenience for |totalSolute|

  id <Map> pumpedMap;  // holds data about most recent flux
  PVT * pvt; // portal vein tract delays solute

  id <List> bile;
  unsigned bilePred, bileFlux;
}

// runtime methods

- stepPhysics;
- (unsigned) calcCC;
- updateSoluteCount;
- (int) pumpSolutes;

- stepBioChem;

// observation methods
- (void) describe: outputCharStream withDetail: (short int) d;

// accessor methods
- (id <Map>) getFlux;
- (id <List>) getRetiredSolutes;
- (id <List>) getCreatedSolutes;

// construction methods

+ create: (id <Zone>) zone flow: (id <Symbol>) flowDir 
perfFlux: (unsigned) pf solFlux: (unsigned) sf;
- setFlow: (id <Symbol>) flowDir;
- setPerfFlux: (unsigned) pf;
- setSoluteFlux: (unsigned) sf withContents: (id <Map>) bc;
@end
