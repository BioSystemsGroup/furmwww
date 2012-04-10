/** 
 * IPRL - main routine
 *
 * Copyright 2003-2007 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
//////////////////////////////////////////////////////////////////////////////////////////////////////
//
//
// IN SEQUENTIAL MODE
//  SYNTAX:
//    ./liver [options]
//      [options] : commandline options ; optional
//          -b or --batch : batch mode
//          -d=<LEVEL> or --display-level=<LEVEL> : display simulation progress message
//             <LEVEL> : TBD
//          -F <NAME> or --param-file=<NAME>  : set single parameter file name
//          -D <NAME> or --param-dir=<NAME>  : set parameter directory name
//          -T <NAME> or --sweep-table=<NAME> : set parameter sweeping table file name
//          -E <BOOL> or --enable-trace=<BOOL> : enable or disable solute trace
//
//  EXAMPLES:
//    0. ./liver -b (equivalent to ./liver -b -D inputs/parameters)
//    1. ./liver -b -d 0
//    2. ./liver -b -F inputs/parameters/liver3.scm
//    3. ./liver -b -D inputs/parameters/parmdir
//    4. ./liver -b -T inputs/parameters/paramsweep.tbl
//    5. ./liver -b  --sweep-table=inputs/parameters/paramsweep.tbl
//    6. ./liver -b  --sweep-table=inputs/parameters/paramsweep.tbl --enable-trace=yes
//
//////////////////////////////////////////////////////////////////////////////////////////////////////

#import "CommandLineOptionHandler.h"
#import "optimization/ParameterSweeper.h"	// for ParameterSweeper
#import "ExperAgent.h"

//#import "BatchAnalyzer.h" // for aposteriori simulation results batch processing
#import <simtools.h>     // initSwarm () 
#import <simtoolsgui.h>  // SET_WINDOW_GEOMETRY_RECORD_NAME
#import <analysis.h>

#import <sys/times.h>
#import <limits.h>

#import <stdlib.h> // for exit()
//#import <dirent.h> // for DIR and dirent
#import <errno.h>  // for errno
//#import <fnmatch.h> // for fnmatch()
#import <string.h> // for strerror()
#import <sys/stat.h> // for flags of mkdir() 

int
main (int argc, char **argv)
{
  const char *parmdir = "inputs/parameters"; // default input parameter folder
  int dLevel; // Simulation progress message display level
  id <String> sweepTblName = nil; // parameter sweeping table name
  id <String> parmFile = nil; // single parameter file
  id <String> parmDir = nil; // parameter directory file
  ParameterSweeper* sweeper = nil; // parameter sweeper
//  BatchAnalyzer* batchAnalyzer = nil; // batch job processor and analyzer

  printf("Run in SEQUENTIAL MODE ... \n");   
  //
  // Phase 1: Swarm environment initialization
  //  
  initSwarmArguments(argc, (const char **)argv, [CommandLineOptionHandler class]);  

  //
  // Phase 1.1: Command line manipulation 
  //
  // a. check  verbose level option : -d and --display-level
  if(![CommandLineOptionHandler exist: "-d" In: arguments] && 
     ![CommandLineOptionHandler exist: "--display-level" In: arguments]) 
    dLevel = 0; // default level
  else
    dLevel = [((CommandLineOptionHandler *)arguments) getDisplayLevelArg];

  // b. check parameter file option: -F and --param-file
  if([CommandLineOptionHandler exist: "-F" In: arguments] ||
      [CommandLineOptionHandler exist: "--param-file" In: arguments]) 
	{
		parmFile = [String create: globalZone setC:
			[((CommandLineOptionHandler *)arguments) getParameterFileNameArg]];
		// remove preceeding directory info
		char *pdir = (char *)[[parmFile copy: scratchZone] getC];
		char *str = pdir;
		char *ptr;
		while((ptr = strstr(str, "/")) != '\0') str = ptr + 1;
		if(str != NULL)
		{
			*(pdir + (str - pdir - 1)) = '\0';
			parmdir = pdir;
		}
	} 
  
	// c. check parameter file option: -D and --param-dir
  if([CommandLineOptionHandler exist: "-D" In: arguments] ||
      [CommandLineOptionHandler exist: "--param-dir" In: arguments])
  {
    parmDir = [String create: globalZone setC:
                             [((CommandLineOptionHandler *)arguments) getParameterDirectoryNameArg]];
   parmdir = [parmDir getC];
  }

  // d. check parameter sweeping table option: -T and --sweep-table
  if([CommandLineOptionHandler exist: "-T" In: arguments] || 
     [CommandLineOptionHandler exist: "--sweep-table" In: arguments]) 
    sweepTblName = [String create: globalZone setC: 
			     [((CommandLineOptionHandler *)arguments) getParameterSweepingTableFileNameArg]];

	// e. check solute trace option : -E <BOOL> or --enable-trace=<BOOL>
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
      printf("Error: -F, -D, and -T options cannot be selected at the same time...\n");
      printf("       just select only one of them...\n");
      exit(-1);
    }

  if(sweepTblName != nil)
    {
      id<String> inDir = [sweepTblName copy: globalZone];
      [inDir catC: ".sweep"];
      parmdir = [inDir getC];
      sweeper = [[ParameterSweeper createBegin: globalZone] createEnd];      
      [sweeper buildParameterSweepingSpace: sweepTblName to: inDir];
    }

  //
  // Phase 1.2: Create Batch Jobs Analyzer
  //
  //batchAnalyzer = [[BatchAnalyzer createBegin: globalZone] createEnd];
  if(sweepTblName != nil) 
    {
      char *ptr;
      char *str = (char *)[sweepTblName getC];
      while((ptr = strstr(str, "/")) != '\0')  str = ptr + 1;
      id<String> outDir = [String create: globalZone setC: str];
      [outDir catC: "-SEQ"];
      //[batchAnalyzer createFileForProcessor: 0 baseDir:  [outDir getC]];
    }
  else {
    //[batchAnalyzer createFileForProcessor: 0];
  }

//   //
//   // Phase 2: Parameter file loading 
//   //
//   id <List> parmlist; // a list of parameter files

//   if(parmFile != nil)
//     { 
//       char *ptr;
//       char *str = (char *)[parmFile getC];
//       while((ptr = strstr(str, "/")) != '\0')  str = ptr + 1;
//       id<String> outDir = [String create: globalZone setC: str];
//       parmlist = [[List createBegin: globalZone] createEnd];
//       [parmlist addLast: outDir];
//     }
//   else
//     {
//       char pattern[512]; // suffix pattern (e.g., *suffix)
//       DIR *dirp; // a directory
//       struct dirent *direntp; // directory entry data structure
//       // open directory
//       if((dirp = opendir(parmdir)) == NULL)
// 	{
// 	  fprintf(stderr, "Could not open the directory %s : %s\n", parmdir, strerror(errno));
// 	}
//       sprintf(pattern, "*%s",  suffix);
//       parmlist = [[List createBegin: globalZone] createEnd];
//       while((direntp = readdir(dirp)) != NULL)
// 	if(fnmatch(pattern, direntp->d_name, FNM_NOESCAPE) == 0)
// 	  [parmlist addLast: [String create: globalZone setC: direntp->d_name]];
//       closedir(dirp);
//     }
 
//   //
//   // Phase 3: Sequential execution of IPRL simulation
//   //
//   int plength = [parmlist getCount]; // number of parameter sets 




//  double *simrst = malloc(sizeof(double)*plength); // simulation result holder
//  double *exetime = malloc(sizeof(double)*plength); // executition time holder
//  char nmrst[plength][256];  // name related to similarity results
//  id <Index> indexer = [parmlist begin: globalZone];
//  int idx;
//  struct timeval expStart, expEnd;

  ExperAgent *experAgent = nil;
  experAgent = [ExperAgent createBegin: globalZone];
  [experAgent setGUIMode: swarmGUIMode];
  if (swarmGUIMode) SET_WINDOW_GEOMETRY_RECORD_NAME (experAgent);
  experAgent = [experAgent createEnd];
  [experAgent buildProbeMap];
  [experAgent setParamDir: [String create: globalZone setC: parmdir]];
  [experAgent enableSoluteTrace: enableTrace];
  [experAgent setDisplayLevel: dLevel];
  [experAgent buildObjects: parmFile]; // needs parmdir
  [experAgent buildActions];
  [experAgent activateIn: nil];
  [experAgent go];

//   for(idx = 0; idx < plength; idx++) // for each parameter set
//     {
//       id <String> parmset = [indexer next];
//       sprintf(nmrst[idx], "%s", [parmset getC]);  
//       printf("Run an ISL Simulation with %s...\n", [parmset getC]);

//       gettimeofday(&expStart, NULL);
//       // Make the experiment swarm
//       experAgent =  [ExperAgent createBegin: globalZone];
//       [experAgent setGUIMode: swarmGUIMode];
//       if (swarmGUIMode) SET_WINDOW_GEOMETRY_RECORD_NAME (experAgent);
//       experAgent = [experAgent createEnd];
//       [experAgent setParamFileName: [parmset getC]];
//       if(sweepTblName != nil) [experAgent setParamDir: [String create: globalZone setC: parmdir]];
//       [experAgent setDisplayLevel: dLevel];
//       [experAgent buildObjects];
//       [experAgent buildActions];
//       [experAgent activateIn: nil];		// Top-level swarm is activated in nil
//       [experAgent go];
//       gettimeofday(&expEnd, NULL);
//       exetime[idx] = expEnd.tv_sec  - expStart.tv_sec;

//       if(dLevel > 0)
// 	printf("Execution time of %s : %f \n", [parmset getC], exetime[idx]);

//       simrst[idx] = [experAgent getSimilarity];
//       [batchAnalyzer recordSimilarity: simrst[idx] withName: nmrst[idx] withMessage: "NO PARALLELISM"];
//       [batchAnalyzer recordExecutionTime: exetime[idx] withName: nmrst[idx] withMessage: "NO PARALLELISM"];
//     }
  [experAgent drop];
  experAgent = nil;
//  [indexer drop];

  //
  // Phase 4: Simulation result analysis
  //
//  [batchAnalyzer findMaxSimilarity: simrst length: plength in: &idx];
  //  [batchAnalyzer recordMessage: "=================================================================\n"];
//  [batchAnalyzer recordSimilarity: simrst[idx] withName: nmrst[idx] withMessage: "Maximum among experiments"];
//  [batchAnalyzer recordExecutionTime: exetime[idx] withName: nmrst[idx] withMessage: "Execution Time"];

//   if(dLevel >= 0)
//     {
//       int i;
//       double totalExeTime = 0.0;
//       for(i = 0; i < plength; i++) totalExeTime += exetime[i];
//       printf("================== << SIMULATION SUMMARY (NO PARALLELISM) >> ====================\n");
//       for(i = 0; i < plength; i++)
// 	printf(" Experiment[%d] :: Parameter Set: %s,  Similarity: %g, Execution Time: %f\n", 
// 	       i, nmrst[i], simrst[i], exetime[i]); 
//       printf("================ << BATCH JOBS ANALYSIS (NO PARALLELISM) >> =====================\n");
//       printf("\t MAX Similarity :: %g@%s\n", simrst[idx], nmrst[idx]);
//       printf("\t TOTAL Execution Time  :: %f\n",  totalExeTime);
//       printf("=================================================================================\n");
//     }
//   [parmlist drop];
//   free(simrst);
//   [batchAnalyzer drop];
   return 0;
}
