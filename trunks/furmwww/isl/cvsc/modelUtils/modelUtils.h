/*
 * IPRL - Utilities Library
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "graph/graph.h"
#import <random.h>
extern int obj_compare(id obj1, id obj2);
extern void list_add(id <List>, id <List>);
extern void list_subtract(id <List>, id <List>, BOOL);
extern unsigned countEntries(id <List> list, id <List> obj);
extern BOOL duplicates( id <List> list);
extern BOOL isSubList(id <List> list, id <List> sub);
extern id <List> shuffle(id <List> src, id <UniformUnsignedDist> rnd, id <Zone> z);
@protocol Comparable
- (int) getNumber;
@end

@protocol Describe
- (void) describe: outputCharStream withDetail: (short int) d;
@end

@protocol Dosage
- (void) setParams: (id <Array>) p;
- (void) setTimes: (id <Array>) t;
- (unsigned) dosage: (unsigned) arg;
@end

@protocol Integer <SwarmObject, Copy>
+ (char *) intStringValue: (int) i;
+ (char *) hexStringValue: (int) i;
+ (char *) intStringValueOf: (int) i format: (const char *) f places: (int) p;
+ create: (id <Zone>) aZone setInt: (int) val;
- setInt: (int) val;
- (void) increment;
- (id) addInt: (int) i;
- (int) getInt;
- (char *) intStringValue;
@end
@protocol Double <SwarmObject, Copy>
+ (char *) doubleStringValue: (double) d;
+ create: (id <Zone>) aZone setDouble: (double) val;
- setDouble: (double) value;
- (double) getDouble;
- (char *) doubleStringValue;
- (void) divideDouble: (double) value;
@end
@protocol Long <SwarmObject, Copy>
+ (char *) longStringValue: (long) l;
+ (char *) hexStringValue: (long) l;
+ (char *) longStringValueOf: (long) l format: (const char *) f places: (long) p;
+ create: (id <Zone>) aZone setLong: (long) val;
- setLong: (long) val;
- (void) increment;
- (id) addLong: (long) l;
- (long) getLong;
- (char *) longStringValue;
@end
@protocol Pair <SwarmObject>
+create: aZone setFirst: f second: s;
-setFirst: f;
-getFirst;
-setSecond: s;
-getSecond;
-(void) deleteMembers;
@end

@protocol Tag <Symbol, SwarmObject, Copy>
+ create: aZone setName: (const char *) name;
- (const char *)getName;
@end

@protocol Telem
+(void)setDebug: (BOOL) b;
+setDebugMode: (int) m;
+setDebugFile: (id <String>) f;
+(int)debugOut: (int) level printf: (const char *) fmt, ...;
+(int)debugOut: (int) level print: (const char *) str;
+(int)debugOut: (int) level describe: obj withDetail: (short int) d;
+(int) debugOut: (int) level describe: obj;
+(int) debugOut: (int) level printPoint: (id <Map>) pt;
+(void)setMonitor: (BOOL) b;
+setMonitorMode: (int) m;
+setMonitorFile: (id <String>) f;
+(int)monitorOut: (int) level printf: (const char *) fmt, ...;
+(int)monitorOut: (int) level print: (const char *) str;
+(int)monitorOut: (int) level describe: obj withDetail: (short int) d;
@end

@protocol Vectormd
+create: (id <Zone>) aZone setDim: (unsigned) dim;
+create: (id <Zone>) aZone copyVector: (id <Vectormd>)vec;
- (void)createV: (id <Zone>) aZone;
- (void)setDim: (unsigned)d;
- (unsigned)getDim;
- (void)setVal: (double)val at: (int)i;
- (double)getValAt: (unsigned)i;
- multByScalar: (double)val;
- add: (id <Vectormd>)vec;
- sub: (id <Vectormd>)vec;
- (double)dotProduct: (id <Vectormd>)vec;
- (double)norm;
- (void) print;
- (id <String>) toString;
- copyVector: (id <Vectormd>)v;
- reflectThru: (id <Vectormd>)v withRatio: (double)alpha;
- contractThru: (id <Vectormd>)v withRatio: (double)beta;
- expandThru: (id <Vectormd>)v withRatio: (double)beta;
- (void) drop;
@end

@protocol Simplex
+ create: (id <Zone>) aZone setDim: (unsigned) d;
- (unsigned)getDim;
- (void)createVertex: (unsigned)i copyVector:(id <Vectormd>)val;
- (id <Vectormd>)getVertex: (unsigned)i;
- shrinkTowardVertex: (unsigned)j WithRatio: (double)sigm;
- (void) print;
- (id <String>) toString;
- vertex: (unsigned)i copyVector: (id <Vectormd>)v;
- (void) drop;
@end

@protocol Vector2d
+create: (id <Zone>) aZone dim1: (int) dim1 dim2: (int) dim2;
- setX: (int) dim1;
- setY: (int) dim2;
- (int)getX;
- (int)getY;
@end

@protocol ParameterManager <DefinedObject>
- (unsigned) getMonteCarloSet;
- (id <Vectormd>) vectorizeEvolvingParameters;
- (id <Vectormd>) vectorizeDparams;
- (void) restoreEvolvingParametersFrom: (id <Vectormd>) v;
- (void) logEvolvingParameters: (id <Vectormd>) v;
@end

#import <gd.h>
#define DIR_SEPARATOR "/"
#define EOL '\n'
@protocol DMM <SwarmObject>

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
+ (BOOL) removeDir: (id <String>) dir;
+ (void) checkAndCreateDir: (id <String>) dir;
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
//- (id <Map>) loadBolusContents;
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
//- (id <Map>) getOutputs: model;

- (id <Map>) getArtMap;
- (id <Map>) getRefMap;
- (id <Map>) getDatMap;
- (id <String>) getOutFileBase;
- (id <String>) getCsvFileBase;
- (id <String>) getGraphFileNameExtension;
 
- setArtMap: (id <Map>) map;

- (int) writePNG: (gdImagePtr) img withID: (int) pid spaceName: (const char *) sn;

+ (id <String>) runMapToString: (id <Map>) runMap;
+ (const char *) pointStringValue: (id <Map>) point;;
@end

@protocol StatCalculator
+ (const char *)getName;
+ sumUpDM: (id <Map>) dataMap forPM: pm;
+ (id <Map>) subtractMap: (id <Map>) m1 from: (id <Map>) m2;
+ (void) addDataPoint: (id <Map>) dp1 to: (id <Map>) dp2;
+ (void) divide: (double) scalar intoDataPoint: (id <Map>) dp;
+ (double) computeCV: (id <Map>) dataMap; 
+ (double) computeSD: (id <List>) dataList;
+ (double) computeSimilarityUsing: (id <String>) measureName 
                      trainingDat: (id <Map>) trainingDat
                         paramSet: pm
                              nom: (id <String>) nomProfile
                       nomDataMap: (id <Map>) nomOut
                              exp: (id <String>) expProfile
                       expDataMap: (id <Map>) expOut
                          storeIn: (id <List>) simData;
+ (double) computeSimilarityUsing: (id <String>) measureName 
                      trainingDat: (id <Map>) trainingDat
                         paramSet: pm
                              nom: (id <String>) nomProfile 
		      columnLabel: (id <String>) colLabel 
                       nomDataMap: (id <Map>) nomOut
                              exp: (id <String>) expProfile
                       expDataMap: (id <Map>) expOut
		         bandCoef: (double) bandCoef
                          storeIn: (id <List>) simData;
@end

#import "gml/gml_parser.h"
@protocol GML <SwarmObject>
- (int) readGMLFile: (const char *) fileName;
- (char *) getKey: (struct GML_pair *)gmlElem;
- (GML_value) getKind: (struct GML_pair *)gmlElem;
- (char *) getLabel: (struct GML_pair *) gmlElem;
- (int) getSource: (struct GML_pair *) gmlEdge;
- (int) getTarget: (struct GML_pair *) gmlEdge;
- printElements;
@end

#import <gui.h>
@protocol LogPlotter <Graph>
-(void) setYAxisLogscale;
@end

@class Integer;
@class Double;
@class Long;
@class Dosage;
@class Pair;
@class Tag;
@class Telem;
@class DMM;
@class StatCalculator;
@class Vector2d;
@class GML;
@class LogPlotter;
@class Simplex;

extern compare_t double_compare( Double *obj1, Double *obj2);
extern compare_t int_compare( Integer *obj1, Integer *obj2);
extern int long_compare( Long *obj1, Long *obj2);

//extern id <DMM> dMM;

#define INVALID_INT 0xffffffff
