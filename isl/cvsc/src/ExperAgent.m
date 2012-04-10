/*
 * ISL - Experiment Agent
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#undef NDEBUG
#import "ExperAgent.h"
#include <assert.h>
#import <float.h>
#import <simtoolsgui.h>
#import <defobj.h> // Archivers
#import <misc.h>  // unlink
#import <dirent.h> // for DIR and dirent
#import <fnmatch.h> // for fnmatch()
#import <LocalRandom.h>
#import <modelUtils.h>

@implementation ExperAgent

// runtime methods

#import "artModel/VasGraph.h"

PHASE(Creating)
+ createBegin: aZone 
{
  return [super createBegin: aZone];
}

PHASE(Setting)

- (void) buildProbeMap
{
  id <ProbeMap> theProbeMap;
  // Build a customized probe map for ExperAgent -- we cannot use
  // a full probemap because we don't want to retain pointers to 
  // dropped objects.

  theProbeMap = [EmptyProbeMap createBegin: self];
  [theProbeMap setProbedClass: [self class]];
  theProbeMap = [theProbeMap createEnd];

  [theProbeMap addProbe: [probeLibrary getProbeForVariable: "runNumber"
                                       inClass: [self class]]];

  [theProbeMap addProbe: [probeLibrary getProbeForMessage: "toggleEndGraphStatsFor:"
                                   inClass: [self class]]];
  [theProbeMap addProbe: [probeLibrary getProbeForMessage: "toggleEndGraphAllOf:"
                                   inClass: [self class]]];


  [probeLibrary setProbeMap: theProbeMap For: [self class]];

}

- createEnd
{
  ExperAgent *obj;
  obj = [super createEnd];


  // Fill in the relevant parameters 
  obj->experScratchZone = [Zone create: obj];
  obj->paramDir = nil;
  obj->runNumber = 0;
  obj->runBase = 0;
  obj->monteCarloRuns = 30;
  obj->monteCarloSet = 0L;
  obj->rerunRM = NO;
  obj->rerunDM = NO;
  obj->paramFileList = nil;
  obj->paramFileNdx = nil;
  obj->pname = nil;
  obj->pmArchiver = nil;
  obj->guiOn = NO;
  obj->similarityBandCoefficient = 1.0;

  return obj;
}

- (void) setParamFileList: (id <List>) pl
{
  if (pl == nil)
    raiseEvent(InvalidArgument, "\tparameter file list is nil.");
  if ([pl getCount] <= 0L)
    raiseEvent(InternalError, "\tparameter file list is empty.");
  paramFileList = pl;

  paramFileNdx = [paramFileList listBegin: self];
}

PHASE(Using)

- buildModel
{
  [Telem debugOut: 2 printf: "%s::buildModel -- Enter\n", [self getName]];

  if(dLevel == 2) 
    {
      // for user feedback
      fprintf(stdout, "Begin Run %d  Time: ######\b\b\b\b\b\b", runNumber);fflush(0);
    }
  // clean up gui from the last run, here, so user can stare at it
  if ( resultGraph != nil) [self _resultGraphDeath_];
  if ( dosageGraph != nil) [self _dosageGraphDeath_];

  [dMM logParameters: parameterManager];

  datModel = [[[CSVDatModel create: self] setName: "DatModel"] setParent: self];
  refModel = [[[RefModel create: self] setName: "ECDModel"] setParent: self];
  artModel = [[[ArtModel create: self] setName: "ArtModel"] setParent: self];

  // for user feedback (1st)
  if(dLevel == 2) {fprintf(stdout,"-");fflush(0);}

  // If this is the first model, create a custom probeMap for modelSwarm 
  // This has to be done here because we need instances of these classes?

  if (runNumber == runBase)
    {
      // Build a customized probe map for the class ModelSwarm
      
      datProbeMap = [[[EmptyProbeMap createBegin: self] 
                        setProbedClass: [datModel class]] createEnd];
      refProbeMap = [[[EmptyProbeMap createBegin: self] 
                         setProbedClass: [refModel class]] createEnd];
      artProbeMap = [[[EmptyProbeMap createBegin: self] 
                         setProbedClass: [artModel class]] createEnd];

      // Add in a bunch of variables, one per simulation parameter

      // dat
      [datProbeMap addProbe: [probeLibrary getProbeForVariable: "cycle"
                                             inClass: [DatModel class]]];

      [datProbeMap addProbe: [probeLibrary getProbeForVariable: "cycleLimit"
                                             inClass: [DatModel class]]];

      // ref
      [refProbeMap addProbe: [probeLibrary getProbeForVariable: "cycle"
                                             inClass: [refModel class]]];
      [refProbeMap addProbe: [probeLibrary getProbeForVariable: "cycleLimit"
                                             inClass: [refModel class]]];
      [refProbeMap addProbe: [probeLibrary getProbeForVariable: "epsilon"
                                             inClass: [refModel class]]];

      // model
      [artProbeMap addProbe: [probeLibrary getProbeForVariable: "cycle"
                                           inClass: [artModel class]]];
      [artProbeMap addProbe: [probeLibrary getProbeForVariable: "cycleLimit"
                                           inClass: [artModel class]]];

      // Now install our custom probeMap into the probeLibrary.
      [probeLibrary setProbeMap: datProbeMap For: [datModel class]];
      [probeLibrary setProbeMap: refProbeMap For: [refModel class]];
      [probeLibrary setProbeMap: artProbeMap For: [artModel class]];      
    } // endif

  // for user feedback (2nd)
  if(dLevel == 2) {fprintf(stdout,"-");fflush(0);}
  
  [Telem debugOut: 2 printf: "parameterManager = %p\n", parameterManager];

  if (rerunDM || runNumber < runBase + 1)
    [dMM nextDMRecordParamSet: parameterManager];

  [Telem debugOut: 2 printf: "parameterManager = %p\n"
         "\trunNumber = %d\n", parameterManager, runNumber];

  if (rerunRM || runNumber < runBase + 1)
    [dMM nextRMRecordParamSet: parameterManager];
  [dMM nextAMRecordParamSet: parameterManager];

  // first initialize the parameters inside each
  [parameterManager initializeDat: datModel];
  [parameterManager initializeRef: refModel];
  [parameterManager initializeArt: artModel];

  [datModel buildObjects];
  [datModel buildActions];
  [datModel activateIn: nil];
  [refModel buildObjects];
  [refModel buildActions];
  [refModel activateIn: nil];

  // for user feedback (3rd)
  if(dLevel == 2) {fprintf(stdout,"-");fflush(0);}

  // extra piece of artModel initialization before buildObjects 
  if(artGraphFileName == '\0' && lobuleSpecFileName == '\0' )
    raiseEvent(LoadError, "You must specify either a GML file or a "
	       "Lobule Specification file.\n");

  // set up the vasgraph
  if (lobuleSpecFileName != (const char *)nil 
      && strcmp(lobuleSpecFileName, "") > 0 ) {
    [Telem monitorOut: 2 
           printf: "%s::buildModel() - generating graph from %s\n",
           [self getName], lobuleSpecFileName];
    [artModel useLobuleSpec: [dMM loadLobuleSpecIntoZone: artModel]];
  } else if (artGraphFileName != (const char *)nil
             && strcmp(artGraphFileName, "") > 0 ) {

    [Telem monitorOut: 2 printf: "%s::buildModel() - reading graph from %s\n",
           [self getName], artGraphFileName];
    [dMM readGML: artGraphFileName intoGraph: [artModel getEmptyGraph]];

  } else {
      raiseEvent(LoadError, "Graph specification mechanism is ambiguous.\n"
                "Do you want to use a Lobule Specification or a GML file?\n");
  }

  [artModel enableSoluteTrace: enableTrace];
  [artModel buildObjects];
  
  // for user feedback (4th)
  if(dLevel == 2) {fprintf(stdout,"-");fflush(0);}
  
  [artModel buildActions];
  [artModel activateIn: nil];

  // for user feedback (5th)
  if(dLevel == 2) {fprintf(stdout,"-");fflush(0);}

   // build the runFile header
  {
    id <List> header = [List create: scratchZone];
    id <ListIndex> labelNdx = [[datModel getLabels] listBegin: scratchZone];
    [header addLast: [[labelNdx next] copy: scratchZone]];  // Time
    id <String> label=nil;
    id <String> ref = [String create: scratchZone setC: "Ref"];
    if (rerunRM || runNumber < runBase + 1) 
      [header addLast: ref];


    // fill in artModel blood solute types
    //    id <String> art = [String create: scratchZone setC: "Art"];
    //    [header addLast: art];
    
    id <MapIndex> bcNdx = [parameterManager->bolusContents mapBegin: scratchZone];
    id <SoluteTag> key = nil;
    while (([bcNdx getLoc] != End)
           && ([bcNdx next: &key]) ) {
      id <String> l = [String create: scratchZone setC: "art-blood-"];
      [l catC: [key getName]];
      if (key != nil) [header addLast: l];
    }
    [bcNdx drop]; bcNdx = nil;

    // fill in artModel bile solute types
    [header addLast: [String create: scratchZone setC: "bile-Metabolite"]];

    if (rerunDM || runNumber < runBase + 1)
      while ( ([labelNdx getLoc] != End)
              && ((label = [labelNdx next]) != nil))
        [header addLast: [label copy: scratchZone]];
    [dMM writeRunFileHeader: header];
    [labelNdx drop]; labelNdx = nil;
    [header deleteAll];
    [header drop]; header = nil;
    //    [ref drop];
    //    [art drop];
  }

  // for user feedback (6th)	 
  if(dLevel == 2) {fprintf(stdout,"-");fflush(0);}
  
  // build the live, per-run, data views
  if (guiOn && showLiveData)
    [self buildRunDataViews];

  if (runNumber == runBase && guiOn && showLiveAgg)
    [self buildExperDataViews];

  // and finally, prime the experSchedule with 4 initial actions
  [stepSchedule at: 0 
                createActionTo: self 
                message: M(stepModel:) : artModel];
  [stepSchedule at: 0
                createActionTo: self 
                message: M(stepModel:) : datModel];
  [stepSchedule at: 0 
                createActionTo: self
                message: M(stepModel:) : refModel];
  [stepSchedule at: 0 createActionTo: self message: M(contModels)];

  [stepSchedule at: 0 createAction: obsActions];

  
  //xfprint(stepSchedule);
  [Telem debugOut: 1 printf: "%s::buildModel -- Exit\n",
         [self getName]];

  
  if(dLevel == 2) {fprintf(stdout,"\b\b\b\b\b\b  0.00");fflush(0);}
	 
  return self;
}  

- stepModel: (id <Swarm>) model {
  float controlTime=0xFFFFFFFF;
  id <Symbol> status=(id)nil;
  status = [[model getActivity] getStatus];
  // if its the ABM, just go one cycle
  if ([(Object *)model isKindOf: [ArtModel class]]) {
    if (status != Completed && status != Terminated) {
      [artModel step];
    }
  } else {
    // if its the data or ref swarm, then catch up to the Art
    controlTime = [artModel getTime];
    if ([(Object *)model isKindOf: [RefModel class]]) {
      [refModel stepUntilTimeIs: controlTime];
    } else if ([(Object *)model isKindOf: [DatModel class]]) {
      [datModel stepUntilTimeIs: controlTime];
    }
  }
  return self;
}

- contModels {
  timeval_t cycle = 0U;
  id <Symbol> status=(id)nil;
  cycle = [[self getActivity] getCurrentTime];

  // The Art controls the execution
  status = [[artModel getActivity] getStatus];
  if (status != Completed && status != Terminated) {

    // schedule the modelSwarm
    [stepSchedule at: cycle+1
                  createActionTo: self
                  message: M(stepModel:) : artModel];

    // schedule the datModel
    if (rerunDM || runNumber < runBase + 1) {
      status = [[datModel getActivity] getStatus];

      if (status != Completed && status != Terminated) {

        [stepSchedule at: cycle+1
                      createActionTo: self
                      message: M(stepModel:) : datModel];
      }
    }
    // schedule the refModel
    if (rerunRM || runNumber < runBase + 1) {
      status = [[refModel getActivity] getStatus];
      if (status != Completed && status != Terminated) {
        [stepSchedule at: cycle+1
                      createActionTo: self
                      message: M(stepModel:) : refModel];
      }
    }

    // re-schedule myself
    [stepSchedule at: cycle+1 createActionTo: self message: M(contModels)];
    [stepSchedule at: cycle+1 createAction: obsActions];
  } 
  return self;
}

/*
 * stopExperiment - Run once at the end of each run to 
 *                  determine whether or not the experiment is 
 *                  complete.  (It's a question "Stop Experiment?")
 */
- stopExperiment
{
  if(dLevel == 2) 
    fprintf(stdout, " End Run %d\n", runNumber);  
  runNumber++;
  [dMM endRun];

  fprintf(stderr, "stopExperiment? -- runNumber = %d, runBase = %d, monteCarloRuns = %d\n", runNumber, runBase, monteCarloRuns);

  if ((runNumber - runBase) >= monteCarloRuns) {
    similarity = 0.0F; 
 
    [self computeSimilarity: [dMM getArtMap] refMap: [dMM getRefMap] datMap: [dMM getDatMap]];

    if (dLevel == 2) {
      fprintf(stdout, "********************************************************\n");
      fprintf(stdout, "************** Monte-Carlo set is Finished! ************\n");
      fprintf(stdout, "************ %4d Monte-Carlo runs completed ***********\n", runNumber);
      fprintf(stdout, "************ Similarity Score: %10g **************\n", similarity);
      fprintf(stdout, "********************************************************\n\n\n");
    }

    monteCarloSet++;
    [parameterManager setMonteCarloSet: monteCarloSet];

    if ( ![parameterManager stepParameters: self] ) {

      if (dLevel == 2) {
        fprintf(stdout, "********************************************************\n");
        fprintf(stdout, "***************** Experiment is Finished! **************\n");
        fprintf(stdout, "********** %4d Monte-Carlo sets completed *************\n", monteCarloSet);
        fprintf(stdout, "********************************************************\n\n\n");
      }
      // display the end-of-experiment plot
      if (guiOn) {
        [self buildEndDataViewOf: [dMM getArtMap] maskedBy: nil];
        [probeDisplayManager update];
        [actionCache doTkEvents];
      }
      [dMM stop];
      [archiver drop];
      
      if (guiOn) [controlPanel setStateStopped];
      [[self getActivity] terminate];
      
    } else { // still more parameter settings to walk through
      runNumber = runBase;

      // do experInitSchedule -- actions needed for new mcSet 
      timeval_t cycle = 0U;
      cycle = [[self getActivity] getCurrentTime];
      [experInitSchedule at: cycle+1
                         createActionTo: self
                         message: M(mcSetInit)];

      fprintf(stderr, "\tstarting new mcSet, runNumber = %d, runBase = %d, monteCarloRuns = %d\n", runNumber, runBase, monteCarloRuns);
    }
  } else { // continue with the next monteCarloRun in this set
    [dMM beginRun: runNumber mcSet: monteCarloSet];
  }
  [parameterManager setRun: runNumber];

  return self;
}

- computeSimilarity: (id <Map>)aMap refMap: (id <Map>)rMap datMap: (id <Map>)dMap
{
 // do the end-of-monte-carlo calculations
  [StatCalculator sumUpDM: aMap forPM: parameterManager];
  [StatCalculator sumUpDM: rMap forPM: parameterManager];
  [StatCalculator sumUpDM: dMap forPM: parameterManager];

  [dMM logAMResultsParamSet: parameterManager];  
  [dMM logRMResultsParamSet: parameterManager];
  [dMM logDMResultsParamSet: parameterManager];
    
  // this is to ensure that Tk shows the above plots
  if (guiOn) {
    [probeDisplayManager update];
    [actionCache doTkEvents];
  }
        
  // this method must occur after "sumUpDM:
  id <List> similarityData = [List create: scratchZone];
  id <Map> nomMap = nil;
  id <Map> expMap = nil;

  if ( strcmp([nominalProfile getC], "dat") == 0 )  nomMap = dMap;
  else if ( strcmp([nominalProfile getC], "ref") == 0 ) nomMap = rMap;
  else if ( strcmp([nominalProfile getC], "art") == 0 ) nomMap = aMap;
  else
    raiseEvent(InvalidArgument, "\n%s(%p)::buildModel -- could not "
	       "classify nominal profile type %s.",
	       [self getName], self, [nominalProfile getC]);

  if ( strcmp([experimentalProfile getC], "dat") == 0 )  expMap = dMap;
  else if ( strcmp([experimentalProfile getC], "ref") == 0 ) expMap = rMap;
  else if ( strcmp([experimentalProfile getC], "art") == 0 ) expMap = aMap;
  else
    raiseEvent(InvalidArgument, "\n%s(%p)::buildModel -- could not "
	       "classify experimental profile type %s.",
	       [self getName], self, [experimentalProfile getC]);
 
 
  similarity = 
    [StatCalculator computeSimilarityUsing: similarityMeasure 
		    trainingDat: dMap
		    paramSet: parameterManager
		    nom: nominalProfile
         	    columnLabel: nominalProfileColumnLabel /*[String create: scratchZone setC: "Diltiazem"]*/
		    nomDataMap: nomMap
		    exp: experimentalProfile
		    expDataMap: expMap
		    bandCoef: similarityBandCoefficient
		    storeIn: similarityData];
  [dMM logSimilarityResult: similarityData];
  [similarityData forEach: M(deleteMembers)];
  [similarityData deleteAll];
  [similarityData drop];
   
  return self;
}

- (double) getSimilarity
{
  return similarity;
}

- (void) setSimilarity: (double) s
{
  similarity = s;
}

// observation methods

/*
 * logRun - To be run at each cycle of each experiment to 
 *          capture the results of each ExperAgent computation.
 */
- logRun
{
///  id <Zone> tmpZone = [Zone create: scratchZone];
  static id <List> data = nil;
  id <Double> valObj=nil;
  id <String> labelObj=nil;
  id <Map> datMap = nil;
  id <ListIndex> labelNdx = [[datModel getLabels] listBegin: scratchZone];

  [Telem debugOut: 2 printf: "ExperAgent::logRun() -- Enter\n"];

  // log the graph structure
  [dMM logGraph: [artModel getGraph] forRun: runNumber mcSet: monteCarloSet];


  /*
   * log the run data
   */
  [labelNdx next];  // throw away time

  if (data == nil) data = [List create: self];
  // time, ecd, art, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12

  [Telem debugOut: 2 printf: "logRun() -- [artModel getTime] = %lf\n",
         [artModel getTime]];

  [data addLast: [Double create: scratchZone setDouble: [artModel getTime]]];

  if (rerunRM || runNumber < runBase + 1) {
    [data addLast: [Double create: scratchZone 
                           setDouble: [refModel getOutputFraction]]];
  }


  /*
   * add art blood solute data
   */
//    [data addLast: [Double create: scratchZone 
//                           setDouble: [artModel getOutputFraction]]];
//    [Telem debugOut: 2 printf: "\t[artModel getOutputFraction] => %lf\n",
//           [artModel getOutputFraction]];

  id <Map> artDataPoint = [dMM getOutputs: artModel]; // allocates memory
  id <MapIndex> bcNdx = [parameterManager->bolusContents mapBegin: scratchZone];
  id <SoluteTag> key = nil;
  while (([bcNdx getLoc] != End)
         && ([bcNdx next: &key]) ) {
    id <String> key_s = [String create: scratchZone setC: [key getName]];
    Double *val = [artDataPoint at: key_s];
    [Telem debugOut: 2 printf: "\tartModel->%s => %lf\n", [key_s getC], [val getDouble]];
    [data addLast: [val copy: scratchZone]];
    [key_s drop]; key_s = nil;
  }
  [bcNdx drop]; bcNdx = nil;
  [artDataPoint deleteAll];
  [artDataPoint drop]; artDataPoint = nil;

  /*
   * add art bile solute data
   */
  [data addLast: [Double create: scratchZone 
			 setDouble: [artModel getBileOutputFraction]]];

  if (rerunDM || runNumber < runBase + 1) {
    datMap = [dMM getOutputs: datModel];

    while ( ([labelNdx getLoc] != End)
            && ( (labelObj = [labelNdx next]) != nil) ) {
      valObj = [datMap at: labelObj];
      // we have to copy here in order to drop later
      [data addLast: [scratchZone copyIVars: valObj]];
    }

    { // debug clause
      id <String> tempStr = [String create: scratchZone setC: "Time"];
      //id <Double> time=[datMap at: tempStr];
      [tempStr drop]; tempStr = nil;
      [Telem debugOut: 2 printf: "%s(%p)::logRun() -- \n",
	     [[self getClass] getName], self];
      id <String> key = nil;
      id <Double> val = nil;
      int datMapSize = [datMap getCount];
      int count = 0;
      id <MapIndex> dNdx = [datMap mapBegin: scratchZone];
      while ( ([dNdx getLoc] != End) && 
	      ( (val = [dNdx next: &key]) != nil)) {
        [Telem debugOut: 2 printf: "%s = %lf%s",
               [key getC], [val getDouble],
               (count++ == datMapSize-1 ? "\n" : ", ")];
      }
      [dNdx drop];

    } // end debug clause

  } // end logRun()

  [dMM writeRunFileData: data];

  [labelNdx drop];
  [data deleteAll];  
 
  if (datMap != nil) {
    [datMap deleteAll];
    [datMap drop];
  }
  /*
   * end logging run data
   */
  
 /// [tmpZone drop];
  
  [Telem debugOut: 2 printf: "ExperAgent::logRun() -- Exit\n"];

  return self;
}

- _showAggStatsFor_: (id <Map>) point withElements: (id <Map>) outElements
{
  id <String> outKey=nil;
  id <GraphElement> ge=nil;
  id <MapIndex> outNdx = [point mapBegin: scratchZone];
  id output=nil;
  id indep=nil;
  id <String> tempStr = [String create: scratchZone setC: "Time"];

  indep = [point at: tempStr];
  while ( ([outNdx getLoc] != End)
          && ( (output = [outNdx next: &outKey]) != nil) ) {
    if ([outKey compare: tempStr] != 0) {
      ge = [outElements at: outKey];
      if (ge != nil) {
        double x = [indep getDouble];
        double y = [output getDouble];
        if (y < FLT_EPSILON) y = FLT_EPSILON;
        [ge addX: x Y: y];
        [Telem debugOut: 2 printf: "Plotting (%lf, %lf)\n",
               [indep getDouble], [output getDouble]];
      }
    }
  }
  [outNdx drop];
  [tempStr drop];

  return self;
}

/*
 * showStats - To be run at each cycle to publish each computation
 *             to the observers.
 */
- showStats
{
  if (showLiveData) {
    double dmX = 0.0F, rmX = 0.0F, amX = 0.0F;
    double dmY = 0.0F, rmY = 0.0F, amY = 0.0F;

    if (rerunDM || runNumber < runBase + 1) {
      dmX = [datModel getTime];
      // note that this is only 1 of the datModel outputs
      dmY = [datModel getOutputFraction];
      if (dmY < FLT_EPSILON) dmY = FLT_EPSILON;
    }
    if (rerunRM || runNumber < runBase + 1) {
      rmX = [refModel getTime];
      rmY = [refModel getOutputFraction];
      if (rmY < FLT_EPSILON) rmY = FLT_EPSILON;
    }
    amX = [artModel getTime];
    amY = [artModel getOutputFraction];
    if (amY < FLT_EPSILON) amY = FLT_EPSILON;

    if (resultGraph) {
      if (rerunDM || runNumber < runBase + 1) [datModelE addX: dmX Y: dmY];
      if (rerunRM || runNumber < runBase + 1) [refModelE addX: rmX Y: rmY];
      [artModelE addX: amX Y: amY];
    }
  }

  if (showLiveAgg) {
    if (rerunDM || runNumber < runBase + 1) 
      [self _showAggStatsFor_: datCurrentPoint withElements: datElements];
    if (rerunRM || runNumber < runBase + 1)
      [self _showAggStatsFor_: refCurrentPoint withElements: refElements];
    [self _showAggStatsFor_: artCurrentPoint withElements: artElements];
  }

  if (showLiveData) {
    if (dosageGraph) {
      double amX  = [artModel getTime];
      double dose = [artModel getCurrentDosage];
      if (dose < FLT_EPSILON) dose = FLT_EPSILON;
      [dosageE addX: amX Y: dose];
    }
  }
  return self;
}

- doStats
{
  [Telem debugOut: 2 printf: "ExperAgent::doStats() -- Enter\n"];

  // Collect a datapoint on the model

  if (rerunDM || runNumber < runBase + 1) datCycle = [datModel getCycle];
  if (rerunRM || runNumber < runBase + 1) refCycle = [refModel getCycle];
  artCycle =  [artModel getCycle];

  // this provides the user with feedback that things are moving
  if(dLevel == 2)
    fprintf(stdout, "\b\b\b\b\b\b%6.2f", [self getModelTime]);

  { // fill a data structure to be shown at the end of all runs
    id <Map> dataPoint = nil;
    id <String> tempStr = [String create: scratchZone setC: "Time"];
    id <Map> mcMap = nil;
    id <Integer> mcRunNum = [Integer create: scratchZone setInt: runNumber];
    id <Map> trajMap = nil;

    if (rerunDM || runNumber < runBase + 1) {
      dataPoint = [dMM getOutputs: datModel];

        { // debug loop
          id <Double> val = nil;
          id <String> label = nil;
          id <MapIndex> dpNdx = [dataPoint mapBegin: scratchZone];
          [Telem debugOut: 1 printf: "doStats() -- DatModel dataPoint --\n"];
          while (([dpNdx getLoc] != End)
                 && ( val = [dpNdx next: &label]) != nil) {
            [Telem debugOut: 1 printf: "\t<%s(%p), val = %lf(%p)>\n",
                   [label getC], label, [val getDouble], val];
          }
          [dpNdx drop];

        }


        datCurrentPoint = dataPoint;
        mcMap = [[dMM getDatMap] at: pmNdx];
        trajMap = [mcMap at: mcRunNum];
        [trajMap at: [datCurrentPoint at: tempStr]
                 insert: datCurrentPoint];
    }

    if (rerunRM || runNumber < runBase + 1) {
      dataPoint = [dMM getOutputs: refModel];
      refCurrentPoint = dataPoint;
      mcMap = [[dMM getRefMap] at: pmNdx];
      trajMap = [mcMap at: mcRunNum];
      [trajMap at: [refCurrentPoint at: tempStr]
               insert: refCurrentPoint];
    }

    dataPoint = [dMM getOutputs: artModel];
    artCurrentPoint = dataPoint;
    mcMap = [[dMM getArtMap] at: pmNdx];
    trajMap = [mcMap at: mcRunNum];
    [trajMap at: [artCurrentPoint at: tempStr]
             insert: artCurrentPoint];

    {
      [Telem debugOut: 2 print: "artCurrentPoint = \n"];
      [Telem debugOut: 2 printPoint: artCurrentPoint];
    }

    [tempStr drop];
    [mcRunNum drop];
  }

  [Telem debugOut: 2 printf: "ExperAgent::doStats() -- Exit\n"];

  return self;
}

/*
 * buildRunDataViews - Sets up the plot for the per run data series.
 */
- buildRunDataViews
{

  resultGraph = [LogPlotter createBegin: self];
  [resultGraph setSaveSizeFlag: NO];
  SET_WINDOW_GEOMETRY_RECORD_NAME (resultGraph);
  resultGraph = [resultGraph createEnd];
  [resultGraph setTitle: "OutputFraction"];
  [resultGraph setAxisLabelsX: "Time" Y: "OutputFraction"];
  [resultGraph setScaleModeX: YES Y: YES];
  [resultGraph setYAxisLogscale];

  datModelE = [resultGraph createElement];
  [datModelE setLabel: "Dat:A"];
  [datModelE setColor: "black"];

  refModelE = [resultGraph createElement];
  [refModelE setLabel: "Ref"];
  [refModelE setColor: "blue"];

  artModelE = [resultGraph createElement];
  [artModelE setLabel: "Art"];
  [artModelE setColor: "red"];

  [resultGraph pack];

  [resultGraph enableDestroyNotification: self
               notificationMethod: @selector (_resultGraphDeath_)];

  dosageGraph = [LogPlotter createBegin: self];
  [dosageGraph setSaveSizeFlag: NO];
  SET_WINDOW_GEOMETRY_RECORD_NAME (dosageGraph);
  dosageGraph = [dosageGraph createEnd];
  [dosageGraph setTitle: "Dosage"];
  [dosageGraph setAxisLabelsX: "Time" Y: "Dosage"];
  [dosageGraph setScaleModeX: YES Y: YES];
  [dosageGraph setYAxisLogscale];

  dosageE = [dosageGraph createElement];
  [dosageE setLabel: "Dosage"];
  [dosageE setColor: "black"];

  [dosageGraph pack];

  [dosageGraph enableDestroyNotification: self
               notificationMethod: @selector (_dosageGraphDeath_)];

  return self;
}

/*
 * logExperiment - To be run once at the end of each experiment
 *                 to capture data that is constant throughout the
 *                 run.
 */
- logExperiment
{
  // have the parameterManager log its state
#ifdef USE_LISP
  [archiver sync];
#endif

  return self;
}

- (BOOL) interpolateDatModel
{
  return interpDatModel;
}

// accessors

- (unsigned)getModelCycle
{
   return [artModel getCycle];
}

- (double) getModelTime
{
  return [artModel getTime];
}

- (unsigned) getRunNumber{
	return runNumber;
}

// construction methods

- setGUIMode: (BOOL) gui {
  guiOn = gui;
  return self;
}

// Create the objects used by the experiment swarm itself
- buildObjects
{
  return [self buildObjects: nil];
}
- buildObjects: (id <String>) pf
{
  // call Swarm's buildObjects
  [super buildObjects];

  // if we want a gui, start the controlPanel and actionCache
  if (guiOn) {
    controlPanel = [ControlPanel create: [self getZone]];
    // create the actionCache, we will initialize it in activateIn
    actionCache = [ActionCache createBegin: [self getZone]];
    SET_COMPONENT_WINDOW_GEOMETRY_RECORD_NAME (actionCache);
    [actionCache setSaveSizeFlag: saveSizeFlag];
    [actionCache setControlPanel: controlPanel];
    actionCache = [actionCache createEnd];
  }

  // set the data manager singleton (dMM) -- required by initPM
  dMM = [LiverDMM create: self];
//	[dMM setInputDirName: [paramDir getC]];
  [dMM setExperAgent: self];
  [dMM setSubDMM];

  // create the parameter manager and set up a probeDisplay
  if (![self initPM: pf])
    raiseEvent(LoadError, "\tNo parameter files to load.\n");
  if (guiOn) CREATE_ARCHIVED_PROBE_DISPLAY (parameterManager);

  // Build a probeDisplay on ourself for modifying ExperAgent values
  if (guiOn) CREATE_ARCHIVED_PROBE_DISPLAY (self);

  // Allow the user to alter experiment parameters
  if (guiOn) [controlPanel setStateStopped];

  [Telem debugOut: 2 printf: "ExperAgent::buildObjects() -- Exit\n"];

  return self;
}

- (BOOL) initPM
{
  return [self initPM: nil];
}

- (BOOL) initPM: (id <String>) pf
{
	if(pf == nil) { // -T or default option
		if(paramFileNdx == nil) {
			char pattern[512]; // suffix pattern (e.g., *suffix)
			DIR *dirp; // a pointer of a directory
			struct dirent *direntp; // a pointer of each directory entry data structure
			const char *parmdir = [paramDir getC];
			dirp = opendir(parmdir);
			if(dirp  == NULL) {
				fprintf(stderr, "Could not open %s directory: %s\n", parmdir, strerror(errno));
				exit(1);
			}
			sprintf(pattern, "*%s",  "scm");
			while((direntp = readdir(dirp)) != NULL)
				if(fnmatch(pattern, direntp->d_name, FNM_NOESCAPE) == 0)
					[paramFileList addLast: [String create: [self getZone] setC: direntp->d_name]];
			closedir(dirp);
			paramFileNdx = [paramFileList listBegin: self];
		}
	} else {  // -F option
		if(paramFileNdx == nil) {
			char *ptr;
			char *str = (char *)[pf getC];
			while((ptr = strstr(str, "/")) != '\0')  str = ptr + 1;
			id<String> outDir = [String create: globalZone setC: str];
			[paramFileList addLast: outDir];
			paramFileNdx = [paramFileList listBegin: self];
		}
	}

	BOOL retVal = YES; // yes => new PM, no => finished
	id <String> newParamFileName = nil;
	startNewLogDir = YES;

	// jump out of here if there are no files to use
	if (([paramFileNdx getLoc] == End) ||
		(newParamFileName = [paramFileNdx next]) == nil) {
		[Telem debugOut: 1 printf: "[%s -initPM] -- No parameter files left.",
		[[self getClass] getName]];
		retVal = NO;
		startNewLogDir = NO;
		return retVal;
	}

/*
	if (pf == nil && paramFileNdx == nil) { // paramFileNdx will be unset the first time through
		//
		// move directory stuff to DMM
		//

		// used to be in the setParamFile method
		const char *parmdir = [paramDir getC];
		const char *suffix = "scm"; // suffix of each paramet file
		id <List> parmlist; // a list of parameter files

		if ( pf != nil ) { 
			char *ptr;
			char *str = (char *)[pf getC];
			while ((ptr = strstr(str, "/")) != '\0') 
			str = ptr + 1;

			id <String> outDir = [String create: self setC: str];
			parmlist = [[List createBegin: globalZone] createEnd];
			[parmlist addLast: outDir];
		} else {
			char pattern[512]; // suffix pattern (e.g., *suffix)
			DIR *dirp; // a directory
			struct dirent *direntp; // directory entry data structure
			// open directory

			fprintf(stderr, "%s::initPM: %p -- parmdir = %s\n", 
				[[self getClass] getName], pf, parmdir);

			if((dirp = opendir(parmdir)) == NULL) {
				fprintf(stderr, "Could not open the directory %s : %s\n", parmdir, strerror(errno));
			}
			sprintf(pattern, "*%s",  suffix);
			parmlist = [[List createBegin: self] createEnd];
			while((direntp = readdir(dirp)) != NULL) {
				if(fnmatch(pattern, direntp->d_name, FNM_NOESCAPE) == 0)
					[parmlist addLast: [String create: globalZone setC: direntp->d_name]];
			}
			closedir(dirp);
		}

		[self setParamFileList: parmlist];
		////////////////////////////////////////////
	}
*/

  //
  // vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
  // DMM and Telem are invalid at this point.
  //

//
// Sunwoo insert something here
//

  // cleanup old pname  to replace it with the new
  if (pname != nil) {
    [pname drop];
    pname = nil;
  }
  pname = newParamFileName;

  // Build the parameter manager, using the parameterManager data stored in
  // the paramlist files.
  id <String> params = nil;
  if(paramDir == nil)
    {
      params = [String create: experScratchZone setC: [dMM getInputDirName]];
      [params catC: DIR_SEPARATOR];
      [params catC: "parameters"];
    }
  else
    {
      params = [paramDir copy: experScratchZone];  
    }
  [params catC: DIR_SEPARATOR];    
  [params catC: [pname getC]];

  // clean up the old archiver to avoid memory leak
  if (pmArchiver != nil) {
    [pmArchiver drop];
    pmArchiver = nil;
  }
  pmArchiver = [LispArchiver create: self setPath: [params getC]];

  // clean up the old parameter manager
  if (parameterManager != nil) {
    [parameterManager drop];
    parameterManager = nil;
  }

  if ((parameterManager = 
       [pmArchiver getWithZone: self key: "parameterManager"]) == nil) {
    raiseEvent(InvalidOperation,
               "Can't find the parameter file, %s", [params getC]);
  }

  [parameterManager setParent: self];
  if (params != nil) {
     [params drop];
     params = nil;
  }

  /*
   * now that we have the pname, we can init the telemetry classes
   * telemetry cannot be used until we do this.
   * ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   */
  id<String> debugs = [String create: [self getZone] setC: "debugs/debug-"];
  id<String> monitors = [String create: [self getZone] setC: "monitors/monitor-"];
  [debugs catC: [pname getC]]; [monitors catC: [pname getC]];
  [Telem setDebugFile: debugs];
  [Telem setMonitorFile: monitors];

  [Telem debugOut: 2 printf: "new parameterManager = %p\n", parameterManager];

  // init the parameters
  [parameterManager initializeParameters];
  return retVal;
}

#define NUMCOLORS 22
static const char * colors[NUMCOLORS] =
{
  "blue", "orange", "yellow", "green",
  "red", "purple", "violet", "cyan",
  "grey50", "darkgreen", "goldenrod", "seagreen",
  "navy", "turquoise",
  "khaki", "gold", "brown", "salmon",
  "pink", "magenta", "maroon", "thistle"
};

#define NUMSYMBOLS 8
static const char * symbols[NUMSYMBOLS] =
{
   "circle", "square", "diamond", "plus", 
   "cross", "splus", "scross", "triangle"
};

- (id <Map>) _buildGraphElementsFor_: (const char *) name 
                               using: (id <List>) labels
                             onGraph: (id <Graph>) g
{
  id <Map> newElements = [Map create: self];
  id <String> newName = nil;
  id <ListIndex> outNdx = [labels listBegin: scratchZone];
  id <String> output=nil;
  id <GraphElement> ge=nil;
  id <String> tempStr = [String create: scratchZone setC: "Time"];

  static unsigned colorNdx=0;
  static unsigned symbolNdx=0;

  newName = [String create: scratchZone setC: name];
  while (( [outNdx getLoc] != End)
         && ( (output = [outNdx next]) != nil) ) {

    // skip this iterate if output is "time"
    if ([output compare: tempStr] == 0)
      continue;

    // iterate the newName
    [newName setC: name];
    [newName catC: ":"];
    [newName catC: [output getC]];
    ge = [g createElement];
    [ge setLabel: [newName getC]];
    [ge setColor: colors[colorNdx % NUMCOLORS]];
    colorNdx++;
    [ge setDashes: 1];
    [ge setSymbol: symbols[symbolNdx % NUMSYMBOLS]];
    symbolNdx++;
    [newElements at: [output copy: globalZone] insert: ge];
  }
  [outNdx drop];
  [newName drop];
  [tempStr drop];

  return newElements;
}

/*
 * buildExperDataViews - sets up the experiment graph that plots all the 
 *                       data for all the runs, if the option is on.
 */
- buildExperDataViews
{
  aggLiveGraph = [LogPlotter createBegin: self];
  [aggLiveGraph setSaveSizeFlag: NO];
  SET_WINDOW_GEOMETRY_RECORD_NAME (aggLiveGraph);
  aggLiveGraph = [aggLiveGraph createEnd];
  [aggLiveGraph setTitle: "Live Aggregate Outputs"];
  [aggLiveGraph setAxisLabelsX: "Time" Y: "Outputs"];
  [aggLiveGraph setScaleModeX: YES Y: YES];
  [aggLiveGraph setYAxisLogscale];

  datElements = [self _buildGraphElementsFor_: "Dat" 
                     using: [datModel getOutputNames]
                     onGraph: aggLiveGraph];
  refElements = [self _buildGraphElementsFor_: "Ref" 
                     using: [refModel getOutputNames]
                     onGraph: aggLiveGraph];
  artElements = [self _buildGraphElementsFor_: "Art" 
                      using: [artModel getOutputNames]
                      onGraph: aggLiveGraph];

  [aggLiveGraph pack];

  [aggLiveGraph enableDestroyNotification: self
                notificationMethod: @selector (_aggLiveGraphDeath_)];

  return self;
}

- buildEndDataViewOf: (id <Map>) outData maskedBy: (id <Map>) maskMap
{
  id <Map> elems=nil;
  if (endDataGraph != nil) [self _endDataGraphDeath_];

  endDataGraph = [LogPlotter createBegin: self];

  [endDataGraph setSaveSizeFlag: NO];
  SET_WINDOW_GEOMETRY_RECORD_NAME (endDataGraph);
  endDataGraph = [endDataGraph createEnd];
  [endDataGraph setTitle: "Experiment Results"];
  [endDataGraph setAxisLabelsX: "Time" Y: "Various"];
  [endDataGraph setScaleModeX: YES Y: YES];
  [endDataGraph setYAxisLogscale];

  {
    id <List> outLabels=[List create: scratchZone];
    id <MapIndex> ndx=nil;
    id <String> key=nil;

    // we need to extract the labels from the data maps
    ndx = [[[[outData getFirst] getFirst] getFirst] mapBegin: scratchZone];
    while (( [ndx getLoc] != End) && ([ndx next: &key])
           && (key != nil) ) {
      [outLabels addLast: key];
    }
    [ndx drop];

    [endDataGraph pack];

    [endDataGraph enableDestroyNotification: self
                  notificationMethod: @selector (_endDataGraphDeath_)];
    {
      id <Double> indep=nil;
      id <Map> labeledTraj=nil;
      id <MapIndex> elemNdx=nil;
      id <Map> trajMap=nil;
      id <MapIndex> pointNdx=nil;
      id <MapIndex> trajNdx=nil;
      id <Map> dataPt=nil;
      id <GraphElement> ge=nil;
      id <String> geKey=nil;
      id <String> geLabel=nil;

      labeledTraj = [dMM getRunsFrom: outData maskedBy: maskMap];

      // loop over the trajectories
      trajNdx = [labeledTraj mapBegin: scratchZone];
      while ( ([trajNdx getLoc] != End)
              && ( (trajMap = [trajNdx next: &geLabel]) != nil) ) {

        // use the label as the base for the elements
        elems = [self _buildGraphElementsFor_: [geLabel getC]
                      using: outLabels onGraph: endDataGraph];

        // loop over the points in the trajectory
        pointNdx = [trajMap mapBegin: scratchZone];
        while (([pointNdx getLoc] != End)
               && ( (dataPt = [pointNdx next: &indep]) != nil) ) {

          if (indep != nil) {
            // loop over the elements in the plot
            elemNdx = [elems mapBegin: scratchZone];
            while (([elemNdx getLoc] != End)
                   && ((ge = [elemNdx next: &geKey]) != nil) ) {
              id val = [dataPt at: geKey];
              if ([val isKindOf: [Double class]]) {
                double x = [indep getDouble];
                double y = [val getDouble];
                if (y < FLT_EPSILON) y = FLT_EPSILON;
                [ge addX: x Y: y];
              }
              else if ([val isKindOf: [Integer class]]) {
                double x = [indep getDouble];
                double y = (double)[val getInt];
                if (y < FLT_EPSILON) y = FLT_EPSILON;
                [ge addX: x Y: y];
              }
            }
            [elemNdx drop];
          } // else indep == nil and we don't know what to do
        }
        [pointNdx drop];
        //[elems drop];
        //[geLabel drop];
        //[labeledTraj drop]; // just the collection, not its contents
      }
      [trajNdx drop];
    }
    [outLabels drop];
  }
  return self;
}

/*
 * these are purposefully not in interface because it's
 * just a passthrough
 */
- (void) setRunFileNameBase: (const char *) s
{
  [dMM setRunFileNameBase: s];
}

- setParamDir: (id <String>) dir
{
  paramDir = dir;
	paramFileList = [[List createBegin: [self getZone]] createEnd];

  return self;
}

- setArtGraphFileName: (const char *) s
{
  if(s != (const char *)nil ) {
    id <String> graphFile = [String create: scratchZone setC: [dMM getInputDirName]];
    [graphFile catC: DIR_SEPARATOR];
    [graphFile catC: s];
    [graphFile catC: [[dMM getGraphFileNameExtension] getC]];
    artGraphFileName = [graphFile getC];
  }
  else 
    artGraphFileName = s;

 // we want to set this even if it's null
  [dMM setGraphFileNameBase: s];
  return self;
}

- toggleEndGraphStatsFor: (id <Map>) outMap
{
  if (endDataGraph != nil) 
    [self _endDataGraphDeath_];
  else {
    id <Map> mask = [Map create: scratchZone];
    Vector2d *range = [Vector2d create: scratchZone dim1: 0 dim2: 0xfffffffe];
    id <String> maskKey = [String create: scratchZone setC: "range"];
    [mask at: maskKey insert: range];
    [self buildEndDataViewOf: outMap maskedBy: mask];
    [mask drop];
    [range drop];
    [maskKey drop];
  }
  return self;
}
- toggleEndGraphAllOf: (id <Map>) outMap
{
  if (endDataGraph != nil) 
    [self _endDataGraphDeath_];
  else
    [self buildEndDataViewOf: outMap maskedBy: nil];
  return self;
}

- experRunTimeSetup
{
  return self;
}

- mcSetInit
{
  [parameterManager initializeExper: self];
  experUUnsDist = [UniformUnsignedDist create: self
				       setGenerator: rng
				       setVirtualGenerator: fixable];
 
  // directory for storing output files
  id <String> base = [String create: scratchZone setC: [dMM getOutputDirName]];
	[base catC: DIR_SEPARATOR];
	
  if(paramDir != nil)
    {
      char *ptr;
      char *str = (char *)[paramDir getC];
      while((ptr = strstr(str, "/")) != '\0') str = ptr + 1;
      [base catC: str];
      [base catC: DIR_SEPARATOR];
      [self checkAndCreatePath: base];
    }
  [base catC: [pname getC]];
  [self checkAndCreatePath: base]; // create the directory, if necessary

  // setup the dMM
  if (startNewLogDir == YES) {
    [dMM initLogDir: base];
    startNewLogDir = NO;
    //monteCarloSet = 0;  // reset mcSet for new directory
  }
  [dMM startWith: base]; 
  [parameterManager setRun: runNumber];
  /*
   * now set up the output archivers
   */
  id<String> hdfs = [[dMM getOutFileBase] copy: self];
  [hdfs catC: "/output-"]; [hdfs catC: [pname getC]]; [hdfs catC: ".hdf"];
  id<String> scms = [[dMM getOutFileBase] copy: self];
  [scms catC: "/output-"]; [scms catC: [pname getC]]; [scms catC: ".scm"];

#ifndef USE_LISP
  unlink ([hdfs getC]);
  archiver = [HDF5Archiver create: self setPath: [hdfs getC]];
#else
  unlink ([scms getC]);
  archiver = [LispArchiver create: self setPath: [scms getC]];
#endif
  [hdfs drop];
  [scms drop];

  // cleanup
  [base drop];

  // initial run setup
  [dMM beginRun: runNumber mcSet: monteCarloSet];
  
  // set the index for the primary logging data structure
  [self resetPMNdx];

  return self;
}

- buildActions
{

  [Telem debugOut: 1 print: "Entering ExperAgent::buildActions()\n"];

  // Create the actions necessary for the experiment. This is where
  // the schedule is built (but not run!)

  [super buildActions];

  // experInitSchedule is used for repeated, periodic inits like
  // mcSetInit experInitSchedule runs before initActions
  experInitSchedule = 
    [[[Schedule createBegin: self] setAutoDrop: YES] createEnd];
  [experInitSchedule at: 0 createActionTo: self message: M(mcSetInit)];

  // guiActions is used to ball up the gui updating
  guiActions = [ActionGroup create: self];
  if (guiOn) {
    [guiActions createActionTo: probeDisplayManager message: M(update)];
    [guiActions createActionTo: actionCache          message: M(doTkEvents)];
  }

  // obsActions is used to ball up the stats and logging updating
  obsActions = [ActionGroup create: self];
  [obsActions createActionTo: self message: M(doStats)];
  if (guiOn) [obsActions createActionTo: self message: M(showStats)];
  [obsActions createActionTo: self message: M(logRun)];
  [obsActions createAction: guiActions];

  // stepSchedule is a dynamic procedure for stepping events
  stepSchedule = [[[Schedule createBegin: self] setAutoDrop: YES] createEnd];

  // endActions holds cleanup actions
  endActions = [ActionGroup create: self];
  [endActions createActionTo: self message: M(logExperiment)];
  [endActions createActionTo: self message: M(stopExperiment)];
  [endActions createActionTo: self message: M(cleanup)];
  [endActions createActionTo: self message: M(resetPMNdx)];

  // Now make the experiment schedule. Note the repeat interval is 1
  experSchedule = 
    [[[Schedule createBegin: self] setRepeatInterval: 1] createEnd];
  [experSchedule at: 0 createActionTo: self message: M(experRunTimeSetup)];
  [experSchedule at: 0 createAction: experInitSchedule]; // dynamic
  [experSchedule at: 0 createActionTo: self message: M(buildModel)];
  [experSchedule at: 0 createAction: guiActions];
  [experSchedule at: 0 createAction: stepSchedule]; // dynamic
  [experSchedule at: 0 createAction: guiActions];
  [experSchedule at: 0 createAction: endActions];
  [experSchedule at: 0 createAction: guiActions];

  [Telem debugOut: 1 print: "Exiting ExperAgent::buildActions()\n"];

  return self;
}  

/*
 * activateIn: - activate the schedules so they're ready to run.
 * The swarmContext argument has to do with what we were activated *in*.
 * Typically an ExperimentSwarm is the top-level Swarm, so swarmContext
 * is "nil". The model we run will be independent of our activity.
 * We will activate it in "nil" when we build it later.
 */
- activateIn: swarmContext
{
  // First, activate ourselves (just pass along the context).

  [super activateIn: swarmContext];

  // Now activate our schedule in ourselves. This arranges for the
  // execution of the schedule we built.

//  [experInitSchedule activateIn: self];
  [experSchedule activateIn: self];

  return [self getActivity];
}

- setRNG: (id <SplitRandomGenerator>) r
{
  assert( r!=nil );
  rng = r;
  return self;
}

- setSimilarityMeasure: (char *) sm
{
  similarityMeasure = [String create: self setC: sm];
  return self;
}

- setNominalProfile: (char *) nomProf
{
  nominalProfile = [String create: self setC: nomProf];
  return self;
}
- setNominalProfileColumnLabel: (char *) nomProfCol
{
  nominalProfileColumnLabel = [String create: self setC: nomProfCol];
  return self;
}

- setExperimentalProfile: (char *) ep;
{
  experimentalProfile = [String create: self setC: ep];
  return self;
}

- setMonteCarloRuns: (unsigned) nr
{
  monteCarloRuns = nr;
  return self;
}

- setShowLiveData: (BOOL) show
{
  showLiveData = show;
  return self;
}

- setShowLiveAgg: (BOOL) show
{
  showLiveAgg = show;
  return self;
}

- resetPMNdx
{
  // creates a new PM instance used to index the data
  pmNdx = [self copyIVars: parameterManager];
  return self;
}

// model-specific construction methods

- setInterpDatModel: (BOOL) idm
{
  interpDatModel = idm;
  return self;
}

- setDatModelFileName: (const char *) s
{
  datModelFileName = s;
  [dMM setValDataFileName: s];
  return self;
}

- setArtGraphSpecFileName: (const char *) s
{
  if(s[0] != '\0')
    {
      lobuleSpecFileName = s;  // local copy for error checking
      [dMM setLobuleSpecFileName: s];
    }
  else lobuleSpecFileName = '\0';

  return self;
}

// utility methods

/*
 * _resultGraphDeath_ - An internal method that gets executed if/when
 *                      the resultGraph widget is destroyed.
 */
- _resultGraphDeath_
{

  [resultGraph drop];
  resultGraph = nil;

  // these elements are dropped by graph
  datModelE = nil;
  refModelE = nil;
  artModelE = nil;
  dosageE = nil;

  return self;
}

/*
 * _dosageGraphDeath_ - An internal method that gets executed if/when
 *                      the dosageGraph widget is destroyed.
 */
- _dosageGraphDeath_
{

  [dosageGraph drop];
  dosageGraph = nil;

  // these elements are dropped by graph
  dosageE = nil;

  return self;
}

- _aggLiveGraphDeath_
{
  [aggLiveGraph drop];
  aggLiveGraph = nil;
  [datElements removeAll];
  [refElements removeAll];
  [artElements removeAll];

  return self;
}

- _endDataGraphDeath_
{
  [endDataGraph drop];
  endDataGraph = nil;
  return self;
}

/*
 * cleanup - Run once at the end of each experiment in order to 
 *           clean up the memory used.
 */
- cleanup
{
  [datModel drop];
  [refModel drop];
  [artModel drop]; // SEGMENT FAULT here in sequential mode !!
  
  return self;
}

/*
 * stolen from GUISwarm
 */
- setWindowGeometryRecordName: (const char *)theWindowGeometryRecordName
{
  baseWindowGeometryRecordName = (theWindowGeometryRecordName
				  ? STRDUP (theWindowGeometryRecordName)
				  : NULL);
  return self;
}

- setSaveSizeFlag: (BOOL)theSaveSizeFlag
{
  saveSizeFlag = theSaveSizeFlag;
  return self;
}

- setWindowGeometryRecordNameForComponent: (const char *)componentName
                                   widget: theWidget
{
  return [theWidget
           setWindowGeometryRecordName:
             buildWindowGeometryRecordName (baseWindowGeometryRecordName,
                                            componentName)];
}
- (id <ActionCache>)getActionCache
{
    return actionCache;
}

- (id <ControlPanel>)getControlPanel
{
    return controlPanel;
}
- (void)drop
{
  if (baseWindowGeometryRecordName)
    FREEBLOCK (baseWindowGeometryRecordName);
  if (actionCache != nil) [actionCache drop];
  if (controlPanel != nil) [controlPanel drop];
  [super drop];
}
- go
{
  if (guiOn)
    return [controlPanel startInActivity: [self getActivity]];

  [[self getActivity] run];
  return [[self getActivity] getStatus];
}
- (id) getArtModel
{
  return artModel;
}
- (id <LiverDMM>) getDMM
{
  return dMM;
}
- (id <LispArchiver>) getPMArchiver
{
  return pmArchiver;
}

- (void) enableSoluteTrace: (BOOL) trace 
{
  enableTrace = trace;
}

- (void) setDisplayLevel: (int) level 
{
  dLevel = level;
}

- setSimilarityBandCoefficient: (double) val
{
  if (val<=0.0) val=1.0;
  similarityBandCoefficient = val;
  return self;
}

- (void) showMessage:(const char *)msg
{
	printf("%s\n", msg); fflush(stdout);
}

//
// sequential wrapper of DMM
//
 - (BOOL) checkDir: (id <String>) dir
{
	return [DMM checkDir: dir];
}

- (BOOL) createDir: (id <String>) dir 
{
  return [DMM createDir: dir];
}

- (void) checkAndCreateDir: (id <String>) dir 
{
  [DMM checkAndCreateDir: dir];
}

- (void) checkAndCreatePath: (id <String>) path 
{
	[DMM checkAndCreatePath: path];
}

- (BOOL) removeDir: (id <String>) dir 
{
  return [DMM removeDir: dir];
}

- (void) terminate
{
	exit(-1);
}
@end
