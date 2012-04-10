/*
 * IPRL - Parameter Sweeper
 *
 * Copyright 2003-2007 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
//#import <objectbase/SwarmObject.h>
#import "../RootObject.h"

@interface ParameterSweeper : RootObject
{
  id <Map> paramTbl;
  id <Map> sweepTbl;
  id <String> baseDir;
  int sweepSpaceSize;
  int tupleSize;
  int tabSize;
  id <String> *sweepSpace;
  id <String> header;
  id <String> tail;
}

+ createBegin: aZone;
- createEnd;

- buildParameterSweepingSpace: (id <String>) fn to: (id <String>) dir;
- buildParameterSweepingTable: (FILE *) fp;
- construct: (int) start to: (int) end;
- generateParameterFiles;
- (unsigned) getSweepingSpaceSize;
- (id <String>) getParameterSweepingSpaceDir;

- printSweepSpace; 
- printParamMap;
- printSweepMap;

/*
- generate: (id <String>) fn 
            withHeader: (id <String>) header 
            withTail: (id <String>) tail 
            withParams: (id <List>) params;

- (void) buildHeader: (id <String>) header;
- (void) buildTail: (id <String>) tail;

- (void) addParameters: (id <List>) params;
- (void) addParameter: (id <String>) prefix withParameter: (id <Pair>) param;

- closeFile;
*/

@end
