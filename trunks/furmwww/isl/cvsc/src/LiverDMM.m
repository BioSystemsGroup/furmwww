/*
 * LiverDMM - Data Management Module specific to the liver model
 * 
 * Copyright 2004-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#undef NDEBUG
#include <assert.h>
#include <errno.h>
#import <simtools.h>
#import <collections.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>

#import "LiverDMM.h"
#import "artModel/VasGraph.h"
#import "artModel/protocols.h"
#import "ParameterManager.h"
#import "ExperAgent.h"

@implementation LiverDMM

/*
 * Data Structure utilities
 */

/* 
 * extract the averaged runMap from the outMap In the case where we've
 * done parameter sweeps as well as monte-carlo runs, this requires
 * the parameter set of interest.
 */
+ (id <List>) getAverageDataListFromMap: (id<Map>) outMap 
                               paramSet: pm
{
  id <Map> runMap = nil;
  {
    id tempPM = nil;
    tempPM = [ParameterManager create: scratchZone];
    [tempPM setMonteCarloSet: 0xffffffff];
    // get the avg runMap for parameter set pm
    runMap = [[outMap at: tempPM] at: pm];
    [tempPM drop];
  }

  unsigned num_cols = [self getPointSizeFrom: runMap withTime: NO];
  unsigned num_rows = [runMap getCount];

  [Telem debugOut: 3 
         printf: "[runMap getCount] = %d, num_cols = %d, num_rows = %d\n",
         [runMap getCount], num_cols, num_rows];


  double cv_data_array [num_cols][num_rows];
  unsigned c_index;
  unsigned r_index;
  for (c_index = 0; c_index < num_cols; c_index++) {
    id <List> temp_list = 
      [self getDataListFromMap: runMap pointIndex: c_index];

    for (r_index = 0; r_index < num_rows; r_index++) {
      cv_data_array[c_index][r_index] = [[temp_list atOffset: r_index] getDouble];
    }
    [temp_list drop];

  }

  // Now step through, calculating mean
  //  double cv_data_mean[num_rows];
  id <List> cv_data_mean = [List create: scratchZone];
  for (r_index = 0; r_index < num_rows; r_index++)
    {
      double sum = 0;
      double num_entries = 0;
      for (c_index = 0; c_index < num_cols; c_index++) 
	{
	  sum +=  cv_data_array[c_index][r_index];
	  num_entries++;
	}
      double value = sum / num_entries;
      id <Double> d_value = [Double create: scratchZone setDouble: value];
      [cv_data_mean addLast: d_value];
    }
  return cv_data_mean;
}

/*
 * Setup methods for singleton instance
 */
- createEnd
{
  LiverDMM *obj = [super createEnd];
  /*  obj->experAgent = nil;
  obj->runFile = (FILE *)nil;
  obj->runFileName = nil;
  obj->runFileNameBase = nil;
  obj->pmFileNameBase = nil;
  obj->graphFileName = nil;
  obj->graphFileNameBase = nil;
  obj->graphFileNameExtension = [String create: [self getZone] setC: ".gml"];
  */
  obj->lobuleSpecInputFileName = nil;
  obj->lobuleSpecOutputFileBase = nil;
  obj->lobuleSpecOutputFileName = nil;
  obj->lobuleSpecFileName = nil;
  obj->lobuleSpecFileExtension = [String create: [self getZone] setC: ".ls"];
  /*
  obj->snapDirBase = nil;
  obj->snapDir = nil;
  */

  obj->inputDirName = "inputs";
  obj->outputDirName = "outputs";

  return obj;
}

- (void) setLobuleSpecFileName: (const char *) s
{
  assert( s != (const char *)nil );
  if (lobuleSpecFileName != nil)
    [lobuleSpecFileName setC: s];
  else
    lobuleSpecFileName = [String create: [self getZone] setC: s];
}

- readLS: (const char *) s intoZone: (id <Zone>) aZone
{
  FILE *inFile;
  LobuleSpec *ls = [LobuleSpec create: aZone];
  int numNumbers=0;
  int zone1=0;

  inFile = fopen(s,"r");

  // read the first line
  ls->numZones = _readLSLine(ls->nodesPerZone, inFile, aZone);

  // read the edges matrix
  ls->edges = (unsigned **) [aZone alloc: ls->numZones*sizeof(unsigned *)];
  for ( zone1=0 ; zone1<ls->numZones ; zone1++ ) {
    ls->edges[zone1] = (unsigned *)[aZone alloc: ls->numZones*sizeof(unsigned)];
    numNumbers = _readLSLine(ls->edges[zone1], inFile, aZone);
    if (numNumbers != ls->numZones)
      raiseEvent(LoadError, "Mismatch between edge entries for zone %d in "
                 "file %s.\n", zone1, s);
  }

  fclose(inFile);
  return ls;
}

#include <stdio.h>
- (void) writeLS: (LobuleSpec *) ls toFileName: (const char *) s
{
  id <String> s_s = [String create: scratchZone setC: s];
  FILE *outFile;
  int zone1=0, zone2=0;
  id <String> tmp = 
    [String create: scratchZone 
            setC: "# file generated automatically by the IPRL - "];
  char *timeString = getTimeString();  // have to free this
  [tmp catC: timeString];
  [globalZone free: timeString];

  //outFile = fopen(s, "w");
  outFile = [DMM openNewFile: s_s];

  fputs([tmp getC], outFile);
  fputs("# nodes per zone\n", outFile);
  for ( zone1=0 ; zone1<ls->numZones ; zone1++ ) {
    fprintf(outFile, "%d ", ls->nodesPerZone[zone1]);
  }
  fprintf(outFile, "\n");
  fputs("# edges\n", outFile);
  for ( zone1=0 ; zone1<ls->numZones ; zone1++ ) {
    for ( zone2=0 ; zone2<ls->numZones ; zone2++ ) {
      fprintf(outFile, "%d ", ls->edges[zone1][zone2]);
    }
    fprintf(outFile, "\n");
  }
  fprintf(outFile, "\n");


  fclose(outFile);
  [tmp drop];
}

- loadLobuleSpecIntoZone: (id <Zone>) aZone
{
  LobuleSpec *ls=nil;
  // read the last one
  ls = [self readLS: [lobuleSpecInputFileName getC] intoZone: aZone];
  return ls;
}

/*
 * increments the lobule specification file.  Stochasticity occurs
 * __whithin__ a single lobule specification.  Changes to the (ambiguous)
 * lobule spec constitute a change in the __parameterization__.
 */
- (void) nextLobuleSpec: ls mcSet: (unsigned) mcSet
{
  [Telem debugOut: 3 printf: "%s::nextLobuleSpec: %s(%p) mcSet: %d\n",
         [[self getClass] getName], [[ls getClass] getName], ls, mcSet];

  lobuleSpecOutputFileName = [lobuleSpecOutputFileBase copy: [self getZone]];
  [lobuleSpecOutputFileName catC: "_"];
  [lobuleSpecOutputFileName catC: [Integer intStringValue: mcSet]];
  [lobuleSpecOutputFileName catC: [lobuleSpecFileExtension getC]];

  // write it for ExperAgent to pick up
  [self writeLS: ls toFileName: [lobuleSpecOutputFileName getC]];
}

- (void) readGML: (const char *) s intoGraph: (id <DiGraph>) g
{
  id <LiverGML> gml = [[LiverGML createBegin: scratchZone] createEnd];
  id <String> tmp = [String create: scratchZone setC: s];
 
  if ([gml readGMLFile: [tmp getC]] == 0)
    [gml decodeIntoDiGraph: g];
  [tmp drop];
  [gml drop];
}

- (void) setValDataFileName: (const char *) fn
{
  if ( fn != NULL ) {
    valDataFileName = [String create: [self getZone] setC: inputDirName];
    [valDataFileName catC: DIR_SEPARATOR];
    [valDataFileName catC: fn];
  } else
    raiseEvent(InvalidArgument, "Validation Data file name cannot be nil.");
}

- (id) loadObject: (const char *) scmKey into: (id <Zone>) aZone
{
  id scmObj = [[experAgent getPMArchiver]
                  getWithZone: aZone key: scmKey];
  if (scmObj == nil)
    raiseEvent(InvalidOperation, 
               "Can't find %s in parameter file.\n", scmKey);
  return scmObj;
}

/*
 * Run Logging utilities
 */
- (void) initLogDir: (id <String>) base
{
  [self initLogDir: base csvbase: nil];
}
- (void) initLogDir: (id <String>) base csvbase: (id <String>) cbase
{
  // set output directories for analystic files
  outFileBase = [base copy: [self getZone]];
  csvFileBase = (cbase == nil) 
    ? [outFileBase copy: [self getZone]]
    : [cbase copy: [self getZone]];

  // create directories if necessary
  [DMM checkAndCreatePath: outFileBase];
  [DMM checkAndCreatePath: csvFileBase];

//   // prepend base to runFileNameBase
//   id <String> rfnb = [outFileBase copy: [self getZone]];
//   [rfnb catC: DIR_SEPARATOR];
//   [rfnb catC: [runFileNameBase getC]];
//   [self setRunFileNameBase: [rfnb getC]];
//   [rfnb drop];

  // set the parameter file name base
  pmFileNameBase = [outFileBase copy: scratchZone];
  [pmFileNameBase catC: DIR_SEPARATOR];
  [pmFileNameBase catC: "pm"];

  /*
   * setup the lobule spec file input and output
   */
  if ( lobuleSpecInputFileName != nil ) {
    [lobuleSpecInputFileName drop];
  }
  // new log dir means use inputs/*.ls file
  lobuleSpecInputFileName = [String create: [self getZone] setC: inputDirName];
  [lobuleSpecInputFileName catC: DIR_SEPARATOR];
  [lobuleSpecInputFileName catC: [lobuleSpecFileName getC]];
  [lobuleSpecInputFileName catC: [lobuleSpecFileExtension getC]];
  // prepend base to lobuleSpecOutputFileNameBase
  lobuleSpecOutputFileBase = [outFileBase copy: [self getZone]];
  [lobuleSpecOutputFileBase catC: DIR_SEPARATOR];
  [lobuleSpecOutputFileBase catC: [lobuleSpecFileName getC]];

  // open the per run data files
  id <String> artrst = [csvFileBase copy: scratchZone]; 
  [artrst catC: DIR_SEPARATOR];
  [artrst catC: "art_results.csv"];
  id <String> refrst = [csvFileBase copy: scratchZone]; 
  [refrst catC: DIR_SEPARATOR];
  [refrst catC: "ref_results.csv"];
  id <String> datrst = [csvFileBase copy: scratchZone]; 
  [datrst catC: DIR_SEPARATOR]; 
  [datrst catC: "dat_results.csv"];
  id <String> simrst = [csvFileBase copy: scratchZone]; 
  [simrst catC: DIR_SEPARATOR];
  [simrst catC: "similarity_results.csv"];
  id <String> simseries = [csvFileBase copy: scratchZone]; 
  [simseries catC: DIR_SEPARATOR];
  [simseries catC: "similarity_series.csv"];
  id <String> optrst = [csvFileBase copy: [self getZone]];
  [optrst catC: DIR_SEPARATOR];
  [optrst catC: "optimization_results.scm"];
  
  artResultsFile = [DMM openNewFile: artrst];
  refResultsFile = [DMM openNewFile: refrst];
  datResultsFile = [DMM openNewFile: datrst];
  simResultsFile = [DMM openNewFile: simrst];
  simSeriesFile = [DMM openNewFile: simseries];
  optResultsFile = [DMM openNewFile: optrst];

  [artrst drop];
  [refrst drop];
  [simrst drop];
  [simseries drop];
  [optrst drop];

  // prepend base to snapshot directory
  snapDirBase = [outFileBase copy: [self getZone]];
  [snapDirBase catC: DIR_SEPARATOR];
  [snapDirBase catC: "snap"];

}

- (void) startWith: (id <String>) base
{
  [Telem debugOut: 4 printf: "%s::startWith: %s(%p) -- begin\n",
         [[self getClass] getName], [base getC], base];

  // initialize data structure indices
  datOut = [Map createBegin: experAgent];
  [datOut setCompareFunction: pm_compare];
  datOut = [datOut createEnd];
  refOut = [Map createBegin: experAgent];
  [refOut  setCompareFunction: pm_compare];
  refOut = [refOut createEnd];
  artOut = [Map createBegin: experAgent];
  [artOut setCompareFunction: pm_compare];
  artOut = [artOut createEnd];

  if ( lobuleSpecInputFileName == nil )
    raiseEvent(InternalError, "\tlobuleSpecInputFileName = nil!\n");
  else {    // now initialize the lobule spec
    LobuleSpec *ls=nil;
    ls = [self loadLobuleSpecIntoZone: [self getZone]];
    // now write the new base file
    // also set the lobuleSpecOutputFileName
    [self nextLobuleSpec: ls mcSet: 0U];
    // now set the new lobuleSpecInputFileName equal to the old one
    // for the next mcSet
    [lobuleSpecInputFileName drop];
    lobuleSpecInputFileName = lobuleSpecOutputFileName;
  }

  // prepend base to runFileNameBase
  id <String> rfnb = [outFileBase copy: [self getZone]];
  [rfnb catC: DIR_SEPARATOR];
  [rfnb catC: [runFileNameBase getC]];
  [self setRunFileNameBase: [rfnb getC]];
  [rfnb drop];

  // prepend base to gml file name
  if (graphFileNameBase != nil) {
    id <String> gfnb = [outFileBase copy: [self getZone]];
    [gfnb catC: DIR_SEPARATOR];
    [gfnb catC: [graphFileNameBase getC]];
    [self setGraphFileNameBase: [gfnb getC]];
    [gfnb drop];
  }

  // check that all necessary files are named
  if (runFileNameBase == nil || pmFileNameBase == nil 
      || (lobuleSpecFileName == nil && graphFileNameBase == nil)) {
    raiseEvent(InvalidOperation, "\n%s(%p)::start -- DMM is missing one "
               "of the base file names for runs (%s), parameters (%s), or "
               "lobule specifications (%s), GML file (%s).\n",
               [self getName], self, [runFileNameBase getC], [pmFileNameBase getC],
               [lobuleSpecFileName getC], [graphFileNameBase getC]);

  }

}

- (void) start 
{
  id <String> str = [String create: [self getZone] setC: outputDirName];
  [str catC: DIR_SEPARATOR];
  [str catC: "liver.scm"];
  [self startWith: str];
  [str drop];
}

- (void) _incRecordFor: (id <Map>) outMap 
              paramSet: pm
{
  id <Map> mcMap=nil;
  id <Map> runMap=nil;
  id <Integer> mcRunNum = [Integer create: scratchZone setInt: [pm getRun]];

  [Telem debugOut: 3 printf: "%s::_incRecordFor: %s(%p) paramSet: %s(%p) -- begin\n",
         [self getName], [outMap getName], outMap, [pm getName], pm];
  {
    ParameterManager *indexPM = [globalZone copyIVars: pm];
    mcMap = [outMap at: pm];
    if (mcMap == nil) {
      [Telem debugOut: 5 printf: "%s::_incRecordFor:paramSet:  "
             "-- Creating a new Monte-Carlo Set for pm(%p) %d\n", 
             [self getName], pm, [pm getMonteCarloSet]];
      mcMap = [Map createBegin: experAgent];
      [mcMap setCompareFunction: (compare_t)int_compare];
      mcMap = [mcMap createEnd];
      [outMap at: indexPM insert: mcMap];
    }
  }
  runMap = [Map createBegin: experAgent];
  [runMap setCompareFunction: (compare_t)double_compare];
  runMap = [runMap createEnd];

  {
    id <Integer> key = nil;
    id <Map> map = nil;
    id <MapIndex> mcNdx = [mcMap mapBegin: scratchZone];
    while ( ([mcNdx getLoc] != End)
            && ( (map = [mcNdx next: &key]) != nil) ) {
      [Telem debugOut: 5 printf: "\n[key(%p) getInt] = %d",
             key, [key getInt]];
    }
    [mcNdx drop];
    [Telem debugOut: 5 printf: "\n[mcRunNum(%p) getInt] = %d\n",
           mcRunNum, [mcRunNum getInt]];
  }
  
  if (![mcMap at: mcRunNum insert: runMap]) { 
    raiseEvent(InvalidIndexLoc, "%s::_incRecordFor:paramSet: "
               "Duplicate monte carlo set for output data structure.\n",
               [self getName]);
  }

  [Telem debugOut: 3 printf: "%s::_incRecordFor:paramSet: -- end\n",
         [self getName]];
}

- (void) nextDMRecordParamSet: pm
{
  [Telem debugOut: 3 printf: "%s::nextDMRecordParamSet: pm = %p -- begin\n",
         [self getName]];

  [self _incRecordFor: datOut paramSet: pm];

  [Telem debugOut: 3 printf: "%s::nextDMRecordParamSet: -- end\n",
         [self getName]];

}
- (void) nextRMRecordParamSet: pm
{
  [Telem debugOut: 3 printf: "%s::nextRMRecordParamSet: pm = %p -- begin\n",
         [self getName]];

  [self _incRecordFor: refOut paramSet: pm];

  [Telem debugOut: 3 printf: "%s::nextRMRecordParamSet: -- end\n",
         [self getName]];

}
- (void) nextAMRecordParamSet: pm
{
  [Telem debugOut: 3 printf: "%s::nextAMRecordParamSet: pm = %p -- begin\n",
         [self getName]];

  [self _incRecordFor: artOut paramSet: pm];

  [Telem debugOut: 3 printf: "%s::nextAMRecordParamSet: -- end\n",
         [self getName]];

}

- (void) _log: (id <Map>) outMap 
     paramSet: (ParameterManager *) pm
           in: (FILE*) file
{ 
  // time, art avg, ecd, d1, ..., d12
  id <Map> runMap = nil;

  [Telem debugOut: 3 printf: "%s::_log:paramSet:in: -- begin\n",
         [self getName]];
  {
    id tempPM = nil;
    tempPM = [ParameterManager create: scratchZone];
    [tempPM setMonteCarloSet: 0xffffffff];  
    // get the avg runMap for parameter set pm
    runMap = [[outMap at: tempPM] at: pm]; 
    [tempPM drop];
  }

  fprintf(file, "Param Set %u\n", [pm getMonteCarloSet]);
  fprintf(file, "Time, "); 
 {
    id <MapIndex> ptNdx=nil;
    id <String> key=nil;

    // get the art labels to write to the file
    ptNdx = [[runMap getFirst] mapBegin: scratchZone];  
    while (( [ptNdx getLoc] != End) 
           && ([ptNdx next: &key] != nil) ) {
      if (key == nil)
        raiseEvent(InvalidLocSymbol, 
                   "%s::_log:paramSet:in:  Null key in outMap (%p)\n",
                   [self getName], outMap);
      if (strcmp([key getC], "Time") != 0) {
        fprintf(file,"%s, ",[key getC]);
      }
    }
    [ptNdx drop];

    fprintf(file, "\n");fflush(0);
    {
      id <MapIndex> rmNdx=nil;
      id <Double> time=nil;
      id <Map> point=nil;
      id <Double> outVal=nil;

      // walk the runMaps and output the data to the file
      rmNdx = [runMap mapBegin: scratchZone];
      while (( [rmNdx getLoc] != End)
             && ( (point = [rmNdx next: &time]) != nil) ) {
        fprintf(file, "%g, ", [time getDouble]);
        ptNdx = [point mapBegin: scratchZone];
        while (( [ptNdx getLoc] != End)
               && ((outVal = [ptNdx next: &key]) != nil) ) {
          if (key == nil)
            raiseEvent(InvalidLocSymbol,
                       "%s::_log:paramSet:in:  Null key in outMap (%p)\n",
                       [self getName], outMap);
          if (strcmp([key getC], "Time") != 0) {
            fprintf(file, "%g, ",[outVal getDouble]);
	  }
        }
        [ptNdx drop];

        fprintf(file, "\n");fflush(0);
      }
      [rmNdx drop];
    }
  }

  [Telem debugOut: 3 printf: "%s::_log:paramSet:in: -- end\n",
         [self getName]];

}

- (void) logGraph: (id <DiGraph>) g forRun: (int) run mcSet: (unsigned) mcSet
{
  VasGraph *vg = nil;

  [Telem debugOut: 3 printf: "%s::logGraph: %s(%p) forRun: %d -- begin\n",
         [[self getClass] getName], [[g getClass] getName], g, run];

  if ([(Object *)g isKindOf: [VasGraph class]]) {
    vg = (VasGraph *)g;
  } else
    raiseEvent(SaveError, "%s is not a VasGraph.\n", [g getName]);

  id <String> fileName = [graphFileNameBase copy: [self getZone]];
  [fileName catC: "_"];
  [fileName catC: [Integer intStringValue: mcSet]];
  [fileName catC: "_"];
  [fileName catC: [Integer intStringValue: run]];
  [fileName catC: [graphFileNameExtension getC]];
  [vg writeGMLToFile: [fileName getC]];
  [fileName drop];
}

- (void) logAMResultsParamSet: pm
{
  [self _log: artOut paramSet: pm in: artResultsFile];
}
- (void) logRMResultsParamSet: pm
{
  [self _log: refOut paramSet: pm in: refResultsFile];
}
- (void) logDMResultsParamSet: pm
{
  [self _log: datOut paramSet: pm in: datResultsFile];
}

/*
 * returns a map where keys are labels and values are runMaps
 */
- (id <Map>) getRunsFrom: (id <Map>) outMap maskedBy: (id <Map>) maskMap
{
  id <Map> runs=[Map create: globalZone];
  /*
   * The mcSetMap is a Monte-Carlo map for individual runs,
   * and a parameterManager map for statistical data.
   */
  id <Map> mcSetMap=nil;
  id pm=nil;
  id <MapIndex> pmNdx=[outMap mapBegin: scratchZone];
  id <String> geLabel=nil;
  const char *prefix=(const char *)nil;

  if (outMap == datOut) 
    prefix = "Dat";
  else if (outMap == refOut)
    prefix = "Ref";
  else
    prefix = "Art";

  // loop over all the parameter vectors
  while (([pmNdx getLoc] != End)
         && ( (mcSetMap = [pmNdx next: &pm]) != nil) ) {
    unsigned plotVal = [pm getMonteCarloSet];
    BOOL masked = NO;

    masked = [self isPM: pm maskedBy: maskMap];
    if (masked) continue;

    /*
     * interpret the pm code and insert the stats and the monte-carlo
     * into the runs data struct
     */

    // stats branch
    if (plotVal == 0xffffffff) {
      // in this case, the mcSetMap is really a pmMap, whose keys
      // are parameter sets and values are trajectories
      id <MapIndex> statRunNdx = [mcSetMap mapBegin: scratchZone];
      id <ParameterManager> statPM = nil;
      id <Map> statRunMap = nil;
      unsigned pmCounter = 0L;

      // loop over all the parameter set runs and add them to runs
      while ( ([statRunNdx getLoc] != End)
              && ( (statRunMap = [statRunNdx next: &statPM]) != nil) ) {
        if (![self isPM: statPM maskedBy: maskMap]) {
          geLabel = [String create: globalZone setC: prefix];
          [geLabel catC: " Avg ParamSet "];
          [geLabel catC: [Integer intStringValue: pmCounter]];
          [runs at: geLabel insert: statRunMap];
          pmCounter++;
        }
      }
    } else {
      id <Integer> mcRunNum = nil;
      id <MapIndex> mcNdx = [mcSetMap mapBegin: scratchZone];
      id <Map> mcRunMap = nil;

      while ( ([mcNdx getLoc] != End)
              && ( (mcRunMap = [mcNdx next: &mcRunNum]) != nil) ) {
        geLabel = [String create: globalZone setC: prefix];
        [geLabel catC: " MC Sample "];

        [geLabel catC: [mcRunNum intStringValue]];
        [runs at: geLabel insert: mcRunMap];
      }

      [mcNdx drop];
    }

  }
  return runs;
}

- (FILE *) buildFileName: (id <String> *) fileName 
                fromBase: (id <String>) base 
             writeHeader: (id <String>) header
{

  FILE * retFile = (FILE *)nil;

  id <String> fn = [outFileBase copy: [base getZone]];
  fn = [outFileBase copy: [base getZone]];
  [fn catC: DIR_SEPARATOR];
  [fn catC: [base getC]];
  [fn catC: "_"];
  [fn catC: [Integer intStringValueOf: monteCarloSet
                     format: "%d" places: 4]];
  [fn catC: "_"];
  [fn catC: [Integer intStringValueOf: runNumber 
                     format: "%d" places: 4]];
  [fn catC: ".csv"];
  *fileName = fn;
  retFile = [LiverDMM openNewFile: *fileName];

  // write the header
  fprintf(retFile, "%s\n", [header getC]);
  return retFile;
}


/*
 * Observation methods
 */
- (id <Map>) getOutputs: model 
{
  id <Map> retVal=nil;

  if ([model isKindOf: [ArtModel class]]) 
    retVal = [(ArtModel *)model getOutputs];
  else if ([model isKindOf: [DatModel class]])
    if ([experAgent interpolateDatModel]) 
      retVal = [(DatModel *)model getOutputsInterpolatedAt: 
                              [experAgent getModelTime]];
    else
      retVal = [(DatModel *)model getOutputs];
  else if ([model isKindOf: [RefModel class]]) 
    retVal = [(RefModel *)model getOutputs];
  
  return retVal;
}

- (id <String>) getLobuleSpecFileExtension { return lobuleSpecFileExtension; }
- (const char *) getInputDirName { return inputDirName; }
- (const char *) getOutputDirName { return outputDirName; }
- (id <String>) getValDataFileName { return valDataFileName; }

- (void) setSubDMM { [super setSubDMM: self];}
@end
