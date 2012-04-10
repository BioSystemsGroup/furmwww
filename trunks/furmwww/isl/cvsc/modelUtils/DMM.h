/*
 * DMM - Data Management Module
 * 
 * Copyright 2003-2005 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <objectbase/SwarmObject.h>
#import <unistd.h>
#import "modelUtils.h"

@interface DMM: SwarmObject <DMM>
{
@public
  unsigned runNumber, monteCarloSet;
  id experAgent;
  id subDMM;
  // output data storage
  id <Map> datOut;        // <ParamMap,[mcSet|pmSet],RunMap> 
  id <Map> refOut;
  id <Map> artOut;

  // file name base for output data
  id <String> outFileBase;
  id <String> csvFileBase;

  // file for per-run data
  id <String> runFileNameBase;
  id <String> runFileName;
  FILE *runFile;

  // files for parameters
  id <String> pmFileNameBase;

  id <String> graphFileName;
  id <String> graphFileNameBase;
  id <String> graphFileNameExtension;

  FILE* artResultsFile;
  FILE* refResultsFile;
  FILE* datResultsFile;
  FILE* simResultsFile;
  FILE* simSeriesFile;
  FILE* optResultsFile;
  FILE* solutesTraceResultsFile;

  id <String> snapDirBase;  // base name for snapshot directories
  id <String> snapDir;  // top directory name for the snapshots

}

/*
 * File utilities
 */

+ (FILE *)openAppendFile: (id <String>) f;
+ (FILE *)openNewFile: (id <String>) f;
+ (FILE *) openInputFile: (id <String>) f;
+ (void)closeFile: (FILE *) f;
// YES => create your file,  NO => leave it alone
+ (BOOL) checkFile: (FILE *) fd fileName: (id <String>) f against: (id <String>) nf;
+ (BOOL) checkDir: (id <String>) dir;
+ (BOOL) createDir: (id <String>) dir;
+ (void) checkAndCreateDir: (id <String>) dir;
+ (BOOL) removeDir: (id <String>) dir;
+ (id <String>) upFrom: (id <String>) child to: (id <String>) parent;
+ (void) checkAndCreatePath: (id <String>) path;
+ (id <List>) getFileList: (id <String>) dirName pattern:(const char *) pattern;

+ (void) increment: (int *) val;

/*
 * Format and data type utilities
 */
+ (const char *) stringValue: d;

/*
 * Data Structure utilities
 */

// pick out a column; -1 means flatten all cols into the list
+ (id <List>) getDataListFromMap: (id <Map>)outMap 
                      pointIndex: (int) _index; 
+ (id <List>) getDataListFromMap: (id <Map>) runMap 
                       withLabel: (id <String>) label;
// flatten the whole matrix
+ (id <List>) getDataListFromMap: (id <Map>)outMap;
+ (id <List>) getAverageDataListFromMap: (id <Map>)outMap 
                               paramSet: pm;
+ (int) getPointSizeFrom: (id <Map>) runMap withTime: (BOOL) includeTime;
+ (id <List>) getKeyListFrom: (id <Map>) m;
- (BOOL) isPM: (id <ParameterManager>) pm maskedBy: (id <Map>) mask;

+ (id <Map>) countConstituents: (id <List>) aList createIn: (id <Zone>) aZone;

/*
 * Show contents of various maps
 */
+ (void) showExpMap: (id <Map>) eMap paramSet: pm;
+ (void) showRunMap: (id <Map>) rMap paramSet: pm;
+ (void) showPoint: (id <Map>) point paramSet: pm;

+ (void) convertMapToArray: (id <Map>) aMap 
         keys: (char *) karray values: (double *) varray  
         paramManager: pm;
+ (void) getArrayDimensions: (id <Map>) aMap 
         width: (unsigned *) columns height: (unsigned *) rows 
         paramSet: pm;
/*
 * Setup methods for singleton instance
 */
- setExperAgent: ea;
- (void) setRunFileNameBase: (const char *) s;
- (void) setGraphFileNameBase: (const char *) s;
- (id) loadObject: (const char *) scmKey into: (id <Zone>) aZone;

/*
 * Run Logging utilities
 */
- (void) endRun;
- (void) stop;
- (void) beginRun: (unsigned) run mcSet: (unsigned) mcSet;
- (void) logParameters: pm;

- (void) writeRunFileHeader: (id <List>) h;
- (void) writeRunFileData: (id <List>) d;

- (void) logSimilarityResult: (id <List>) data;
- (int)  logOptResultsPrintf: (const char *) fmt, ... ;

/*
 * Observation methods
 */

- (id <Map>) getArtMap;
- (id <Map>) getRefMap;
- (id <Map>) getDatMap;
- (id <String>) getOutFileBase;
- (id <String>) getCsvFileBase;
- (id <String>) getGraphFileNameExtension;
 
- setArtMap: (id <Map>) map;

- (int) writePNG: (gdImagePtr) img withID: (int) pid spaceName: (const char *) sn;

+ (id <String>) runMapToString: (id <Map>) runMap;
+ (const char *) pointStringValue: (id <Map>) point;
- (void) setSubDMM: sd;

@end

extern int _readLSLine(unsigned *num, FILE *file, id <Zone> aZone);
extern char *getTimeString();
