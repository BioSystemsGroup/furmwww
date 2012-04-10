/*
 * IPRL - Parallelism class to assist with PISL organization
 *
 * Copyright 2003-2007 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <stdlib.h>
#import <string.h>
#import "Parallelism.h"

@implementation Parallelism 

+ (int) getParallelLevel: (const char *) str
{
  int pLevel = atoi(str);
  return (pLevel >= 0 && pLevel <= FINEST_PARALLEL_LEVEL) ? pLevel: -1;
}

+ (BOOL) isSupportedParallelism: (const char *) str
{
  int pLevel = atoi(str);
  return (atoi(str) >= 0 && pLevel <= FINEST_PARALLEL_LEVEL) ? YES : NO; 
}

@end
