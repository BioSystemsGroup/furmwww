/*
 * IPRL - Data structure for spaces sandwiched by other spaces
 *
 * Copyright 2003-2008 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#import "Cell.h"

#import "FlowSpace.h"

struct factor_pair {
  double source_factor;
  double target_factor;
};

@interface MiddleSpace : FlowSpace
{
@public
  id innerSpace;
  id outerSpace;
  id <List> soluteTypes; // solute types to recognize
@protected
  // "i" => inner, "s" => self, "o" => outer
  float in2self_JumpProb, self2in_JumpProb;
  float self2out_JumpProb, out2self_JumpProb;
}
- setInnerSpace: iSpace;
- setOuterSpace: oSpace;

- (void) setFlowIn2Self: (float) i2s self2In: (float) s2i 
                self2Out: (float) s2o out2Self: (float) o2s;

- (void) recognize: (id <SoluteTag>) tag;

- flow;

- (struct factor_pair) get_overlap_factors: (int)source_x_size : (int)source_y_size : (int)target_x_size : (int)target_y_size : (int)source_x_index : (int)source_y_index : (int)target_x_index : (int)target_y_index;
- (struct factor_pair) internal_get_overlap_factors_fast: (int)source_x_size : (int)source_y_size : (int)target_x_size : (int)target_y_size : (int)source_x_index : (int)source_y_index : (int)target_x_index : (int)target_y_index;
- (struct factor_pair) internal_get_overlap_factors_correct: (int)source_x_size : (int)source_y_size : (int)target_x_size : (int)target_y_size : (int)source_x_index : (int)source_y_index : (int)target_x_index : (int)target_y_index;
@end
