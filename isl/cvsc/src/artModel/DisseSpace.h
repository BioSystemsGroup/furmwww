/*
 * IPRL - Data structure indexing the hepatocytes
 *
 * Copyright 2003-2008 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "FlowSpace.h"
#import "ESpace.h"

@interface DisseSpace: FlowSpace
{
  MiddleSpace *inSpace;
}
- (void) setInSpace: (MiddleSpace *) iSpace;
- flow;

@end
