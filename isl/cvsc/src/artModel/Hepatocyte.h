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
#import "Cell.h"
#import "Solute.h"
#import "Enzyme.h"
extern id <SoluteTag> Metabolite;
@interface Hepatocyte : Cell
{
@public
  id <List> enzymes;
  float metProb;
  unsigned induction_window; // size of the window used to trigger enzyme induction
  unsigned induction_threshold; // max binds per window to trigger signal
  unsigned induction_requests; // number of Enzymes requesting more Enzymes
  float induction_rate; // enzymes/step
  unsigned metabolic_event_count;
@protected
  id <List> _killList_;
}
- (void) setMetProb: (float) mp;
- (void) setEIWindow: (unsigned) w thresh: (unsigned) t rate: (float) r;
- (void) createAnEnzyme;

- (void) incMetabolizedSolute: (Solute *) s;
- (unsigned) getMetabolicEventCount;
- (Solute *) metabolizeSoluteAt: (Enzyme *) e;
- (timeval_t) getKeyForActionTo: (id <ActionTo>) a;
@end
