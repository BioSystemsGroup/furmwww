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
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <assert.h>

#import <float.h>
#import <math.h> // for isnan()

#import <activity.h>
#import <collections.h>

#import <graph/graph.h>
#import "artModel/FlowLink.h"
#import <modelUtils.h>
#import "artModel/Hepatocyte.h"   // for initialization
#import "artModel/SoluteTag.h"

#import "LiverDMM.h"

#import "ArtModel.h"
@implementation ArtModel  

// runtime methods

- step
{
   unsigned ndx=0U;
   unsigned inputPrior=0U, outputPrior=0U, bilePrior=0U;
   id <Map> inPriorMap=nil, outPriorMap=nil;

   // reset these counters to sum over stepsPerCycle
   inputCount = 0U;
   outputCount = 0U;
   bileFlux = 0U;

   [Telem debugOut: 3
          printf: "%s::step -- Begin -- artScratchZone: %d, globlaZone: %d\n",
          [[self class] getName],
          [[artScratchZone getPopulation] getCount], 
          [[globalZone getPopulation] getCount]];

   for ( ndx=0U; ndx<stepsPerCycle ; ndx++ ) {
     currentStep = ndx;
     id <Symbol> status = [[self getActivity] getStatus];
     if (status != Completed && status != Terminated) {

       if (soluteInCount != nil) {
         [soluteInCount drop]; 
         soluteInCount = nil;
       }
       inputPrior = inputCount;

       if (soluteOutCount != nil) {
         [soluteOutCount drop]; 
         soluteOutCount = nil;
       }
       outputPrior = outputCount;

       bilePrior = hepaticVein->bileFlux;


       //       (strcmp(swarm_version,"2.1.1") == 0 ? 
       //        [[self getActivity] next] :
       //        [[self getActivity] nextAction]);
       [Telem debugOut: 1 printf: "ArtModel activity getStatus => %s\n",
              [[[self getActivity] getStatus] getName]];
       [[self getActivity] nextAction];

       [StatCalculator addDataPoint: inPriorMap to: soluteInCount];
       if (inPriorMap != nil) {
         [inPriorMap deleteAll]; [inPriorMap drop]; inPriorMap = nil;
       }
       inputCount += inputPrior;

       // deep copy inPriorMap
       if (soluteInCount != nil) {
         id <Integer> val=nil;
         id <SoluteTag> key=nil;
         inPriorMap = [Map create: self];
         id <MapIndex> cpNdx = [soluteInCount mapBegin: artScratchZone];
         while (([cpNdx getLoc] != End)
                && ( (val = [cpNdx next: &key]) != nil) ) {
           [inPriorMap at: key insert: [self copyIVars: val]];
         }
	 			[cpNdx drop];
       } // deep copy clause


       [StatCalculator addDataPoint: outPriorMap to: soluteOutCount];
       if (outPriorMap != nil) {
         [outPriorMap deleteAll]; [outPriorMap drop]; outPriorMap = nil;
       }
       outputCount += outputPrior;

       // deep copy outPriorMap
       if (soluteOutCount != nil) {
         id <Integer> val=nil;
         id <SoluteTag> key=nil;
         outPriorMap = [Map create: self];
         id <MapIndex> cpNdx = [soluteOutCount mapBegin: artScratchZone];
         while (([cpNdx getLoc] != End)
                && ( (val = [cpNdx next: &key]) != nil) ) {
           [outPriorMap at: key insert: [self copyIVars: val]];
         }
         [cpNdx drop];
       } // deep copy clause

       bileFlux =  hepaticVein->bileFlux + bilePrior;

     } // end if (status != Completed && status != Terminated) {
   } // end for ( ndx=0U; ndx<stepsPerCycle ; ndx++ ) {

  cycle++;

  [Telem debugOut: 3
         printf: "%s::step -- End -- artScratchZone: %d, globlaZone: %d\n",
         [[self class] getName],
         [[artScratchZone getPopulation] getCount], 
         [[globalZone getPopulation] getCount]];

  return self;
}

- checkToStop {
  // stopping criterion
  if (cycle > cycleLimit)
	{
		//
		// write the summary information on each monte carlo run to "summary.txt"
		// including totalNumberOfSoluteCreated
		//
		if(enableTrace) {
			id <String> summary = [bdir copy: artScratchZone];
			[summary catC: DIR_SEPARATOR];
			[summary catC: "summary.txt"];
			FILE *fp = fopen([summary getC], "w");
			totalNumberOfSolutes = portalVein->totalSoluteCreated;
			fprintf(fp, "totalNumberOfSoluteCreated %u\n", totalNumberOfSolutes);
			fprintf(fp, "fineResolution %f\n", 1.0/(stepsPerCycle*stepsPerCycle)); // bug ?
			fprintf(fp, "coarseResolution %f\n", 1.0/stepsPerCycle);
			fclose(fp);
		}

		if(enableTrace) {
			// create a file for traced results of the retired solutes
			[self writeTracedRetiredSolutes];
			// create a file for traced results of the metabolized solutes
			[self writeTracedMetabolizedSolutes];
			// close all opened files
			if(sfp != NULL) fclose(sfp); 
			if(dfp != NULL) fclose(dfp);
			if(ofp != NULL) fclose(ofp);
			id <ListIndex> nNdx = [[graph getNodeList] listBegin: artScratchZone];
			id node = nil;
			while (([nNdx getLoc] != End) && ((node = [nNdx next]) != nil)) {
				[node closeFileDescriptor];
				if([node isKindOf: [Sinusoid class]]) [(Sinusoid *)node closeMetFileDescriptor];
			}
			[nNdx drop];
		}
    [[self getActivity] terminate];
	}

  if (abmDetails >= 1) {
    [Telem monitorOut: 1 print: "\n=============== End ABM Details =================\n\n"];
  }

  return self;
}

- (unsigned) getTotalNumberOfSolutesCreated
{
	return totalNumberOfSolutes;
}

- bolus
{
  unsigned dose=0U;
  unsigned arg=0U;
  arg = cycle;
	//
	// Note: arg < dosageEndTime  prevents new injection starting from dosageEntTime
	//
//  if (arg >= 0U && arg < dosageEndTime) { // create new dose until dosageEndTime
  if (arg >= 0U) { 
    dose = [bolus dosage: arg];
  } else {
    dose = 0U;
  }
  [portalVein setSoluteFlux: dose withContents: bolusContents];

  if ((abmDetails >= 1) && (dose > 0) ) {
    [Telem monitorOut: 1 printf: "\n\tBolus (cycle %d) ==> ", cycle];
    [Telem monitorOut: 1 printf: " dosage(%d) = %d\n", arg, dose];
  }

  return self;
}

// observation methods

- printResults
{

  [Telem monitorOut: 1 print: "\n"];
  [Telem monitorOut: 1 printf: "%s:  %f (", [self getName], [self getTime]];

  id <SoluteTag> key=nil;
  id <Integer> val=nil;
  if (soluteInCount != nil) {
    id <MapIndex> ndx = [soluteInCount mapBegin: artScratchZone];
    while (([ndx getLoc] != End)
	   && ( (val = [ndx next: &key]) != nil) ) {
      [Telem monitorOut: 1 printf: " %sIn: %d ", [key getName], [val getInt]];
    }
    [ndx drop];
  }

  [Telem monitorOut: 1 printf: ") totalIn = %d  (",inputCount];

  if (soluteOutCount != nil) {
    id <MapIndex> ndx = [soluteOutCount mapBegin: artScratchZone];
    while (([ndx getLoc] != End)
	   && ( (val = [ndx next: &key]) != nil) ) {
      [Telem monitorOut: 1 printf: " %sOut: %d ", [key getName], [val getInt]];
    }
    [ndx drop];
  }
  [Telem monitorOut: 1 printf: ") totalOut = %d -- total out fract = %g\n",
         outputCount, [self getOutputFraction]];

  // repeat for debug output
  [Telem debugOut: 1 print: "\n"];
  [Telem debugOut: 1 printf: "%s:  %f (", [self getName], [self getTime]];

  if (soluteInCount != nil) {
    id <MapIndex> ndx = [soluteInCount mapBegin: artScratchZone];
    while (([ndx getLoc] != End)
	   && ( (val = [ndx next: &key]) != nil) ) {
      [Telem debugOut: 1 printf: " %sIn: %d ", [key getName], [val getInt]];
    }
    [ndx drop];
  }

  [Telem debugOut: 1 printf: ") totalIn = %d  (",inputCount];

  if (soluteOutCount != nil) {
    id <MapIndex> ndx = [soluteOutCount mapBegin: artScratchZone];
    while (([ndx getLoc] != End)
	   && ( (val = [ndx next: &key]) != nil) ) {
      [Telem debugOut: 1 printf: " %sOut: %d ", [key getName], [val getInt]];
    }
    [ndx drop];
  }
  [Telem debugOut: 1 printf: ") totalOut = %d -- total out fract = %g\n",
         outputCount, [self getOutputFraction]];



  if (abmDetails >= 1) {
    [Telem monitorOut: 1 print: "\n============= Begin ABM Details =================\n\n"];

    // report on the sinusoidal structure and contents
    [Telem monitorOut: 1 describe: portalVein withDetail: abmDetails];
    [Telem monitorOut: 1 describe: graph withDetail: abmDetails];
    [Telem monitorOut: 1 describe: hepaticVein withDetail: abmDetails];

    { // report on the intra-cellular concentrations
      id <Map> ecConc = [Map create: artScratchZone];
      id <Map> hepConc = [Map create: artScratchZone];
      id <List> graphNodes = [graph getNodeList];
      id <ListIndex> nNdx = [graphNodes listBegin: artScratchZone];
      id node = nil;
      int listNum=0;
      while ( ([nNdx getLoc] != End)
              && ( (node = [nNdx next]) != nil) ) {
        if ([node isKindOf: [Sinusoid class]] ) {
          for ( listNum=0 ; listNum<2 ; listNum++ ) {
            Sinusoid *sin = node;
            id <List> list = nil;
            id <Map> coll = nil;

            if (listNum == 0) {
              list = sin->eCells;
              coll = ecConc;
            }
            if (listNum == 1) {
              list = sin->hepatocytes;
              coll = hepConc;
            }

            id <ListIndex> ndx = [list listBegin: artScratchZone];
            id <ContainerObj> cell = nil;
            while ( ([ndx getLoc] != End)
                    && ( (cell = [ndx next]) != nil) ) {
              id <Map> chemMap = [cell countMobileObjects: artScratchZone];
              if (chemMap != nil) {
                id <MapIndex> chemNdx = [chemMap mapBegin: artScratchZone];
                id <Integer> num = nil;
                id <Symbol> type = nil;
                while ( ([chemNdx getLoc] != End)
                        && ( (num = [chemNdx next: &type]) != nil) ) {
                  if ([coll containsKey: type]) {
                    id <Integer> prevNum = [coll at: type];
                    int prevNum_value = [prevNum getInt];
                    int newNum = prevNum_value + [num getInt];
                    [prevNum setInt: newNum];
                  } else {
                    [coll at: type insert: [artScratchZone copyIVars: num]];
                  }
                }
                [chemNdx drop];
		[chemMap deleteAll];
		[chemMap drop];
              } // else this cell has no solute
            }
            [ndx drop];
          } // end loop over cell types
        } // if its not an SS skip it
      } // end loop over nodeList
      [nNdx drop];

      // print it out
      for ( listNum=0 ; listNum<2 ; listNum++ ) {
        id <Map> map = nil;
        id <MapIndex> ndx = nil;
        id <Integer> num = nil;
        id <Symbol> type = nil;
        if (listNum == 0) {
          [Telem monitorOut: 1 printf: "\n@@@ ECells contain ("];
          map = ecConc;
        }
        if (listNum == 1) {
          [Telem monitorOut: 1 printf: "@@@ Hepatocytes contain ("];
          map = hepConc;
        }
        ndx = [map mapBegin: artScratchZone];
        if ([ndx getLoc] != End) num = [ndx next: &type];
        if (num != nil && type != nil)
          [Telem monitorOut: 1 printf: "%s: %d", [type getName], [num getInt]];
        while ( ([ndx getLoc] != End)
                && ( (num = [ndx next: &type]) != nil) ) {
          [Telem monitorOut: 1 printf: ", %s: %d", 
                 [type getName], [num getInt]];
        }
        [ndx drop];

        [Telem monitorOut: 1 print: ")\n"];

        [map deleteAll];
        [map drop];
      }
    }
  } // end abmDetails

  fflush(0);

  return self;
}

- writeTracedRetiredSolutes
{
		id <String> retired = [bdir copy:artScratchZone];
		[retired catC: DIR_SEPARATOR];
		[retired catC: "retiredSolutes.txt"];
		FILE *fp = fopen([retired getC], "w");
		id <MapIndex> mNdx = [retiredSoluteMap mapBegin:artScratchZone];
		id retiredSolute;
		id <Double> time;
		fprintf(fp,"SoluteID RetiredTime SoluteType\n");
		while (([mNdx getLoc] != End) && ((time = [mNdx next: &retiredSolute]) != nil))
			fprintf(fp, "%u %f %s\n",[retiredSolute getNumber], [time getDouble], [[retiredSolute getType] getName]);
		[retiredSoluteMap removeAll];
		retiredSoluteMap = [Map create:artScratchZone];
		fclose(fp);
		return self;
}

- writeTracedMetabolizedSolutes
{
		id <Map> metabolizedSoluteMap = [[[Map createBegin:artScratchZone] setCompareFunction:(compare_t)double_compare] createEnd];
  	id <String> mdir = [bdir copy: scratchZone];
  	[mdir catC: DIR_SEPARATOR];
  	[mdir catC: "metabolized"];
  	id <List> metFileList = [DMM getFileList:mdir pattern:"*.met"];
		if(metFileList == nil) return self;

		id <ListIndex> lNdx = [metFileList listBegin:artScratchZone];
		id <String> fn = nil;
		id <List> tuple = nil;
		FILE *fp = NULL;
		while(([lNdx getLoc] != End) && ((fn = [lNdx next]) != nil)) {
			fp = fopen([fn getC], "r");
			if(fp == NULL) {
				fprintf(stderr, "can't read the file %s\n", [fn getC]); fflush(stdout);
				[_parent terminate];
			}
			char line[1024];
			if(fgets(line,1024, fp) == NULL) return self; // skip the header
			while(fgets(line,1024, fp)) {
				id <Integer> sid = [Integer create:artScratchZone setInt:atoi(strtok(line, " "))]; //  the first token "SoluteID"
				id <Double> time = [Double create:artScratchZone setDouble:atof(strtok(NULL, " "))]; //  the second token "Time"
				id <String> stype = [String create:artScratchZone setC:(strtok(NULL, " "))]; // the third token "SoluteType"
				tuple = [List create:scratchZone];
				[tuple addLast:sid]; [tuple addLast:time]; [tuple addLast:stype];	
				if([metabolizedSoluteMap at:time] == nil)
					[metabolizedSoluteMap at:time insert:[List create:artScratchZone]];
				[[metabolizedSoluteMap at:time] addLast:tuple]; 
			}
			fclose(fp);
		}

		id <String> metabolized = [bdir copy:artScratchZone];
		[metabolized catC: DIR_SEPARATOR];
		[metabolized catC: "metabolizedSolutes.txt"];
		FILE *mfp = fopen([metabolized getC], "w");
		id <MapIndex> mNdx = [metabolizedSoluteMap mapBegin:artScratchZone];
		id <List> tList = nil;
		while(([mNdx getLoc] != End) && ((tList = [mNdx next]) != nil)) {
			lNdx = [tList listBegin:artScratchZone];
			while(([lNdx getLoc] != End) && ((tuple = [lNdx next]) != nil)) 
				fprintf(mfp, "%d %f %s", [[tuple atOffset:0] getInt], [[tuple atOffset:1] getDouble], [[tuple atOffset:2] getC]);	
		}
		fclose(mfp);
		[lNdx drop];
		[mNdx drop];
		return self;
}

// trace all solutes in each vas 
- traceSolutes
{ 
	unsigned iter = cycle * stepsPerCycle + currentStep; 
	char msg[2048];
	sprintf(msg, "saving info. for tracing analysis... Iter: %d "
					"=> cycle: %u, currentStep: %u, time: %f, timeInFinRes: %f",
					iter, cycle, currentStep, [self getTime], [self getTimeInFineResolution]);
//	[_parent showMessage:msg];

	// trace cleared solutes
		id <Map> clearedSoluteMap = [hepaticVein getFlux];
	if(clearedSoluteMap != nil) {
		id <MapIndex> mNdx = [clearedSoluteMap mapBegin: artScratchZone];
		id <SoluteTag> key = nil;
		id <Integer> val = nil;
		while(([mNdx getLoc] != End) && ((val = [mNdx next:&key]) != nil)) {
		 	fprintf(ofp, "%d %f %s\n", [val getInt], [self getTimeInFineResolution], [key getName]);
		}
	}

	// trace internal activities of each node
	id <List> graphNodes = [graph getNodeList];
	id <ListIndex> nNdx = [graphNodes listBegin: artScratchZone];
	id node = nil;
	Solute* solute = nil;
	Vector2d *loc = nil;
	while (([nNdx getLoc] != End) && ((node = [nNdx next]) != nil)) {
		FILE *fp = [node getFileDescriptor]; 
		if([node isKindOf: [Sinusoid class]]) {
			Sinusoid *sinusoid = (Sinusoid *) node;
			FILE *mfp = [sinusoid getMetFileDescriptor]; 
			// collect metabolized solute info. from each sinusoid
			id <List> metabolizedSoluteList = [sinusoid getMetabolizedSoluteList];
			if(metabolizedSoluteList != nil) {
				id <ListIndex> lNdx = [metabolizedSoluteList listBegin: artScratchZone];
				id <Pair> pair = nil;
				while(([lNdx getLoc] != End) && ((pair = [lNdx next]) != nil))
					fprintf(mfp,"%d %f %s\n",[[pair getSecond] getInt], [self getTimeInFineResolution], [[pair getFirst] getName]);
				[sinusoid clearMetabolizedSoluteList];			
			}

			// inspect all three spaces of the sinusoid
			SinusoidalSpace *ss = sinusoid->sSpace;
			ESpace *es = sinusoid->eSpace;
			DisseSpace *ds = sinusoid->sod;
			id <Array> hc = ss->core->tube;

			id <List> slist = [List create: artScratchZone];
			[slist addLast: ss];
			[slist addLast: es];
			[slist addLast: ds];
			FlowSpace* space = nil;
			id <ListIndex> sNdx  = [slist listBegin: artScratchZone];
			while(([sNdx getLoc] != End) && ((space = [sNdx next]) != nil))
			{
				// For freely mobile solutes in a space
				id<Map> aMap = space->mobileObjMap;
				id <MapIndex> ndx = [aMap mapBegin: artScratchZone];
				while(([ndx getLoc] != End) && ((loc = [ndx next: &solute]) != nil))
				{
					fprintf(fp, "%u, %u, %f, %f, %s, %u, %s, %s, %u, %u, %s, (%d:%d)\n", 
						iter, cycle, [self getTime], [self getTimeInFineResolution], // simulation time info.
						[sinusoid getNodeLabel], [sinusoid getLength], [[space class] getName], "NA", [aMap getCount],  // sinusoid info.
						[solute getNumber], [[solute getType] getName], [loc getX], [loc getY]); // solute info.
				}
				// For solutes trapped in container objects of the space
				aMap = space->containerObjMap;
				ndx = [aMap mapBegin: artScratchZone];
				id cobj = nil; // ContainerObj 
				while(([ndx getLoc] != End) && ((loc = [ndx next: &cobj]) != nil))
				{
					if([cobj isKindOf: [Cell class]]) {  
						// For solutes in a ECell or a Hepatocyte
						Cell *cell = (Cell *) cobj;
						id <ListIndex> cNdx = [cell->unboundSolute listBegin: artScratchZone];
						while(([cNdx getLoc] != End) && ((solute = [cNdx next]) != nil))
						{
							fprintf(fp, "%u, %u, %f, %f, %s, %u, %s, +%s+, %u, %u, %s, (%d:%d)\n", 
								iter, cycle, [self getTime], [self getTimeInFineResolution], // simulation time info.
								[sinusoid getNodeLabel], [sinusoid getLength], [[space class] getName], [cobj getName], [cell->unboundSolute getCount],  // sinusoid info.
								[solute getNumber], [[solute getType] getName], [loc getX], [loc getY]); // solute info.
						}
						[cNdx drop];
						// For boound solutes with a Binder or a Enzyme
						id <ListIndex> bNdx = [cell->binders listBegin: artScratchZone];
						Binder *binder = nil;
						while(([bNdx getLoc] != End) && ((binder = [bNdx next]) != nil))
						{
							solute = [binder getAttachedSolute];
							if(solute != nil) {
								fprintf(fp, "%u, %u, %f, %f, %s, %u, %s, -%s-, %u, %u, %s, (%d:%d)\n",
									iter, cycle, [self getTime], [self getTimeInFineResolution], // simulation time info.
									[sinusoid getNodeLabel], [sinusoid getLength], [[space class] getName], [binder getName], [cell->binders getCount],  // sinusoid info.
									[solute getNumber], [[solute getType] getName], [loc getX], [loc getY]); // solute info.
							}
						}
						[bNdx drop];
					} else {
						// For solutes in an unknown container object of the space
						solute = [cobj getMobileObject]; // id <ContainerObj> obj
						if(solute != nil) {
							fprintf(fp, "%u, %u, %f, %f, %s, %u, %s, *%s*, %u, %u, %s, (%d:%d)\n",
								iter, cycle, [self getTime], [self getTimeInFineResolution], // simulation time info.
								[sinusoid getNodeLabel], [sinusoid getLength], [[space class] getName], [cobj getName], [aMap getCount],  // sinusoid info.
								[solute getNumber], [[solute getType] getName], [loc getX], [loc getY]); // solute info.
						}
					}
				}
				[ndx drop];
			}
			[slist drop];
			[sNdx drop];

			// For solutes in Hepatic Core
			id <Index> hNdx = [hc begin: artScratchZone];
			id <List> list = nil;
			loc = [Vector2d create: scratchZone dim1: 0 dim2: 0]; // no coordination info available in Core now
			while(([hNdx getLoc] != End) && ((list = [hNdx next]) != nil))
			{
				id <ListIndex> lNdx = [list listBegin: artScratchZone];
				while(([lNdx getLoc] != End) && ((solute = [lNdx next]) != nil))
				{
//				loc = [ss->corePos atOffset: [hNdx getOffset]];
//				loc = [space getPosOfObject: solute];  //temporary assignment SW
					fprintf(fp, "%u, %u, %f, %f, %s, %u, %s, %s, %u, %u, %s, (%d:%d)\n",
						iter, cycle, [self getTime], [self getTimeInFineResolution], // simulation time info.
						[sinusoid getNodeLabel], [sinusoid getLength], "Core", "NA", [ss->core->tube getCount],  // sinusoid info.
						[solute getNumber], [[solute getType] getName], [loc getX], [loc getY]); // solute info.
				}
				[lNdx drop];
			}
			[hNdx drop];
		} else { // if node is either PV or CV
			id <ListIndex> lNdx;
			if (strcmp([node getNodeLabel], "portalVein") == 0) {
//				id <List> graphNodes = [graph getNodeList];
				id <List> createdSolutes = [node getCreatedSolutes];
				if (createdSolutes != nil) {
					if(sfp == NULL) {
						id <String> soluteListFile = [bdir copy: artScratchZone];
						[soluteListFile catC: DIR_SEPARATOR];
						[soluteListFile catC: "injectedSolutes.txt"];
						sfp = fopen([soluteListFile getC], "w");
						fprintf(sfp,"SoluteID InjectedTime SoluteType\n");
						id <String> dosageListFile = [bdir copy: artScratchZone];
						[dosageListFile catC: DIR_SEPARATOR];
						[dosageListFile catC: "dosage.txt"];
						dfp = fopen([dosageListFile getC], "w");
						fprintf(dfp,"timeInFineRes InjectedTime\n");
						id <String> clearedSoluteListFile = [bdir copy: artScratchZone];
						[clearedSoluteListFile catC: DIR_SEPARATOR];
						[clearedSoluteListFile catC: "clearedSolutes.txt"];
						ofp = fopen([clearedSoluteListFile getC], "w");
						fprintf(ofp,"SoluteID Time SoluteType\n");
					}
					if([createdSolutes getCount] > 0) {
						fprintf(dfp, "%f %u\n", [self getTimeInFineResolution], [createdSolutes getCount]);
						lNdx = [createdSolutes listBegin: artScratchZone];
						while(([lNdx getLoc] != End) && ((solute = [lNdx next]) != nil)) {
							fprintf(sfp,"%u %f %s\n",[solute getNumber], [self getTimeInFineResolution], [[solute getType] getName]);
						}
					}
				}
			}
			id <List> solutes = [node getSolutes];
			loc = [Vector2d create: scratchZone dim1: 0 dim2: 0]; // no coordination info available in PV and CV now
			if([solutes getCount] != 0) {
				lNdx = [solutes listBegin: artScratchZone];
				while(([lNdx getLoc] != End) && ((solute = [lNdx next]) != nil)) {
					fprintf(fp, "%u, %u, %f, %f, %s, %u, %s, %s, %u, %u, %s, (%d:%d)\n",
						iter, cycle, [self getTime], [self getTimeInFineResolution], // simulation time info.
						[node getNodeLabel], 0, "NA", "NA", [solutes getCount],  // node info.
						[solute getNumber], [[solute getType] getName], [loc getX], [loc getY]); // solute info.
				}
				[lNdx drop];
			} else {
				fprintf(fp, "%u, %u, %f, %f, %s, %u, %s, %s, %u, %u, %s, (%d:%d)\n",
					iter, cycle, [self getTime], [self getTimeInFineResolution], // simulation time info.
					[node getNodeLabel], 0, "NA", "NA", 0,  // node info.
					-1, "NA", [loc getX], [loc getY]); // solute info.
			}

			//  For retired solutes
			id <List> lst = [node getRetiredSolutes];
			if(lst != nil) {
				id <ListIndex> Ndx = [lst listBegin: artScratchZone];
				while(([Ndx getLoc] != End) && ((solute = [Ndx next]) != nil))
				{
					if([retiredSoluteMap at:solute] == nil)
						[retiredSoluteMap at:solute insert:[Double create:artScratchZone setDouble:[self getTimeInFineResolution]]];
/*
					fprintf(fp, "%u, %u, %f, %f, %s, %u, %s, %s, %u, %ld, %s, (%d:%d)\n",
						iter, cycle, [self getTime], [self getTimeInFineResolution], // simulation time info.
						[node getNodeLabel], 0, "Retired", "NA", [solutes getCount],  // node info.
						[solute getNumber], [[solute getType] getName], [loc getX], [loc getY]); // solute info.
*/
				}
				[Ndx drop];
			}
		}
	}
	[nNdx drop];

	return self;
}

/**
 * [ArtModel -measure: (LiverNode *)] returns a map <SoluteTag,
 * Integer> of the constituents in that Vas.
 */
- (id <Map>) measure: (LiverNode *) ln
{
  id <Map> retVal = nil;
  if ([ln isKindOf: [Sinusoid class]] || [ln isKindOf: [Vas class]]) {
    retVal = [DMM countConstituents: ln->solutes createIn: artScratchZone];
  } else {
    raiseEvent(InvalidArgument, 
               "No %s(%p)-specific measures are defined.\n",
               [[ln getClass] getName], ln);
  }
  return retVal;
}

/**
 * [ArtModel -measureVasaFlux] prepares the data to be accessed by the
 * ExperAgent via [ArtModel -getOutputs].  This is the core method for
 * the inter-model outflow profile measure.
 */
- (id) measureVasaFlux
{
  id <Map> input=nil, output=nil;
  id <Integer> intObj=nil;

  input = [portalVein getFlux];
  output = [hepaticVein getFlux];

  /*
   * first assemble the inputs
   */

  [Telem debugOut: 4 printf: "%s::measureVasaFlux -- \n\t",
         [[self class] getName]];

  inputCount = 0U;
  id <MapIndex> bcNdx = [bolusContents mapBegin: artScratchZone];
  id val=nil;
  id <SoluteTag> key = nil;
  while (( [bcNdx getLoc] != End)
         && ( (val = [bcNdx next: &key]) != nil) ) {
    if (input != nil) intObj = [input at: key];
    if (intObj != nil) {
      if (soluteInCount == nil) soluteInCount = [Map create: self];
      [Telem debugOut: 4 printf: "\tXXXX intObj (%s:%p) = %d\n",
             [[intObj getClass] getName], intObj, [intObj getInt]];
      [soluteInCount at: key insert: intObj];
      inputCount += [intObj getInt];

      [Telem debugOut: 4 printf: "%s-in = %d, ", [key getName], 
             [intObj getInt]];

      intObj = nil;
    }
  }
  // don't drop bcNdx yet

  [Telem debugOut: 4 print: "\n\t"];

  /*
   * now assemble the outputs
   */

  outputCount = 0U;
  [bcNdx setLoc: Start];
  while (( [bcNdx getLoc] != End)
         && ( (val = [bcNdx next: &key]) != nil) ) {
    if (output != nil) intObj = [output at: key];
    if (intObj != nil) {
      if (soluteOutCount == nil) soluteOutCount = [Map create: self];
      [soluteOutCount at: key insert: intObj];
      outputCount += [intObj getInt];

      [Telem debugOut: 4 printf: "%s-out = %d, ", [key getName], [intObj getInt]];

      intObj = nil;
    }
  }
  [bcNdx drop];

  { // debug clause
    [Telem debugOut: 4 printf: "\n\tinputCount = %d, outputCount = %d\n", 
           inputCount, outputCount];

    [Telem debugOut: 4 printf: "%s::measureVasaFlux -- |soluteInCount| = %d\n",
           [[self class] getName], 
	   (soluteInCount != nil ? [soluteInCount getCount] : -1)];
    if (soluteInCount != nil) {
      id <MapIndex> sNdx = [soluteInCount mapBegin: artScratchZone];
      while (([sNdx getLoc] != End)
	     && ( (val = [sNdx next: &key])!= nil) ) {
	[Telem debugOut: 4 printf: "\tkey = %s (%s:%p) val = %d (%s:%p)\n",
	       [key getName], [[key getClass] getName], key, 
	       [val getInt], [[val getClass] getName], val];
      }
      [sNdx drop];
    }

    [Telem debugOut: 4 printf: "%s::measureVasaFlux -- |soluteOutCount| = %d\n",
	   [[self class] getName], 
	   (soluteOutCount != nil ? [soluteOutCount getCount] : -1)];
    if (soluteOutCount != nil) {
      id <MapIndex> sNdx = [soluteOutCount mapBegin: artScratchZone];
      while (([sNdx getLoc] != End)
	     && ( (val = [sNdx next: &key])!= nil) ) {
	[Telem debugOut: 4 printf: "\tkey = %s (%s:%p) val = %d (%s:%p)\n",
	       [key getName], [[key getClass] getName], key, 
	       [val getInt], [[val getClass] getName], val];
      }
      [sNdx drop];
    }
  } // debug clause

  return self;
}

- (double) getOutputFraction
{
  double of = soluteScale * (((double)outputCount)/((double)totalSoluteMassEst));

  [Telem debugOut: 3 printf: "ArtModel::getOutputFraction -- soluteScale = %lf, outputCount = %d, totalSoluteMassEst = %d, of = %lf\n", soluteScale, outputCount, totalSoluteMassEst, of];

  return (isnan(of) ? 0.F : of);
}
/*
 * provides # of bile objects / total solute injected
 */
- (double) getBileOutputFraction
{
  double bileOF = soluteScale * ((double)bileFlux)/((double)totalSoluteMassEst);
  [Telem debugOut: 6 printf: "[%s(%p) -getBileOutputFraction] -- "
	 "bileFlux = %d, totalSoluteMassEst = %d, bileOF = %lf\n",
	 [[self getClass] getName], self, bileFlux, totalSoluteMassEst, bileOF];
  return bileOF;
}

- (id <List>) getOutputNames
{
  return outLabels;
}

/**
 * [ArtModel -getOutputs] provides the primary measure data to the
 * ExperAgent.  This method _must_ have analogs in the other models.
 */
- (id <Map>) getOutputs
{
  [Telem debugOut: 3 printf: "%s::getOutputs -- enter\n", [[self class] getName]];

  id <Map> newOuts = [Map create: globalZone];
	
  // install the time
  [newOuts at: [String create: globalZone setC: "Time"] 
           insert: [Double create: globalZone
                           setDouble: [self getTime]]];
  // install the overall total
  [newOuts at: [String create: globalZone setC: "Total"]
           insert: [Double create: globalZone
                           setDouble: [self getOutputFraction]]];

  // install the solute-specific fractions
  id <SoluteTag> key=nil;
  id <Integer> val=nil;
  id <MapIndex> bcNdx = [bolusContents mapBegin: artScratchZone];
  while (([bcNdx getLoc] != End)
         && ( (val = [bcNdx next: &key]) != nil) ) {
    unsigned outCount = 0U;
    Integer *outCountInt = nil;
    if (soluteOutCount != nil && (outCountInt = [soluteOutCount at: key]) != nil)
       outCount = [outCountInt getInt];
    unsigned totalEst = [[soluteMassEst at: key] getInt];
    double outFract = soluteScale * ((double)outCount)/((double)totalEst);
    [newOuts at: [String create: globalZone setC: [key getName]]
             insert: [Double create: globalZone setDouble: outFract]];

    [Telem debugOut: 4
           printf: "%s::getOutputs -- %s at time = %lf: "
           "totalEst = %d, outCount = %d, soluteScale = %lf, outFract = %lf\n",
           [[self class] getName], [key getName], [self getTime], 
           totalEst, outCount, soluteScale, outFract];
    if (soluteOutCount != nil) {
       if ([soluteOutCount at: key] != nil) {
          [Telem debugOut: 4 printf: "\t|soluteOutCount| = %d, "
                 "[soluteOutCount at: key] = %d (%s:%p)\n",
                 [soluteOutCount getCount], [[soluteOutCount at: key] getInt], 
                 [[[soluteOutCount at: key] class] getName], [soluteOutCount at: key]];
       } else {
          [Telem debugOut: 4 printf: "\tNo %s in soluteOutCount\n", [key getName]];
       }
    } else
      [Telem debugOut: 4 printf: "\t|soluteOutCount| = nil\n"];

  }
  [bcNdx drop];

  [Telem debugOut: 3 printf: "%s::getOutputs -- exit\n", [[self class] getName]];
  
  return newOuts;
}


/**
 * [ArtModel -snap] takes a PNG snapshot of the SS solute contents.
 */
- (void) snap
{
  // walk the vasgraph to snap the SSes
  [graph writeToPNG: [_parent getDMM]];
}

/**
 * [ArtModel -writeSSConstituents] implements the intra-model measures
 * that do not have analogs in the other models (Ref and Dat).  This
 * method is a sibling to [ArtModel -measureVasaFlux], which prepares
 * the data accessed via [ArtModel -getOutputs], which is the
 * inter-model measurements taken by the ExperAgent.
 *
 * Note!!!  Relying on the output from writeSSConstituents _violates_
 * good simulation methodology by using measures that don't have analogs
 * in the other models.
 *
 * for each SS, get the number of enzymes and write it to a file and
 * get the number of metabolic events per ss and write it to debug out
 */
- writeSSConstituents 
{

  [Telem debugOut: 2 printf: "[%s(%p) -writeSSConstituents] -- begin\n",
         [[self getClass] getName], self];


  id <ListIndex> ssNdx = [[graph getNodeList] listBegin: artScratchZone];
   id <LiverDMM> dMM = [_parent getDMM];
  id <String> eHeader = [String create: artScratchZone setC: "Time, "];
  id <String> amHeader = [String create: artScratchZone setC: "Time, "];
  id <String> aHeader = [String create: artScratchZone setC: "Time, "];


  if (enzymeDistFileName == (id <String>)nil || 
      amountMetabFileName == (id <String>)nil ||
      amountFileName == (id <String>)nil ) {
    // build the headers
    [ssNdx setLoc: Start];
    id ln = nil;
    id <MapIndex> bNdx = [bolusContents mapBegin: artScratchZone];
    while ( ([ssNdx getLoc] != End) &&
            ( (ln = [ssNdx next]) != nil) ) {
      id <String> nodeName = [String create: artScratchZone setC: "Node_"];
      [nodeName catC: [Integer intStringValue: ((LiverNode *)ln)->myNumber]];

      BOOL isSS = [ln isKindOf: [Sinusoid class]];

      if (isSS) {
        // enzymes header
        [eHeader catC: [nodeName getC]];
        if ([ssNdx getLoc] != End) [eHeader catC: ", "];
      }

      // amount and amount metabolized headers based on bolusContents
      [bNdx setLoc: Start];
      id <SoluteTag> key = nil;
      id val = nil; // don't care what this is
      while (([bNdx getLoc] != End)
             && ( (val = [bNdx next: &key]) != nil) ) {
        if (isSS) {
          [amHeader catC: [nodeName getC]];
          [amHeader catC: "."];
          [amHeader catC: [key getName]];
        }

        [aHeader catC: [nodeName getC]];
        [aHeader catC: "."];
        [aHeader catC: [key getName]];

        if ([ssNdx getLoc] != End) {
          if (isSS) [amHeader catC: ", "];
          [aHeader catC: ", "];
        }
      }

      [nodeName drop];

    } // end liver node loop
    // we'll reuse ssNdx
    [bNdx drop];

  } // end nil file names branch


  /**
   *  Build the enzyme data file name and header
   */
  // assume ArtModel is re-instantiated or re-initialized each time
  // and the first time this code is exercised, the file is initialized
  if (enzymeDistFileName == (id <String>)nil) {
    enzymeDistFile = [dMM buildFileName: &enzymeDistFileName
                          fromBase: enzymeDistFileBase
                          writeHeader: eHeader];
    [eHeader drop];
  } else {
    enzymeDistFile = [LiverDMM openAppendFile: enzymeDistFileName];
  }

  /**
   * Now build the file name and open file for amount metabolized
   */
  if (amountMetabFileName == (id <String>)nil) {
    amountMetabFile = [dMM buildFileName: &amountMetabFileName 
                           fromBase: amountMetabFileBase
                           writeHeader: amHeader];
    [amHeader drop];
  } else {
    amountMetabFile = [LiverDMM openAppendFile: amountMetabFileName];
  }

  /**
   * Build file name and open file for amount
   */
  if (amountFileName == (id <String>)nil) {
    amountFile = [dMM buildFileName: &amountFileName
                      fromBase: amountFileBase
                      writeHeader: aHeader];
    [aHeader drop];
  } else {
    amountFile = [LiverDMM openAppendFile: amountFileName];
  }

  /**
   * Gather the data
   */

  id <String> enzymeLine = [String create: artScratchZone];
  [enzymeLine catC: [Double doubleStringValue: [self getTime]]];
  [enzymeLine catC: ", "];

  id <String> amountMetabLine = [String create: artScratchZone];
  [amountMetabLine catC: [Double doubleStringValue: [self getTime]]];
  [amountMetabLine catC: ", "];

  id <String> amountLine = [String create: artScratchZone];
  [amountLine catC: [Double doubleStringValue: [self getTime]]];
  [amountLine catC: ", "];

  /* loop over VasGraph nodes again */
  LiverNode *ln = nil;
  [ssNdx setLoc: Start];
  while ( ([ssNdx getLoc] != End) &&
          ( (ln = [ssNdx next]) != nil) ) {

    BOOL isSS = [ln isKindOf: [Sinusoid class]];

    if (isSS) {
      Sinusoid *ss = (Sinusoid *)ln;

      // gather Hepatocyte specific data
      unsigned eSum = 0U; // count of enzymes in this SS
      unsigned mSum = 0U; // count of metabolic events in this SS
      id <ListIndex> hNdx = 
        [ss->hepatocytes listBegin: artScratchZone];
      Hepatocyte *h = nil;

      while ( ([hNdx getLoc] != End) &&
              ( (h = [hNdx next]) != nil) ) {
        eSum += [h->binders getCount];
        mSum += [h getMetabolicEventCount];
      }
      [hNdx drop];

      [enzymeLine catC: [Integer intStringValue: eSum]];
      if ([ssNdx getLoc] != End) [enzymeLine catC: ", "];

    } // end Sinusoid-specific branch

    // gather amount and amount metabolized
    id <MapIndex> bNdx = [bolusContents mapBegin: artScratchZone];
    id <SoluteTag> key = nil;
    id val = nil; // don't care what this is
    id <Integer> am = nil;
    id <Integer> a = nil;
    id <Map> amountMetabolized = (!isSS ? nil :
                                  [((Sinusoid *)ln) getAmountMetabolized]);
    id <Map> amount = [self measure: ln]; // measure solute inside this node

    while (([bNdx getLoc] != End)
           && ( (val = [bNdx next: &key]) != nil) ) {

      // gather amount metabolized
      if (isSS) {
        if (amountMetabolized != nil) am = [amountMetabolized at: key];
        if (am != nil)
          [amountMetabLine catC: [am intStringValue]];
        else
          [amountMetabLine catC: [Integer intStringValue: 0]];
      }

      // gather amount
      if (amount != nil) a = [amount at: key];
      if ( a != nil )
        [amountLine catC: [a intStringValue]];
      else
        [amountLine catC: [Integer intStringValue: 0]];

      if ([ssNdx getLoc] != End) {
        if (isSS) [amountMetabLine catC: ", "];
        [amountLine catC: ", "];
      }
    }
    [bNdx drop];

  } // end loop over VasGraph nodes
  [ssNdx drop];


  // write the enzyme data
  fprintf(enzymeDistFile, "%s\n", [enzymeLine getC]);
  [enzymeLine drop]; enzymeLine = nil;
  [LiverDMM closeFile: enzymeDistFile];

  // write the amount metabolized data
  fprintf(amountMetabFile, "%s\n", [amountMetabLine getC]);
  [amountMetabLine drop]; amountMetabLine = nil;
  [LiverDMM closeFile: amountMetabFile];

  // write amount data to file
  fprintf(amountFile, "%s\n", [amountLine getC]);
  [amountLine drop]; amountLine = nil;
  [LiverDMM closeFile: amountFile];


  //ooooooooooooooooooooooooooooooooooooo;



  [Telem debugOut: 2 printf: "[%s(%p) -writeSSConstituents] -- end\n",
         [[self getClass] getName], self];

  return self;
}

// accessors

- getSinusoidList { 
  return [graph getNodeList]; 
}
- getGraph { 
  return graph; 
}
- (unsigned)getCycle { 
  return cycle;
}
- (double) getTime
{ 
  return (double)cycle/stepsPerCycle;
}
- (double) getTimeInFineResolution
{
	return (double)cycle/stepsPerCycle + (double)currentStep/(stepsPerCycle*stepsPerCycle);
}
- (float) getCurrentDosage
{
  return (float)([bolus dosage: cycle]);
}

// construction methods

+ createBegin: aZone
{
  return [super createBegin: aZone];
}

- createEnd
{

  ArtModel *obj;
  obj = [super createEnd];

  obj->artScratchZone = [Zone create: obj];

  obj->tortSinCircMin = 5U;
  obj->tortSinCircMax = 10U;
  obj->dirSinCircMin = 10U;
  obj->dirSinCircMax = 15U;
  obj->tortSinLenAlpha = 2.0L;
  obj->tortSinLenBeta = 2.0L;
  obj->tortSinLenShift = 5.5L;
  obj->dirSinLenAlpha = 2.0L;
  obj->dirSinLenBeta = 1.0L;
  obj->dirSinLenShift = 12.5L;
  obj->sSpaceScale = 1U;
  obj->eSpaceScale = 1U;
  obj->dSpaceScale = 1U;
  obj->ecDensity = 0.95F;
  obj->hepDensity = 0.50F;
  obj->binderNumMin = 1L;
  obj->binderNumMax = 10L;
  obj->metabolizationProb = 0.5F;
  obj->enzymeInductionWindow = 20U;
  obj->enzymeInductionThreshold = 2U;
  obj->enzymeInductionRate = 0.5F;
  obj->bindProb = 0.5F;

  obj->soluteScale = 5.0F;
  obj->cycleLimit = 1000U;
  obj->stepsPerCycle = 10U;
  obj->turbo = 0.5F;
  obj->coreFlowRate = 1U;
  obj->bileCanalCirc = 1U;
  obj->ssS2EJumpProb = 0.9F;
  obj->ssE2SJumpProb = 0.9F;
  obj->ssE2DJumpProb = 0.9F;
  obj->ssD2EJumpProb = 0.9F;

  obj->inputCount = 0U;
  obj->outputCount = 0U;
  obj->soluteInCount = nil;
  obj->soluteOutCount = nil;
  obj->totalSoluteMassEst = 0U;
  obj->soluteMassEst = [Map create: obj];

  obj->abmDetails = 0;
  obj->snapOn = NO;

  obj->enzymeDistFileBase = [String create: obj setC: "enzymes"];
  obj->enzymeDistFileName = nil;
  obj->enzymeDistFile = (FILE *)nil;

  obj->amountMetabFileBase = [String create: obj setC: "amount_metab"];
  obj->amountMetabFileName = nil;
  obj->amountMetabFile = (FILE *)nil;

  obj->amountFileBase = [String create: obj setC: "amount"];
  obj->amountFileName = nil;
  obj->amountFile = (FILE *)nil;

	obj->bolusContents = nil;
	obj->currentStep = 0U;

	obj->totalNumberOfSolutes = 0U;
	obj->retiredSoluteMap = [Map create:obj];
  obj->enableTrace = NO;

  return obj;
}

- buildObjects
{
  [Telem debugOut: 3 print: "ArtModel::buildObjects() -- Enter\n"];

  uUnsDist = [UniformUnsignedDist create: self
                                  setGenerator: rng
                                  setVirtualGenerator: monteCarlo];
  uUnsFixDist = [UniformUnsignedDist create: self
                                     setGenerator: rng
                                     setVirtualGenerator: fixable];
  uDblDist = [UniformDoubleDist create: self
                                setGenerator: rng
                                setVirtualGenerator: monteCarlo];
  uDblFixDist = [UniformDoubleDist create: self
                                   setGenerator: rng
                                   setVirtualGenerator: fixable];
  gDblDist = [GammaDist create: self
                             setGenerator: rng
                             setVirtualGenerator: monteCarlo];

  // simple output description labels
  outLabels = [List create: self];
  [outLabels addLast: [String create: self setC: "totalOutFract"]];
  id <SoluteTag> key=nil;
  id <Double> val=nil;
  id <MapIndex> ndx = [bolusContents mapBegin: artScratchZone];
  while (([ndx getLoc] != End)
         && ( (val = [ndx next: &key]) != nil) ) {
    [outLabels addLast: [String create: self setC: [key getName]]];

    // set global Metabolite for use inside Enzymes
    if (strcmp([key getName],"Metabolite") == 0)
      Metabolite = key;
  }
  [ndx drop];

  // Now, set the attributes of the Vasa, sinusoids, etc, in the graph
  // designated by the graph:.
  [self initGraph: graph];

  cycle = 0;

  [Telem debugOut: 3 print: "ArtModel::buildObjects() -- Exit\n"];

  return self;
}

- (id <DiGraph>) getEmptyGraph
{
  if (graph == nil)
    graph = [VasGraph create: self];
  else 
    raiseEvent(InvalidOperation, "Cannot call getEmptyGraph() more than once.\n");
  return graph;
}

- (void) useLobuleSpec: (LobuleSpec *) ls
{
  Vas *v = nil;
  VasGraph *g = (VasGraph *)[self getEmptyGraph];
  [g useLobuleSpec: ls];

  // the two vasa have to be in the graph before generate is called.
  v = [[[[Vas createBegin: self]
          setNodeLabel: "portalVein"] setNumber: 0] createEnd];
  [g addNode: v];

  v = [[[[Vas createBegin: self] 
      setNodeLabel: "hepaticVein"] setNumber: 1] createEnd];

  [g addNode: v];

  [g generate];
}

/**
 * Calculates the relative CC ratios for each liver node
 * Relative CC is:
 * 
 *    outlet_CC/Sum{outlet_CC}
 *
 */
- (void) _calcRelativeCCs: (id <DiGraph>) g
{
  id <ListIndex> gNdx = [[g getNodeList] listBegin: artScratchZone];
  LiverNode *ln = nil;

  // loop over graph nodes
  while ( ([gNdx getLoc] != End)
          && ( (ln = [gNdx next]) != nil) ) {


    // loop over outlet nodes to get the totalCC
    int ccSum = 0; // for calculating relative CC for empty SSes
    FlowLink *outlet = nil;
    // -- ASSUMUPTION: rely on immutable toList!
    id <List> toList = [ln getToLinks];
    int outNum = [toList getCount];
    int outNdx = 0;
    for ( outNdx = 0 ; outNdx < outNum ; outNdx++ ) {
      outlet = [toList atOffset: outNdx];
      // add CC to sum to determine relativeCC for empty SS
      ccSum += [outlet getCC];
    }
    ln->outCCSum = ccSum;

    // loop over them again to set their relativeCC
    for ( outNdx = 0 ; outNdx < outNum ; outNdx++ ) {
      outlet = [toList atOffset: outNdx];
      [ln->outCCRatios addLast: 
                     [Double create: [outlet getZone] 
                             setDouble: (double)[outlet getCC]/(double)ln->outCCSum]];
    }

  } // end loop over graph nodes
  

  [gNdx drop];
}

/*
 * calcNumBuffSpaces derives the number of buffer spaces needed in
 * each SS, each of which will have a set of solute types they
 * recognize.  It also returns a canonical Map from SoluteTag to
 * numBuffSpaces to help set the recognized solute in the buffer
 * spaces.
 */
- (void) calcNumBuffSpaces: (id <Map>) nbsCounters
{
  [nbsCounters deleteAll];
  // get data from bolusContents
  id <MapIndex> bcNdx = [bolusContents mapBegin: artScratchZone];
  id <SoluteTag> tag=nil;
  int maxNBS = -INT_MAX;
  while (([bcNdx getLoc] != End)
         && ([bcNdx next: &tag])) {
    int nbs = [tag getNumBufferSpaces];
    [nbsCounters at: tag insert: [Integer create: artScratchZone setInt: nbs]];
    if (nbs > maxNBS) maxNBS = nbs;
  }
  [bcNdx drop];
  numBuffSpaces = maxNBS;
}

- (unsigned) getNumBuffSpaces { return numBuffSpaces; }



- initGraph: (id <DiGraph>) g
{
  [Telem debugOut: 3 print: "ArtModel::initGraph() -- Enter\n"];

  // these are symbols to help with the nonspatial vasa
  In = [Symbol create: self setName: "InFlow"];
  Out = [Symbol create: self setName: "OutFlow"];

  double draw = 0.0L;
  char type;
  id <ListIndex> gNdx = [[g getNodeList] listBegin: artScratchZone];
  LiverNode *ln = nil;
  id <String> netDir = nil;
  id <String> metDir = nil;

  id <String> dir = [[[_parent getDMM] getCsvFileBase] copy: artScratchZone];
  [DMM checkAndCreateDir: dir];
  [dir catC: DIR_SEPARATOR];

  if(enableTrace) {
    [dir catC: "trace"];
    [DMM checkAndCreateDir: dir];
    // create a directory for the current runNumber
    id <String>mcdir = [dir copy:artScratchZone];
    [mcdir catC:DIR_SEPARATOR];
    [mcdir catC:"MC-"];
    [mcdir catC:[Integer intStringValue:[_parent getRunNumber]]];
    [DMM removeDir: mcdir];
    [DMM createDir: mcdir];
    // create a sub directory "Node" below the current runNumber directory
    [mcdir catC: DIR_SEPARATOR];
    [mcdir catC: "Nodes"];
    [DMM createDir: mcdir];
    bdir = [mcdir copy: artScratchZone];
    //		printf("Base Dir: %s\n", [bdir getC]); fflush(stdout);
    netDir = [bdir copy: artScratchZone];
    [netDir catC: DIR_SEPARATOR];
    [netDir catC: "sinusoidalNetwork"];
    [DMM createDir: netDir];
    metDir = [bdir copy: artScratchZone];
    [metDir catC: DIR_SEPARATOR];
    [metDir catC: "metabolized"];
    [DMM createDir: metDir];
  }


  /*
   * calculate the number of buffer spaces for each SS for use in
   * [Sinusoid -createSubSpaces]
   */
  // set counters for solutes recognized by buff spaces
  id <Map> nbsCounters = [Map create: scratchZone];
  [self calcNumBuffSpaces: nbsCounters];
  if ([nbsCounters getCount] <= 0)
    raiseEvent(InternalError, 
               "Error!!  No numBuffSpaces registered for bolus contents.");

  // find and finish setup on input and output vasa
  while ( ([gNdx getLoc] != End) 
          && ( (ln = [gNdx next]) != nil) ) {

    ln->_parent = self;

    if(enableTrace) {
      // for tracking a liver node
      id <String> fn = [netDir copy: artScratchZone];
      [fn catC: DIR_SEPARATOR];
      [fn catC: [ln getNodeLabel]];
      [fn catC: ".csv"];
      [ln setFileDescriptor: [DMM openNewFile: fn]];
      fprintf([ln getFileDescriptor], "%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s\n",
              "iter", "cycle", "time", "timeInFineRes", // simulation time info.
              "node id", "node length", "space", "+cell+/-binder-", "obj count",  // node info.
              "solute id", "solute type", "coordinate"); // solute info.
      [fn drop];
      // for tracking metabolized solutes
      id <String> mfn = [metDir copy: artScratchZone];
      [mfn catC: DIR_SEPARATOR];
      [mfn catC: [ln getNodeLabel]];
      [mfn catC: ".met"];
      [ln setMetFileDescriptor: [DMM openNewFile: mfn]];
      fprintf([ln getMetFileDescriptor], "SoluteID Time SoluteType\n");
      [mfn drop];
    }

    // type-specific setup
    if (strcmp([ln getNodeLabel], "portalVein") == 0) {
      portalVein = (Vas *)ln;
      [portalVein setFlow: In];
      [portalVein setSoluteFlux: 0U withContents: bolusContents];
    } else if (strcmp([ln getNodeLabel], "hepaticVein") == 0) {
      hepaticVein = (Vas *)ln;
      [hepaticVein setFlow: Out];
    } else if (strncmp([ln getNodeLabel], "sinusoid", strlen("sinusoid")) == 0) {
      Sinusoid *aSinusoid = (Sinusoid *)ln;
      draw = [uDblFixDist getDoubleWithMin: 0.0L withMax: 1.0L];
      type = (draw <= dirSinRatio ? 'd' : 't');

      // setup geometry
      if (type == 'd') {
        int length;
        do {
          length = (unsigned)(dirSinLenShift 
                              + [gDblDist 
                                  getSampleWithAlpha: (double)dirSinLenAlpha
                                  withBeta: (double)dirSinLenBeta]);
        } while (length <= 1);

        [aSinusoid 
          setCirc: 
            [uUnsDist getUnsignedWithMin: dirSinCircMin withMax: dirSinCircMax]
          length: length];

      } else {
        int length;
        do {
          length = (unsigned)(tortSinLenShift 
                              + [gDblDist 
                                  getSampleWithAlpha: (double)tortSinLenAlpha
                                  withBeta: (double)tortSinLenBeta]);
        } while (length <= 1);

        [aSinusoid 
          setCirc: [uUnsDist getUnsignedWithMin: tortSinCircMin withMax: tortSinCircMax]
          length: length];
      } // end geometry setup

      [aSinusoid setTurbo: turbo];
      [aSinusoid setCoreFlowRate: coreFlowRate];
      [aSinusoid setBileCanalCirc: bileCanalCirc];

      { // subSpace setup
        [aSinusoid setScaleS: sSpaceScale E: eSpaceScale D: dSpaceScale];
        [aSinusoid create: numBuffSpaces subSpacesWithAmounts: nbsCounters];
        [aSinusoid setSpaceJumpProbsS2E: ssS2EJumpProb e2S: ssE2SJumpProb 
                   e2D: ssE2DJumpProb d2E: ssD2EJumpProb];
      }

      [aSinusoid setSnaps: snapOn];

      { // populate with cells
        Cell *c = nil;
        Hepatocyte *h = nil;

        [aSinusoid createECellsWithDensity: ecDensity];
        id <ListIndex> ndx = [[aSinusoid getECs] listBegin: artScratchZone];
        while (([ndx getLoc] != End) 
               && ( (c = [ndx next]) != nil) ) {
          [c createBindersMin: binderNumMin max: binderNumMax 
             withBindCycles: bindCycles];
          [c setBindingProb: bindProb];
        }
        [ndx drop];

        [aSinusoid createHepatocytesWithDensity: hepDensity];
        ndx = [[aSinusoid getHepatocytes] listBegin: artScratchZone];
        while (([ndx getLoc] != End)
               && ( (h = [ndx next]) != nil) ) {
          [h createBindersMin: binderNumMin max: binderNumMax
             withBindCycles: bindCycles];
          [h setBindingProb: bindProb];
          [h setMetProb: metabolizationProb];
          [h setEIWindow: enzymeInductionWindow 
             thresh: enzymeInductionThreshold 
             rate: enzymeInductionRate];
        }
        [ndx drop];
      } // end populate with cells
    } // end type specific Sinusoid setup
  } // end loop over liver nodes

    // assumption that the hepaticVein flux = portalVein flux
  [hepaticVein setPerfFlux: [portalVein getCC]];

  [self _calcRelativeCCs: g];

  [gNdx drop];
  [nbsCounters deleteAll];
  [nbsCounters drop];


  [Telem debugOut: 3 print: "ArtModel::initGraph() -- Exit\n"];

  return self;
}

- buildActions
{
  id <ActionForEach> actionForEach = nil;

  [Telem debugOut: 3 print: "ArtModel::buildActions() -- Enter\n"];

  // Create the list of simulation actions. 

  adminActions = [ActionGroup create: self];
  macroActions = [ActionGroup create: self];
  microActions = [ActionGroup create: self];
  modelActions = [ActionGroup create: self];
  obsActions = [ActionGroup create: self];

  /*
   * begin model actions
   */
  actionForEach = [macroActions 
                    createActionForEach: [graph getNodeList] 
                    message: M(stepPhysics)];
  [actionForEach setDefaultOrder: Randomized];
  // bolus should really be on an autodrop schedule
  [macroActions createActionTo: self message: M(bolus)];

  actionForEach = [microActions createActionForEach: [graph getNodeList]
                                message: M(stepBioChem)];
  [actionForEach setDefaultOrder: Randomized];

  [modelActions createAction: macroActions];
  [modelActions createAction: microActions];
  /*
   * end model actions
   */

  /*
   * begin admin actions
   */
  [adminActions createActionTo: self message: M(checkParameters)];
  /*
   * end admin actions
   */

  // Then we create a schedule that executes the action groups
  
  abmSchedule = [Schedule createBegin: self];
  [abmSchedule setRepeatInterval: 1];
  abmSchedule = [abmSchedule createEnd];

  [abmSchedule at: 0 createAction: adminActions];
  [abmSchedule at: 0 createAction: modelActions]; 
  [abmSchedule at: 0 createAction: obsActions];  // dynamic

  // control action
  [abmSchedule at: 0 createActionTo: self message: M(checkToStop)];

  // observation actions
  [obsActions createActionTo: self message: M(measureVasaFlux)];
  [obsActions createActionTo: self message: M(writeSSConstituents)];
  [obsActions createActionTo: self message: M(printResults)];
	if (enableTrace) {
		[obsActions createActionTo: self message: M(traceSolutes)];
	}
  if (snapOn) {
    snapAction = [obsActions createActionTo: self message: M(snap)];
  }

  [Telem debugOut: 3 print: "ArtModel::buildActions() -- Exit\n"];

  return self;
}

- activateIn: swarmContext {
  [super activateIn: swarmContext];
  [abmSchedule activateIn: self];
  [self activateGraphSinusoidCellsIn: self];
  return [self getActivity];
}

- activateGraphSinusoidCellsIn: (id) swarmContext
{
  id <List> graphNodes = [graph getNodeList];
  id <ListIndex> nNdx = [graphNodes listBegin: artScratchZone];
  id node = nil;

  while ( ([nNdx getLoc] != End)
        && ( (node = [nNdx next]) != nil) ) {
    if ([node isKindOf: [Sinusoid class]] ) {
      Sinusoid *sin = node;
      [sin activateCellSchedulesIn: swarmContext];
    }
  }
  [nNdx drop];

  return self;
}

- (id) setParent: (id) p {
  assert(p!=nil);
  _parent = p;
  return self;
}
- setCycleLimit: (unsigned) cl {
  assert(cl > 1);
  cycleLimit = cl;
  return self;
}
- setStepsPerCycle: (unsigned) is {
  assert( is > 1 );
  stepsPerCycle=is;
  return self;
}

- setTortSinCircMin: (unsigned) cmin max: (unsigned) cmax 
           lenAlpha: (float) lalpha beta: (float) lbeta
          lenShift: (float) lshift
//             lenMin: (unsigned) lmin max: (unsigned) lmax
{
  //assert( cmin > 0 && lmin > 0 );
  //assert( cmax >= cmin && lmax >= lmin );
  //assert( lmin > cmin );
  tortSinCircMin = cmin;
  tortSinCircMax = cmax;
  tortSinLenAlpha = lalpha;
  tortSinLenBeta = lbeta;
  tortSinLenShift = lshift;
  //tortSinLenMin = lmin;
  //tortSinLenMax = lmax;
  return self;
}

- setDirSinCircMin: (unsigned) cmin max: (unsigned) cmax 
          lenAlpha: (float) lalpha beta: (float) lbeta
         lenShift: (float) lshift
{
  //assert( cmin > 0 && lmin > 0 );
  //assert( cmax >= cmin && lmax >= lmin );
  dirSinCircMin = cmin;
  dirSinCircMax = cmax;
  dirSinLenAlpha = lalpha;
  dirSinLenBeta = lbeta;
  dirSinLenShift = lshift;
  //dirSinLenMin = lmin;
  //dirSinLenMax = lmax;
  return self;
}

- setSpaceScaleS: (unsigned) sscale E: (unsigned) escale D: (unsigned) dscale
{
  assert( sscale != 0 );
  assert( escale != 0 );
  assert( dscale != 0 );
  sSpaceScale = sscale;
  eSpaceScale = escale;
  dSpaceScale = dscale;
  return self;
}

- setSinRatiosDirect: (float) d tortuous: (float) t {
  [Telem debugOut: 1 printf: "ArtModel::setSinRatioDirect: d=%f, t=%f \n",d,t];
  assert ( ((d + t) - 1.0L) < FLT_EPSILON );
  dirSinRatio = d;
  tortSinRatio = t;
  return self;
}

- setSoluteScale: (double) ss
{
  assert( ss >= 1.0L);
  soluteScale = ss;
  return self;
}

- setDosageParams: (id <Array>) p andTimes: (id <Array>) t
{
  if (stepsPerCycle == INVALID_INT)
    raiseEvent(InternalError, "[%s -setDosageParams:andTimes:] depends on artStepsPerCycle (= %d).\n", [[self getClass] getName], stepsPerCycle);

  // initialize the Dosage object
  bolus = [SerialInjection create: self];
  [bolus setParams: [p copy: self]];
  // convert from times to cycles
  id <Array> cycles = [Array create: self setCount: [t getCount]];
  int tNdx=0U;
  for ( tNdx=0 ; tNdx<[t getCount] ; tNdx++ ) {
    [cycles atOffset: tNdx put: [[t atOffset: tNdx] copy: self]];
  }
  id <Integer> time_Int = nil;
  int time_int = INVALID_INT;
  for ( tNdx=0 ; tNdx<[cycles getCount] ; tNdx++ ) {
    time_Int = [cycles atOffset: tNdx];
    if (time_Int != nil && 
        (time_int = [time_Int getInt]) != INVALID_INT) {
      [time_Int setInt: time_int*stepsPerCycle];
    }
  }
  [bolus setTimes: cycles];
//	dosageEndTime = [[cycles atOffset:1] getInt]; // dosageEndTime

  // estimate total dosage
  unsigned cNdx=0U, sNdx=0U;
  totalSoluteMassEst = 0U;
  if (cycleLimit > 0) 
    for (cNdx=0 ; cNdx<cycleLimit ; cNdx++) {
      for (sNdx=0 ; sNdx<stepsPerCycle ; sNdx++) {
        totalSoluteMassEst += [bolus dosage: cNdx];
      }
    }
  [Telem monitorOut: 1 printf: "ArtModel.totalSoluteMassEst = %d\n",
         totalSoluteMassEst];

  return self;
}

- (void) setBolusContents: (id <Map>) bc
{
  assert([bc getCount] > 0);
  if (bolusContents != nil) [bolusContents drop];
  bolusContents = [Map create: self];
  id v=nil, k=nil;
  id <MapIndex> bcNdx = [bc mapBegin: scratchZone];
  while (([bcNdx getLoc] != End) &&
         ((v = [bcNdx next: &k]) != nil)) {
    [bolusContents at: [k copy: self] insert: [v copy: self]];
  }
  [bcNdx drop];

  // calculate estimated mass per solute compound
  bcNdx = [bolusContents mapBegin: artScratchZone];
  id <SoluteTag> soluteTag=nil;
  id <Double> percentage=nil;
  while (([bcNdx getLoc] != End)
         && ((percentage = [bcNdx next: &soluteTag]) != nil)) {
    double perc = [percentage getDouble];

    if (soluteMassEst != nil)
      if (strcmp([soluteTag getName], "Metabolite") == 0)
        [soluteMassEst at: soluteTag insert: [Integer create: self setInt: totalSoluteMassEst]];
      else
        [soluteMassEst at: soluteTag insert: [Integer create: self setInt: perc*totalSoluteMassEst]];
    else
      raiseEvent(InternalError, "soluteMassEst not initialized.\n");
  }
  [bcNdx drop];
}

- (id <DiGraph>) getGraphContainer
{
  return [VasGraph create: self];
}
- setSinusoidTurbo: (double) t {
  assert( t >= 0.0);
  turbo = t;
  return self;
}
- (void) setCoreFlowRate: (unsigned) cfr
{
  assert (cfr > 0U);
  coreFlowRate = cfr;
}
- (void) setBileCanalCircumference: (unsigned) c
{
  assert (c > 0U);
  bileCanalCirc = c;
}
- (void) setSpaceJumpProbsS2E: (float) s2e 
                          e2S: (float) e2s e2D: (float) e2d d2E: (float) d2e
{
  ssS2EJumpProb = s2e;
  ssE2SJumpProb = e2s;
  ssE2DJumpProb = e2d;
  ssD2EJumpProb = d2e;
}
- (void) setECDensity: (float) ecd
{
  assert( 0.0F < ecd );
  assert( ecd <= 1.0F );
  ecDensity = ecd;
}
- (void) setHepDensity: (float) hd
{
  assert( 0.0F < hd );
  assert( hd <= 1.0F );
  hepDensity = hd;
}
- (void) setBinderNumMin: (unsigned) bnmin max: (unsigned) bnmax
{
  assert( bnmin >= 0U );
  assert( bnmax >= bnmin );
  binderNumMin = bnmin;
  binderNumMax = bnmax;
}
- (void) setMetabolizationProb: (float) mp
{
  assert( 0.0F <= mp && mp <= 1.0F);
  metabolizationProb = mp;
}
- (void) setEnzymeInductionWindow: (unsigned) w thresh: (unsigned) t rate: (float) r
{ 
  enzymeInductionWindow = w; 
  enzymeInductionThreshold = t;
  enzymeInductionRate = r; 
}
- (void) setBindingProb: (float) bp andCycles: (unsigned) bc
{
  assert( 0.0F <= bp && bp <= 1.0F);
  assert( bc >= 0U );
  bindProb = bp;
  bindCycles = bc;
}

/*
 * [ArtModel -checkParameters] -- compares parameters and alerts user
 * to potential problems with the run.
 */
- (void) checkParameters
{
  if (enzymeInductionThreshold * bindCycles >= enzymeInductionWindow-1)
    [WarningMessage raiseEvent: "enzymeInductionThreshold (%d) * bindCycles (%d) "
                    "= %d which is too close to enzymeInductionWindow (%d).\n"
                    "Enzymes may not be induced.\n", 
                    enzymeInductionThreshold, bindCycles, 
                    enzymeInductionThreshold*bindCycles, enzymeInductionWindow];

}

- setViewArtDetails: (short int) details
{
  abmDetails = details;
  return self;
}

- (void) setSnapshots: (BOOL) snaps
{
  snapOn = snaps;
  // if we're going from off to on, then schedule this action
  if (snapOn && snapAction == nil) 
    snapAction = [obsActions createActionTo: self message: M(snap)];
  // if we're going from on to off, then remove the action
  if (!snapOn && snapAction != nil) {
    [obsActions remove: snapAction];
  }
}

- (void) enableSoluteTrace: (BOOL) trace 
{
  enableTrace = trace;
}

- setRNG: (id <SplitRandomGenerator>) r
{
  rng = r;
  return self;
}

// utility methods

- (void)drop
{

  [graph drop];
  [bolusContents deleteAll];
  [bolusContents drop];
  bolusContents = nil;
  if (soluteInCount != nil) {
    [soluteInCount deleteAll];
    [soluteInCount drop];
  }
  if (soluteOutCount != nil) {
    [soluteOutCount deleteAll];
    [soluteOutCount drop];
  }
  [soluteMassEst deleteAll];
  [soluteMassEst drop];
  // don't drop rng because it's used in the global dists
  [outLabels deleteAll];
  [outLabels drop];

  _parent = nil;
  enzymeDistFile = (FILE *)nil;
  [enzymeDistFileBase drop];
  [enzymeDistFileName drop];

  // have to do these because they are global
  uDblDist = nil;
  uDblFixDist = nil;
  uUnsDist = nil;
  uUnsFixDist = nil;

  [super drop];
}

@end
