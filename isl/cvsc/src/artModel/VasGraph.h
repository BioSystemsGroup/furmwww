/*
 * IPRL - Vascular graph
 *
 * Copyright 2003-2007 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <collections.h>
#import <random.h>
#import "LobuleSpec.h"
#import "protocols.h"
#import "LiverNode.h"

#import <graph/DiGraph.h>
@interface VasGraph: DiGraph
{

  // specification
  LobuleSpec *spec;

  // description

  // map indexed by zone, returns list of vertices in that zone
  id <Map> zoneMap;

}
+createBegin: (id <Zone>) aZone;
-createEnd;
-useLobuleSpec: (LobuleSpec *) ls;
-generate;
- (BOOL) linkNode: (LiverNode *) n toZone: (int) z;
- (BOOL) isNode: (LiverNode *) n1 linkedTo: (LiverNode *) n2;
-(LobuleSpec*)generateLobuleSpec;
-(void) writeGMLToFile: (const char *) s;
- (void) writeToPNG: (id <LiverDMM>) dMM;

@end
