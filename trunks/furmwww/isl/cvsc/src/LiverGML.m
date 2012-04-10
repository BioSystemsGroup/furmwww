/*
 * IPRL - LiverGML (Graph Modeling Language) interface object specific
 *        to the liver model
 *
 * Copyright 2004 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "LiverGML.h"
@implementation LiverGML
- (void) decodeIntoDiGraph: (id <DiGraph>) g
{
  iterPtr = elemList;
  if (iterPtr == (struct GML_pair *)nil)
    return;

  while (iterPtr != (struct GML_pair *)nil) {
    switch ([self getKind: iterPtr]) {
    case GML_INT:
    case GML_DOUBLE:
    case GML_STRING:
      break;
    case GML_LIST:
      if (strcmp([self getKey: iterPtr], "graph") == 0)
        [self decode: iterPtr->value.list into: g];
      else
        raiseEvent(GMLError, "GML: List element %s is not a graph.\n",
                   [self getKey: iterPtr]);
      break;

    default:
      raiseEvent(GMLError, "GML: Could not classify element: %s\n", 
                 [self getKey: iterPtr]);
    }
    iterPtr = iterPtr->next;
  }
}


- decode: (struct GML_pair *) list into: (id <DiGraph>) g
{
  struct GML_pair *local = list;
  const char *key = (const char *)nil;
  const char *label = (const char *)nil;
  int number=0U;
  id <DiGraphNode> node = nil;

  while (local != (struct GML_pair *)nil) {
    switch ([self getKind: local]) {
    case GML_INT:
      if (strcmp([self getKey: local], "version") == 0)
        if (local->value.integer != 2)
          raiseEvent(GMLError, "GML: Only GML version 2 is supported.\n");
      if (strcmp([self getKey: local], "directed") == 0)
        if (local->value.integer != 1)
          raiseEvent(GMLError, "GML: Graph is not a directed graph.\n");
      break;
    case GML_DOUBLE:
    case GML_STRING:
    case GML_LIST:
      key = [self getKey: local];
      label = [self getLabel: local];
      number = [self getID: local];
      if (strcmp(key, "graph") == 0)
        raiseEvent(GMLError, "GML: Subgraphs not allowed.\n");

      /*
       * Node handling
       */

      if (strcmp(key, "node") == 0) {
        label = [self getLabel: local];
        if (strcmp(label, "portalVein") == 0) {
          node = [Vas createBegin: [g getZone]];
          [node setNodeLabel: "portalVein"];
        } else if(strcmp(label, "hepaticVein") == 0) {
          node = [Vas createBegin: [g getZone]];
          [node setNodeLabel: "hepaticVein"];
        } else if(strcmp(label, "sinusoid") == 0) {
          node = [Sinusoid createBegin: [g getZone]];
          [node setNodeLabel: "sinusoid"];
        }
        [node setNumber: number];
        node = [node createEnd];
        [g addNode: node];
      }

      /*
       * edge handling
       */
      else if (strcmp(key, "edge") == 0) {
        id <DiGraphNode> srcNode = nil;
        id <DiGraphNode> tgtNode = nil;
        id link = nil;
        int source = [self getSource: local];
        int target = [self getTarget: local];
        srcNode = [g findNodeWithID: source];
        tgtNode = [g findNodeWithID: target];

        [Telem debugOut: 2 printf: 
                 "GML: link from node %d (%p) to node %d (%p)\n",
               source, srcNode, target, tgtNode];

        link = [[[FlowLink createBegin: [g getZone]]
                  setFrom: srcNode To: tgtNode]
                 createEnd];
      }

      /*
       * everything else
       */
      else
        raiseEvent(GMLError, "GML: Only nodes and edges inside a graph.\n");
      break;
    default:
      raiseEvent(GMLError, "GML: Could not classify element: %s\n", 
                 [self getKey: local]);
    }
    local = local->next;
  }
  return g;
}
@end
