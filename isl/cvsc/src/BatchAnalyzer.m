/*
 * BatchAnalyzer
 *
 * Copyright 2003-2008 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#include "BatchAnalyzer.h"

@implementation BatchAnalyzer


//
// find the largest similarity value from the list of similarity values
//
// parameters:
//    result: IN  : a list of simulation results
//    size  : IN  : a length of the list 
// return:
//    the largest similarity value
//
- (double) findMaxSimilarity: (double *) result length: (int) size 
{
  int idx;
  return [self findMaxSimilarity: result length: size in: &idx];
}

//
// find the largest similarity value from the list of similarity values
//
// parameters:
//    result: IN  : a list of simulation results
//    size  : IN  : a length of the list 
//    idx   : OUT : an idex of the list containg the largest similarity value
// return:
//    the largest similarity value
//
- (double) findMaxSimilarity: (double *) result length: (int) size in: (int *) idx
{
  int i;
  double max = result[0];
  *idx = 0;
  for(i = 1; i < size; i++) 
    if(result[i] > max) 
      {
	max = result[i];
	*idx = i;
      }
  return max;
}


//
// find the smallest similarity value from the list of similarity values
//
// parameters:
//    result: IN  : a list of simulation results
//    size  : IN  : a length of the list 
// return:
//    the smallest similarity value
//
- (double) findMinSimilarity: (double *) result length: (int) size 
{
  int idx;
  return [self findMinSimilarity: result length: size in: &idx];
}

//
// find the smallest similarity value from the list of similarity values
//
// parameters:
//    result: IN  : a list of simulation results
//    size  : IN  : a length of the list 
//    idx   : OUT : an idex of the list containg the smallest similarity value
// return:
//    the largest similarity value
//
- (double) findMinSimilarity: (double *) result length: (int) size in: (int *) idx
{
  int i;
  double min = result[0];
  *idx = 0;
  for(i = 1; i < size; i++) 
    if(result[i] < min)
      {
	min = result[i];
	*idx = i;
      }
  return min;
}

//
// find the longest execution time
//
// parameters:
//    result: IN  : a list of execution time
//    size  : IN  : a length of the list 
// return:
//    the longest execution value
//
- (double) findMaxExecutionTime: (double *) result length: (int) size 
{
  int idx;
  return [self findMaxExecutionTime: result length: size in: &idx];
}

//
// find the longest execution time
//
// parameters:
//    result: IN  : a list of execution time
//    size  : IN  : a length of the list 
//    idx   : OUT : an idex of the list containg the largest execution time
// return:
//    the longest similarity value
//
- (double) findMaxExecutionTime: (double *) result length: (int) size in: (int *) idx
{
  int i;
  double max = result[0];
  *idx = 0;
  for(i = 1; i < size; i++) 
    if(result[i] > max) 
      {
	max = result[i];
	*idx = i;
      }
  return max;
}


//
// create a file that will contains batch analysis result
//
// parameters:
//    number: IN : a batch set id (e.g., processor rank)
// return:
//    self
//
- createFileForProcessor: (int) number
{
  return [self createFileForProcessor: number baseDir: '\0'];
}

//
// create a file that will contains batch analysis result
//
// parameters:
//    number: IN : a batch set id (e.g., processor rank)
//    prefix: IN : file prefix 
// return:
//    self
//
- createFileForProcessor: (int) number baseDir: (const char *) dir
{
  id <String> bDir = [String create: [self getZone] setC: "outputs"];
  [bDir catC: DIR_SEPARATOR];

  if(dir != '\0') 
    {
      [bDir catC: dir];
      [DMM checkAndCreateDir: bDir];
      [bDir catC: DIR_SEPARATOR];
    }
  [bDir catC: "BatchAnalysis."];

  rank = number;
  id <String> fn = [bDir copy: globalZone];
  char suffix[128];
  sprintf(suffix, "proc%d", number); 
  [fn catC: suffix];
  id <String> sfn = [fn copy: [self getZone]];
  [sfn catC: "-similarity"];
  id <String> tfn = [fn copy: [self getZone]];
  [tfn catC: "-exectime"];
  sfp = [DMM openNewFile: sfn];
  tfp = [DMM openNewFile: tfn];
  return self;
}

//
// record all similarity values 
//
// parameters:
//    values : IN : a list of similarity values
//    names  : IN : a list of parameter file names
//    length : IN : a length of the similarity list
// return:
//    self
//
- recordAllSimilarities: (double *) values  withNames: (char [][256]) names length: (int) size
{
  return [self recordAllSimilarities: values withNames: names length: size
	       withMessage: (char *) nil];
} 

//
// record all similarity values 
//
// parameters:
//    values : IN : a list of similarity values
//    names  : IN : a list of parameter file names
//    length : IN : a length of the similarity list
// return:
//    self
//
- recordAllSimilarities: (double *) values  withNames: (char [][256]) names length: (int) size
	    withMessage: (char *) msg
{
  int idx;
  [self recordMessage: "=====================================================\n" to: sfp];
  for(idx = 0; idx < size; idx++)
    [self recordSimilarity: values[idx] withName: names[idx] withMessage: msg];
  [self recordMessage: "=====================================================\n" to: sfp];
  return self;
} 


//
// record all execution time information 
//
// parameters:
//    values : IN : a list of execution times
//    names  : IN : a list of paremeter file names
//    length : IN : a length of the executition time list
// return:
//    self
//
- recordAllExecutionTime: (double *) values  withNames: (char [][256]) names length: (int) size
{
  return [self recordAllExecutionTime: values withNames: names length: size
	       withMessage: (char *) nil];
} 

//
// record all execution time information 
//
// parameters:
//    values : IN : a list of execution times
//    names  : IN : a list of paremeter file names
//    length : IN : a length of the executition time list
// return:
//    self
//
- recordAllExecutionTime: (double *) values  withNames: (char [][256]) names length: (int) size
	    withMessage: (char *) msg
{
  int idx;
  [self recordMessage: "=====================================================\n" to: tfp];
  for(idx = 0; idx < size; idx++)
    [self recordExecutionTime: values[idx] withName: names[idx] withMessage: msg];
  [self recordMessage: "=====================================================\n" to: tfp];
  return self;
}

//
// record a similarity value 
//
// parameters:
//    value: IN : similarity value
//    msg  : IN : a message for the value
// return:
//    self
//
- recordSimilarity: (double) value withMessage: (char *) msg
{
  return [self recordSimilarity: value withName: (char *) nil withMessage: msg];
}

//
// record a similarity value 
//
// parameters:
//    value: IN : similarity value
//    name : IN : a parameter file associated with the value
//    msg  : IN : a message for the value
// return:
//    self
//
- recordSimilarity: (double) value withName: (char *) name withMessage: (char *) msg
{
  char message[256];
  if(name == (char *)nil)
    sprintf(message, ":: Similarity: %g    ; %s\n", value,  msg); 
  else 
    sprintf(message, "%s:: Similarity: %g   ; %s\n", name, value, msg);
  return [self recordMessage: message to: sfp];
}

//
// record in silico experiment time 
//
// parameters:
//    value: IN : experiment time
//    name : IN : a parameter file associated with the value
//    msg  : IN : a message for the value
// return:
//    self
//
- recordExecutionTime: (double) value withName: (char *) name withMessage: (char *) msg
{
  char message[256];
  if(name == (char *)nil)
    sprintf(message, ":: Execution Time: %f second    ; %s\n", value,  msg); 
  else 
    sprintf(message, "%s:: Execution time: %f sec.  ; %s\n", name, value, msg);
  return [self recordMessage: message to: tfp];
}


//
// record a message to an associate file 
//
// parameters:
//    msg  : IN : a message 
// return:
//    self
//
- recordMessage: (char *) msg to: (FILE *) fp
{
  fprintf(fp, "%s", msg);
  return self;
}

//
// misc.
//
- setBaseDir: (const char *) dir
{
  baseDir = (char *)dir;
  return self;
}

//
// object life time
//
+ createBegin: aZone
{
  BatchAnalyzer *obj;
  obj = [super createBegin: aZone];
  obj->baseDir = '\0';
  return obj;
}

- createEnd
{
  return [super createEnd];
}

- drop
{
  [DMM closeFile: sfp];
  [DMM closeFile: tfp];
  return self;
}

@end
