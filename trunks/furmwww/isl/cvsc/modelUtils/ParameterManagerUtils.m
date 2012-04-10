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
#undef NDEBUG
#include <assert.h>
#import <string.h>

#import "ParameterManagerUtils.h"
//#import "ExperAgent.h"

int pm_compare ( id obj1, id obj2 )
{
  int retVal=0;
  unsigned o1mc = 0L;
  unsigned o2mc = 0L;
  if ( obj1 == nil || obj2 == nil ) retVal = 0xffffffff;
  o1mc = [obj1 getMonteCarloSet];
  o2mc = [obj2 getMonteCarloSet];
  if (o1mc < o2mc ) retVal = -1;
  if (o1mc > o2mc ) retVal = 1;

  return retVal;
}

@implementation ParameterManagerUtils

// runtime methods


// observation methods

- (unsigned) getRun
{
  return currentRun;
}

- (unsigned) getMonteCarloSet
{
   return monteCarloSet;
}

- (void) log: (const char *) fmt, ... 
{
  [self subclassResponsibility: @selector(log:)];
}

// construction methods
- createEnd
{
  ParameterManagerUtils *obj = [super createEnd];
  obj->NMS = 1; // N&M exit code initialized to "continue"
  obj->reflScore = NAN;
  obj->contractRatio = NAN;
  obj->shrinkRatio = NAN;
  obj->expandRatio = NAN;
  obj->reflectRatio = NAN;

  return obj;
}

- (void)initializeParameters
{
  rng = [ C4LCGXgen create: [self getZone]
                    setA: 2 setV: 0 setW: 63
                    setStateFromSeed: STARTSEED ];
  monteCarloSet = 0L;

  pmUUnsDist = [UniformUnsignedDist create: [self getZone]
                                    setGenerator: rng
                                    setVirtualGenerator: fixable];
  iterateNumber=1;
  

  // parse nominalProfile
  if (strchr(nominalProfile,':')==(char *)nil)
  {
    nomProfCol = "Average";
  } else {
    char *s=(char *)nil;
    strtok(nominalProfile,":");
    nomProfCol=strtok(s,":");
  }
  
  
}
- setRun: (unsigned) r
{
  currentRun = r;
  return self;
}
- setMonteCarloSet: (unsigned) mcSet
{
  monteCarloSet = mcSet;
  return self;
}

/*
 * 						
 * Nelder and Mead Simplex Optimization Method  
 * 						
 */

- (unsigned)evolveParametersUsingSimplexMethod: (double)similarity
{
  dL=3; //debug level 
  [Telem debugOut: dL printf: "ParameterManager::evolveParametersUsingSimplexMethod:Enter\n"];
  if (similarity != 0.0)
    [self log: "\n********** Monte Carlo Set: %u ***********\n",
          monteCarloSet-1];
  [Telem debugOut: dL printf: "[%s(%p) -stepParameters] -- "
         "monteCarloSet = %u, similarity score = %f\n", [[self getClass] getName], self, 
         monteCarloSet, similarity];
  [self log: "Similarity score= %f \n",similarity];
  unsigned exitCode; //0=done(converged), 1= continue, 2=at least one parameter is out of range
  
  paramsOutOfRange = NO;
  if (similarity > similarity_max)
  {
    similarity_max = similarity;
    best_monteCarloSet = monteCarloSet-1;
  }

  if (iterateNumber == 1) {
    similarity_max = similarity;

    initialParams = [Vectormd create: [self getZone] 
				copyVector: [self vectorizeEvolvingParameters]];
    reflParams = [Vectormd create: [self getZone] 
			   setDim: [initialParams getDim]];
    centParams = [Vectormd create: [self getZone] 
			   setDim: [initialParams getDim]];
    c1Params   = [Vectormd create: [self getZone] 
			   setDim: [initialParams getDim]];
    c2Params   = [Vectormd create: [self getZone] 
			   setDim: [initialParams getDim]];
    expParams  = [Vectormd create: [self getZone] 
			   setDim: [initialParams getDim]];

    dim = [initialParams getDim]+1; //simplex dimension
    iBest = iterateNumber-1; 
    iWorst= iBest;
    iNextWorst = iBest;

    simplex = [Simplex create: [self getZone] setDim: dim];
    //score = (double *)[[self getZone] alloc: (sizeof(double)*dim)];
    score = [Vectormd create: [self getZone] setDim: dim];
    state = 0;
    runNewMonteCarloSet = NO;

    [Telem debugOut: dL printf:"initialParams= %s \n", [[initialParams toString] getC]];

  }
  
  [Telem debugOut: dL 
	   printf:"monteCarloSet= %u  similarity_max= %f \n",
  	   monteCarloSet, similarity_max];
  [self log:"Max Similarity Score= %f \n", similarity_max];	   
  if (dim > 1){// check if there is any parameter to be evolved
  /*
   * The first n=dim experiments make the initial simplex
   */  
    if (iterateNumber < dim){
      [simplex createVertex: (iterateNumber-1) 
		       copyVector: [self vectorizeEvolvingParameters]];
      //score[iterateNumber-1] = similarity;
      [score setVal: similarity at: iterateNumber-1];
      
      /*
       * calculate the next (initial) vertex:
       * Pi = P0 + dPi 
       */

      id <Vectormd> evolveParams = [Vectormd create:[self getZone] 
					     setDim: [initialParams getDim]];
      id <Vectormd> dp = [self vectorizeDparams];
      [evolveParams add: initialParams];
      [evolveParams setVal: [evolveParams getValAt:iterateNumber-1]+[dp getValAt:iterateNumber-1] 
			at: iterateNumber-1];
      [self restoreEvolvingParametersFrom: evolveParams];
      
      [evolveParams drop];
      [dp drop];    

    }
    if (iterateNumber >= dim){ 
        if (iterateNumber == dim){
          [simplex createVertex: (iterateNumber-1) 
			   copyVector: [self vectorizeEvolvingParameters]];
	  [score setVal: similarity at: iterateNumber-1];
	  [self log: 
	  "Initial simplex formed. Optimization starts hereafter... \n"];
        }
        [self findSimplexExtremes];
        [Telem debugOut: dL printf:"Best vertex so far: \n"];
	[self log:"\nBest vertex so far: \n"];
	[self logEvolvingParameters: [simplex getVertex: iBest]];
	[self log:
  	"\nBest monte carlo set so far: %u \n", best_monteCarloSet];
        runNewMonteCarloSet = NO;
        if (state == 1){
          [Telem debugOut: dL printf: "state =1\n"];
          reflScore = similarity;
        //   if paramsRefl worse than paramsWorst?
	  if (reflScore < /*score[iWorst]*/ [score getValAt: iWorst]){
        //     paramsC1 = contract paramsWorst thru paramsCent
	    [c1Params copyVector: [simplex getVertex: iWorst]];
	    [c1Params contractThru: centParams withRatio: contractRatio];
	    [self restoreEvolvingParametersFrom: c1Params];
            state = 2;
          
          }
        //   elseif paramsRefl worse than paramsNextWorst?
	  else if (reflScore < /*score[iNextWorst]*/ [score getValAt: iNextWorst]){
        //     paramsC2 = contract paramsRefl thru paramsCent
	    [c2Params copyVector: reflParams];
	    [c2Params contractThru: centParams withRatio: contractRatio];
	    [self restoreEvolvingParametersFrom: c2Params];
            state = 3;
         
          }
        //   elseif paramsRefl worse than paramsBest?
          else if (reflScore < /*score[iBest]*/ [score getValAt: iBest]){
        //     paramsExp = expand paramsRefl thru paramsCent
	    [expParams copyVector: reflParams];
	    [expParams expandThru: centParams withRatio: expandRatio];
 	    [self restoreEvolvingParametersFrom: expParams];
            state = 4;
          }
        //   elseif paramsRefl better than paramsBest?
          else {
        //     replace paramsWorst with paramsRefl
	    [simplex vertex: iWorst copyVector: reflParams];
	    [score setVal: similarity at: iWorst];
        //     find the best, worst and next-worst vertices of simplex
            [self findSimplexExtremes];
        //     paramsRefl = reflect paramsWorst thru paramsCent
	    [reflParams copyVector: [simplex getVertex: iWorst]];
	    [reflParams reflectThru: centParams withRatio: reflectRatio];
	    [self restoreEvolvingParametersFrom: reflParams];
	    state = 1;       
          }
	  
        // EXIT, run a new monte carlo set and measure the similarity.
          runNewMonteCarloSet = YES;
        }
        if (!runNewMonteCarloSet){
          if (state == 2){
            [Telem debugOut: dL printf: "state =2\n"];
            state = 0;
          //   if paramsC1 better than paramsWorst?
            if (similarity > /*score[iWorst]*/ [score getValAt: iWorst]){
          //     replace paramsWorst with pharamsC1
	      [simplex vertex: iWorst copyVector: c1Params];
       	      [score setVal: similarity at: iWorst];	   
	    } else {
          //     shrink simplex
	      [simplex shrinkTowardVertex: iBest WithRatio: shrinkRatio];
	    }
          }
          if (state == 3){
            [Telem debugOut: dL printf: "state =3\n"];
  	    state = 0;
          //   if paramsC2 better than paramsRefl?
            if (similarity > reflScore){
          //     replace paramsWorst with paramsC2
	      [simplex vertex: iWorst copyVector: c2Params];
	      [score setVal: similarity at: iWorst];
	    } else {
          //     replace paramsWorst with paramsRefl
	      [simplex vertex: iWorst copyVector: reflParams];
	      [score setVal: reflScore at: iWorst];	
          //     find extremes
              [self findSimplexExtremes];
          //     shrink simplex
	      [simplex shrinkTowardVertex: iBest WithRatio: shrinkRatio];
            }	
          }
          if (state == 4){
            [Telem debugOut: dL printf: "state =4\n"];
    	    state = 0;
          //   if paramsExp better than paramsBest?
            if (similarity > /*score[iWorst]*/ [score getValAt: iWorst]){
          //     replace paramsWorst with paramsExp
	      [simplex vertex: iWorst copyVector: expParams];
	      [score setVal: similarity at: iWorst];
            } else {
          //     replace paramsWorst with paramsRefl
	      [simplex vertex: iWorst copyVector: reflParams];
	      [score setVal: reflScore at: iWorst];
            }
          }
          if (state == 0){
            [Telem debugOut: dL printf: "state =0\n"];
          //   find the best, worst and next-worst points of simplex
            [self findSimplexExtremes];
          //   paramCent = mean of all vertices except the worst.
	    [centParams copyVector: [Vectormd create: [self getZone] 
		      			setDim: [initialParams getDim]]];
	    unsigned i;
	    for (i=0;i<dim;i++)
  	      if (i != iWorst) {
 	        [centParams add: [simplex getVertex: i]]; 
	      }
	    [centParams multByScalar: (1/(dim-1))];
//c//	    [centParams copyVector: [simplex getVertex: iBest]];
//c//	    [centParams contractThru: [simplex getVertex: iNextWorst] 
//c//			   withRatio: 0.5];
          //   paramsRefl = reflect paramsWorst thru paramsCent	  
	    [reflParams copyVector: [simplex getVertex: iWorst]];
	    [reflParams reflectThru: centParams withRatio: reflectRatio];
	    [self restoreEvolvingParametersFrom: reflParams];
            state = 1;
            runNewMonteCarloSet = YES;
          }
        }

    }
  //*debug*
      if (iterateNumber >= dim){ 
        [self log:"\nCurrent Simplex:%s \n",[[simplex toString] getC]];
        unsigned i;
        for (i=0; i<dim ; i++){
	  [self log: "Vertex (%u) Score=%f \n",i,[score getValAt: i]];
        }
      }
  //*******
  }

	
  [Telem debugOut: dL 
  printf:"ParameterManager::evolveParametersUsingSimplexMethod:Exit with parameter values: %s \n",[[[self vectorizeEvolvingParameters] toString] getC]];
  exitCode = 1; // tells the experAgent to continue the experiments.
  if (([self simplexConverged]) || (dim==1)){
    exitCode=0; // the algorithm is converged 
                // or there is no evolving parameter (if dim==1). 
  } else {
    if (paramsOutOfRange) {
      //at least one parameter is out of the acceptable range	  
      exitCode=2;
      [self log: "\nParameter vector is out of the feasable region. Trying again ...\n\n******************************************\n"];
    }
  }
  iterateNumber++;
  return exitCode;	  
}
/*
 * findSimplexExtremes - Finds the best, worst and next-to-worst vertices
 *                       of the simplex.                     
 */
- (void) findSimplexExtremes 
{
  unsigned i;
  if ([score getValAt: 0] <= [score getValAt: 1]){
    iWorst = 0; 
    iBest = iNextWorst = 1; 
  } else { 
    iWorst = 1; 
    iBest = iNextWorst = 0; 
  }
  for (i = 2; i < dim ; i++){
    if ([score getValAt: i] > [score getValAt: iBest]){
      iBest = i;
    }else if ([score getValAt: i] <= [score getValAt: iWorst]){ 
      iNextWorst = iWorst; 
      iWorst = i; 
    }else if ([score getValAt: i] <= [score getValAt: iNextWorst]){
      iNextWorst = i; 
    }
  }
}


/*
 * simplexConverged - Returns YES if the simplex is converged to a point, i.e. 
 *                    all the vertices are equal.
 */
- (BOOL) simplexConverged
{ 
  BOOL retVal = NO;

  if (iterateNumber>=dim){
    unsigned i;
    double sum=0;
    id <Vectormd> t1=[Vectormd create: [self getZone] setDim: dim-1];
    //retVal = YES;
    for (i=1; i<dim; i++){
      [t1 copyVector: [simplex getVertex: i]];
      sum += [[t1 sub: [simplex getVertex: (i-1)]] norm];
    }
    [self log:"\nSimplex perimeter=%f \n",sum];
    if (sum <= 0.00001) retVal = YES;
  }

  return retVal;
}
- (id <Vectormd>) vectorizeEvolvingParameters
{
  return [self subclassResponsibility: @selector(vectorizeEvolvingParameters)];
}
- (id <Vectormd>) vectorizeDparams
{
  return [self subclassResponsibility: @selector(vectorizeDparams)];
}
- (void) restoreEvolvingParametersFrom: (id <Vectormd>) v
{
  [self subclassResponsibility: @selector(restoreEvolvingParametersFrom:)];
}
- (void) logEvolvingParameters: (id <Vectormd>) v
{
  [self subclassResponsibility: @selector(logEvolvingParameters:)];
}
@end
