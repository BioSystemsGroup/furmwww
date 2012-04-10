/*
 * DMM - Data Management Module
 * 
 * Copyright 2003-2005 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <objectbase/SwarmObject.h>

//#include <modelUtils.h>
#import <DMM.h>
//#include "../lp/framework/ExperAgent.h"
#import "artModel/LobuleSpec.h"
#import "protocols.h"

@interface LiverDMM: DMM <LiverDMM>
{
@public
   char * outputDirName;
   char * inputDirName;

@protected
  id <String> lobuleSpecInputFileName;
  id <String> lobuleSpecOutputFileBase;
  id <String> lobuleSpecOutputFileName;
  id <String> lobuleSpecFileName;
  id <String> lobuleSpecFileExtension;

  id <String> valDataFileName;
}

/*
 * File utilities
 */
+ (id <List>) getAverageDataListFromMap: (id <Map>)outMap 
                               paramSet: pm;
			       
/*
 * Setup methods for singleton instance
 */
- (void) setLobuleSpecFileName: (const char *) s;
- readLS: (const char *) s intoZone: (id <Zone>) aZone;
- (void) writeLS: (LobuleSpec *) ls toFileName: (const char *) s;
- loadLobuleSpecIntoZone: (id <Zone>) aZone;
- (void) nextLobuleSpec: ls mcSet: (unsigned) mcSet;
- (void) readGML: (const char *) s intoGraph: (id <DiGraph>) g;

- (void) setValDataFileName: (const char *) s;

/*
 * Run Logging utilities
 */
- (void) initLogDir: (id <String>) base;
- (void) initLogDir: (id <String>) base csvbase: (id <String>) cbase;
- (void) startWith: (id <String>) base;
- (void) start;

- (void) nextDMRecordParamSet: pm;
- (void) nextRMRecordParamSet: pm;
- (void) nextAMRecordParamSet: pm;

- (void) logGraph: (id <DiGraph>) g forRun: (int) run mcSet: (unsigned) mcSet;

- (void) logAMResultsParamSet: pm;
- (void) logRMResultsParamSet: pm;
- (void) logDMResultsParamSet: pm;

- (id <Map>) getRunsFrom: (id <Map>) outMap maskedBy: (id <Map>) maskMap;

- (FILE *) buildFileName: (id <String> *) fileName 
                fromBase: (id <String>) base 
             writeHeader: (id <String>) header;

/*
 * Observation methods
 */
- (id <Map>) getOutputs: model;
- (id <String>) getLobuleSpecFileExtension;
- (const char *) getInputDirName;
- (const char *) getOutputDirName;
- (id <String>) getValDataFileName;

- (void) setSubDMM;

@end

