// Copyright © 1995-2000 Swarm Development Group.
// No warranty implied, see LICENSE for terms.
//
// This is a derived work.
// Modified from the original by glen e. p. ropella <gepr@tempusdictum.com>
//

#import <objectbase/SwarmObject.h>
#import <gui.h>

@interface DiGraphNode: SwarmObject
{
  id fromList;
  id toList;
  id <Canvas> canvas;
  id <NodeItem> nodeItem;
  id <Symbol> nodeType;
  const char *label;
  id uRandPosition;
  FILE *fp;
@public
  int myNumber;
}

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
- setFileDescriptor: (FILE *) h;
- (FILE *) getFileDescriptor;
- (void) closeFileDescriptor;
@end
