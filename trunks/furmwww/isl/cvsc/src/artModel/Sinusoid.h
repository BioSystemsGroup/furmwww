/*
 * IPRL - Sinusoidal Segment
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <space.h>
#import "LiverNode.h"
#import "SinusoidalSpace.h"
#import "DisseSpace.h"
#import "ESpace.h"
#import "FlowLink.h"
#import "BileCanal.h"
#import "Hepatocyte.h"

@interface Sinusoid: LiverNode
{
@public
  SinusoidalSpace *sSpace;
  id <List> buffSpaces;
  ESpace *eSpace; 
  DisseSpace *sod;
  BileCanal *bileCanal;

  id <List> eCells;
  id <List> hepatocytes;

  unsigned circ, length;
  double turbo;
  unsigned coreFlowRate;
  unsigned sScale, eScale, dScale;

  unsigned bileCanalCirc;

  BOOL snapOn;
}

// runtime methods
- stepPhysics;
- (BOOL) findOutFlowFor: obj;
- (BOOL) findBileOutFlowFor: (Solute *) s;
- (unsigned) calcCC;
- (id <List>) takeSolutesFrom: (id <List>) fl;
- (void) takeMetabolite: (Solute *) m from: (Hepatocyte *) h;
- (unsigned) intakeRuleEst;
- (id <List>) intakeRule: (id <List>) inList;

- stepBioChem;

// observation methods

// accessors
- (unsigned) getCirc;
- (unsigned) getLength;
- (unsigned) getCC;
- (float) getAIREMult;
- (id <List>) getHepatocytes;
- (id <List>) getECs;

// construction methods
- createEnd;
- setCirc: (unsigned) c length: (unsigned) l;
- setBileCanalCirc: (unsigned) c;
- setTurbo: (double) t;
- (void) setCoreFlowRate: (unsigned) cfr;
- (void) setScaleS: (unsigned) s E: (unsigned) e D: (unsigned) d;
- (void) create: (int) numBuffSpaces subSpacesWithAmounts: (id <Map>) nbsc;
- (void) setSpaceJumpProbsS2E: (float) s2e 
                          e2S: (float) e2s e2D: (float) e2d d2E: (float) d2e;
- (void) createHepatocytesWithDensity: (float) hd; 
- (void) createECellsWithDensity: (float) ecd;
- activateCellSchedulesIn: (id) aSwarmContext;

@end

