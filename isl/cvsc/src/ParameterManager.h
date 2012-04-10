/*
 * ISL ParameterManager - This object initializes and increments the
 *     parameters for the execution of each run of the experiment.
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <ParameterManagerUtils.h>
#import "protocols.h"
//int pm_compare ( id obj1, id obj2 );

@interface ParameterManager: /*SwarmObject*/ ParameterManagerUtils
{
@public
  id <Map> bolusContents;
@protected
  id <ExperAgent> _parent;
  LiverDMM *dMM;
  // art parameters
  unsigned artStepsPerCycle;
//  id <Map> bolusContents;
  id <Array> dosageParams;
  id <Array> dosageTimes;

  const char * artGraphInputFile; // explicit graph
  const char * artGraphSpecFile;  // graph parameters
  unsigned artGraphSpecIterates;  // how many different parameter vectors
  int graphSpecCount; // used to iterate over graph specs
  float artDirSinRatio, artTortSinRatio;
  unsigned artTortSinCircMin, artTortSinCircMax;
  float artTortSinLenAlpha, artTortSinLenBeta, artTortSinLenShift;
  unsigned artDirSinCircMin, artDirSinCircMax;
  float artDirSinLenAlpha, artDirSinLenBeta, artDirSinLenShift;
  unsigned artSSpaceScale, artESpaceScale, artDSpaceScale;
  float artECDensity, artHepDensity;
  unsigned artBindersPerCellMin, artBindersPerCellMax;
  float artMetabolizationProb;
  unsigned artEnzymeInductionWindow;
  unsigned artEnzymeInductionThreshold;
  float artEnzymeInductionRate;
  float artSoluteBindingProb;
  unsigned artSoluteBindingCycles;

  double artSoluteScale;
  unsigned artDosageParamA, artDosageParamB, artDosageParamC;
  double artSinusoidTurbo;
  unsigned artCoreFlowRate;
  unsigned artBileCanalCirc;
  float artS2EJumpProb, artE2SJumpProb, artE2DJumpProb, artD2EJumpProb;

  short int artViewDetails;
  BOOL artSnapshotsOn;

/******** evolution parameters ***********************/
  //Initial increments
  double d_artDirSinRatio, d_artTortSinRatio;
  double d_artTortSinCircMin, d_artTortSinCircMax;
  double d_artTortSinLenAlpha, d_artTortSinLenBeta, d_artTortSinLenShift;
  double d_artDirSinCircMin, d_artDirSinCircMax;
  double d_artDirSinLenAlpha, d_artDirSinLenBeta, d_artDirSinLenShift;
  double d_artECDensity;
  double d_artCoreFlowRate;
  double d_artBileCanalCirc;
  double d_artS2EJumpProb, d_artE2SJumpProb, d_artE2DJumpProb, d_artD2EJumpProb;
  double d_artSoluteScale, d_artSinusoidTurbo;
  double d_artDosageParamA, d_artDosageParamB, d_artDosageParamC;


  //indices
  unsigned i_artDirSinRatio, i_artTortSinRatio;
  unsigned i_artTortSinCircMin, i_artTortSinCircMax;
  unsigned i_artTortSinLenAlpha, i_artTortSinLenBeta, i_artTortSinLenShift;
  unsigned i_artDirSinCircMin, i_artDirSinCircMax;
  unsigned i_artDirSinLenAlpha, i_artDirSinLenBeta, i_artDirSinLenShift;
  unsigned i_artECDensity;
  unsigned i_artCoreFlowRate;
  unsigned i_artBileCanalCirc;
  unsigned i_artS2EJumpProb, i_artE2SJumpProb, i_artE2DJumpProb, i_artD2EJumpProb;
  unsigned i_artSoluteScale, i_artSinusoidTurbo;
  unsigned i_artDosageParamA, i_artDosageParamB, i_artDosageParamC;
  

/*************************************************/
  
  
  // ref parameters
  double refTimeStart, refTimeIncrement;
  double ref_k1, ref_k2, ref_ke;
  double refDispersionNum;
  double refExpTransitTime;
  double refBolusMass;
  double refPerfusateFlow;
  double refMainDivertRatio;
  double refSecDivertRatio;
  double refEpsilon;

  // dat parameters
  BOOL datInterpolate;
  const char * datFileName;

//  unsigned monteCarloSet;
}

// runtime methods
- (BOOL)stepParameters: theExper;
- (void)initializeExper: theExper;
- (void)initializeDat: theDat;
- (void)initializeRef: theRef;
- (void)initializeArt: theArt;
- (BOOL)iterateArtGraphSpec;

//construction methods
- (void)initializeParameters;
- (id) setParent: (id) p;

// optimization methods
// - (id <Vectormd>) vectorizeEvolvingParameters;
// - (id <Vectormd>) vectorizeDparams;
// - (void) restoreEvolvingParametersFrom: (id <Vectormd>) v;
- (unsigned) findNumberOfEvolvingParams;
// - (void) logEvolvingParameters: (id <Vectormd>) v;
@end

