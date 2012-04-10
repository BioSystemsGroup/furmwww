/*
 * IPRL - Protocol file for Graph library.
 *
 * Copyright 2003 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
//
// This is a new file included in a derived work, derived from the Swarm 
// Development Group DiGraph library.  
// Added by glen e. p. ropella <gepr@tempusdictum.com>, under work-for-hire
// contract to UC San Francisco.
//

#import <objectbase.h>

#define DEFAULT_RANDOM_SEED    911

extern id <Symbol> RectangleNode, OvalNode ; 
extern void initGraphLibrary();

@protocol DiGraphNode <SwarmObject>
- setRandPosFunc: rp;
- setCanvas: aCanvas;
- setCanvas: aCanvas withRandPosFunc: posFunc;
- createEnd;
- getNodeItem;
- getToLinks;
- getFromLinks;
- makeLinkTo: aNode;
- makeLinkFrom: aNode;
- addFrom: aLink;
- addTo: aLink;
- removeFrom: aLink;
- removeTo: aLink;
- (int)linkedTo: anObj;
- (int)linkedFrom: anObj;
- (int)agreeX: (int)x Y: (int)y;
- updateLinks;
- hideNode;
- (void)drop;
- setNumber: (int) n;
- (int)getNumber;
- setNodeLabel: (const char *)aLabel;
- (const char *) getNodeLabel;
@end

@protocol DiGraphLink <SwarmObject>
- setCanvas: aCanvas;
- setFrom: from To: to;
- createEnd;
- getFrom;
- getTo;
- getLinkItem;
- (void)update;
- hideLink;
- (void)drop;
@end

@protocol DiGraph <SwarmObject>
- getNodeList;
- getLinkList;
- addNode: aNode;
- dropNode: which;
- addLinkFrom: this To: that;
- removeLink: aLink;
- (id <DiGraphNode>) findNodeWithID: (int) nodeID;
- (id <DiGraphNode>) findNodeWithLabel: (const char *) nodeLabel;
- setRandPosSeed: (int)seed;
- setCanvas: aCanvas;
- setCanvas: aCanvas withRandPosSeed: (int)seed;
- showCanvas: aCanvas;
- hideCanvas;
- getCanvas;
- (void) update;
- redistribute;
- setSpringLength: (float) aLength;
- boingDistribute: (int) iterations;
- boingDistribute;
- (double) boingStep;
@end

@class DiGraph;
@class DiGraphNode;
@class DiGraphLink;
