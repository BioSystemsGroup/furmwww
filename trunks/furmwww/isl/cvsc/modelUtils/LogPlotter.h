/*
 * IPRL - BLT Graph with semilog capabilities
 *
 * Copyright 2003 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <tkobjc/global.h>
#import <tkobjc/Graph.h>

#import "modelUtils.h"

@interface LogPlotter: Graph <LogPlotter>
{
}
-(void) setYAxisLogscale;
@end
