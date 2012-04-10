/*
 * IPRL - Binder object
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <assert.h>

#import "Cell.h"
#import "Solute.h"
#import "Particle.h"
@interface Binder: Particle
{
  id _parent;
  BOOL occupied; // indicates if the enzyme is processing a solute
  Solute *tgtSolute;
}
- (void) attachTo: (id) solute;
- (id) releaseSolute;
- (Solute *) getAttachedSolute;
- (id) getParentCell;
- (void) setParentCell: (id) pCell;
@end
