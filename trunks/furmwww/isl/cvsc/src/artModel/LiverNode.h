/*
 * IPRL - Vascular node in the liver
 *
 * Copyright 2003-2007 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "protocols.h"
#import <graph/graph.h>
#import "LiverLink.h"
#import "Solute.h"

#import <graph/DiGraphNode.h>
@interface LiverNode: DiGraphNode <Describe>
{
@public
  id <List> solutes;

  // list of Doubles representing the CC ratio for each outlet
  id <List> outCCRatios; 
  int outCCSum;

  id _parent;  // my parent (probably a swarm)

@protected
  unsigned _cc_;
  BOOL _ccNeedsUpdate_;

  id <Map> amountMetabolized;
	id <List> metabolizedSoluteList;
	FILE *mfp;
}

// runtime methods
- stepPhysics;
- (unsigned) calcCC;
- (id <List>) takeSolutesFrom: (id <List>) fl;
- (void) takeMetabolite: (Solute *) m;
- (unsigned) slice: (unsigned) n 
       solutesFrom: (id <List>) fl 
                to: (id <List>) tl;
- (id <List>) distributeSolutesFrom: (id <List>) sl;

- stepBioChem;
// - (void) incMetabolizedSoluteType: (id <SoluteTag>) t;
- (void) incMetabolizedSolute: (Solute *) s;

// observation methods
- printToLinks: os;
- (void) describe: outputCharStream withDetail: (short int) d;
- (void) setSnaps: (BOOL) s;
- (void) writeToPNG: (id <LiverDMM>) dMM;
- (id <Map>) getAmountMetabolized;

- setMetFileDescriptor: (FILE *) f;
- (void) closeMetFileDescriptor;
- (void) clearMetabolizedSoluteList;

// accessor methods
- (unsigned) getCC;
- getSolutes;
- (id <List>) getMetabolizedSoluteList;
- (FILE *) getMetFileDescriptor;

// construction methods
+ createBegin: (id <Zone>) zone;

@end

