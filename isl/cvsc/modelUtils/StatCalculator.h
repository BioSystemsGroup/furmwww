/*
 * IPRL - Statistics Calculator
 *
 * Copyright 2003 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <collections.h>
#import <objectbase/SwarmObject.h>

#import "modelUtils.h"
#import "ParameterManagerUtils.h"

@interface StatCalculator: SwarmObject <StatCalculator>
{
}
+ (const char *)getName;
+ sumUpDM: (id <Map>) dataMap forPM: pm;
+ (void) addDataPoint: (id <Map>) dp1 to: (id <Map>) dp2;
+ (void) divide: (double) scalar intoDataPoint: (id <Map>) dp;
+ (double) computeCV: (id <Map>) dataMap; 
+ (double) computeSD: (id <List>) dataList;
+ (double) computeSimilarityUsing: (id <String>) measureName 
                      trainingDat: (id <Map>) trainingDat
                         paramSet: (ParameterManagerUtils *) pm
                              nom: (id <String>) nomProfile
                       nomDataMap: (id <Map>) nomOut
                              exp: (id <String>) expProfile
                       expDataMap: (id <Map>) expOut
                          storeIn: (id <List>) simData;
+ (double) computeSimilarityUsing: (id <String>) measureName 
                      trainingDat: (id <Map>) trainingDat
                         paramSet: (ParameterManagerUtils *) pm
                              nom: (id <String>) nomProfile 
		      columnLabel: (id <String>) colLabel 
                       nomDataMap: (id <Map>) nomOut
                              exp: (id <String>) expProfile
                       expDataMap: (id <Map>) expOut
		         bandCoef: (double) bandCoef
                          storeIn: (id <List>) simData;
@end
