/*
 * IPRL - Data structure indexing the endothelial cells
 *
 * Copyright 2003-2008 - Regents of the University of California, San
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
#include <math.h>
#include <float.h>
#import "ESpace.h"
#import "Sinusoid.h"
#import <modelUtils.h>
#import "SinusoidalSpace.h"
#import "DisseSpace.h"

@implementation ESpace

- (void) describe: outputCharStream withDetail: (short int) d
{ 
  [outputCharStream catC: "eSpace:"];
  [super describe: outputCharStream withDetail: d];
}

@end
