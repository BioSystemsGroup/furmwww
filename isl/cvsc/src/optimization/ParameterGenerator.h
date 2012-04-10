/*
 * IPRL - Parameter Generator
 *
 * Copyright 2003-2008 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <stdlib.h>
#import <unistd.h>
//#import <objectbase/SwarmObject.h>
#import "../RootObject.h"
#import <modelUtils.h>

@interface ParameterGenerator : RootObject
{
  FILE *target;
}

+ createBegin: aZone;

- createEnd;

- generate: (id <String>) fn 
            withHeader: (id <String>) header 
            withTail: (id <String>) tail 
            withParams: (id <List>) params;

- (void) buildHeader: (id <String>) header;
- (void) buildTail: (id <String>) tail;

- (void) addParameters: (id <List>) params;
- (void) addParameter: (id <String>) prefix withParameter: (id <Pair>) param;

- closeFile;


@end
