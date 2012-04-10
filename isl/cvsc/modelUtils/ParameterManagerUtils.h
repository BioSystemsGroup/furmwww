/*
 * IPRL ParameterManager - This object initializes and increments the
 *    parameters for the execution of each run of the experiment.
 *
 * Copyright 2003 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <objectbase/SwarmObject.h>
#import "modelUtils.h"
#import "LocalRandom.h"
#import "Vector.h"
#import "Simplex.h"

int pm_compare ( id obj1, id obj2 );

@interface ParameterManagerUtils: SwarmObject
{
  // experiment parameters
  unsigned monteCarloRuns;
  const char *runFileNameBase;
  BOOL showLiveData;
  BOOL showLiveAgg;

  char *similarityMeasure; // Right now, only 'global_sd' is available
  char *nominalProfile; // profile to use as reference data ('art', 'ref', 'dat' = average of data, 'dat:[column name]' e.g. 'dat:Diltiazem')
  char *nomProfCol;    // used to temporarily store the column name parsed from 'nominalProfile'
  char *experimentalProfile; // profile to compare against ref data ('art', 'ref', 'dat')

  unsigned currentRun;

  // pseudo-rng handling
  BOOL fixedParam;
  id <C4LCGXgen> rng;
  id <UniformUnsignedDist> pmUUnsDist;

  // cross-model run parameters
  unsigned cycle, cycleLimit;
  double similarityBandCoefficient;
  unsigned monteCarloSet;
  id <ParameterManager> subClass;

  // optimization parameters 
  int dL; //debug level
  double similarity_max; //maximum similarity score so far
  unsigned best_monteCarloSet; //best monte carlo set so far
  unsigned numberOfEvolvingParams;
  //Nelder&Mead Simplex optimization parameters
  unsigned NMS; //the exit code of N&MS algorithm: 
  		//0=done(converged), 
		//1= continue, 
		//2=at least one parameter is out of range
  id <Vectormd> initialParams, reflParams, centParams, c1Params, c2Params, expParams;
  unsigned dim,iterateNumber;
  id <Simplex> simplex;
  id <Vectormd> score; //double *score;
  unsigned iBest,   iWorst,   iNextWorst;
  double reflScore, contractRatio, shrinkRatio, expandRatio, reflectRatio;
  unsigned state;
  BOOL runNewMonteCarloSet,paramsOutOfRange;
  // end optimization parameters
}

// observation methods
- (unsigned) getRun;
- (unsigned) getMonteCarloSet;
- (void) log: (const char *) fmt, ... ;

//construction methods
- (void)initializeParameters;
- setRun: (unsigned) r;
- setMonteCarloSet: (unsigned) mcSet;

//optimization methods
- (unsigned)evolveParametersUsingSimplexMethod: (double)similarity;
- (void) findSimplexExtremes;
- (BOOL) simplexConverged;
- (id <Vectormd>) vectorizeEvolvingParameters;
- (id <Vectormd>) vectorizeDparams;
- (void) restoreEvolvingParametersFrom: (id <Vectormd>) v;
- (void) logEvolvingParameters: (id <Vectormd>) v;


/*
- (id <Vectormd>) reflect: (id <Vectormd>)v1 thru: (id <Vectormd>)v2 withRatio: (double)alpha;
- (id <Vectormd>) contract: (id <Vectormd>)v1 thru: (id <Vectormd>)v2 withRatio: (double)beta;
- (id <Vectormd>) expand: (id <Vectormd>)v1 thru: (id <Vectormd>)v2 withRatio: (double)beta;
- (void) shrinkSimplexWithRatio: (double)sigma;
*/
@end
