/*
 * IPRL - CSV formatted Data Model
 *
 * Copyright 2003-2008 - Regents of the University of California, San
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

#import <stdlib.h>
#import <malloc.h>
#import <math.h> // for NAN
#import <float.h> // for FLT_MIN

#import "CSVDatModel.h"
#import <modelUtils.h>
#import "protocols.h"

@implementation CSVDatModel

- (id) _getTime_
{
  id retVal = nil;
  float *val = (float *)nil;

  if (dataNdx < numRows) {
    val = (float *)[[self getZone] alloc: sizeof(float)];
    *val = data[dataNdx][0];
    retVal = (id)val;
  }
  return retVal;
}

- (id <Map>) getOutputFractions
{
  id <Map> vals = nil;
  float val = NAN;

  unsigned localDataNdx = dataNdx-1; // post-step data gathering

  if (localDataNdx >= 0) {
    vals = [Map create: globalZone];
    unsigned fNdx = 1U; // skip Time

    for ( fNdx = 1U ; fNdx < numColumns ; fNdx++ ) {
      val = data[localDataNdx][fNdx];
      [vals at: [[labels atOffset: fNdx] copy: globalZone]
            insert: [Double create: globalZone setDouble: val]];
    }
  }

  return vals;
}

- (float) getOutputFraction 
{
  unsigned localDataNdx = dataNdx - 1; // looking backward a step
  if (localDataNdx >= 0)
    return data[localDataNdx][1];
  else
    return NAN;
}

- (id <Map>) getOutputs
{
  id <Map> retVal = nil;
  unsigned localDataNdx = dataNdx - 1; // looking backward
  if (localDataNdx >= 0) {
    retVal = [self getOutputFractions];
    if (retVal != nil) {
      id <String> ts = [[labels atOffset: 0] copy: globalZone];
      id <Double> v = [Double create: globalZone
                              setDouble: data[localDataNdx][0]];
      if (![retVal at: ts insert: v])
        [retVal at: ts replace: v];
    }
  }

  return retVal;
}

- (id <Map>) getOutputsInterpolatedAt: (float) tmid
{
  id <Map> dataPt = nil;
  int tmpDataNdx = dataNdx-1;
  float time = data[tmpDataNdx][0];

  // find where tmid sits in valData
  while ( (time < tmid) 
          && (tmpDataNdx >= 0)
          && (tmpDataNdx < numRows) ) {
    tmpDataNdx++;
    time = data[tmpDataNdx][0];
  }

  dataPt = [Map create: globalZone];

  // insert the time value into the data point
  [dataPt at: [[labels atOffset: 0] copy: globalZone]
          insert: [Double create: globalZone setDouble: tmid]];

  // if we're near an observation, use it
  if ( (tmpDataNdx >= numRows)
       || (tmpDataNdx <= 0) 
       || ((tmid - FLT_MIN) <= time && time <= (tmid + FLT_MIN)) ) {

    [Telem debugOut: 4 print: "DatModel direct\n"];

    // get the data
    id <Map> tmpDataPt = [self getOutputs];

    // copy that data to dataPt
    id <MapIndex> dpNdx = [tmpDataPt mapBegin: scratchZone];
    id val = nil, key = nil;
    while (([dpNdx getLoc] != End) &&
           ((val = [dpNdx next: &key]) != nil)) {
      [dataPt at: key insert: val];
    }
    [tmpDataPt drop];
    [dpNdx drop];

  } else { // do the interpolation

    // time should end up > tmid
    float ttop = data[tmpDataNdx][0];
    float tbot = data[(tmpDataNdx-1)][0];
    float ratio = (tmid - tbot)/(ttop - tbot);

    [Telem debugOut: 4 printf: "DatModel -- interpolated\n"
           "tbot = %lf, tmid = %lf, ttop = %lf, ratio = %lf\n",
           tbot, tmid, ttop, ratio];

    unsigned fNdx = 1U;
    for ( fNdx = 1U ; fNdx < numColumns ; fNdx++ ) {
      float vtop = data[tmpDataNdx][fNdx];
      float vbot = data[(tmpDataNdx-1)][fNdx];
      float vmid = vbot + ratio*(vtop-vbot);

      [Telem debugOut: 4 printf: "DatModel -- interpolated\n"
             "vbot = %lf, vmid = %lf, vtop = %lf\n",
             vbot, vmid, vtop];

      [dataPt at: [[labels atOffset: fNdx] copy: globalZone] 
              insert: [Double create: globalZone setDouble: vmid]];
    } // end for ( fNdx = 1U ; fNdx < numColumns ; fNdx++ )

  } // end interpolation branch

  return dataPt;
}


- (int) _loadData_
{
  int errors = 0;
  id <LiverDMM> dMM = [(id <ExperAgent>)_parent getDMM];
  labels = [List create: [self getZone]];
  id <String> fileName = [dMM getValDataFileName];
  FILE *file = [DMM openInputFile: fileName];
  id <List> data_l = [List create: scratchZone];

  unsigned fNdx = 0U;  // local field index
  unsigned rNdx = 0U;  // local record index

  // load and parse the file
  const unsigned LINE_LENGTH = 512;
  unsigned numLines = 0U; // total lines
  unsigned numValidLines = 0U; // lines of data ignoring comments
  char tmp[LINE_LENGTH];
  while (fgets(tmp, LINE_LENGTH, file) != NULL) {
    numLines++;
    // allow comments 
    if (tmp[0] == '#') continue;

    if (strrchr(tmp, '\n') == NULL)
      raiseEvent(LoadError, "%s line number %d is longer than %d.\n", 
                 fileName, numLines, LINE_LENGTH);

    numValidLines++;
    /**
     * parse the line
     */

    // remove the new line character
    char *nl = strchr(tmp, '\n');
    nl[0] = '\0';

    const char * delim = ",";
    char *tok;
    if (numValidLines == 1) { // get labels from the first line
      tok = strtok(tmp, delim);
      do {

        [labels addLast: [String create: [self getZone] setC: tok]];

      } while ((tok = strtok(NULL, delim)) != NULL);
    } else {            // get the data from the rest
      unsigned numFields = [labels getCount];
      id <Array> record = [Array create: scratchZone setCount: numFields];
      fNdx = 0U;
      tok = strtok(tmp, delim);
      do {
        if (fNdx >= numFields)
          raiseEvent(LoadError, "%s line %d has too many fields.",
                     fileName, numLines);

        [record atOffset: fNdx++ put: [Double create: scratchZone setDouble: atof(tok)]];

      } while ((tok = strtok(NULL, delim)) != NULL);
      [data_l addLast: record];
    }

  }

  // transfer the data from the list to an array
  unsigned numRec = [data_l getCount];
  unsigned numFields = [labels getCount];
  data = (float **) calloc (numRec, sizeof(float *));

  for (rNdx = 0U ; rNdx < numRec ; rNdx++ )
    data[rNdx] = (float *) calloc(numFields, sizeof(float));

  id val = nil;
  rNdx = 0U;
  id <ListIndex> lNdx = [data_l listBegin: scratchZone];
  while (([lNdx getLoc] != End) &&
         ( (val = [lNdx next]) != nil) ) {
    id <Array> record = (id <Array>) val;
    for ( fNdx = 0U ; fNdx < [record getCount] ; fNdx++ ) {
      Double *d = [record atOffset: fNdx];
      data[rNdx][fNdx] = [d getDouble];
    }
    rNdx++;
  }
  [lNdx drop];

  numRows = numRec;
  numObservations = numRows;
  numColumns = numFields;

  //clean up
  [data_l drop]; data_l = nil;


  /**
   * build the drug->sucrose-with-drug map
   */
  // create and init the d2s map to "-1", which indicates no target
  d2sMap = (int *) calloc(numColumns, sizeof(int));
  for ( fNdx = 0U ; fNdx < numColumns ; fNdx++ )
    d2sMap[fNdx] = NO_D2S_TARGET;

  // loop through non-Sucrose labels
  char *drug = NULL;
  for ( fNdx = 1U ; fNdx < numColumns ; fNdx++ ) {
    const char *label = [[labels atOffset: fNdx] getC];
    // skip the plain sucrose labels
    if ( strstr(label, "Sucrose") != NULL ) continue;

    drug = (char *) calloc(strlen(label)+1, sizeof(char));
    strcpy(drug, label);
    char *end = strchr(drug, DRUG_NAME_DELIMITER);
    if ( end != NULL ) end[0] = '\0';
    // now drug contains the characters before the '-'

    id <String> sucwith = [String create: scratchZone setC: "Sucrose-with-"];
    [sucwith catC: drug];
    free(drug);
    unsigned f2Ndx = 0U;
    for ( f2Ndx = fNdx ; f2Ndx < numColumns ; f2Ndx++ ) {
      const char *label2 = [[labels atOffset: f2Ndx] getC];
      if (strcmp([sucwith getC], label2) == 0) 
        d2sMap[fNdx] = f2Ndx;
    }

  }
  


  { // report on what we've done
    [Telem monitorOut: 1 print: "\nCSVDatModel loaded:"];
    [Telem monitorOut: 1 print: "labels = ["];
    unsigned labelNdx=0U;
    for ( labelNdx = 0U ; labelNdx < numColumns ; labelNdx++ ) {
      [Telem monitorOut: 1 printf: " %s", [[labels atOffset: labelNdx] getC]];
      if ( labelNdx < numColumns-1) [Telem monitorOut: 1 print: ","];
    }
    [Telem monitorOut: 1 print: "]\n"];
    [Telem monitorOut: 1 printf: "data[%d][%d] = \n", numRows, numColumns];
    for ( rNdx = 0U ; rNdx < numRows ; rNdx++ ) {
      unsigned fNdx = 0U;
      for ( fNdx = 0U ; fNdx < numColumns ; fNdx++ ) {
        [Telem monitorOut: 1 printf: " %12.9g", data[rNdx][fNdx]];
        if ( fNdx < numColumns-1 )
          [Telem monitorOut: 1 print: ","];
      }
      [Telem monitorOut: 1 print: "\n"];
    }
    [Telem monitorOut: 1 print: "\n"];

    [Telem monitorOut: 1 printf: "d2sMap[%d] = [", numColumns];
    for ( labelNdx = 0U ; labelNdx < numColumns ; labelNdx++ )
      [Telem monitorOut: 1 printf: " %d%s", d2sMap[labelNdx], 
             (labelNdx == numColumns-1 ? "]\n" : ",")];
  }

  return errors;
}

- buildObjects
{
  if ([self _loadData_] > 0)
    raiseEvent(LoadError, "Could not load validation Data.\n");
  return self;
}

- drop
{
  free(d2sMap);
  d2sMap = (int *)nil;
  int rNdx = 0U;
  for (rNdx = 0U ; rNdx < numRows ; rNdx++ )
    free(data[rNdx]);
  free(data);
  data = (float **)nil;
  [super drop];
  return self;;
}

- step
{
  // just print values to the monitor file
  [Telem monitorOut: 1 printf: "\n%s:  %7.2f", [self getName],
         data[dataNdx][0]];
  unsigned cNdx=0U;
  for ( cNdx = 1U ; cNdx < numColumns ; cNdx++ ) {
    [Telem monitorOut: 1 printf: " %13e", data[dataNdx][cNdx]];
  }
  [Telem monitorOut: 1 print: "\n"];

  // increments cycle and dataNdx
  return [super step];
}


@end
