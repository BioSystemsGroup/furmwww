/*
 * IPRL - Statistics Calculator
 *
 * Copyright 2003-2007 - Regents of the University of California, San
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

#import <string.h>
#import <float.h>

//#import "../ExperAgent.h"
#import "Double.h"
#import "StatCalculator.h"

#import "DMM.h" // temp: SW
 
@implementation StatCalculator

+ (const char *)getName
{
  return ((Class) self)->name;
}
 
+ sumUpDM: (id <Map>) dataMap forPM: pm
{
  unsigned numRuns = 0L;
  id <MapIndex> timeNdx = nil;
  id time = nil;
  id <MapIndex> runNdx = nil;
  id <Map> runMap = nil;
  id newPM = nil;
  id <Map> mcMap = nil;
  id <Map> avgMap = nil;
  id <Map> dataPt=nil;
  id <Map> dpSum = nil;
  id <Map> avgRunMap = [Map createBegin: globalZone];
  [avgRunMap setCompareFunction: (compare_t)double_compare];
  avgRunMap = [avgRunMap createEnd];
  mcMap = [dataMap at: pm];
  numRuns = [mcMap getCount];

  timeNdx = [[mcMap getFirst] mapBegin: scratchZone];
  while (([timeNdx getLoc] != End)
         && ( ([timeNdx next: &time]) != nil) ) {
    [Telem debugOut: 4 printf: "Averaging over %d runs: \n",
           numRuns];
    dpSum = [Map create: globalZone];
    runNdx = [mcMap mapBegin: scratchZone];
    while (([runNdx getLoc] != End)  && ( (runMap = [runNdx next]) != nil) ) {
      dataPt = [runMap at: time];
      [self addDataPoint: dataPt to: dpSum];
      [Telem debugOut: 4 print: [DMM pointStringValue: dataPt]];
    }
    [runNdx drop];

    [self divide: (double)numRuns intoDataPoint: dpSum];

    [Telem debugOut: 4 print: " => "];
    [Telem debugOut: 4 print: [DMM pointStringValue: dpSum]];

    [avgRunMap at: time insert: dpSum];
  }
  [timeNdx drop];


  newPM = [ParameterManagerUtils create: globalZone];
  [newPM setMonteCarloSet: 0xffffffff];
  // in the avg section insert the new average runMap for that PM
  avgMap = [dataMap at: newPM];
  if (avgMap == nil) {
    avgMap = [Map createBegin: globalZone];
    [avgMap setCompareFunction: pm_compare];
    avgMap = [avgMap createEnd];
    [dataMap at: newPM insert: avgMap];
  }
  {
    ParameterManagerUtils *indexPM = [globalZone copyIVars: pm];
    [avgMap at: indexPM insert: avgRunMap];
  }
  return self;
}

// originally for constituent maps used in DMM
+ (id <Map>) subtractMap: (id <Map>) m1 from: (id <Map>) m2
{
  id <ListIndex> klNdx=nil;
  id <Integer> m1Val=nil, m2Val=nil;
  id <Symbol> key=nil;
  id <List> keyList1=nil;
  id <List> keyList2=nil;
  id <List> keyList=nil;
  id <Map> result = nil;

  if ((m1 == nil) && (m2 == nil)) {
    // continue
  } else if (m1 == nil) { // then m2 - m1 => m2
    id <MapIndex> mNdx = [m2 mapBegin: scratchZone];
    result = [Map create: globalZone];
    while ( ([mNdx getLoc] != End)
            && ( (m2Val = [mNdx next: &key]) != nil) ) {
      [result at: key insert: [globalZone copyIVars: m2Val]];
    }
    [mNdx drop];
  } else if (m2 == nil) { // then m2 - m1 => -m1
    result = [Map create: globalZone];
    id <MapIndex> mNdx = [m1 mapBegin: scratchZone];
    result = [Map create: globalZone];
    while ( ([mNdx getLoc] != End)
            && ( (m1Val = [mNdx next: &key]) != nil) ) {
      id <Integer> tmpInt = [globalZone copyIVars: m1Val];

      [Telem debugOut: 4 printf: "%s::subtractMap:from: -- \n"
             "\t[m1Val(%p) getInt] => %d\n"
             "\t[key(%p) getName] => %s\n"
             "\t[tmpInt(%p) getInt] => %d\n",
             [[self class] getName],
             m1Val, [m1Val getInt],
             key, [key getName],
             tmpInt, [tmpInt getInt]];

      [result at: key insert: [tmpInt setInt: -1*[tmpInt getInt]]];
    }
    [mNdx drop];
  } else {
    result = [Map create: globalZone];
    keyList = [List create: scratchZone];
    // list of keys, use that to index the maps
    keyList1 = [DMM getKeyListFrom: m1];
    keyList2 = [DMM getKeyListFrom: m2];

    // merge the key lists
    klNdx = [keyList1 listBegin: scratchZone];
    while ( ([klNdx getLoc] != End)
            && ( (key = [klNdx next]) != nil) ) {
      if (![keyList contains: key]) {
        [keyList addLast: key];
      }
    }
    [klNdx drop];
    klNdx = [keyList2 listBegin: scratchZone];
    while ( ([klNdx getLoc] != End)
            && ( (key = [klNdx next]) != nil) ) {
      if (![keyList contains: key]) {
        [keyList addLast: key];
      }
    }
    [klNdx drop];
    [keyList1 drop];
    [keyList2 drop];

    klNdx = [keyList listBegin: scratchZone];
    while ( ([klNdx getLoc] != End)
            && ( (key = [klNdx next]) != nil) ) {
      m1Val = [m1 at: key];
      m2Val = [m2 at: key];
      assert ( ! ((m1Val == nil) && (m2Val == nil)) );
      if ( (m1Val == nil) && (m2Val != nil) ) {
        [result at: key 
                insert: [globalZone copyIVars: m2Val]];
      } else if ( (m2Val == nil) && (m1Val != nil) ) {
        id <Integer> newInt = [globalZone copyIVars: m1Val];

      // negate the m1Val value
        [newInt setInt: [newInt getInt] * -1];
        [result at: key
                insert: newInt];
      } else { // both are non-nil
        assert ([m1Val conformsTo: @protocol(Integer)]);
        assert ([m2Val conformsTo: @protocol(Integer)]);
        [result at: key 
                insert: [Integer create: globalZone 
                                 setInt: [m2Val getInt] - [m1Val getInt]]];
      }
    }
    [klNdx drop];
    [keyList drop];
  }

  return result;
}

+ (void) addDataPoint: (id <Map>) dp1 to: (id <Map>) dp2
{
  id <MapIndex> dpNdx=nil;
  id key = nil;
  id val = nil;

  if (dp1 == nil || [dp1 getCount] == 0)
    return;
  else if (dp2 == nil) {
    dp2 = [Map create: [dp1 getZone]];
  } 

  if ([dp2 getCount] == 0) {
    dpNdx = [dp1 mapBegin: scratchZone];
    while (([dpNdx getLoc] != End)
           && ( (val = [dpNdx next: &key]) != nil) ) {
      [dp2 at: key insert: [[val getZone] copyIVars: val]];
    }
    [dpNdx drop];
  } else {
    dpNdx = [dp2 mapBegin: scratchZone];
    while (([dpNdx getLoc] != End)
           && ( (val = [dpNdx next: &key]) != nil) ) {

       // if no value at that key, then do nothing (same as adding zero to dp2)
       if ([dp1 at: key] != nil) {
          //if ([val conformsTo: @protocol(Double)])
          if ([val respondsTo: @selector(addDouble:)])
             [val addDouble: [[dp1 at: key] getDouble]];
          //else if ([val conformsTo: @protocol(Integer)])
          else if ([val respondsTo: @selector(addInt:)])
             [val addInt: [[dp1 at: key] getInt]];
          else {
             raiseEvent(InternalError, "unrecognized value %s(%p) for data point maps.\n",
                        [[val class] getName], val);
          }
       }
    }
    [dpNdx drop];
  }

}

+ (void) divide: (double) scalar intoDataPoint: (id <Map>) dp
{
  id <MapIndex> dpNdx=[dp mapBegin: scratchZone];
  id <String> key = nil;
  id val = nil;

  if (scalar < DBL_EPSILON) 
    raiseEvent(WarningMessage, "%s::divide() -- Divide by Zero error.\n",[self getName]);
  else if (dp == nil) 
    raiseEvent(WarningMessage, "%s::divide() -- Numerator is Zero.\n",[self getName]);
  else {
    while (([dpNdx getLoc] != End)
           && ( (val = [dpNdx next: &key]) != nil) ) {
      [val divideDouble: scalar];
    }
    [dpNdx drop];
  }
}

+ (double) computeCV: (id <Map>) runMap
{
  // Use all available data to find the average coefficient of variance
  //   we are assuming that each column has the same length

  id <List> cv_data_list = [DMM getDataListFromMap: runMap];
  id <List> cv_data_list_first_col = 
    [DMM getDataListFromMap: runMap pointIndex: 1];
  unsigned num_cols = [cv_data_list getCount] / [cv_data_list_first_col getCount];
  unsigned num_rows = [cv_data_list_first_col getCount];
  [cv_data_list drop];
  [cv_data_list_first_col drop];

  double cv_data_array [num_cols][num_rows];
  unsigned c_index;
  unsigned r_index;
  for (c_index = 0; c_index < num_cols; c_index++) 
    {
      id <List> temp_list = 
        [DMM getDataListFromMap: runMap pointIndex: c_index];
      for (r_index = 0; r_index < num_rows; r_index++) 
	{
	  cv_data_array[c_index][r_index] = [[temp_list atOffset: r_index] getDouble];
	}
      [temp_list drop];
    }

  // Now step through, calculating means. But, ignore values of 0 ('NA')
  double cv_data_mean[num_rows];
  for (r_index = 0; r_index < num_rows; r_index++)
    {
      double sum = 0;
      double num_entries = 0;
      for (c_index = 0; c_index < num_cols; c_index++) 
	{
	  if (cv_data_array[c_index][r_index] != 0) {
	    sum +=  cv_data_array[c_index][r_index];
	    num_entries++;
	  }
	}
      cv_data_mean[r_index] = (sum / num_entries);
    }

  // Now step through, normalizing and calc'ing stddev; insert into a list
  id <List> cv_data_final_list = [List create: scratchZone];
  for (c_index = 0; c_index < num_cols; c_index++) 
    {
      for (r_index = 0; r_index < num_rows; r_index++) 
	{
	  double value = 0;
	  if (cv_data_mean[r_index] != 0)
	    {
	      value =  (cv_data_array[c_index][r_index] - cv_data_mean[r_index]) / cv_data_mean[r_index];
	      if (cv_data_array[c_index][r_index] != 0) { // 0's removed from stddev calc as well
		id <Double> d_value = [Double create: scratchZone setDouble: value];
		[cv_data_final_list addLast: d_value];
	      }
	    }
	}
    }

  // Finally, calculate the standard deviation of all the numbers
  double standard_deviation = [self computeSD: cv_data_final_list];
  [cv_data_final_list drop];

  return standard_deviation;
}

+ (double) computeSD: (id <List>) dataList
{
  unsigned size = [dataList getCount];
  unsigned index;
  double sum = 0;
  for (index = 0; index < size; index++) 
    {
      sum += [[dataList atOffset: index] getDouble];
    }
  double mean = sum / (double)size;

  double sum_std = 0;
  for (index = 0; index < size; index++)
    {
      double difference =  ([[dataList atOffset: index] getDouble] - mean);
      sum_std += (difference * difference);
    }
  sum_std = sum_std / (double)size;
  double standard_deviation = sqrt(sum_std);
  return standard_deviation;
}

+ (double) computeSimilarityUsing: (id <String>) measureName 
                      trainingDat: (id <Map>) trainingDat
                         paramSet: (ParameterManagerUtils *) pm
                              nom: (id <String>) nomProfile
                       nomDataMap: (id <Map>) nomOut
                              exp: (id <String>) expProfile
                       expDataMap: (id <Map>) expOut
                          storeIn: (id <List>) simData
{
  return [self 	computeSimilarityUsing: measureName 
                      trainingDat: trainingDat
                         paramSet: pm
                              nom: nomProfile
		      columnLabel: [String create: scratchZone setC:"Average"]
                       nomDataMap: nomOut
                              exp: expProfile
                       expDataMap: expOut
		         bandCoef: 1.0
                          storeIn: simData];
}
/*
 * Computes the similarity score and saves to similarity_results.csv
 */
+ (double) computeSimilarityUsing: (id <String>) measureName 
                      trainingDat: (id <Map>) trainingDat
                         paramSet: (ParameterManagerUtils *) pm
                              nom: (id <String>) nomProfile
		      columnLabel: (id <String>) colLabel 
                       nomDataMap: (id <Map>) nomOut
                              exp: (id <String>) expProfile
                       expDataMap: (id <Map>) expOut
		         bandCoef: (double) bandCoef
                          storeIn: (id <List>) simData
{
  id <Map> trainMap = nil;
  id <Map> nomMap = nil;
  id <Map> expMap = nil;
  double similarity_score = 0.L;
  [Telem debugOut: 1 printf: "[%s(%p) -computeSimilarityUsing...] -- "
         "measureName=%s, nomProfile=%s, expProfile=%s, pm=%p\n",
         [self getName], self,
         [measureName getC], [nomProfile getC], [expProfile getC], pm];
  /*
   *  For now, all similarity metrics map to the original global standard 
   *  deviation measure. Eventually this metric will be metric '0'. 
   *    1. Get the data from the three models 
   *    2. Compute the metric parameter from the 'metricProfile' data
   *    3. Compute the similarity, using that metric parameter, between the 
   *       'experimental' and the 'nominal' profile data. 
   *  Mapping for nominal/experimental profiles: 0 = art, 1 = ref. 
   */

  if (simData == nil) simData = [List create: scratchZone];

  [simData
    addLast: 
      [Pair create: scratchZone
            setFirst: [String create: scratchZone setC: "Parameter Set"]
            second: [Integer create: scratchZone 
                             setInt: [pm getMonteCarloSet]]]];
    

  [simData 
    addLast: 
      [Pair create: scratchZone 
            setFirst: [String create: scratchZone setC: "Similarity Measure"] 
            second: [measureName copy: scratchZone]]];
  
  id <String> tempNom = [nomProfile copy: scratchZone];
  [tempNom catC: ":"];
  [tempNom catC: [colLabel getC]];
  
  [simData 
    addLast:
      [Pair create: scratchZone
            setFirst: [String create: scratchZone setC: "Nominal"]
            second: [tempNom /*nomProfile*/ copy: scratchZone]]];

  [tempNom drop];

  [simData 
    addLast: 
      [Pair create: scratchZone
            setFirst: [String create: scratchZone setC: "Experimental"]
            second: [expProfile copy: scratchZone]]];

  {
    id tempPM = nil;
    tempPM = [ParameterManagerUtils create: scratchZone];
    [tempPM setMonteCarloSet: 0xffffffff];
    // get the avg runMap for parameter set pm
    trainMap = [[trainingDat at: tempPM] at: pm];
    nomMap = [[nomOut at: tempPM] at: pm];
    expMap = [[expOut at: tempPM] at: pm];
    [tempPM drop];
  }


  if ( strcmp([measureName getC], "global_sd") == 0 ) 
    {
      /*
       * 1. Use the different data series in trainingDat to calculate the CV
       * 2. Get the nominal data series
       * 3. Get the experimental data series, compute the percentage of 
       *    time the ex pts are within CV of the nm data.
       */
      double co_var = [self computeCV: trainMap];
      [Telem debugOut: 1 printf: "[%s(%p) -computeSimilarityUsing:...] -- co_var=%f\n",
             [self getName], self, co_var];

      [simData
        addLast:
          [Pair create: scratchZone
                setFirst: [String create: scratchZone setC: "StdDev of Resid"]
                second: [Double create: scratchZone setDouble: co_var]]];

      if (co_var > 1)
        {
          raiseEvent(WarningMessage, "The computeCV() result is larger "
                     "than 1 (%g), and is unusable\n", 
                     co_var);
        }


      id <List> n_list = nil; // nominal data
      id <List> e_list = nil; // experimental data

      // XXXX - find a better way to pick which method to use

      [Telem debugOut: 5 print: "Nominal profile = \n"];
      [Telem debugOut: 5 print: [[DMM runMapToString: nomMap] getC]];
      
      if ( strcmp([nomProfile getC], "dat") == 0 ) {
	if (strcmp([colLabel getC], "Average") ==0 ) {
          n_list = [DMM getAverageDataListFromMap: nomOut paramSet: pm];
          [Telem debugOut: 5 printf: "get avg from %s\n", [nomProfile getC]];
	} else {
	  n_list = [DMM getDataListFromMap: nomMap withLabel: colLabel];
	  [Telem debugOut: 5 printf: "get column '%s' from %s\n",[colLabel getC], [nomProfile getC]];
	}
      } else {
        n_list = [DMM getDataListFromMap: nomMap pointIndex: 0];
        [Telem debugOut: 5 printf: "get column from %s\n", [nomProfile getC]];
      }

      [Telem debugOut: 5 printf: "[n_list getCount] = %d\n",
             [n_list getCount]];

      [Telem debugOut: 5 print: "Experimental profile = \n"];
      [Telem debugOut: 5 print: [[DMM runMapToString: expMap] getC]];

      if ( strcmp([expProfile getC], "dat") != 0) {
        e_list = [DMM getAverageDataListFromMap: expOut paramSet: pm];
        [Telem debugOut: 5 printf: "get avg from %s\n", [expProfile getC]];
      } else {
        e_list = [DMM getDataListFromMap: expMap pointIndex: 1];
        [Telem debugOut: 5 printf: "get column from %s\n", [expProfile getC]];
      }
      [Telem debugOut: 5 printf: "[e_list getCount] = %d\n",
             [e_list getCount]];

      // Get the minimum of num points, for direct comparison
      unsigned n_pts = [n_list getCount];
      unsigned e_pts = [e_list getCount];
      unsigned min_pts = (n_pts <= e_pts) ? n_pts : e_pts;
      
      // Now, compare each of the experimental points to each of the nominal 
      // bands (1+x, 1-x)
      unsigned num_within = 0;
      unsigned index;
      // ...and save the nominal, upper, lower, and experimental bands
      id <List> series = [List create: scratchZone];

      id <List> record = [List create: scratchZone];
      {
        id <String> tmpStr = [String create: scratchZone setC: "Param Set "];
        [tmpStr catC: [Integer intStringValue: [pm getMonteCarloSet]]];
        [record addLast: tmpStr];
      }
      [series addLast: record];

      record = [List create: scratchZone];
      [record addLast: [String create: scratchZone setC: "Nominal"]];
      [record addLast: [String create: scratchZone setC: "Upper"]];
      [record addLast: [String create: scratchZone setC: "Lower"]];
      [record addLast: [String create: scratchZone setC: "Experimental"]];
      [series addLast: record];

      for (index = 0; index < min_pts; index++) {
        double n_value = [[n_list atOffset: index] getDouble];
        double e_value = [[e_list atOffset: index] getDouble];
        double upper_value = (n_value * (1.L + co_var))*bandCoef;
        double lower_value = (n_value * (1.L - co_var))/bandCoef;

        record = [List create: scratchZone];
        [record addLast: [Double create: scratchZone setDouble: n_value]];
        [record addLast: [Double create: scratchZone setDouble: upper_value]];
        [record addLast: [Double create: scratchZone setDouble: lower_value]];
        [record addLast: [Double create: scratchZone setDouble: e_value]];
        [series addLast: record];

        if ((e_value <= upper_value /*(n_value * (1.L + co_var))*/) &&
            (e_value >= lower_value /*(n_value * (1.L - co_var))*/)) 
          {
            num_within++;
          }
      }
      [n_list drop];
      [e_list drop];

      [simData 
        addLast: [Pair create: scratchZone
                       setFirst: [String create: scratchZone setC: "Series"]
                       second: series]];

      [simData
        addLast: 
          [Pair create: scratchZone
                setFirst: [String create: scratchZone setC: "Nom Points"]
                second: [Integer create: scratchZone setInt: n_pts]]];

      [simData
        addLast: 
          [Pair create: scratchZone
                setFirst: [String create: scratchZone setC: "Exp Points"]
                second: [Integer create: scratchZone setInt: e_pts]]];

      [simData
        addLast: 
          [Pair create: scratchZone
                setFirst: [String create: scratchZone setC: "Pts In Band"]
                second: [Integer create: scratchZone setInt: num_within]]];

      [simData
        addLast: 
          [Pair create: scratchZone
                setFirst: [String create: scratchZone setC: "Total Points"]
                second: [Integer create: scratchZone setInt: min_pts]]];

      similarity_score = ((double)num_within)/((double)min_pts);
    } //   if ( strcmp([measureName getC], "global_sd") == 0 ) 

  [simData
    addLast: 
      [Pair create: scratchZone
            setFirst: [String create: scratchZone setC: "Similarity"]
            second: [Double create: scratchZone setDouble: similarity_score]]];
  
  return similarity_score;
}

@end
