/*
 * IPRL - Hepatocyte object
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

#import "Solute.h"
#import "Enzyme.h"
#import "Sinusoid.h"
#import <LocalRandom.h>
#import "Hepatocyte.h"
@implementation Hepatocyte

- (void) step
{
  // handle bindings by calling super
  [super step];

  /*
   * handle induction
   */
  if (induction_requests > 0) {
    /*
     * schedule a certain # of enzymes to be produced based on the equation
     * induction_requests(e) / induction_rate(e/s) = #steps to complete
     */
    // distribute induction_requests over the #steps to complete them
    unsigned sNdx = 1U;  // can't happen this step
    unsigned eCount = 0U;  // enzymes scheduled
    if (induction_rate >= 1.0F) {
      unsigned epr_i = floorf(induction_rate+0.5F);
      while (eCount < induction_requests) {

        [Telem debugOut: 5 printf: 
                 "[%s(%p) -step] -- step = %d -- scheduling enzyme creation at step %d\n",
               [[self getClass] getName], self, step, step+sNdx];

        [cellSchedule at: step + sNdx createActionTo: self
                      message: M(createAnEnzyme)];
        eCount++;
        if (eCount % epr_i == 0) {
          sNdx++;
        }
      }
    } else if (induction_rate > 0.0F) {
      unsigned s_inc = floorf(1.0F/induction_rate + 0.5F);
      sNdx = (s_inc == 0U ? 1U : s_inc);
      while (eCount < induction_requests) {

        [Telem debugOut: 5 printf: 
                 "[%s(%p) -step] -- step = %d -- scheduling enzyme creation at step %d\n",
               [[self getClass] getName], self, step, step+sNdx];

        [cellSchedule at: step + sNdx createActionTo: self
                      message: M(createAnEnzyme)];
        eCount++;
        sNdx += s_inc;
      }
    }

    // induction_rate == 0 => do nothing

    induction_requests = 0U;  // zero out the requests
  } // end if (induction_requests > 0)

  /*
   * handle per-cycle metabolization
   */
  Enzyme *e = nil;
  id <List> moveList = [List create: scratchZone];
  id <MapIndex> eNdx = [bound mapBegin: scratchZone];
  Solute *s = nil;
  while (([eNdx getLoc] != End) &&
         ((s = [eNdx next: &e]) != nil) ) {
    if (e != nil) {

      /*
       * if ready to metabolize, remove the future event from the 
       * schedule and execute -metabolizeSoluteAt: immediately
       */
      if ([e ifMetabolize]) {
        Solute *metabolite = [self metabolizeSoluteAt: e];
        [moveList addLast: e];
        if (metabolite != nil) {
          /*
           * Some metabolite go into bile, some into hepatocyte and
           * are allowed to wander back into the SS.
           */
          double draw = [uDblDist getDoubleWithMin: 0.0F withMax: 1.0F];
          if (draw < [[s getType] getBileRatio]) {
            [Telem debugOut: 3 printf: "[%s(%p) -step] -- placing %s(%p) in bile\n",
                   [[self getClass] getName], self, [[metabolite getClass] getName], metabolite];
            [_parent takeMetabolite: metabolite from: self];
          } else {
            // put into unbound solutes list
            [Telem debugOut: 3 printf: "[%s(%p) -step] -- placing %s(%p) in cell\n",
                   [[self getClass] getName], self, [[metabolite getClass] getName], metabolite];
            [self putMobileObject: metabolite]; // works if membrane crossing is YES
            id <List> parentSolute = [_parent getSolutes];
            if ([parentSolute contains: metabolite])
              raiseEvent(InternalError, "[%s(%p) -step] -- _parent %s(%p) already contains %s(%p)\n",
                         [[self getClass] getName], self, [[_parent getClass] getName], _parent,
                         [[metabolite getClass] getName], metabolite);
            [parentSolute addLast: metabolite];
          }
        }
      }
    } // else move to the next enzyme

  } // end loop over enzymes
  [eNdx drop]; eNdx = nil;
  // move from bound to unbound list
  id <ListIndex> mvNdx = [moveList listBegin: scratchZone];
  while (([mvNdx getLoc] != End) &&
         ((e = [mvNdx next]) != nil)) {
    [bound removeKey: e];
    [unboundBinders addLast: e];
  }
  [mvNdx drop]; mvNdx = nil;
  [moveList drop]; moveList = nil;
}

- (Solute *) metabolizeSoluteAt: (Enzyme *) e
{
  Solute *s_prior_m = [e getAttachedSolute];
  if (s_prior_m == nil) {
    [Telem debugOut: 1 printf: "Warning:  %s(%d:%p) had no solute attached to it!.\n",
               [[e getClass] getName], [e getNumber], e];
    raiseEvent(WarningMessage, "Warning:  %s(%d:%p) had no solute attached to it!.\n",
               [[e getClass] getName], [e getNumber], e);
    return s_prior_m;
  }

  Solute *metabolite = [e metabolize];
  [self incMetabolizedSolute: s_prior_m];

  // remove solute from this cell
  [self removeMobileObject: s_prior_m];
  // remove solute from this Sinusoid's list 
  [[((Sinusoid *)_parent) getSolutes] remove: s_prior_m];
  [s_prior_m drop]; s_prior_m = nil;

  return metabolite;
}

/*
 * override from Cell in order to accomodate an enzyme metabolizing its 
 * attached solute before this event comes around.
 */
- (void) releaseSolute: (id) s From: (id) e
{
  Solute *as = [e getAttachedSolute];
  if (as != s) {
    [Telem debugOut: 4 printf: "[%s(%p) -releaseSolute: %p From: %s(%p)] -- "
           "cycle = %d -- "
           "attached solute %p is not the one this for which this action was "
           "scheduled.  Null action.\n", [[self getClass] getName], self,
           s, [[e getClass] getName], e, getCurrentTime(), as];
    return;
  }
  [super releaseSolute: s From: e];
}

/* comment out the following method because we're changing the
 * semantics so that release just releases and metabolize metabolizes

// override from Cell
- (void) releaseSoluteFrom: (id) b
{

  [Telem debugOut: 4 printf: "%s(%p)::releaseSoluteFrom: %s(%p) -- begin\n",
         [[self getClass] getName], self, [[b getClass] getName], b];

  Solute *s_prior_m = [b getAttachedSolute];
  if (s_prior_m == nil) {
    raiseEvent(WarningMessage, "Warning:  %s(%d:%p) had no solute attached to it!.\n",
               [[b getClass] getName], [b getNumber], b);
    return;
  }

  if ([b isKindOf: [Enzyme class]]) {
    Enzyme *e = (Enzyme *)b;
    
    Solute *s_post_m = [e releaseSolute];

    // re-list this enzyme to be used again
    [unboundBinders addLast: e];

    if (s_post_m == nil) { 
      // it was metabolized
      [self incMetabolizedSolute: s_prior_m];
      // remove solute from this cell
      Solute *sol = (Solute *)[self removeMobileObject: s_prior_m];
      [sol drop]; sol = nil;

      // remove solute from this Sinusoid's list 
      [[((Sinusoid *)_parent) getSolutes] remove: s_prior_m];
    } else if (s_post_m != nil) {
      if (![unboundSolute contains: s_post_m]) { 
        [self addToUnboundSolute: s_post_m]; 
      }
    }
   	// remove solute from the bound list
   	[bound remove: s_prior_m];
  } else { 
    // this is not an Enzyme, call Cell::releaseSoluteFrom:b with no
    //    metabolism
    [super releaseSoluteFrom: b];
  }

  [Telem debugOut: 4 printf: "%s(%p)::releaseSoluteFrom: %s(%p) -- end\n",
         [[self getClass] getName], self, [[b getClass] getName], b];

}
*/

/*
 * overhead function should be made generic and moved to modelutils
 */
- (timeval_t) getKeyForActionTo: (id <ActionTo>) a
{
  id <MapIndex> eNdx = [cellSchedule mapBegin: scratchZone];
  id <ActionTo> action = nil;
  timeval_t cycle = -1;
  while (([eNdx getLoc] != End) &&
         ((action = [eNdx next: (void *) &cycle]) != nil)) {
    if (action == a) break;
  }
  [eNdx drop]; eNdx = nil;
  return cycle;
}


- (void) setMetProb: (float) mp
{
  assert( 0.0F <= mp && mp <= 1.0F);
  metProb = mp;
}
- (void) setEIWindow: (unsigned) w thresh: (unsigned) t rate: (float) r
{
  induction_window = w;
  induction_threshold = t;
  induction_rate = r;
}

// override from Cell
- (void) putBinder: (id) e
{
  // do everything binders do
  [super putBinder: e];
  // plus we use the enzymes list to check metabolize every cycle
  [enzymes addLast: e];
}

- createEnd 
{
  Hepatocyte *obj = [super createEnd];
  obj->_killList_ = [List create: [self getZone]];
  obj->metProb = 0.5F;
  obj->enzymes = [List create: [self getZone]];
  obj->induction_window = 20U;
  obj->induction_threshold = 2U;
  obj->induction_requests = 0U;
  obj->induction_rate = 0.5F;
  obj->metabolic_event_count = 0U;
  return obj;
}

- (void) createAnEnzyme
{

  // 1st block debug if-then
  if (step > 0) {
    [Telem debugOut: 4 printf: 
             "[%s(%p) -createAnEnzyme] -- step = %d -- |enzymes| changed from %d ",
           [[self getClass] getName], self, step, [binders getCount]];
  }

  Enzyme *e = [Enzyme create: [self getZone]];
  // Cell/Binder runtime settings are set in [Cell -putBinder]
  [self putBinder: e];
  // Hepatocyte/Enzyme runtime settings would go here

  // 2nd block debug if-then
  if (step > 0)
    [Telem debugOut: 4 printf: " to %d, added Enzyme:%d:%p\n", 
	   [binders getCount], [e getNumber], e];

}

// overridden from Cell superclass to use Enzymes
- (void) createBindersMin: (unsigned) min max: (unsigned) max
           withBindCycles: (unsigned) bc
{
  assert(min > 0);
  assert(max >= min);
  assert(bc >= 0);
  bindCycles = bc;
  unsigned numBinders = [uUnsDist getUnsignedWithMin: min withMax: max];
  int ndx = 0L;
  for ( ndx=0 ; ndx<numBinders ; ndx++ ) {
    // all the binders in the Hepatocytes are Enzymes
    [self createAnEnzyme];
  }
}

- (void) incMetabolizedSolute: (Solute *) s
{
  metabolic_event_count++;  // convenience counter

  // place it in the amountMetabolized Map
  //  id <SoluteTag> tag = [s getType];
  //  [(Sinusoid *)_parent incMetabolizedSoluteType: tag];
  [(Sinusoid *)_parent incMetabolizedSolute: s];
}

- (unsigned) getMetabolicEventCount
{
  return metabolic_event_count;
}

@end

