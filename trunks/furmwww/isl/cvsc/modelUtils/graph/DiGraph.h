// Copyright © 1995-2000 Swarm Development Group.
// No warranty implied, see LICENSE for terms.
//
// This is a derived work.
// Modified from the original by glen e. p. ropella <gepr@tempusdictum.com>
//

#import <objectbase/SwarmObject.h>
#import <gui.h>

#import "graph.h"

@interface DiGraph: SwarmObject
{
  id nodeList;

  // visualization state
  id <Canvas> canvas;
  int randPosSeed;
  id randGPosition, uRandPosition;
  float springLength;
}

- getNodeList;
- getLinkList;
- addNode: aNode;
- dropNode: which;
- addLinkFrom: this To: that;
- removeLink: aLink;
- (id <DiGraphNode>) findNodeWithID: (int) nodeID;
- (id <DiGraphNode>) findNodeWithLabel: (const char *) nodeLabel;

// visualization methods
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
