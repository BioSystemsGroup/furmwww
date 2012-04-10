/*
 * IPRL - Enzyme object
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "Hepatocyte.h"
#import <LocalRandom.h>
#import "Enzyme.h"

id <SoluteTag> Metabolite;
@implementation Enzyme
- createEnd
{
  Enzyme *obj = [super createEnd];
  obj->last_bind_step = 0U;
  obj->induction_count = 0U;
  return obj;
}

- (void) attachTo: (id) solute
{
  // perform all the generic binder stuff
  [super attachTo: solute];
  // do the enzyme-specific stuff
  Hepatocyte *parent = (Hepatocyte *)_parent;
  last_bind_step = parent->step;
  induction_count++;

  // send signal if warranted
  if (induction_count > parent->induction_threshold) {
    parent->induction_requests++;
  }

  [Telem debugOut: 3 
	 printf: "[%s(%p) -attachTo: %s(%p)] -- cycle = %d -- induction_count = %d, "
         "parent->induction_threshold = %d, parent->induction_requests = %d\n", 
	 [[self getClass] getName], self,
         [[solute getClass] getName], solute, getCurrentTime(), induction_count, 
         parent->induction_threshold, parent->induction_requests]; 
}

- (id) releaseSolute
{
  id solute = tgtSolute;
  Hepatocyte *parent = _parent;

  [Telem debugOut: 3 printf: 
           "[%s(%p) -releaseSolute] -- parent->induction_window = %d, "
         "induction_count = %d, parent->step = %d, last_bind_step = %d, "
         "parent->bindCycles = %d\n", [[self getClass] getName], self,
         parent->induction_window, induction_count, parent->step,
         last_bind_step, parent->bindCycles];

  // test for induction signal
  if ( (parent->induction_window > 0) && (induction_count > 0) ) {
    if ( (parent->step - last_bind_step) > 
         ((parent->induction_window % parent->bindCycles) + 1) ) {
      induction_count--;
    }
  }

  tgtSolute = nil;
  occupied = NO;
  return solute;
}
- (BOOL) ifMetabolize
{
  Hepatocyte *parent = _parent;
  double metDraw = [uDblDist getDoubleWithMin: 0.0F withMax: 1.0F];
  return (metDraw < parent->metProb);
}

static unsigned totalMetabolite = 0U;
- (id) metabolize
{
  [Telem debugOut: 4 printf: "[%s(%p) -metabolize] -- cycle = %d -- metabolizing solute %s(%p)\n",
         [[self getClass] getName], self, getCurrentTime(), [[tgtSolute getClass] getName], tgtSolute];
  tgtSolute = nil;
  Solute *retVal = [[[[Solute create: [self getZone]] 
                       setName: "Metabolite"] 
                      setType: Metabolite] 
                     setNumber: totalMetabolite++];
  return retVal;
}

@end
