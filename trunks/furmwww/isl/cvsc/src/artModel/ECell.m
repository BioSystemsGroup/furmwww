/*
 * IPRL - Endothelial Cell
 *
 * Copyright 2003 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <space.h>
#import "ECell.h"
#import "ESpace.h"

@implementation ECell

+ create: aZone
{
  ECell *obj = [self createBegin: aZone];
  [obj createEnd];

  return obj;
}

- (id) setParent: (id) eSpace 
{
  self->_parent = (ESpace *)eSpace;
  return self;
}

- (void) checkForUptake
{
}

@end
