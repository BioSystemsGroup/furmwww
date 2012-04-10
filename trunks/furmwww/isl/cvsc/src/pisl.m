/** 
 * IPRL - main routine
 *
 * Copyright 2003-2007 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

//////////////////////////////////////////////////////////////////////////////////////////////////////
//
// IN PARALLEL MODE
//
//  SYNTAX:
//    mpirun -np <size> ./liver [options]
//      <size> : the total number of processors ; mandatory 
//      [options] : commandline options ; optional
//          -b or --batch : batch mode
//          -P <LEVEL> or --parallel-level=<LEVEL> : set PISL parallelism level
//             <LEVEL> : 0 for Group-level parallelism
//                       1 for Experimental-level parallelism 
//                       2 for Model-level parallelism (Not implemented yet)
//             * default : Experimental-level
//          -d=<LEVEL> or --display-level=<LEVEL> : display simulation progress message
//             <LEVEL> : TBD
//          -F <NAME> or --param-file=<NAME>  : set single parameter file name
//          -D <NAME> or --param-dir=<NAME>  : set parameter directory name
//          -T <NAME> or --sweep-table=<NAME> : set parameter sweeping table file name
//          -E <BOOL> or --enable-trace=<BOOL> : enable or disable solute trace
//
//  EXAMPLES:
//    0. mpirun -np 2 ./liver -b  (equivalent to mpirun -np 2 ./liver -b -D inputs/parameters)
//    1. mpirun -np 2 ./liver -b --parallel-level=0
//    2. mpirun -np 2 ./liver -b -P 1
//    3. mpirun -np 2 ./liver -b -P 1 -d 0
//    4. mpirun -np 2 ./liver -b -P 2 -F inputs/parameters/liver3.scm
//    5. mpirun -np 2 ./liver -b -P 2 -D inputs/parameters/parmdir
//    6. mpirun -np 2 ./liver -b -P 2 -T inputs/parameters/paramsweep.tbl
//    7. mpirun -np 2 ./liver -b -P 2 --sweep-table=inputs/parameters/paramsweep.tbl
//    8. mpirun -np 2 ./liver -b -P 2 --sweep-table=inputs/parameters/paramsweep.tbl --enable=trace=yes
//
//////////////////////////////////////////////////////////////////////////////////////////////////////

#import "ParallelCLOH.h"
#import "ParallelEA.h"

#import "BatchAnalyzer.h" // for aposteriori simulation results batch processing
#import <simtools.h>     // initSwarm () 
#import <simtoolsgui.h>  // SET_WINDOW_GEOMETRY_RECORD_NAME
#import <analysis.h>
#import "optimization/ParameterSweeper.h" // for ParameterSweeper

#import <sys/times.h>
#import <limits.h>

#import "parallel/Handler.h" // for MAX_OP, etc.
#import "parallel/Partitioner.h" // for Parallel Paritioner
#import "parallel/OperationBuilder.h" // for OperationBuilder
#import <unistd.h> // for gethostname()

int
main (int argc, char **argv)
{
  int rank; // processor id
  int size; // totoal number of processors
  int pLevel; // Parallelism level; see parallel/Parallelism.h
  int dLevel; // Simulation progress message display level
  const char *parmdir = "inputs/parameters"; // default input parameter folder
  id <String> sweepTblName = nil; // parameter sweeping table name
  id <String> parmFile = nil; // single parameter file name
  id <String> parmDir = nil; //  parameter directory name
  ParameterSweeper* sweeper = nil; // parameter sweeper
//  BatchAnalyzer* batchAnalyzer = nil; // batch job processor and anaylzer

  //
  // Phase 1: MPI environment initialization
  //
  MPI_Init(&argc, &argv);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank); // resolve the processor id of this process
  MPI_Comm_size(MPI_COMM_WORLD, &size); // resolve the number of processors 
  
  //
  // Phase 2: Swarm environment initialization
  //
  initSwarmArguments(argc, (const char **)argv, [ParallelCLOH class]); 

  //
  // Phase 2.1: Commandline argument manipulation  
  //
  //
  // a. check  parellelism level option : -P and --parallel-level
  if(![ParallelCLOH exist: "-P" In: arguments] && 
     ![ParallelCLOH exist: "--parallel-level" In: arguments]) 
    pLevel = EXPERIMENTAL_LEVEL; // default level
  else
    {
      pLevel = [((ParallelCLOH *)arguments) getParallelLevelArg];
      if(pLevel == NON_SUPPORTED_PARALLELISM) 
	{
	  printf("WARNING: The requested parallelism is not supported yet..\n");
	  printf("         PISL will be run in a default parallel level; Experimental Level\n");
	  pLevel = EXPERIMENTAL_LEVEL; // default level
	}
    }
  printf("Processor[%d] :: Start simulation in PARALLEL MODE (%s) ... \n", 
	 rank, (pLevel == GROUP_LEVEL ? "GROUP_LEVEL" : "EXPERIMENTAL_LEVEL")); 

  // b. check parameter file option: -F and --param-file
  if([ParallelCLOH exist: "-F" In: arguments] ||
      [ParallelCLOH exist: "--param-file" In: arguments]) 
    {
      parmFile = [String create: globalZone setC: 
			   [((ParallelCLOH *)arguments) getParameterFileNameArg]];
    }

 // c. check parameter file option: -D and --param-dir
  if([ParallelCLOH exist: "-D" In: arguments] ||
     [ParallelCLOH exist: "--param-dir" In: arguments])
  {
    parmDir = [String create: globalZone setC:
                             [((ParallelCLOH *)arguments) getParameterDirectoryNameArg]];
   parmdir = [parmDir getC];
  }

  // d. check parameter file option: -T and --sweep-table
  if([ParallelCLOH exist: "-T" In: arguments] || 
     [ParallelCLOH exist: "--sweep-table" In: arguments]) 
    sweepTblName = [String create: globalZone setC: 
			     [((ParallelCLOH *)arguments) getParameterSweepingTableFileNameArg]];

  // e. check verbose level option : -d and --display-level
  if(![ParallelCLOH exist: "-d" In: arguments] && 
     ![ParallelCLOH exist: "--display-level" In: arguments]) 
    dLevel = 1; // default level
  else
    dLevel = [((ParallelCLOH *)arguments) getDisplayLevelArg];

 	// f. check solute trace option : -E <BOOL> or --enable-trace=<BOOL>
  BOOL enableTrace = NO;
  if([CommandLineOptionHandler exist: "-E" In: arguments] ||
     [CommandLineOptionHandler exist: "--enable-trace" In: arguments]) {
    id<String> enable = [String create: globalZone setC:
           [((CommandLineOptionHandler *)arguments) getParameterEnableTraceArg]];
    enableTrace = (strstr([enable getC],"yes") != NULL) || (strstr([enable getC],"YES") != NULL) ? YES : NO;
  }

  // -F, -D, and -T options cannot be selected at the same time
  if(parmFile != nil && parmDir != nil && sweepTblName != nil)
    {
      if(rank == 0)
	{
	  printf("Error: -F, -D, and -T options cannot be selected at the same time...\n");
	  printf("       just select only one of them...\n");
	}
      MPI_Finalize();
      exit(-1);
    }

  // More than one paremter files are requred in GROUP LEVEL PARALLELISM
  if((parmFile != nil) && (pLevel == GROUP_LEVEL) && (size != 1))
    {
      if(rank == 0)
	{
	  printf("Error: A single parameter file cannot be parallelized in GROUP LEVEL PARALLELISM...\n");
	  printf("       set np to 1 (i.e., -np 1) or change to EXPERIMENTAL LEVEL PARALLELISM...\n");
	}
      MPI_Finalize();
      exit(-1);
    }

  // if the option -T is selcted, 
  //   create necessary folders for parameter sweeping space construction
  //   paremter sweeping folder : 
  //       <SweepingTableName>-<ParallelismLevel>-<numberOfProcessors>
  //   e.g. input/parameters/paramTable.tbl-GLP-4, input/parameters/paramTable.tbl-ELP-8, etc.
  id<String> inDir = nil; 
  if(sweepTblName != nil)
    {
      inDir = [sweepTblName copy: globalZone];
      if(pLevel == 0) [inDir catC: "-GLP-"];
      else if(pLevel == 1) [inDir catC: "-ELP-"];
      else 
	{
	  if(rank == 0) printf("Non-supported parallelism level...\n");
	  MPI_Finalize();
	  exit(-1);
	}
      [inDir catC: [Integer intStringValue: size]];
      parmdir = [inDir getC]; // update the default value !
    }

  // create a parameter sweeper if the option -T is selected
  if(rank == 0) 
    {
      if(sweepTblName != nil)
	{
	  sweeper = [[ParameterSweeper createBegin: globalZone] createEnd];
	  // generate parameter files to the fold inDir
	  [sweeper buildParameterSweepingSpace: sweepTblName to: inDir];
	}
    }

  //
  // Phase 2.3: Create Batch Jobs Analyzer
  //
  if(pLevel == GROUP_LEVEL || (pLevel == EXPERIMENTAL_LEVEL && rank == 0))
    {
      //batchAnalyzer = [[BatchAnalyzer createBegin: globalZone] createEnd];
      if(sweepTblName != nil) 
	{
	  char *ptr;
	  char *str = (char *)[sweepTblName getC];
	  while((ptr = strstr(str, "/")) != '\0')  str = ptr + 1;
	  id<String> outDir = [String create: globalZone setC: str];
	  if(pLevel == GROUP_LEVEL) [outDir catC: "-GLP-"];
	  else if(pLevel == EXPERIMENTAL_LEVEL) [outDir catC: "-ELP-"];
	  else 
	    {
	      printf("Non-supported parallelism level...\n");
	      MPI_Finalize();
	      exit(-1);
	    }
	  [outDir catC: [Integer intStringValue: size]];
	  //[batchAnalyzer createFileForProcessor: rank baseDir:  [outDir getC]];
	}
      //else
        //[batchAnalyzer createFileForProcessor: rank];
    }




//   //
//   // Phase 3: Parameter file loading (and parallel partitioning, if necessary)
//   //
//   id <List> parmlist = nil;  
//   Partitioner *p = [[Partitioner createBegin: globalZone] createEnd]; 

//   if(pLevel == GROUP_LEVEL)
//     {
//       if(parmFile == nil)
// 	{
// 	  //
// 	  // Phase 3.1: A root (or coordinator) node reads all parameter file names having a suffix 
// 	  //   "scm" from the folder paamDir and sends them to all processors.
// 	  //
// 	  int tp; // total number of parameter sets
// 	  if(rank == 0) // a root node
// 	    {
// 	      // get input parameter files having a suffix "scm" from parmdir 
// 	      parmlist = [p getFileListInfo: parmdir with: "scm"];
// 	      tp = [parmlist getCount]; // only root node knows tp
// 	      MPI_Bcast(&tp, 1, MPI_INT , 0, MPI_COMM_WORLD); // root node broadcasts tp 
// 	    }
// 	  else
// 	    MPI_Bcast(&tp, 1, MPI_INT , 0, MPI_COMM_WORLD); // all other nodes receive tp 

// 	  // now, every node knows the total number of parameter sets !!

// 	  char parms[tp][256];
// 	  if(rank == 0)
// 	    {
// 	      int idx;
// 	      id <Index> indexer = [parmlist begin: globalZone];
// 	      for(idx = 0; idx < tp; idx++)  sprintf(parms[idx], "%s", [[indexer next] getC]);
// 	      [indexer drop];
// 	      MPI_Bcast(&parms,tp*256, MPI_CHAR , 0, MPI_COMM_WORLD); // root node broadcasts all parameter info  
// 	    }
// 	  else
// 	    MPI_Bcast(&parms,tp*256, MPI_CHAR , 0, MPI_COMM_WORLD); // all other nodes receive all parameter info 

// 	  // now, every node knows all parameter set information that is read and broadcasted by root node !!
	  
// 	  //
// 	  // Phase 3.3: perform parallel partitioning
// 	  // root (or coordinator) node reads parameter file names having a suffix 
// 	  //   "scm" from a direct
// 	  //
// 	  parmlist = [p partition: parms length: tp for: size myid: rank];   
// 	}
//       else  
// 	{ // if parmFile != nil
// 	  char *ptr;
// 	  char *str = (char *)[parmFile getC];
// 	  while((ptr = strstr(str, "/")) != '\0')  str = ptr + 1;
// 	  id<String> outDir = [String create: globalZone setC: str];
// 	  parmlist = [[List createBegin: globalZone] createEnd];
// 	  [parmlist addLast: outDir];
// 	}
//     }
//   else if(pLevel == EXPERIMENTAL_LEVEL)
//     {
//       if(parmFile == nil)
// 	parmlist = [p getFileListInfo: parmdir with: "scm"];
//       else
// 	{ // if parmFile != nil 
// 	  char *ptr;
// 	  char *str = (char *)[parmFile getC];
// 	  while((ptr = strstr(str, "/")) != '\0')  str = ptr + 1;
// 	  id<String> outDir = [String create: globalZone setC: str];
// 	  parmlist = [[List createBegin: globalZone] createEnd];
// 	  [parmlist addLast: outDir];
// 	}
//     }

//    //
//    // Phase 4: Parallel execution and result analysis of IPRL simulation
//    //
//    int plength = [parmlist getCount]; // number of parameter sets 



//    double *simrst = malloc(sizeof(double)*plength); // similarity result holder
//    double *exetime = malloc(sizeof(double)*plength); // execution time holder
//    char nmrst[plength][256];  // name related to similarity results
//    id <Index> indexer = [parmlist begin: globalZone];
//    ParallelEA *experAgent = nil;
//    double expStart, expEnd;
//    int idx;

   ParallelEA *experAgent = nil;
   experAgent = [ParallelEA createBegin: globalZone];
   [experAgent setGUIMode: swarmGUIMode];
   if (swarmGUIMode) SET_WINDOW_GEOMETRY_RECORD_NAME (experAgent);
   experAgent = [experAgent createEnd];
   if(sweepTblName != nil) [experAgent setParamDir: [String create: globalZone setC: parmdir]];
   [experAgent setParallelLevel: pLevel];
   [experAgent setRank: rank];
   [experAgent setNumberOfProcessors: size];
   [experAgent enableSoluteTrace: enableTrace];
   [experAgent setDisplayLevel: dLevel];
   [experAgent buildObjects: parmFile]; // needs pLevel, rank, size
   [experAgent buildActions];
   [experAgent activateIn: nil];
   [experAgent go];

//    for(idx = 0; idx < plength; idx++)
//      {
//        id <String> parmset = [indexer next];
//        sprintf(nmrst[idx], "%s", [parmset getC]);  
//        if(pLevel == GROUP_LEVEL)
// 	 printf("Processor[%d] :: Run a PISL Simulation with %s...\n", rank, [parmset getC]);
//        else if(pLevel == EXPERIMENTAL_LEVEL && rank == 0)
// 	 printf("Run a PISL Simulation with %s...\n", [parmset getC]);

//        expStart = MPI_Wtime();
//        // Make the experiment swarm
//        ParallelEA *experAgent =  [ParallelEA createBegin: globalZone for: [parmset getC]];
//        if(sweepTblName != nil) [experAgent setParamDir: [String create: globalZone setC: parmdir]];
//        [experAgent setParallelLevel: pLevel];
//        [experAgent setRank: rank];
//        [experAgent setNumberOfProcessors: size];
//        [experAgent setDisplayLevel: dLevel];
//        [experAgent setGUIMode: swarmGUIMode];
//        if (swarmGUIMode) SET_WINDOW_GEOMETRY_RECORD_NAME (experAgent);
//        experAgent = [experAgent createEnd];
       
//        [experAgent buildObjects];
//        [experAgent buildActions];
//        [experAgent activateIn: nil];		// Top-level swarm is activated in nil
//        [experAgent go];      
//        expEnd = MPI_Wtime();
//        exetime[idx] = expEnd - expStart;

//        simrst[idx] = [experAgent getSimilarity];
       
//        if((pLevel == EXPERIMENTAL_LEVEL && rank == 0) && (parmFile == nil))
// 	 {
// 	   [batchAnalyzer recordSimilarity: simrst[idx] withName: nmrst[idx]
// 			  withMessage: "EXPERIMENTAL_LEVEL PARALLELISM"];
// 	   [batchAnalyzer recordExecutionTime: exetime[idx] withName: nmrst[idx] 
// 			  withMessage: "EXPERIMENTAL_LEVEL PARALLELIS"];
// 	 }
//        else if ((pLevel == GROUP_LEVEL) && (parmFile == nil))
// 	 {
// 	   [batchAnalyzer recordSimilarity: simrst[idx]  withName: nmrst[idx] 
// 			  withMessage: "GROUP_LEVEL PARALLELISM"];
// 	   [batchAnalyzer recordExecutionTime: exetime[idx]  withName: nmrst[idx] 
// 			  withMessage: "GROUP_LEVEL PARALLELISM"]; 
// 	 }
//      }
   [experAgent drop];
//   [indexer drop];

   if(pLevel == GROUP_LEVEL)
     {
//        struct payload localMax, simMax, timeMax;
//        localMax.similarity = [batchAnalyzer findMaxSimilarity: simrst length: plength in: &idx];
//        localMax.exetime = [batchAnalyzer findMaxExecutionTime: exetime length: plength in: &idx];
//        sprintf(localMax.name, "%s", nmrst[idx]);
//        [batchAnalyzer recordSimilarity: localMax.similarity  withName: nmrst[idx] withMessage: "LOCAL MAXIMUM"];
//        [batchAnalyzer recordExecutionTime: localMax.exetime  withName: nmrst[idx] withMessage: "LOCAL EXECUTION TIME"];

//        if(dLevel >= 0)
// 	 {
// 	   printf("Processor[%d] :: ======== << SIMULATION SUMMARY (GROUP_LEVEL PARALLELISM) >> ========\n", rank);
// 	   for(idx = 0; idx < plength; idx++)
// 	       printf("Processor[%d] :: Experiment[%d] =>  Parameter Set: %s, Similarity: %g, Execution Time: %f\n", 
// 		      rank, idx, nmrst[idx], simrst[idx], exetime[idx]);
// 	   printf("Processor[%d] :: --------------------------------------------------------------------\n", rank);
// 	   printf("Processor[%d] :: \t\t\t Local Maximum: %g, Local Execution Time: %f \n", 
// 		  rank, localMax.similarity, localMax.exetime);
// 	   printf("Processor[%d] :: ====================================================================\n", rank);
// 	 }
//        MPI_Op maxop = [OperationBuilder buildOperation: MAX_SIMILARITY];
//        MPI_Reduce(&localMax, &simMax, 1, [p getPayloadType: localMax], maxop, 0, MPI_COMM_WORLD);
//        maxop = [OperationBuilder buildOperation: MAX_EXEC_TIME];
//        MPI_Reduce(&localMax, &timeMax, 1, [p getPayloadType: localMax], maxop, 0, MPI_COMM_WORLD);
     
       if(rank == 0)
	 {
// 	   //	   [batchAnalyzer recordMessage: "=================================================================\n"];
// 	   [batchAnalyzer recordSimilarity: simMax.similarity withName: simMax.name
// 			  withMessage: "(GLOBAL) Maximum among experiments"];
// 	   [batchAnalyzer recordExecutionTime: timeMax.exetime withName: timeMax.name
// 	   		  withMessage: "(GLOBAL) Total Execution Time"];

	   if(dLevel >= 0)
	     { 
	       printf("=============== << BATCH JOBS ANALYSIS (GROUP_LEVEL PARALLELISM) >> ===============\n");
// 	       printf("\t Global Max Similarity: %g@%s\n", simMax.similarity, simMax.name);
// 	       printf("\t Total Execution Time: %f\n", timeMax.exetime);
	       printf("===================================================================================\n");
	     }
	 }
     }
   else if(pLevel == EXPERIMENTAL_LEVEL && rank == 0)
     {
//        [batchAnalyzer findMaxSimilarity: simrst length: plength in: &idx];
//        [batchAnalyzer findMaxExecutionTime: exetime length: plength in: &idx];
//        //       [batchAnalyzer recordMessage: "=================================================================\n"];
//        [batchAnalyzer recordSimilarity: simrst[idx] withName: nmrst[idx]
// 			  withMessage: "Maximum among experiments"];
//        [batchAnalyzer recordExecutionTime: exetime[idx] withName: nmrst[idx]
// 			  withMessage: "TOTAL Execution Time"];

       if(dLevel >= 0)
	 {
//	   int i;
	   printf("=========== << SIMULATION SUMMARY (EXPERIMENTAL_LEVEL PARALLELISM) >> ===========\n");
// 	   for(i = 0; i < plength; i++)
// 	     printf(" Experiment[%d] :: Parameter Set: %s,  Similarity: %g, Execution Time: %f\n", 
// 		    i, nmrst[i], simrst[i], exetime[i]); 
// 	   printf("========= << BATCH JOBS ANALYSIS (EXPERIMENTAL_LEVEL PARALLELISM) >> ============\n");
// 	   printf("\t MAX Similarity : %g@%s\n", simrst[idx], nmrst[idx]);
// 	   printf("\t Total Execution Time: %f\n", exetime[idx]);
	   printf("=================================================================================\n");
	 }
     }

//    free(simrst);
//   [parmlist drop];
//   [p drop];
//    if(batchAnalyzer != nil) [batchAnalyzer drop];

   //
   // Phase 5: MPI termination
   //
   MPI_Finalize(); // shut down MPI environment

  return 0;
}
