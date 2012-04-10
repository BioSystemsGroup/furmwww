/*
 * OperationBuilder
 *
 * Copyright 2007-2008 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
//#import <objectbase/SwarmObject.h>
#import "../RootObject.h"
#import <mpi.h>

@interface OperationBuilder : RootObject
// MPI operation builder
+ (MPI_Op) buildOperation: (void *) handler;
@end
