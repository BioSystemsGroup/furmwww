#import <modelUtils.h>
@protocol LobuleSpec
@end

@protocol LiverDMM <DMM>
+ (id <List>) getAverageDataListFromMap: (id <Map>)outMap 
                               paramSet: pm;
- (void) setLobuleSpecFileName: (const char *) s;
- readLS: (const char *) s intoZone: (id <Zone>) aZone;
- (void) writeLS: (id <LobuleSpec>) ls toFileName: (const char *) s;
- loadLobuleSpecIntoZone: (id <Zone>) aZone;
- (void) nextLobuleSpec: ls mcSet: (unsigned) mcSet;
- (void) readGML: (const char *) s intoGraph: (id <DiGraph>) g;
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
- (id <Map>) getOutputs: model;
- (id <String>) getLobuleSpecFileExtension;
- (const char *) getInputDirName;
- (const char *) getOutputDirName;
- (id <String>) getValDataFileName;
- (void) setValDataFileName: (const char *) s;
- (void) setSubDMM;
@end
@class LiverDMM;

@protocol LiverGML <GML>
- (void) decodeIntoDiGraph: (id <DiGraph>) g;
- decode: (struct GML_pair *) list into: (id <DiGraph>) g;
@end
@class LiverGML;

@protocol DMMWrapper
- (BOOL) checkDir: (id <String>) dir;
- (BOOL) createDir: (id <String>)dir;
- (void) checkAndCreateDir: (id <String>) dir;
- (BOOL) removeDir: (id <String>) dir;
- (void) checkAndCreatePath: (id <String>) path;
@end

@protocol ExperAgent <DMMWrapper>
- (id <LiverDMM>) getDMM;
- (unsigned) getRunNumber;
- (void) showMessage:(const char *)msg;	
- (void) terminate;
@end
@class ExperAgent;

@protocol ArtModel <Swarm>
- (unsigned) getNumBuffSpaces;
@end
@class ArtModel;
