/*
 * ISL - One dimensional flow space connecting hepatocytes
 *
 * Copyright 2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "FlowTube.h"
@interface BileCanal : FlowTube
{
@public
@protected
  id _parent;   // my parent
}
// override - (BOOL) outflow: (Solute *) s;
@end
