/*
 * IPRL - Vascular graph
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "VasGraph.h"
#import "Vas.h"

#import "FlowLink.h"
#import "Sinusoid.h"

#define LINK_LEAF_TRIES 10

@implementation VasGraph

-generate 
{
  id <Zone> myZone = [self getZone];
  LiverNode *dgn=nil;
  char *tmpStr;
  id <DiGraphNode> pv=nil;
  id link=nil;
  int zone, node, edge;
  int count=2; // start at 2 to account for PV and HV
  unsigned numZones;
  unsigned *npz;
  unsigned **edges;
  const char * labelBase = "sinusoid_";

  if (spec == nil)
    raiseEvent(LoadError, "LobuleSpecification file required to use generate.\n");

  numZones = spec->numZones;
  npz = spec->nodesPerZone;
  edges = spec->edges;

  [Telem debugOut: 5 printf: "[nodeList getCount] = %d\n",[nodeList getCount]];

  pv = [self findNodeWithLabel: "portalVein"];

  // create the zones
  for ( zone=0 ; zone<numZones ; zone++ ) {
    id <List> zoneNodes = [List create: myZone];
    id <String> zoneKey=nil;
    // create the vertices for each zone
    for ( node=0 ; node<npz[zone] ; node++ ) {
      id <String> label = [String create: myZone setC: labelBase];
      [label catC: [Integer intStringValue: count]];
      dgn = [[[Sinusoid createBegin: myZone] 
               setNodeLabel: ZSTRDUP(myZone, [label getC])]
              createEnd];
      [dgn setNumber: count++];

      // link zone I nodes from the portal
      if (zone == 0) {
        link = [[[FlowLink createBegin: myZone]
                  setFrom: pv To: dgn]
                 createEnd];
      }

      [zoneNodes addLast: dgn];
      [self addNode: dgn];
      [label drop]; label = nil;
    }

    zoneKey = [String create: myZone setC: "Zone"];
    tmpStr = [Integer intStringValue: zone];
    [zoneKey catC: tmpStr];
    [scratchZone free: tmpStr];
    [zoneMap at: zoneKey insert: zoneNodes];
    
  }

  { // create the edges
     id <List> zone1Nodes=nil;
     id <List> zone2Nodes=nil;
     id <String> zone1Key=nil;
     id <String> zone2Key=nil;
     const char *prefix= "Zone";
     unsigned srcZone, tgtZone;

     for ( srcZone=0L ; srcZone<numZones ; srcZone++ ) {
        unsigned cachedEdges=0L;
        zone1Key = [String create: scratchZone setC: prefix]; 
        [zone1Key catC: [Integer intStringValue: srcZone]];
        zone1Nodes = [zoneMap at: zone1Key]; // nodes in this zone

        [Telem debugOut: 5 printf: "|zone1Nodes| = %d\n",
               [zone1Nodes getCount]];

        // move on if zone1nodes is zero
        if ( [zone1Nodes getCount] <= 0L ) continue;

        for ( tgtZone=0L ; tgtZone<numZones ; tgtZone++ ) {
           unsigned edgeNum=0L;

           zone2Key = [String create: scratchZone setC: prefix];
           [zone2Key catC: [Integer intStringValue: tgtZone]];
           zone2Nodes = [zoneMap at: zone2Key]; // nodes in this zone

           [Telem debugOut: 5 printf: "|zone2Nodes| = %d\n",
                  [zone2Nodes getCount]];

           // if there are no edges between these zones, move on
           edgeNum = cachedEdges + edges[srcZone][tgtZone];

           // if zone2 has no nodes in it, cache these edges to go
           // between srcZone and the next zone
           if ( [zone2Nodes getCount] <= 0L ) {
              cachedEdges = edgeNum;
              continue;
           }

           // randomly select the src and tgt nodes and link them
           for ( edge=0 ; edge<edgeNum ; edge++ ) {
              LiverNode *node1;
              LiverNode *node2;
              node1 = [zone1Nodes atOffset: [uniformIntRand getIntegerWithMin: 0L 
                                                            withMax: [zone1Nodes getCount]-1]];

              node2 = [zone2Nodes atOffset: [uniformIntRand getIntegerWithMin: 0L 
                                                            withMax: [zone2Nodes getCount]-1]];
              // no self links
              if (node1 != node2) {

                // no back links
                if (![self isNode: node2 linkedTo: node1]) {
                  // finally make the link
                  link = [[[FlowLink createBegin: myZone]
                            setFrom: node1 To: node2]
                           createEnd];
                  [Telem debugOut: 5 printf: "linking node %d:%d to node %d:%d\n",
                         srcZone, [node1 getNumber], tgtZone, [node2 getNumber]];
                } // no back links
              } // no self links
           }
           [zone2Key drop]; zone2Key = nil;
        }
        [zone1Key drop]; zone1Key = nil;
     }
  } // end edge creation

  { // handle leaf nodes and last zone nodes
    if (YES) { // if in the last zone, link to hv, else link to another node in this zone
      unsigned zone = 0L;
      const char *prefix= "Zone";
      for ( zone=0L ; zone<numZones ; zone++ ) {
        id <String> zoneKey = [String create: scratchZone setC: prefix]; 
        [zoneKey catC: [Integer intStringValue: zone]];
        id <List> nodes = [zoneMap at: zoneKey]; // nodes in this zone
        id <ListIndex> nNdx = [nodes listBegin: scratchZone];
        LiverNode *node = nil;
        while ( ([nNdx getLoc] != End)
                && ( (node = [nNdx next]) != nil) ) {


          // first link all nodes in the last zone to the hepaticVein
          if (zone == numZones - 1) {
            [self linkNode: node toZone: numZones];
          }

          // next handle any left over leaf nodes
          if ([[node getToLinks] getCount] == 0) {

            // try to link in this zone, increasing zone till the call comes back YES
            int zNdx = zone;
            while (![self linkNode: node toZone: zNdx++] && zNdx <= LINK_LEAF_TRIES);
            if (zNdx > LINK_LEAF_TRIES) {
              raiseEvent(WarningMessage, "\n!!! %s(%p) %d has no outputs.\n",
                         [[node getClass] getName], node, [node getNumber]);
            }
          } 

        } // end node loop


        [nNdx drop]; nNdx = nil;
        [zoneKey drop]; zoneKey = nil;
      } // end zone loop

    } else { // connect the leaves, regardless of their zone, to the hepaticVein
      id <DiGraphNode> hv=[self findNodeWithLabel: "hepaticVein"];
      id <ListIndex> nodeNdx = [nodeList listBegin: scratchZone];
      LiverNode *node=nil;
      id link=nil;
      while ( ([nodeNdx getLoc] != End)
              && ( (node = [nodeNdx next]) != nil) ) {
        if ([[node getToLinks] getCount] == 0) {
          [Telem debugOut: 5 printf: "linking leaf node %d to hv\n",
                 [node getNumber]];

          link = [[[FlowLink createBegin: myZone]
                    setFrom: node To: hv]
                   createEnd];
        }
      }
      [nodeNdx drop]; nodeNdx = nil;
    }
  }

  /*  -- commented out until you need it
  { // examine the graph
    [Telem debugOut: 1 print: "VasGraph::generate() --\n"];
    id <ListIndex> gni = [nodeList begin: scratchZone];
    id <DiGraphNode> gn = nil;
    while ( ([gni getLoc] != End)
            && ( (gn = [gni next]) != nil) ) {
      [Telem debugOut: 1 printf: "[gni getNumber] => %d\n",
             [gn getNumber]];
    }
    [gni drop]; gni = nil;
  }
  */

  return self;
}

/**
 * links node n to a randomly selected node in zone z.  If z is beyond
 * the last zone, then it links it to the hepaticVein.  It tries to
 * link to find a target node LINK_LEAF_TRIES, after which it raises a
 * warning and bails, leaving the node unlinked.
 */
- (BOOL) linkNode: (LiverNode *) n toZone: (int) z
{
  BOOL retVal = NO;
  id <DiGraphNode> hv=[self findNodeWithLabel: "hepaticVein"];
  unsigned numZones = [zoneMap getCount];
  LiverLink *link = nil;
  
  // if beyond last zone link to hv
  if (z >= numZones) {
    link = [[[FlowLink createBegin: [self getZone]]
              setFrom: n To: hv] createEnd];
    retVal = YES;
  } else {// else try to link to nodes in that zone
    const char *prefix= "Zone";
    id <String> zoneKey = [String create: scratchZone setC: prefix]; 
    [zoneKey catC: [Integer intStringValue: z]];
    id <List> nodes = [zoneMap at: zoneKey]; // nodes in this zone

    if ([nodes getCount] > 0) {
      LiverNode *tgt = nil;

      int count = 0;
      do {
        int rnd = [uniformIntRand getIntegerWithMin: 0L 
                                  withMax: [nodes getCount]-1];
        tgt = [nodes atOffset: rnd];
        // no self links and no back links
        if (n != tgt && ![self isNode: tgt linkedTo: n]) {
          link = [[[FlowLink createBegin: [self getZone]] 
                    setFrom: n To: tgt]
                   createEnd];
          retVal = YES;
        }
      } while (!retVal && count++ < LINK_LEAF_TRIES);
    }
  }
  return retVal;
}

- (BOOL) isNode: (LiverNode *) n1 linkedTo: (LiverNode *) n2 
{
  BOOL backLink = NO;
  id <List> n1OutList = [n1 getToLinks];
  id <ListIndex> n1OutNdx = [n1OutList listBegin: scratchZone];
  LiverLink *edge = nil;

  [Telem debugOut: 5 printf: "%s has edges to:\n", [n1 getNodeLabel]];

  while ( ([n1OutNdx getLoc] != End) 
          && ( (edge = [n1OutNdx next]) != nil) ) {
    LiverNode *outNode = [edge getTo];

    [Telem debugOut: 5 printf: "\t%s - edge(%p)\n", [outNode getNodeLabel], edge];

    if (outNode == n2) backLink = YES;
  }
  [n1OutNdx drop]; n1OutNdx = nil;

  [Telem debugOut: 5 printf: "\tbackLink(%s, %s) = %s\n", [n1 getNodeLabel], 
         [n2 getNodeLabel], (backLink == YES ? "YES" : "NO")];

  return backLink;
}

- useLobuleSpec: (LobuleSpec *) ls
{
  spec = ls;
  return self;
}

// construction methods
+createBegin: (id <Zone>) aZone
{
  VasGraph *newObj = [super createBegin: aZone];

  newObj->zoneMap = [Map create: globalZone];

  return newObj;
}
-createEnd
{
  return [super createEnd];
}

// observation methods

- (void) describe: outputCharStream withDetail: (short int) d
{
  id <MapIndex> zoneNdx = nil;
  id <String> zone = nil;
  id <List> nodes = nil;
  LiverNode *node = nil;

  if (zoneMap == nil) return;
  else zoneNdx = [zoneMap mapBegin: scratchZone];

  while ( ([zoneNdx getLoc] != End)
          && ( (nodes = [zoneNdx next: &zone]) != nil) ) {
    [outputCharStream catC: "\n"];
    [outputCharStream catC: [zone getC]];
    [outputCharStream catC: "\n"];

    id <ListIndex> nodeNdx = [nodes listBegin: scratchZone];
    while ( ([nodeNdx getLoc] != End)
            && ( (node = [nodeNdx next]) != nil) ) {
      [node describe: outputCharStream withDetail: d];
    }

    [nodeNdx drop]; nodeNdx = nil;
  }

  [zoneNdx drop]; zoneNdx = nil;

}

-(LobuleSpec*) generateLobuleSpec
{
 
  LobuleSpec* ls;
  ls = [LobuleSpec create: [self getZone]];
  
  unsigned numOfZones = [zoneMap getCount];
  ls->numZones = numOfZones;
  
  unsigned zoneNum;
  for (zoneNum = 0; zoneNum < numOfZones; zoneNum++){
    
    char *tmpStr;
    id <String> zoneKey = nil;
    id <List> nodesList; //list of nodes for each zone
    
    zoneKey = [String create: [self getZone] setC: "Zone"];
    tmpStr = [Integer intStringValue: zoneNum];
    [zoneKey catC: tmpStr];
    [scratchZone free: tmpStr];
    nodesList = [zoneMap at: zoneKey];
    
    //if no nodesList with that key, then go to next zone
    if (nodesList == nil) continue;

    unsigned nodesPerZone; //number of nodes in zone
    unsigned nodeNum; //number of current node in zone
    
    nodesPerZone = [nodesList getCount];
    ls->nodesPerZone[zoneNum] = nodesPerZone;
    
    //initialize ls->edge array for the current zone to zeroes
    unsigned z;
    for (z = 0; z < numOfZones; z++){
      ls->edges[zoneNum][z] = 0;
    }

    //go through each node in the current zone and find toLinks
    for (nodeNum = 0; nodeNum < nodesPerZone; nodeNum++){
       
      id <ListIndex> toNdx=nil;
      FlowLink *sl;
      BOOL end=YES;
      
      toNdx = [[[nodesList atOffset: nodeNum] getToLinks] listBegin: scratchZone];
      while (( [toNdx getLoc] != End )
	     && ((sl = [toNdx next]) != nil)){
	end=NO;
	LiverNode *currentToLinkNode;
	currentToLinkNode = [sl getTo];

	//look at zoned nodes
	if (![((id) currentToLinkNode) isKindOf: [Vas class]]){
	  
	  BOOL zoneFound = NO;
	  unsigned toLinkZoneNum = 0;

	  //find the zone for the toLink node and update edge matrix
	  while(!zoneFound){
	    id <String> toLinkZoneKey = nil;
	    char *toLinkTmpStr;
	    
	    toLinkZoneKey = [String create: [self getZone] setC: "Zone"];
	    toLinkTmpStr = [Integer intStringValue: toLinkZoneNum];
	    [toLinkZoneKey catC: toLinkTmpStr];
	    [scratchZone free: toLinkTmpStr];
	    
	    id <List> toLinkNodesList;
	    toLinkNodesList = [zoneMap at: toLinkZoneKey];
	    
	    if ([toLinkNodesList contains: currentToLinkNode]){
	      ls->edges[zoneNum][toLinkZoneNum] = ls->edges[zoneNum][toLinkZoneNum] + 1;
	      zoneFound = YES;
	    } else {
	      toLinkZoneNum++;

	      if (toLinkZoneNum >= numOfZones) {
		raiseEvent(WarningMessage, "A node with no zone was found\n");
		break;
	      }
	    }
	  }
	}
      }
    }
  }
  return ls;
}

-(void)writeGMLToFile: (const char *) s
{
  FILE *outFile;
  outFile = fopen(s, "w");  
  fputs("graph \[\n",outFile);

  id <List> nodesList = nil; 
  nodesList = [self getNodeList];  
  
  unsigned numOfNodes; //number of nodes in zone
  unsigned nodeNum; //number of current node in zone
  numOfNodes = [nodesList getCount];
         
  //print out node information
  for (nodeNum = 0; nodeNum < numOfNodes; nodeNum++){    
    LiverNode *currentDGN;
    currentDGN = [nodesList atOffset:nodeNum];
    fprintf(outFile,"node [\n");
    fprintf(outFile,"id %d\n",[currentDGN getNumber]);
    fprintf(outFile,"label \"%s\"\n", [currentDGN getNodeLabel]);
    fprintf(outFile,"]\n");
  }

  //print out edge information
  for (nodeNum = 0; nodeNum < numOfNodes; nodeNum++){
    LiverNode *sourceDGN = nil;//source Node
    sourceDGN = [nodesList atOffset:nodeNum];

    id <ListIndex> toNdx=nil;
    FlowLink *sl;
    BOOL end=YES;

    toNdx = [[sourceDGN getToLinks] listBegin: scratchZone];
    while (( [toNdx getLoc] != End )
	   && ( (sl = [toNdx next]) != nil)
	   && (strcmp([sourceDGN getNodeLabel], "hepaticVein") != 0)){
      end=NO;
      LiverNode *targetDGN;
      targetDGN = [sl getTo];
      fprintf(outFile,"edge [\n");
      fprintf(outFile,"source %d\n",[sourceDGN getNumber]);
      fprintf(outFile,"target %d\n",[targetDGN getNumber]);
      fprintf(outFile,"]\n");
    }
    [toNdx drop]; toNdx = nil;
  }
  
  fprintf(outFile,"]\n");
  fclose(outFile);
} 

- (void) writeToPNG: (id <LiverDMM>) dMM
{
  id <MapIndex> zoneNdx = nil;
  id <String> zone = nil;
  id <List> nodes = nil;
  LiverNode *node = nil;

  if (zoneMap == nil) return;
  else zoneNdx = [zoneMap mapBegin: scratchZone];

  while ( ([zoneNdx getLoc] != End)
          && ( (nodes = [zoneNdx next: &zone]) != nil) ) {

    id <ListIndex> nodeNdx = [nodes listBegin: scratchZone];
    while ( ([nodeNdx getLoc] != End)
            && ( (node = [nodeNdx next]) != nil) ) {
      [node writeToPNG: dMM];
    }

    [nodeNdx drop]; nodeNdx = nil;
  }

  [zoneNdx drop]; zoneNdx = nil;

}


// misc admin

- (void) drop
{
  //[zoneMap removeAll];
  //[zoneMap drop]; zoneMap = nil;
  //[super drop];
}
@end
