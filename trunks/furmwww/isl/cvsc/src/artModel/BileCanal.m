/*
 * ISL - One dimensional flow space connecting hepatocytes
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "Solute.h"
#import "Sinusoid.h"
#import "BileCanal.h"
@implementation BileCanal

/*
 * override to handle bile canals different from other flowtubes
 */
- (BOOL) outflow: (Solute *) s
{
  return [_parent findBileOutFlowFor: s];
}

@end

