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
#import <modelUtils.h>
#import "DisseSpace.h"

@implementation DisseSpace

- (void) setInSpace: (MiddleSpace *) iSpace {
  self->inSpace = iSpace;
}

- flow
{
  [super flow];
  return self;
}

- (void) describe: outputCharStream withDetail: (short int) d
{
  [outputCharStream catC: "dSpace:"];
  [super describe: outputCharStream withDetail: d];
}
@end
