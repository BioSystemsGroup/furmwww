/*
 * IPRL - GML (Graph Modeling Language) interface object
 *
 * Copyright 2003 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <objectbase/SwarmObject.h>
#import "modelUtils.h"
#include "gml/gml_parser.h"
@interface GML: SwarmObject <GML>
{
  id <Error> GMLError;

  struct GML_pair* elemList;
  struct GML_stat* parserStat;

  // iterator
  struct GML_pair* iterPtr;
}
- (int) readGMLFile: (const char *) fileName;
- (char *) getKey: (struct GML_pair *)gmlElem;
- (GML_value) getKind: (struct GML_pair *)gmlElem;
- (int) getID: (struct GML_pair *) gmlElem;
- (const char *) getLabel: (struct GML_pair *) gmlElem;
- (int) getSource: (struct GML_pair *) gmlEdge;
- (int) getTarget: (struct GML_pair *) gmlEdge;
- printElements;
@end
