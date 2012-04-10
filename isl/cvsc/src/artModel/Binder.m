/*
 * IPRL - Binder object
 *
 * Copyright 2003 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "Binder.h"
@implementation Binder
- (void) attachTo: (id) solute
{
  assert(solute != nil);
  tgtSolute = solute;

  if (![solute isKindOf: [Solute class]])
    raiseEvent(InternalError, "%s::attachTo %s is not Solute", [[self getClass] getName], [[solute getClass] getName]); 

  occupied = YES;
}
- (id) releaseSolute
{
  id solute = tgtSolute;
  tgtSolute = nil;
  occupied = NO;
  return solute;
}
- (Solute *) getAttachedSolute;
{
 if (tgtSolute != nil && ![tgtSolute isKindOf: [Solute class]])
   raiseEvent(InternalError, "[%s(%op) -getAttachedSolute] -- %s is not Solute", 
              [[self getClass] getName], self, [[tgtSolute getClass] getName]); 
  return tgtSolute;
}
- createEnd
{
  Binder *obj = [super createEnd];
  obj->occupied = NO;
  obj->tgtSolute = nil;
  return obj;
}

- (id) getParentCell
{
  //return parent_cell;
  return _parent;
}

- (void) setParentCell: (id) pCell 
{
  //parent_cell = pCell;
  _parent = pCell;
  return;
}
@end
