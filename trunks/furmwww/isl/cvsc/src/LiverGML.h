/*
 * IPRL - GML (Graph Modeling Language) interface object
 *
 * Copyright 2004 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <GML.h>
#import <modelUtils.h>
#import "artModel/Vas.h"
#import "artModel/Sinusoid.h"
#import "artModel/FlowLink.h"
@interface LiverGML : GML <GML>
- (void) decodeIntoDiGraph: (id <DiGraph>) g;
- decode: (struct GML_pair *) list into: (id <DiGraph>) g;
@end
