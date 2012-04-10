/*
 * ISL - ParameterManager -- responsible for iterating over parameter
 *                           sets.
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
#include <assert.h>
#import <float.h>

#import "ExperAgent.h"
#import "LiverDMM.h"
#import "ParameterManager.h"

@implementation ParameterManager

// runtime methods

/*
 * stepParameters - This method increments the parameters to be swept
 *                  At present, it simply sweeps both parameters until
 *                  they each hit their max, then they stay at their
 *                  max as the others catch up.  What should really be
 *                  here is a permutations algorithm that sweeps the 
 *                  space in a linearly independent way.
 */
- (BOOL)stepParameters: theExper
{
  BOOL retVal=NO; // YES => new parameter set, NO => nothing left

  [Telem debugOut: 3 
         printf: "[%s(%p) -stepParameters: %s(%p)] -- Enter.\n",
         [[self getClass] getName], self, 
         [[theExper getClass] getName], theExper];

  // example of direct manipulation
  /*
  if ( (artSoluteConc < artSoluteConcMax) ) {
    artSoluteConc += artSoluteConcInc;
    retVal = YES;
  }
  */



  /*
   * optimization parameter stepping
   */
  if (retVal == NO) {
    // if there is no parameter to optimize then finish the experiment.
    NMS = ([self findNumberOfEvolvingParams] == 0 ? 0 : NMS);
    if (NMS != 0) { // optimization continues
      double s = [theExper getSimilarity];
      while (( NMS = [self evolveParametersUsingSimplexMethod: s]
               ) == 2 ) {
        [Telem debugOut: 0 printf:"N&M: At least one of the parameters is out of range.\n"];	
        s = 0.0;
      }
      [theExper setSimilarity: s];
      retVal = YES;
    }
  }
  /*
   * end optimization stepping
   */

  [Telem debugOut: 1 printf: "[%s(%p) -stepParameters:] -- finished optimization iterations, retVal = %s\n",
         [[self getClass] getName], self, (retVal?"yes":"no")];

  /*
   * GraphSpec parameter sweeps handled separately
   */
  if (retVal == NO) {

    [Telem debugOut: 1 printf: "\tchecking for graph spec iterates, artGraphSpecFile = %s\n", 
           artGraphSpecFile];

    if (artGraphSpecFile[0] != '\0')
      retVal = [self iterateArtGraphSpec];
  }
  /*
   * end graphspec stepping
   */

  [Telem debugOut: 1 printf: "[%s(%p) -stepParameters:] -- finished lobule spec iterations, retVal = %s\n",
         [[self getClass] getName], self, (retVal?"yes":"no")];


  /*
   * parameter sweep table files
   */
  if (retVal == NO) {
    //    add in the code to walk the .tbl files
  }
  /*
   * end table sweeping
   */


  /*
   * multiple parameter files
   */
  if (retVal == NO) {
    retVal = [theExper initPM];
  }
  /*
   * end multiple parameter files
   */


  [Telem debugOut: 1 printf: "[%s(%p) -stepParameters:] -- finished parameter file iterations, retVal = %s\n",
         [[self getClass] getName], self, (retVal?"yes":"no")];

  /*
   *  if fixedParam is true, then run virtual generator 2 with the
   *  same cycle each time, regardless of whether there is a new
   *  parameter vector.
   */
  if (fixedParam)
    [rng restartGenerator: fixable];

  [Telem debugOut: 3 printf: "ParameterManager::stepParameters() -- Exit -- retVal = %s\n",
         (retVal?"yes":"no")];

  return retVal;
}

- (void)initializeExper: theExper
{
  [theExper setRunFileNameBase: runFileNameBase];
  [theExper setMonteCarloRuns: monteCarloRuns];
  [theExper setShowLiveData: showLiveData];
  [theExper setShowLiveAgg: showLiveAgg];

  [theExper setSimilarityMeasure: similarityMeasure];
  [theExper setNominalProfile: nominalProfile];
  [theExper setNominalProfileColumnLabel: nomProfCol];
  [theExper setExperimentalProfile: experimentalProfile];

  [theExper setInterpDatModel: datInterpolate];
  [theExper setDatModelFileName: datFileName];

  [theExper setArtGraphFileName: artGraphInputFile];
  [theExper setArtGraphSpecFileName: artGraphSpecFile];
  [theExper setRNG: rng];

  [theExper setSimilarityBandCoefficient: similarityBandCoefficient];
}

- (void)initializeDat: theDat
{
  [theDat setCycleLimit: cycleLimit];
}
- (void)initializeRef: theRef
{
  [theRef setCycleLimit: cycleLimit];
  [theRef setEpsilon: refEpsilon];
  [theRef setTimeStart: refTimeStart increment: refTimeIncrement];
  [theRef setParmK1: ref_k1 k2: ref_k2 ke: ref_ke 
          disp: refDispersionNum
          transit: refExpTransitTime 
          mass: refBolusMass
          flow: refPerfusateFlow 
          r2am2s: refMainDivertRatio 
          r2as2m: refSecDivertRatio];
  [theRef setBolusContents: bolusContents];
}
- (void)initializeArt: theArt
{
  [theArt setTortSinCircMin: artTortSinCircMin max: artTortSinCircMax
          lenAlpha: artTortSinLenAlpha beta: artTortSinLenBeta
          lenShift: artTortSinLenShift];

  [theArt setDirSinCircMin: artDirSinCircMin max: artDirSinCircMax
          lenAlpha: artDirSinLenAlpha beta: artDirSinLenBeta
          lenShift: artDirSinLenShift];
  [theArt setSpaceScaleS: artSSpaceScale E: artESpaceScale D: artDSpaceScale];
  [theArt setSinRatiosDirect: artDirSinRatio tortuous: artTortSinRatio];
  [theArt setSinusoidTurbo: artSinusoidTurbo];
  [theArt setCoreFlowRate: artCoreFlowRate];
  [theArt setBileCanalCircumference: artBileCanalCirc];
  [theArt setSpaceJumpProbsS2E: artS2EJumpProb e2S: artE2SJumpProb 
          e2D: artE2DJumpProb d2E: artD2EJumpProb];
  [theArt setECDensity: artECDensity];
  [theArt setHepDensity: artHepDensity];
  [theArt setBinderNumMin: artBindersPerCellMin max: artBindersPerCellMax];
  [theArt setMetabolizationProb: artMetabolizationProb];
  [theArt setEnzymeInductionWindow: artEnzymeInductionWindow 
          thresh: artEnzymeInductionThreshold 
          rate: artEnzymeInductionRate];
  [theArt setBindingProb: artSoluteBindingProb 
          andCycles: artSoluteBindingCycles];
  [theArt setSoluteScale: artSoluteScale];
  [theArt setCycleLimit: cycleLimit];
  [theArt setStepsPerCycle: artStepsPerCycle]; // set this before dosageTimes
  [theArt setDosageParams: dosageParams andTimes: dosageTimes];
  [theArt setBolusContents: bolusContents];

  [theArt setViewArtDetails: artViewDetails];
  [theArt setSnapshots: artSnapshotsOn];
  [theArt setRNG: rng];

}

/*
 * Change the __parameterization__ of the articulated model graph Note
 * the distinction, here, between the parameterization and the
 * stochastic changes.  Stochasticity occurs within the single
 * (ambigous) lobule specification.
 */ 
#define TOTALNODES_FACTOR 3L
#define EDGE_FACTOR 3L
- (BOOL) iterateArtGraphSpec
{
  unsigned zone1=0L, zone2=0L;
  BOOL cont=YES;
  int nodesAvail = 0L;
  int totalNodes = 0L;
  LobuleSpec *ls=nil;
  ls = [dMM loadLobuleSpecIntoZone: scratchZone];

  [Telem debugOut: 2 printf: 
           "[%s(%p) -iterateArtGraphSpec] -- "
         "graphSpecCount = %d, artGraphSpecIterates = %d\n",
         [[self getClass] getName], self,
         graphSpecCount, artGraphSpecIterates];

  if (graphSpecCount >= artGraphSpecIterates-1) return NO;

  // calculate some graph properties
  for ( zone1=0 ; zone1<ls->numZones ; zone1++ ) {
    totalNodes += ls->nodesPerZone[zone1];
  }

  nodesAvail = [pmUUnsDist getUnsignedWithMin: totalNodes/TOTALNODES_FACTOR
                           withMax: totalNodes*TOTALNODES_FACTOR];
  { // modify it
     for ( zone1=0 ; zone1<ls->numZones ; zone1++ ) {
       unsigned minNpZ = 0L;
       if ( zone1 == 0 ) minNpZ = 1L;
       ls->nodesPerZone[zone1] = 
         [pmUUnsDist getUnsignedWithMin: minNpZ withMax: nodesAvail];
       nodesAvail = nodesAvail - ls->nodesPerZone[zone1];
       for ( zone2=0 ; zone2<ls->numZones ; zone2++ ) {
         ls->edges[zone1][zone2] = 
           [pmUUnsDist 
             getUnsignedWithMin: 0L
             withMax: ls->edges[zone1][zone2]*EDGE_FACTOR];
       }
     }
  }

  [Telem debugOut: 2 printf: "[%s(%p) -iterateArtGraphSpec] -- end\n",
         [[self getClass] getName], self];

  [dMM nextLobuleSpec: ls mcSet: monteCarloSet];

  [ls drop];

  graphSpecCount++;

  return cont;
}


// construction methods
- createEnd
{
  ParameterManager *obj = [super createEnd];
  obj->graphSpecCount = 0L;
  return obj;
}

- (void)initializeParameters
{
  [super initializeParameters];
  dMM = (LiverDMM *)[_parent getDMM];
  bolusContents = [dMM loadObject: "bolusContents" into: [self getZone]];
  dosageParams = [dMM loadObject: "dosageParams" into: [self getZone]];
  dosageTimes = [dMM loadObject: "dosageTimes" into: [self getZone]];
}

- (id) setParent: (id) p
{
  assert(p != nil);
  _parent = p;
  return self;
}

 /*
  * Optimization Local Methods
  */

- (id <Vectormd>) vectorizeEvolvingParameters
{

  id <Vectormd> retVal = [Vectormd create: [self getZone] 
				   setDim: [self findNumberOfEvolvingParams]];
  unsigned i=0;

  if (d_artDirSinRatio != 0){
    [retVal setVal: (double)artDirSinRatio	 at: i];
    i_artDirSinRatio = i;	  
    i++;
  }
  if (d_artTortSinRatio != 0){ 
    [retVal setVal: (double)artTortSinRatio	 at: i];
    i_artTortSinRatio = i;
    i++;
  }
  if (d_artTortSinLenAlpha != 0){ 
    [retVal setVal: (double)artTortSinLenAlpha 	 at: i];
    i_artTortSinLenAlpha = i;
    i++;
  }
  if (d_artTortSinLenBeta != 0){ 
    [retVal setVal: (double)artTortSinLenBeta 	 at: i];
    i_artTortSinLenBeta = i;
    i++;
  }
  if (d_artTortSinLenShift != 0){ 
    [retVal setVal: (double)artTortSinLenShift	 at: i];
    i_artTortSinLenShift = i;
    i++;
  }
  if (d_artDirSinLenAlpha != 0){ 
    [retVal setVal: (double)artDirSinLenAlpha	 at: i];
    i_artDirSinLenAlpha = i;
    i++;
  }
  if (d_artDirSinLenBeta != 0){ 
    [retVal setVal: (double)artDirSinLenBeta	 at: i];
    i_artDirSinLenBeta = i;
    i++;
  }
  if (d_artDirSinLenShift != 0){ 
    [retVal setVal: (double)artDirSinLenShift	 at: i];
    i_artDirSinLenShift = i;
    i++;
  }
  if (d_artECDensity != 0){ 
    [retVal setVal: (double)artECDensity	 at: i];
    i_artECDensity = i;
    i++;
  }
  if (d_artCoreFlowRate != 0){ 
    [retVal setVal: (double)artCoreFlowRate	 at: i];
    i_artCoreFlowRate = i;
    i++;
  }
  if (d_artBileCanalCirc != 0) {
    [retVal setVal: (double)artBileCanalCirc  at: i];
    i_artBileCanalCirc = i;
    i++;
  }
  if (d_artS2EJumpProb != 0){ 
    [retVal setVal: (double)artS2EJumpProb 	 at: i];
    i_artS2EJumpProb = i;
    i++;
  }
  if (d_artE2SJumpProb != 0){ 
    [retVal setVal: (double)artE2SJumpProb 	 at: i];
    i_artE2SJumpProb = i;
    i++;
  }
  if (d_artE2DJumpProb != 0){ 
    [retVal setVal: (double)artE2DJumpProb 	 at: i];
    i_artE2DJumpProb = i;
    i++;
  }
  if (d_artD2EJumpProb != 0){ 
    [retVal setVal: (double)artD2EJumpProb	 at: i];
    i_artD2EJumpProb = i;
    i++;
  }
  if (d_artSoluteScale != 0){ 
    [retVal setVal: (double)artSoluteScale       at: i];
    i_artSoluteScale = i;
    i++;
  }
  if (d_artSinusoidTurbo != 0){ 
    [retVal setVal: (double)artSinusoidTurbo     at: i];
    i_artSinusoidTurbo = i;
    i++;
  }
  if (d_artDosageParamA != 0){ 
    [retVal setVal: (double)artDosageParamA     at: i];
    i_artDosageParamA = i;
    i++;
  }
  if (d_artDosageParamB != 0){ 
    [retVal setVal: (double)artDosageParamB     at: i];
    i_artDosageParamB = i;
    i++;
  }
  if (d_artDosageParamC != 0){ 
    [retVal setVal: (double)artDosageParamC     at: i];
    i_artDosageParamC = i;
    i++;
  }
  

  return retVal;
}

- (id <Vectormd>) vectorizeDparams
{	
  id <Vectormd> retVal = [Vectormd create: [self getZone] 
				   setDim: [self findNumberOfEvolvingParams]];
  if (d_artDirSinRatio != 0 )     
	  [retVal setVal: (double)d_artDirSinRatio	 
		      at: i_artDirSinRatio];
  if (d_artTortSinRatio != 0 )    
	  [retVal setVal: (double)d_artTortSinRatio	 
		      at: i_artTortSinRatio];
  if (d_artTortSinLenAlpha != 0 ) 
	  [retVal setVal: (double)d_artTortSinLenAlpha   
		      at: i_artTortSinLenAlpha];
  if (d_artTortSinLenBeta != 0 )  
	  [retVal setVal: (double)d_artTortSinLenBeta    
		      at: i_artTortSinLenBeta];
  if (d_artTortSinLenShift != 0 ) 
	  [retVal setVal: (double)d_artTortSinLenShift   
		      at: i_artTortSinLenShift];
  if (d_artDirSinLenAlpha != 0 )  
	  [retVal setVal: (double)d_artDirSinLenAlpha	 
		      at: i_artDirSinLenAlpha];
  if (d_artDirSinLenBeta != 0 )   
	  [retVal setVal: (double)d_artDirSinLenBeta	 
		      at: i_artDirSinLenBeta];
  if (d_artDirSinLenShift != 0 )  
	  [retVal setVal: (double)d_artDirSinLenShift	 
		      at: i_artDirSinLenShift];
  if (d_artECDensity != 0 )       
	  [retVal setVal: (double)d_artECDensity	 
		      at: i_artECDensity];
  if (d_artCoreFlowRate != 0 )    
	  [retVal setVal: (double)d_artCoreFlowRate	 
		      at: i_artCoreFlowRate];
  if (d_artBileCanalCirc != 0 )
	  [retVal setVal: (double)d_artBileCanalCirc
		      at: i_artBileCanalCirc];
  if (d_artS2EJumpProb != 0 ) 	  
	  [retVal setVal: (double)d_artS2EJumpProb 	 
		      at: i_artS2EJumpProb];
  if (d_artE2SJumpProb != 0 ) 	  
	  [retVal setVal: (double)d_artE2SJumpProb 	 
		      at: i_artE2SJumpProb];
  if (d_artE2DJumpProb != 0 ) 	  
	  [retVal setVal: (double)d_artE2DJumpProb 	 
		      at: i_artE2DJumpProb];
  if (d_artD2EJumpProb != 0 ) 	 
	  [retVal setVal: (double)d_artD2EJumpProb	 
		      at: i_artD2EJumpProb];
  if (d_artSoluteScale != 0 ) 	
	  [retVal setVal: (double)d_artSoluteScale   
		      at: i_artSoluteScale];
  if (d_artSinusoidTurbo != 0 )  
	  [retVal setVal: (double)d_artSinusoidTurbo    
		      at: i_artSinusoidTurbo];
   if (d_artDosageParamA != 0) 
	  [retVal setVal: (double)d_artDosageParamA    
		      at: i_artDosageParamA];
   if (d_artDosageParamB != 0) 
	  [retVal setVal: (double)d_artDosageParamB    
		      at: i_artDosageParamB];
   if (d_artDosageParamC != 0) 
	  [retVal setVal: (double)d_artDosageParamC    
		      at: i_artDosageParamC];

  return retVal;
}
- (void) restoreEvolvingParametersFrom: (id <Vectormd>) v
{
  if (d_artDirSinRatio != 0){
    artDirSinRatio    =(float)[v getValAt: i_artDirSinRatio];
    if (artDirSinRatio <0)  paramsOutOfRange=YES;
    if (artDirSinRatio >1)  paramsOutOfRange=YES;
  }
  if (d_artTortSinRatio != 0){ 
    artTortSinRatio   =(float)[v getValAt: i_artTortSinRatio];
    if (artTortSinRatio <0)  paramsOutOfRange=YES;
    if (artTortSinRatio >1)  paramsOutOfRange=YES;
  }
  if (d_artTortSinRatio != 0 || d_artDirSinRatio != 0){
    if (((artDirSinRatio+artTortSinRatio) - 1.0L) >= FLT_EPSILON ) paramsOutOfRange=YES;
  }
  if (d_artTortSinLenAlpha != 0){ 
    artTortSinLenAlpha=(float)[v getValAt: i_artTortSinLenAlpha];
    if (artTortSinLenAlpha <=0)  paramsOutOfRange=YES;
  }
  if (d_artTortSinLenBeta != 0){ 
    artTortSinLenBeta =(float)[v getValAt: i_artTortSinLenBeta];
    if (artTortSinLenBeta <=0)  paramsOutOfRange=YES;
  }
  if (d_artTortSinLenShift != 0){ 
    artTortSinLenShift=(float)[v getValAt: i_artTortSinLenShift];
  }
  if (d_artDirSinLenAlpha != 0){ 
    artDirSinLenAlpha =(float)[v getValAt: i_artDirSinLenAlpha];
    if (artDirSinLenAlpha <=0)  paramsOutOfRange=YES;
  }
  if (d_artDirSinLenBeta != 0){ 
    artDirSinLenBeta  =(float)[v getValAt: i_artDirSinLenBeta];
    if (artDirSinLenBeta <=0)  paramsOutOfRange=YES;
  }
  if (d_artDirSinLenShift != 0){ 
    artDirSinLenShift =(float)[v getValAt: i_artDirSinLenShift];
  }
  if (d_artECDensity != 0){ 
    artECDensity      =(float)[v getValAt: i_artECDensity];
    if (artECDensity <0)  paramsOutOfRange=YES;
    if (artECDensity >1)  paramsOutOfRange=YES;
  }
  if (d_artCoreFlowRate != 0){ 
    artCoreFlowRate   = (unsigned)[v getValAt: i_artCoreFlowRate];
    if (([v getValAt: i_artCoreFlowRate] <=0) || artCoreFlowRate==0) paramsOutOfRange=YES;
  }
  if (d_artBileCanalCirc != 0){ 
    artBileCanalCirc   = (unsigned)[v getValAt: i_artBileCanalCirc];
    if (([v getValAt: i_artBileCanalCirc] <=0) || artBileCanalCirc==0) paramsOutOfRange=YES;
  }
  if (d_artS2EJumpProb != 0){ 
    artS2EJumpProb    =(float)[v getValAt: i_artS2EJumpProb];
    if (artS2EJumpProb < 0) paramsOutOfRange=YES;
    if (artS2EJumpProb > 1) paramsOutOfRange=YES;
  }
  if (d_artE2SJumpProb != 0){ 
    artE2SJumpProb    =(float)[v getValAt: i_artE2SJumpProb];
    if (artE2SJumpProb < 0) paramsOutOfRange=YES;
    if (artE2SJumpProb > 1) paramsOutOfRange=YES;
  }
  if (d_artE2DJumpProb != 0){ 
    artE2DJumpProb    =(float)[v getValAt: i_artE2DJumpProb];
    if (artE2DJumpProb < 0) paramsOutOfRange=YES;
    if (artE2DJumpProb > 1) paramsOutOfRange=YES;
  }
  if (d_artD2EJumpProb != 0){ 
    artD2EJumpProb    =(float)[v getValAt: i_artD2EJumpProb];
    if (artD2EJumpProb < 0) paramsOutOfRange=YES;
    if (artD2EJumpProb > 1) paramsOutOfRange=YES;
  }
  if (d_artSoluteScale != 0){ 
    artSoluteScale    =(double)[v getValAt: i_artSoluteScale];
    if (artSoluteScale < 1) paramsOutOfRange=YES;
  }
  if (d_artSinusoidTurbo != 0){ 
    artSinusoidTurbo  =(double)[v getValAt: i_artSinusoidTurbo];
    if ((artSinusoidTurbo < 0) || (artSinusoidTurbo > 1)) paramsOutOfRange=YES;
  }
  if (d_artDosageParamA != 0){
    artDosageParamA = (unsigned)[v getValAt: i_artDosageParamA];
    if (([v getValAt: i_artDosageParamA] <=0) || artDosageParamA==0) paramsOutOfRange=YES;
  }
  if (d_artDosageParamB != 0){
    artDosageParamB = (unsigned)[v getValAt: i_artDosageParamB];
    if (([v getValAt: i_artDosageParamB] <=0) || artDosageParamB==0) paramsOutOfRange=YES;
  }
  if (d_artDosageParamC != 0){
    artDosageParamC = (unsigned)[v getValAt: i_artDosageParamC];
    if (([v getValAt: i_artDosageParamC] <=0) || artDosageParamC==0) paramsOutOfRange=YES;
  }
}
- (void) logEvolvingParameters: (id <Vectormd>) v
{
  if (d_artDirSinRatio != 0) {
    [dMM logOptResultsPrintf: "artDirSinRatio = %f \n",[v getValAt: i_artDirSinRatio]];
  }
  if (d_artTortSinRatio != 0){ 
    [dMM logOptResultsPrintf:"artTortSinRatio =%f \n",[v getValAt: i_artTortSinRatio]];
  }
  if (d_artTortSinLenAlpha != 0){ 
    [dMM logOptResultsPrintf:"artTortSinLenAlpha=%f \n",[v getValAt: i_artTortSinLenAlpha]];
  }
  if (d_artTortSinLenBeta != 0){ 
    [dMM logOptResultsPrintf:"artTortSinLenBeta =%f \n",[v getValAt: i_artTortSinLenBeta]];
  }
  if (d_artTortSinLenShift != 0){ 
    [dMM logOptResultsPrintf:"artTortSinLenShift=%f \n",[v getValAt: i_artTortSinLenShift]];
  }
  if (d_artDirSinLenAlpha != 0){ 
    [dMM logOptResultsPrintf:"artDirSinLenAlpha =%f \n",[v getValAt: i_artDirSinLenAlpha]];
  }
  if (d_artDirSinLenBeta != 0){ 
    [dMM logOptResultsPrintf:"artDirSinLenBeta  =%f \n",[v getValAt: i_artDirSinLenBeta]];
  }
  if (d_artDirSinLenShift != 0){ 
    [dMM logOptResultsPrintf:"artDirSinLenShift =%f \n",[v getValAt: i_artDirSinLenShift]];
  }
  if (d_artECDensity != 0){ 
    [dMM logOptResultsPrintf:"artECDensity      =%f \n",[v getValAt: i_artECDensity]];
  }
  if (d_artCoreFlowRate != 0){ 
    [dMM logOptResultsPrintf:"artCoreFlowRate   =%f \n",[v getValAt: i_artCoreFlowRate]];
  }
  if (d_artBileCanalCirc != 0){ 
    [dMM logOptResultsPrintf:"artBileCanalCirc   =%f \n",[v getValAt: i_artBileCanalCirc]];
  }
  if (d_artS2EJumpProb != 0){ 
    [dMM logOptResultsPrintf:"artS2EJumpProb    =%f \n",[v getValAt: i_artS2EJumpProb]];
  }
  if (d_artE2SJumpProb != 0){ 
    [dMM logOptResultsPrintf:"artE2SJumpProb    =%f \n",[v getValAt: i_artE2SJumpProb]];
  }
  if (d_artE2DJumpProb != 0){ 
    [dMM logOptResultsPrintf:"artE2DJumpProb    =%f \n",[v getValAt: i_artE2DJumpProb]];
  }
  if (d_artD2EJumpProb != 0){ 
    [dMM logOptResultsPrintf:"artD2EJumpProb    =%f \n",[v getValAt: i_artD2EJumpProb]];
  }
  if (d_artSoluteScale != 0){ 
    [dMM logOptResultsPrintf:"artSoluteScale    =%f \n",[v getValAt: i_artSoluteScale]];
  }
  if (d_artSinusoidTurbo != 0){ 
    [dMM logOptResultsPrintf:"artSinusoidTurbo  =%f \n",[v getValAt: i_artSinusoidTurbo]];
  }
  if (d_artDosageParamA != 0){
    [dMM logOptResultsPrintf:"artDosageParamA  =%f \n",[v getValAt: i_artDosageParamA]];
  }	  
  if (d_artDosageParamB != 0){
    [dMM logOptResultsPrintf:"artDosageParamB  =%f \n",[v getValAt: i_artDosageParamB]];
  }	  
  if (d_artDosageParamC != 0){
    [dMM logOptResultsPrintf:"artDosageParamC  =%f \n",[v getValAt: i_artDosageParamC]];
  }	  
}
- (void) log: (const char *) fmt, ...
{
  char * buff;
  va_list ap;
  if (!fmt)
    raiseEvent(InvalidArgument, "Cannot print nil to optimization output.\n");
  va_start(ap, fmt);
#ifdef __USE_GNU
  // GNU CC specific
  if (vasprintf(&buff, fmt, ap) == -1)
    raiseEvent(SaveError, "Couldn't write to variable buff (%p).\n",buff);
#else
  raiseEvent(InternalError, 
             "The ParameterManager requires vasprintf() from GNU CC.");
#endif
  [dMM logOptResultsPrintf: (const char *)buff];
  va_end(ap);
  free(buff);
}

- (unsigned) findNumberOfEvolvingParams
{
   unsigned n = 0;
   if (d_artDirSinRatio != 0) n++;
   if (d_artTortSinRatio != 0) n++;
   if (d_artTortSinLenAlpha != 0) n++;
   if (d_artTortSinLenBeta != 0) n++;
   if (d_artTortSinLenShift != 0) n++;
   if (d_artDirSinLenAlpha != 0) n++;
   if (d_artDirSinLenBeta != 0) n++;
   if (d_artDirSinLenShift != 0) n++;
   if (d_artECDensity != 0) n++;
   if (d_artCoreFlowRate != 0) n++;
   if (d_artBileCanalCirc != 0) n++;
   if (d_artS2EJumpProb != 0) n++;
   if (d_artE2SJumpProb != 0) n++;
   if (d_artE2DJumpProb != 0) n++;
   if (d_artD2EJumpProb != 0) n++;
   if (d_artSoluteScale != 0) n++;
   if (d_artSinusoidTurbo != 0) n++;
   if (d_artDosageParamA != 0) n++;
   if (d_artDosageParamB != 0) n++;
   if (d_artDosageParamC != 0) n++;
   return n;
}
@end
