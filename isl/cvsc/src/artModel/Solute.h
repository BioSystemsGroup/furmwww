/*
 * ISL - Solute object
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <modelUtils.h>
#import "protocols.h"
#import "Particle.h"

@interface Solute: Particle <Comparable>
{
  id <SoluteTag> type;
}
- setType: (id <SoluteTag>) st;
- (id <SoluteTag>) getType;
@end
