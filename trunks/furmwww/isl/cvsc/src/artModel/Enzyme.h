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
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <assert.h>

#import "Binder.h"
@interface Enzyme: Binder
{
@public
  unsigned last_bind_step;
  unsigned induction_count;
}
- (id) metabolize;
- (BOOL) ifMetabolize;
@end
