/*
 * IPRL - Experiment Agent
 *
 * Copyright 2003-2007 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <mpi.h>
#import "parallel/Parallelism.h"
#import "parallel/Partitioner.h"

#import "ParallelEA.h"
@implementation ParallelEA

/*
 * buildProbeMap is over-ridden in order to access instances of the
 * superclass instead of this class.
 */
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
                                       inClass: [super class]]];

  [theProbeMap addProbe: [probeLibrary getProbeForMessage: "toggleEndGraphStatsFor:"
                                   inClass: [super class]]];
  [theProbeMap addProbe: [probeLibrary getProbeForMessage: "toggleEndGraphAllOf:"
                                   inClass: [super class]]];


  [probeLibrary setProbeMap: theProbeMap For: [self class]];

}


- buildObjects: (id <String>) pf
{
	[super buildObjects: pf];
	return self;
}

- createEnd
{
  ParallelEA *obj;
  obj = [super createEnd];


  // Fill in the relevant parameters 
  obj->rank = INVALID_INT;
  obj->np = INVALID_INT;
  obj->pLevel = INVALID_INT;
  obj->totalRuns = INVALID_INT;

  //[self buildProbeMap];
  
  return obj;
}

/*
 * stopExperiment - overridden to handle MPI master/slave diffs
 */
- stopExperiment
{
  if( dLevel==2 ) 
    fprintf(stdout, " End Run %d\n", runNumber);  
  runNumber++;
  [dMM endRun];

  if(pLevel == EXPERIMENTAL_LEVEL && dLevel >= 1)
    fprintf(stdout, "<< %s >> : Processor[%d] : MC Run: %d (%d of %d local "
            "Monte-Carlo runs) is done... \n", 
            [pname getC], rank, runNumber, (runNumber-runBase), monteCarloRuns); 

  [Telem debugOut: 2 printf: "[%s(%p) -stopExperiment] -- runNumber = %d, runBase = %d, monteCarloRuns = %d\n", 
         [[self class] getName], self, runNumber, runBase, monteCarloRuns];

  if ((runNumber - runBase) >= monteCarloRuns) {
    similarity = 0.0F; 
 
    id <Map> aMap = nil;
    switch (pLevel) {
    case GROUP_LEVEL:
      aMap = [dMM getArtMap];
      [self computeSimilarity: aMap refMap: [dMM getRefMap] 
            datMap: [dMM getDatMap]];
      break;  // out of GROUP_LEVEL

    case EXPERIMENTAL_LEVEL:
      aMap = [self collectLocalResults: [dMM getArtMap]];
      [dMM setArtMap: aMap]; 

      if(rank == 0) {	  
        [self computeSimilarity: aMap refMap: [dMM getRefMap] 
              datMap: [dMM getDatMap]];
      }
      break;  // out of EXPERIMENTAL_LEVEL

    default:
      raiseEvent(InternalError, "Unrecognized parallelism type: %d\n", pLevel);
    } // end switch (pLevel)

    switch (pLevel) {
    case GROUP_LEVEL:
      if(dLevel >= 1)
        fprintf(stdout, "Processor[%d] : Parameter: %s, MC runs: %d, "
                "Similarity Score: %10g\n", 
                rank, [pname getC], runNumber, similarity);
      break;
    case EXPERIMENTAL_LEVEL:
      if(dLevel >= 1 && rank == 0) {
        fprintf(stdout, "  Parameter: %s, MC runs: %4d, "
                "Similarity Score: %10g\n", 
                [pname getC], runNumber, similarity);
      }
      break;
    default:
      raiseEvent(InternalError, "Unrecognized parallelism type: %d\n", pLevel);
    }

    monteCarloSet++;
    [parameterManager setMonteCarloSet: monteCarloSet];

    if (! [parameterManager stepParameters: self]) {

      switch (pLevel) {
      case GROUP_LEVEL:
        if (dLevel == 2) {
          fprintf(stdout, 
                  "Processor[%d] : \n"
                  "\t**********************************************\n"
                  "\t******* Experiment is Finished! **************\n"
                  "\t***** %4d Monte-Carlo sets completed ********\n"
                  "\t**********************************************\n\n",
                  rank, monteCarloSet);
        }
        break;
      case EXPERIMENTAL_LEVEL:
        if(dLevel == 2 && rank == 0) {
          fprintf(stdout, 
                  "*********************************************\n"
                  "******** Experiment is Finished! ************\n"
                  "*** %4d Monte-Carlo sets completed *********\n"
                  "*********************************************\n\n\n",
                  monteCarloSet);
        }
        break;
      default:
        raiseEvent(InternalError, "Unrecognized parallelism type: %d\n", pLevel);
      }

      // display the end-of-experiment plot
      if (guiOn) {
        [self buildEndDataViewOf: aMap maskedBy: nil];
        [probeDisplayManager update];
        [actionCache doTkEvents];
      } 
      [dMM stop];
      [archiver drop];

      if (guiOn) [controlPanel setStateStopped];
			if(pLevel == EXPERIMENTAL_LEVEL) MPI_Barrier(MPI_COMM_WORLD);
      [[self getActivity] terminate];

    } else { // still more parameter settings to walk through

      [Telem debugOut: 2 printf: 
               "[%s(%p) - stopExperiment] -- "
             "more parameter settings to walk through\n",
             [[self getClass] getName], self];

      runNumber = runBase;

      // do experInitSchedule -- actions needed for new mcSet 
      timeval_t cycle = 0U;
      cycle = [[self getActivity] getCurrentTime];
      [experInitSchedule at: cycle+1
                         createActionTo: self
                         message: M(mcSetInit)];

      [Telem debugOut: 2 printf: "\tstarting new mcSet, runNumber = %d, runBase = %d, monteCarloRuns = %d\n", 
             runNumber, runBase, monteCarloRuns];

      [Telem debugOut: 2 printf: 
               "[%s(%p) - stopExperiment] -- "
             "scheduled new [-mcSetInit]\n",
             [[self getClass] getName], self];

    } // if (! [parameterManager stepParameters: self])

  } else { // continue with the next monteCarloRun in this set
    [dMM beginRun: runNumber mcSet: monteCarloSet];
  }
  [parameterManager setRun: runNumber];

  return self;
}

/*
 * initPM -- overridden to partition param files
 */
- (BOOL) initPM: (id <String>) pf
{
  /*
   * if paramFileNdx exists, then we've already done this and don't
   * need to do it again.
   */

  if (paramFileNdx == nil) {
    /// used to be in the setParamFile method
     id <String> tmpStr = [String create: scratchZone setC: [dMM getInputDirName]];
     [tmpStr catC: DIR_SEPARATOR];
     [tmpStr catC: "parameters"];
     //"inputs/parameters" default input parameter folder
     const char *parmdir = [tmpStr getC];

     id <List> parmlist = nil;  
     Partitioner *p = [[Partitioner createBegin: self] createEnd]; 

     if (pLevel == GROUP_LEVEL) {
        if (pf == nil) {
           //
           // Phase 3.1: A root (or coordinator) node reads all parameter file names having a suffix 
           //   "scm" from the folder paamDir and sends them to all processors.
           //
           int tp; // total number of parameter sets
           if(rank == 0) { // a root node
              // get input parameter files having a suffix "scm" from parmdir 
              parmlist = [p getFileListInfo: parmdir with: "scm"];
              tp = [parmlist getCount]; // only root node knows tp
              MPI_Bcast(&tp, 1, MPI_INT , 0, MPI_COMM_WORLD); // root node broadcasts tp 
           } else
              MPI_Bcast(&tp, 1, MPI_INT , 0, MPI_COMM_WORLD); // all other nodes receive tp 

           // now, every node knows the total number of parameter sets !!

           char parms[tp][256];
           if (rank == 0) {
              int idx;
              id <Index> indexer = [parmlist begin: globalZone];
              for(idx = 0; idx < tp; idx++)  sprintf(parms[idx], "%s", [[indexer next] getC]);
              [indexer drop];
              MPI_Bcast(&parms,tp*256, MPI_CHAR , 0, MPI_COMM_WORLD); // root node broadcasts all parameter info  
           } else
              MPI_Bcast(&parms,tp*256, MPI_CHAR , 0, MPI_COMM_WORLD); // all other nodes receive all parameter info 

           // now, every node knows all parameter set information that is read and broadcasted by root node !!
	  
           //
           // Phase 3.3: perform parallel partitioning
           // root (or coordinator) node reads parameter file names having a suffix 
           //   "scm" from a direct
           //
           if (parmlist != nil) {  
              [parmlist removeAll];
              [parmlist drop];
           }
           parmlist = [p partition: parms length: tp for: np myid: rank];   
        } else  { // if pf != nil
           char *ptr;
           char *str = (char *)[pf getC];
           while((ptr = strstr(str, "/")) != '\0')  str = ptr + 1;
           id<String> outDir = [String create: globalZone setC: str];
           parmlist = [[List createBegin: globalZone] createEnd];
           [parmlist addLast: outDir];
        }
     } else if(pLevel == EXPERIMENTAL_LEVEL) {
        if(pf == nil)
           parmlist = [p getFileListInfo: parmdir with: "scm"];
        else { // if pf != nil 
           char *ptr;
           char *str = (char *)[pf getC];
           while((ptr = strstr(str, "/")) != '\0')  str = ptr + 1;
           id<String> outDir = [String create: globalZone setC: str];
           parmlist = [[List createBegin: globalZone] createEnd];
           [parmlist addLast: outDir];
        }

    }

     [tmpStr drop];  // used to define "parmdir"

     [self setParamFileList: parmlist];
     /////////////////////////////////////////
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
   * vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
   * DMM and Telem are invalid at this point.
   */

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
  [params drop];

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

  [Telem debugOut: 2 printf: "[%s(%p) -initPM] -- new parameterManager = %p\n", 
         [[self class] getName], self, parameterManager];

  // init the parameters
  [parameterManager initializeParameters];

  [Telem debugOut: 2 printf: "[%s(%p) -initPM] -- End\n",
         [[self class] getName], self];

  return retVal;
}


/*
 * mcSetInit -- overridden because the directory structure in the PISL
 * is different from that of the ISL.
 */
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


  // preparation for per processor output directories
  id <String> cbase = nil;
  switch (pLevel) {
  case EXPERIMENTAL_LEVEL:
    //diretory holding analystic result files (i.e., *.csv)
    cbase = [base copy: scratchZone];
    [cbase catC: DIR_SEPARATOR];
    [cbase catC: "analysis"];

    // adjust the base for EXPERIMENTAL_LEVEL parallelism
    [base catC: DIR_SEPARATOR]; 
    [base catC: "proc"];
    [base catC: [Integer intStringValue: rank]];

    break;
  case GROUP_LEVEL:
    // do nothing
    break;
  default:
    raiseEvent(InternalError, "Unrecognized parallelism type: %d\n", pLevel);
  } // end switch (pLevel)

  // setup the dMM
  if (startNewLogDir == YES) {
    [dMM initLogDir: base csvbase: cbase];
    startNewLogDir = NO;
    //monteCarloSet = 0;  // reset mcSet for new directory
  }
  if (cbase != nil) [cbase drop];

  [dMM startWith: base]; 


  //
  // computer parallel parameter space partitioning
  // based on simple parallel-offset-exploration approach
  //
  totalRuns = monteCarloRuns;
      
  if ( pLevel == EXPERIMENTAL_LEVEL ) {
		if(np > totalRuns) {
	  	printf("Error:  number of processors(%d) >= total Monte Carlo runs(%d)\n", 
		 	np, totalRuns);
	  	MPI_Finalize();
	  	exit(-1);
		}
	}

  int quotient = monteCarloRuns/np;
  int remainder =  monteCarloRuns%np;

	switch (pLevel) {
		case EXPERIMENTAL_LEVEL:
    	// each processor changes the values of monteCarloRuns and
    	// runNumbers for parallel execution
    	monteCarloRuns = (remainder == 0) 
      	? quotient 
      	: ((rank < remainder) ? quotient + 1 : quotient);
    	runNumber = runBase = (remainder == 0) 
      	? rank * quotient 
      	: rank * quotient + ((rank < remainder) ? rank : remainder); 
    	break;
  case GROUP_LEVEL:
    // do nothing
    break;

  default:
    raiseEvent(InternalError, "Unrecognized parallelism type: %d\n", pLevel);
  }

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


/*
 * parallel-specific methods
 */
- (void) setRank: (int) rk
{
  rank = rk;
}

- (void) setNumberOfProcessors: (int) size
{
  np = size;
}

- (void) setParallelLevel: (int) level
{
  pLevel = level;
}

- (id <Map>) collectLocalResults: (id <Map>) inputMap
{
  //
  // resolve the total number of bytes to send to the root processor
  //

  unsigned columns, rows, size;
  [DMM getArrayDimensions: inputMap  width: &columns height: &rows  
       paramSet: parameterManager];
	  
  size = monteCarloRuns * rows * columns;
  char *localKeys = malloc(size * 128 * sizeof(char)); // 128 character for each key
  double *localValues = malloc(size * sizeof(double));

  [DMM convertMapToArray: inputMap keys: localKeys values: localValues 
       paramManager: parameterManager]; 
  
  //
  // a root node collects all local information on keys and values 
  //
  int totalLength = -1; // only meaningful to the root processor
  char *firstKeys = (char *) nil;
  double *firstValues = (double *) nil;

  if(rank == 0)
    {
      totalLength = (totalRuns/np)*np * rows * columns;
      firstKeys = malloc(totalLength * 128 * sizeof(char));
      firstValues = malloc(totalLength * sizeof(double));
    }

  long txsize = (totalRuns/np) * rows * columns;
  MPI_Gather(localKeys, txsize * 128, MPI_CHAR, 
	     firstKeys, txsize * 128, MPI_CHAR, 0, MPI_COMM_WORLD);
  
  MPI_Gather(localValues, txsize, MPI_DOUBLE, 
	     firstValues, txsize, MPI_DOUBLE, 0, MPI_COMM_WORLD);

  //
  // phase 2:
  //
  char *secondKeys = (char *)nil;	   
  double *secondValues = (double *)nil;
  int residue = totalRuns%np;
  if(residue > 0)
    {
      char *mKeys = (char *)nil;
      double *mValues = (double *)nil;
      size = rows * columns;
      if(rank < residue)
	{
	  if(rank == 0)
	    {
	      totalLength = np * size;
	      secondKeys = malloc(totalLength * 128 * sizeof(char));
	      secondValues = malloc(totalLength * sizeof(double));
	    }
	  int offset = (totalRuns/np)*size;
	  mKeys = localKeys + offset * 128;
	  mValues = localValues + offset;
	}
      else
	{
	  mKeys = malloc(size*128);
	  mValues = malloc(size*sizeof(double));
	}
      
      MPI_Gather(mKeys, size * 128, MPI_CHAR, 
		 secondKeys, size * 128, MPI_CHAR, 0, MPI_COMM_WORLD);
      
      MPI_Gather(mValues, size, MPI_DOUBLE, 
		 secondValues, size, MPI_DOUBLE, 0, MPI_COMM_WORLD);
    }

  //
  // build an experiment map with the collected array information
  //

  id <Map> expMap = [Map createBegin: self];
  [expMap setCompareFunction: pm_compare];
  expMap = [expMap createEnd];

  if(rank == 0)
    {      
      id <Map> aMap = [Map create: globalZone];
      int  itr, row, col, fcnt, scnt, runs;
      fcnt = scnt = runs = 0;
      while(runs < totalRuns)
	{
	  for(itr = 0; itr < totalRuns/np; itr++, runs++)	
	    {  
	      id <Map> runMap = [[[Map createBegin: globalZone] setCompareFunction: (compare_t)double_compare] createEnd];
	      for(row = 0; row < rows; row++)
		{
		  id <Map> point = [Map create: globalZone];
		  for(col = 0; col < columns; col++)
		    {
		      [point at: [String create: globalZone setC: (firstKeys + fcnt*128)]
			     insert: [Double create: globalZone setDouble: firstValues[fcnt]]];
		      fcnt++;
		    }
		  [runMap at: [point at: [String create: globalZone setC: "Time"]] insert: point];
		}
	      [aMap at: [Integer create: globalZone setInt: runs] insert: runMap];
	    }
	 		    
	  if(residue > 0) 
	    {
	      runs++; residue--;
	      id <Map> runMap = [[[Map createBegin: globalZone] setCompareFunction: (compare_t)double_compare] createEnd];	
	      for(row = 0; row < rows; row++)
		{
		  id <Map> point = [Map create: globalZone];
		  for(col = 0; col < columns; col++)
		    {
		      [point at: [String create: globalZone setC: (secondKeys + scnt*128)]
			     insert: [Double create: globalZone setDouble: secondValues[scnt]]]; 
		      scnt++;
		    }
		  [runMap at: [point at: [String create: globalZone setC: "Time"]] insert: point]; 
		}
	      [aMap at: [Integer create: globalZone setInt: runs]  insert: runMap]; 
	    }  
	}

      [expMap at: parameterManager insert: aMap];
    }

  return expMap;
}


- (void) showMessage:(const char *)msg
{
	printf("Processor[%d] ==> %s\n", rank, msg); fflush(stdout);
}

//
// parallel wrapper of DMM
//
 - (BOOL) checkDir: (id <String>) dir
{
  BOOL ret = NO; 
  if(rank == 0) ret = [DMM checkDir: dir];
  MPI_Barrier(MPI_COMM_WORLD);
  return ret;
}

- (BOOL) createDir: (id <String>) dir 
{
  BOOL ret = NO; 
  if(rank == 0) ret = [DMM createDir: dir];
  MPI_Barrier(MPI_COMM_WORLD);
  return ret;
}

- (void) checkAndCreateDir: (id <String>) dir 
{
  if(rank == 0) [DMM checkAndCreateDir: dir];
  MPI_Barrier(MPI_COMM_WORLD);
}

 - (void) checkAndCreatePath: (id <String>) path
{ 
	if(rank == 0) [DMM checkAndCreatePath: path];
  MPI_Barrier(MPI_COMM_WORLD);
} 

- (BOOL) removeDir: (id <String>) dir 
{
  BOOL ret = NO;
  if(rank == 0) ret = [DMM removeDir: dir];
  MPI_Barrier(MPI_COMM_WORLD);
  return ret;
}

- (void) terminate 
{
	MPI_Finalize();
	exit(-1);
}

/*
 * end parallel specific methods
 */

@end
