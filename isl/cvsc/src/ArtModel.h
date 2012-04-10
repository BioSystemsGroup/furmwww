/*
 * IPRL - Articulated Model agent
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
//#import <objectbase/Swarm.h>
#import "RootSwarm.h"

#import <space.h>
#import <LocalRandom.h>
#import "artModel/Vas.h"
#import "artModel/Sinusoid.h"
#import "artModel/VasGraph.h"
#import "artModel/LobuleSpec.h"
#import "artModel/protocols.h"
#import "artModel/Binder.h"
#import "artModel/Cell.h"

id <UniformUnsignedDist> uUnsDist;
id <UniformUnsignedDist> uUnsFixDist;
id <UniformDoubleDist> uDblDist;
id <UniformDoubleDist> uDblFixDist;
id <GammaDist> gDblDist;

@interface ArtModel: RootSwarm
{
@public
  id<ExperAgent> _parent;

  id <Zone> artScratchZone;

  unsigned cycle;
  unsigned cycleLimit;
  unsigned stepsPerCycle;
  id <Map> bolusContents;

  id <Dosage> bolus;

  Vas *portalVein;
  Vas *hepaticVein;

  id graph;

  double turbo;
  unsigned coreFlowRate;
  unsigned bileCanalCirc;
  float ssS2EJumpProb;
  float ssE2SJumpProb;
  float ssE2DJumpProb;
  float ssD2EJumpProb;
  unsigned numBuffSpaces;

  id adminActions;
  id macroActions;
  id microActions;
  id modelActions;
  id obsActions;
  id snapAction;
  id abmSchedule;

  double dirSinRatio, tortSinRatio;
  unsigned tortSinCircMin, tortSinCircMax;
  float tortSinLenAlpha, tortSinLenBeta, tortSinLenShift;
  unsigned dirSinCircMin, dirSinCircMax;
  float dirSinLenAlpha, dirSinLenBeta, dirSinLenShift;
  unsigned sSpaceScale, eSpaceScale, dSpaceScale;

  float ecDensity, hepDensity; // % of space filled with
  unsigned binderNumMin, binderNumMax; // enzymes per hepatocyte
  float metabolizationProb;
  unsigned enzymeInductionWindow;
  unsigned enzymeInductionThreshold;
  float enzymeInductionRate;
  float bindProb;
  unsigned bindCycles;
  
  double soluteScale; // amount of solute per "Solute"

  unsigned inputCount, outputCount, bileFlux;
  id <Map> soluteInCount, soluteOutCount;
  unsigned totalSoluteMassEst;
  id <Map> soluteMassEst;

  short int abmDetails; // 0 = none, 1 = minimal, >1 = lots
  BOOL snapOn; // YES => png snapshots, NO => none

  // file detail for SS constituent outputs
  id <String> enzymeDistFileBase;
  id <String> enzymeDistFileName;
  FILE *enzymeDistFile;
  id <String> amountMetabFileBase;
  id <String> amountMetabFileName;
  FILE *amountMetabFile;
  id <String> amountFileBase;
  id <String> amountFileName;
  FILE *amountFile;

  id <SplitRandomGenerator> rng;

  id <List> outLabels;

  unsigned currentStep;
  unsigned dosageEndTime;

  FILE *sfp;
  FILE *dfp;
  FILE *ofp;
  unsigned totalNumberOfSolutes;
  id <String> bdir;
  id <Map> retiredSoluteMap;
  BOOL enableTrace;  // turn on and off solute trace
}

// runtime methods
- step;
- checkToStop;
- bolus;

// observation methods
- printResults;
- writeTracedRetiredSolutes;
- writeTracedMetabolizedSolutes;
- traceSolutes;
- (id <Map>) measure: (LiverNode *) v;
- (id) measureVasaFlux;
- (double) getOutputFraction;
- (double) getBileOutputFraction;
- (id <List>) getOutputNames;
- (id <Map>) getOutputs;

// accessors
- getSinusoidList;
- getGraph;
- (unsigned)getCycle;
- (double) getTime;
- (double) getTimeInFineResolution;
- (float) getCurrentDosage;
- (unsigned) getTotalNumberOfSolutesCreated;

// construction methods
+ createBegin: aZone;
- createEnd;
- buildObjects;
//- createASinusoid;
- (id <DiGraph>) getEmptyGraph;
- (void) useLobuleSpec: (LobuleSpec *) ls;
- initGraph: (id <DiGraph>) g;
- buildActions;
- activateIn: swarmContext;
- activateGraphSinusoidCellsIn: (id) swarmContext;

- (id) setParent: (id) p;
- setCycleLimit: (unsigned) cl;
- setStepsPerCycle: (unsigned) is;
- setTortSinCircMin: (unsigned) cmin max: (unsigned) cmax
           lenAlpha: (float) lapha beta: (float) lbeta
          lenShift: (float) lshift;
- setDirSinCircMin: (unsigned) cmin max: (unsigned) cmax
          lenAlpha: (float) lapha beta: (float) lbeta
         lenShift: (float) lshift;
- setSpaceScaleS: (unsigned) sscale E: (unsigned) escale D: (unsigned) dscale;
- setSinRatiosDirect: (float) d tortuous: (float) t;
- setSoluteScale: (double) ss;
- setDosageParams: (id <Array>) p andTimes: (id <Array>) t;
- (void) setBolusContents: (id <Map>) bc;

- (id <DiGraph>) getGraphContainer;
- setSinusoidTurbo: (double) t;
- (void) setCoreFlowRate: (unsigned) cfr;
- (void) setBileCanalCircumference: (unsigned) c;
- (void) setSpaceJumpProbsS2E: (float) s2e 
                          e2S: (float) e2s e2D: (float) e2d d2E: (float) d2e;
- (void) calcNumBuffSpaces: (id <Map>) nbsCounters;
- (unsigned) getNumBuffSpaces;

- (void) setECDensity: (float) ecd;
- (void) setHepDensity: (float) hd;
- (void) setBinderNumMin: (unsigned) bnmin max: (unsigned) bnmax;
- (void) setMetabolizationProb: (float) mp;
- (void) setEnzymeInductionWindow: (unsigned) w thresh: (unsigned) t rate: (float) r;
- (void) setBindingProb: (float) bp andCycles: (unsigned) bc;

- (void) checkParameters;

- setViewArtDetails: (short int) details;
- (void) setSnapshots: (BOOL) snaps;
- setRNG: (id <SplitRandomGenerator>) r;
- (void) enableSoluteTrace: (BOOL) trace;

@end
