/*
 * IPRL - Experiment Agent
 *
 * Copyright 2003-2005 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * 
 */
//#import <objectbase/Swarm.h>
#import "RootSwarm.h"

#import <objectbase/SwarmObject.h>
#import <objectbase.h>
#import <simtools.h>
#import <simtoolsgui.h>
#import <analysis.h>
#import <defobj.h> // Archiver

#import <modelUtils.h>
#import "ParameterManager.h"
#import "CSVDatModel.h"
#import "RefModel.h"
#import "ArtModel.h"
#import "protocols.h"
//#import "LiverDMM.h"

/*
 * ExperAgent - This object creates, executes, and destroys all
 *              the objects and processes needed to carry out 
 *              several runs of the models.
 */
@interface ExperAgent: RootSwarm <DMMWrapper>
{
@public
  id <LiverDMM> dMM;

@protected
  id <Zone> experScratchZone;
  id <SplitRandomGenerator> rng;
  id <UniformUnsignedDist> experUUnsDist;
    
  unsigned datCycle;
  unsigned refCycle;
  unsigned artCycle;
  unsigned runNumber, monteCarloRuns;
  unsigned monteCarloSet;

  double similarity;
  double similarityBandCoefficient;

  int runBase;
  int dLevel;
  id <String>paramDir; 
	BOOL enableTrace;

  // Similarity parameters
  id <String> similarityMeasure; // metric (global sd, etc)
  id <String> nominalProfile; // profile to use as reference data
  id <String> nominalProfileColumnLabel; // used to determine a particular drug as reference when nominalProfile=dat 
  id <String> experimentalProfile; // profile to compare against ref data.

  id <ActionGroup> guiActions;
  id <ActionGroup> obsActions;
  id <ActionGroup> initActions;
  id <ActionGroup> endActions;
  id <Schedule> stepSchedule;
  id <Schedule> experSchedule;                  
  id <Schedule> experInitSchedule;

  CSVDatModel *datModel;             
  BOOL rerunDM;
  BOOL interpDatModel;
  const char * datModelFileName;

  RefModel *refModel;            
  BOOL rerunRM;

  ArtModel *artModel;
  BOOL startNewLogDir;
  const char *artGraphFileName;      // explicit graph
  const char *lobuleSpecFileName;  // graph parameters                  
  id <List> paramFileList;
  id <ListIndex> paramFileNdx;
  id <String> pname; // a file name having all input parameters
  id <LispArchiver> pmArchiver;

  ParameterManager *parameterManager;

  // run-time indices indicating each model's current state
  id pmNdx;
  id <Map> datCurrentPoint;
  id <Map> refCurrentPoint;
  id <Map> artCurrentPoint;

  // Display objects, widgets, etc.
  id <Archiver> archiver;            

  BOOL guiOn;

  BOOL showLiveData;
  id <LogPlotter> resultGraph;
  id <GraphElement> datModelE;
  id <GraphElement> refModelE;
  id <GraphElement> artModelE;

  id <LogPlotter> dosageGraph;
  id <GraphElement> dosageE;

  BOOL showLiveAgg;
  id <LogPlotter> aggLiveGraph;   // to hold aggregate, live data
  id <Map> datElements;
  id <Map> refElements;
  id <Map> artElements;

  id <LogPlotter> endDataGraph;

  id <ProbeMap> datProbeMap;
  id <ProbeMap> refProbeMap;
  id <ProbeMap> artProbeMap;

  // stolen from GUISwarm
  id <ControlPanel> controlPanel;
  id <ActionCache> actionCache;
  const char *baseWindowGeometryRecordName;
  BOOL saveSizeFlag;

}

// runtine methods
- buildModel;
- stepModel: (id <Swarm>) model;
- contModels;
- stopExperiment;
- computeSimilarity: (id <Map>)aMap refMap: (id <Map>)rMap datMap: (id <Map>)dMap;

// observation methods
- showStats;
- doStats;
- buildRunDataViews;
- buildExperDataViews;
- buildEndDataViewOf: (id <Map>) outData maskedBy: (id <Map>) mask; 
- logExperiment;
- (BOOL) interpolateDatModel;

// accessors
- (unsigned) getModelCycle;
- (double) getModelTime;
- (id) getArtModel;
- (id <LiverDMM>) getDMM;
- (id <LispArchiver>) getPMArchiver;
- (unsigned) getRunNumber;

// construction methods
- setGUIMode: (BOOL) gui;
+ createBegin: aZone;
- (void) buildProbeMap;
- (void) setParamFileList: (id <List>) pl;
- buildObjects;
- buildObjects: (id <String>) pf;
- (BOOL) initPM;
- (BOOL) initPM: (id <String>) pf;
- mcSetInit;
- buildActions;
- activateIn: swarmContext;

- setParamDir: (id <String>) dir;
- setRNG: (id <SplitRandomGenerator>) r;

- setSimilarityMeasure: (char *) sm;
- setNominalProfile: (char *) nomProf;
- setNominalProfileColumnLabel: (char *) nomProfCol;
- setExperimentalProfile: (char *) ep;

- setMonteCarloRuns: (unsigned) nr;
- setShowLiveData: (BOOL) show;
- setShowLiveAgg: (BOOL) show;
- resetPMNdx;

- (double) getSimilarity;
- (void) setSimilarity: (double) s;

// model-specific construction methods
- setInterpDatModel: (BOOL) idm;
- setDatModelFileName: (const char *) s;
- setArtGraphFileName: (const char *) s;
- setArtGraphSpecFileName: (const char *) s;

// utility methods
- _resultGraphDeath_;
- _dosageGraphDeath_;
- _endDataGraphDeath_;
- cleanup;

// stolen from GUISwarm
- setWindowGeometryRecordName: (const char *)windowGeometryRecordName;
- setSaveSizeFlag: (BOOL)saveSizeFlag;
- setWindowGeometryRecordNameForComponent: (const char *)componentName
                                   widget: aWidget;
- (id <ActionCache>)getActionCache;
- (id <ControlPanel>)getControlPanel;
- go;

- (void) setDisplayLevel: (int) level;
- (void) enableSoluteTrace: (BOOL) trace;
- setSimilarityBandCoefficient: (double) val;
@end
