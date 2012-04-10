/*
 * IPRL - Data Model
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

#import "HDFDatModel.h"
#import <Double.h>
#import <activity.h>
#import <collections.h>
#import <random.h>
#import <modelUtils.h>

@implementation HDFDatModel  

+ createBegin: aZone
{
  HDFDatModel *obj;
  obj = [super createBegin: aZone];

  obj->valRank = 0U;
  obj->valDims = (size_t *)nil;
  obj->timeData = (float *) nil;
  obj->antData = (float *) nil;
  obj->antSucData = (float *) nil;
  obj->ateData = (float *) nil;
  obj->ateSucData = (float *) nil;
  obj->dilData = (float *) nil;
  obj->dilSucData = (float *) nil;
  obj->labData = (float *) nil;
  obj->labSucData = (float *) nil;
  obj->praData = (float *) nil;
  obj->praSucData = (float *) nil;
  obj->proData = (float *) nil;
  obj->proSucData = (float *) nil;

  return obj;
}

// These methods provide access to the objects inside the DatModel.

// if you call this, you should free this memory.
- (id) _getTime_
{
  float *nt = (float *)nil;
  if (dataNdx >= valDims[0]) 
    return nil;
  nt = (float *)[[self getZone] alloc: sizeof(float)];
  // copy value into new spot
  *nt = ((float *)timeData)[dataNdx];
  //memcpy(nt, timeData+dataNdx, sizeof(float));
  return (id)nt;
}

/*
 * getOutputFractions - 
 *
 */
- (id <Map>) getOutputFractions
{
  id <Map> vals = nil;
  float val;

  int localDataNdx = dataNdx-1; // post-step data gathering

  // check to see that we're in the datmodel domain
  if (localDataNdx >= 0) {
    vals = [Map create: globalZone];
    // antipyrine
    val = antData[localDataNdx*valDims[valRank-1]];
    [vals at: [antLabel copy: globalZone] 
          insert: [Double create: globalZone setDouble: val]];
    val = antSucData[localDataNdx*valDims[valRank-1]];
    [vals at: [antSucLabel copy: globalZone] 
          insert: [Double create: globalZone setDouble: val]];

    // atenolol
    val = ateData[localDataNdx*valDims[valRank-1]];
    [vals at: [ateLabel copy: globalZone] 
          insert: [Double create: globalZone setDouble: val]];
    val = ateSucData[localDataNdx*valDims[valRank-1]];
    [vals at: [ateSucLabel copy: globalZone] 
          insert: [Double create: globalZone setDouble: val]];

    // diltiazem
    val = dilData[localDataNdx*valDims[valRank-1]];
    [vals at: [dilLabel copy: globalZone] 
          insert: [Double create: globalZone setDouble: val]];
    val = dilSucData[localDataNdx*valDims[valRank-1]];
    [vals at: [dilSucLabel copy: globalZone] 
          insert: [Double create: globalZone setDouble: val]];

    // labetalol
    val = labData[localDataNdx*valDims[valRank-1]];
    [vals at: [labLabel copy: globalZone] 
          insert: [Double create: globalZone setDouble: val]];
    val = labSucData[localDataNdx*valDims[valRank-1]];
    [vals at: [labSucLabel copy: globalZone] 
          insert: [Double create: globalZone setDouble: val]];

    // prazosin
    val = praData[localDataNdx*valDims[valRank-1]];
    [vals at: [praLabel copy: globalZone] 
          insert: [Double create: globalZone setDouble: val]];
    val = praSucData[localDataNdx*valDims[valRank-1]];
    [vals at: [praSucLabel copy: globalZone] 
          insert: [Double create: globalZone setDouble: val]];

    // propranolol
    val = proData[localDataNdx*valDims[valRank-1]];
    [vals at: [proLabel copy: globalZone] 
          insert: [Double create: globalZone setDouble: val]];
    val = proSucData[localDataNdx*valDims[valRank-1]];
    [vals at: [proSucLabel copy: globalZone] 
          insert: [Double create: globalZone setDouble: val]];

  }

  return vals;
}

- (float) getOutputFraction 
{
  int localDataNdx = dataNdx-1; // post-step data gathering
  if (localDataNdx >= 0)
    return antData[localDataNdx*valDims[valRank-1]];
  else
    return NAN;
}

- (id <List>) getOutputNames {
  return labels;
}

// just for compliance with the other models -- should survive drop
- (id <Map>) getOutputs
{
  id <Map> data = [self getOutputFractions];
  id <String> ts = nil;
  id <Double> v = nil;

  int localDataNdx = dataNdx - 1; // post-step data gathering

  if (data != nil && localDataNdx >= 0) {
    // prepend the time to the data to get a complete vector
    v = [Double create: globalZone 
                setDouble: timeData[localDataNdx]];
    ts = [timeLabel copy: globalZone];
    if (![data at: ts insert: v])
      [data at: ts replace: v];
  } else {
    if (data != nil) [data drop];
    return nil;
  }

  return data;
}


#import <float.h>
- (id <Map>) getOutputsInterpolatedAt: (float) tmid
{
  id <Map> dataPt = nil;
  int tmpDataNdx=dataNdx-1;
  float time=((float *)timeData)[tmpDataNdx];

  // find where tmid sits in valData
  while ( (time < tmid) 
          && (tmpDataNdx >= 0)
          && (tmpDataNdx < valDims[0]) ) {
    tmpDataNdx++;
    time = ((float *)timeData)[tmpDataNdx];
    [Telem debugOut: 4 printf: "DatModel -- next time = %lf\n", time];
  }

  if ( (tmpDataNdx >= valDims[0]) 
       || (tmpDataNdx <= 0) 
       || ((tmid - FLT_MIN) <= time && time <= (tmid + FLT_MIN)) )
    dataPt = [self getOutputs];
  else { // do the interpolation
    // time should end up > tmid
    float ttop = ((float *)timeData)[tmpDataNdx];
    float tbot = ((float *)timeData)[(tmpDataNdx-1)];
    float ratio = (tmid - tbot)/(ttop - tbot);

    [Telem debugOut: 5 printf: "DatModel -- interpolated\n"
           "tbot = %lf, tmid = %lf, ttop = %lf, ratio = %lf\n",
           tbot, tmid, ttop, ratio];

    dataPt = [Map create: globalZone];

    [dataPt at: [String create: globalZone setC: "Time"]
            insert: [Double create: globalZone setDouble: tmid]];

    // antipyrine
    float vtop = antData[tmpDataNdx*valDims[valRank-1]];
    float vbot = antData[(tmpDataNdx-1)*valDims[valRank-1]];
    float vmid = vbot + ratio*(vtop-vbot);
    [dataPt at: [antLabel copy: globalZone] 
            insert: [Double create: globalZone setDouble: vmid]];
    vtop = antSucData[tmpDataNdx*valDims[valRank-1]];
    vbot = antSucData[(tmpDataNdx-1)*valDims[valRank-1]];
    vmid = vbot + ratio*(vtop-vbot);
    [dataPt at: [antSucLabel copy: globalZone] 
            insert: [Double create: globalZone setDouble: vmid]];

    [Telem debugOut: 5 printf: "\tvbot = %f, vmid = %f, ttop = %f\n",
           vbot, vmid, vtop];

    // atenolol
    vtop = ateData[tmpDataNdx*valDims[valRank-1]];
    vbot = ateData[(tmpDataNdx-1)*valDims[valRank-1]];
    vmid = vbot + ratio*(vtop-vbot);
    [dataPt at: [ateLabel copy: globalZone] 
            insert: [Double create: globalZone setDouble: vmid]];
    vtop = ateSucData[tmpDataNdx*valDims[valRank-1]];
    vbot = ateSucData[(tmpDataNdx-1)*valDims[valRank-1]];
    vmid = vbot + ratio*(vtop-vbot);
    [dataPt at: [ateSucLabel copy: globalZone] 
            insert: [Double create: globalZone setDouble: vmid]];

    // diltiazem
    vtop = dilData[tmpDataNdx*valDims[valRank-1]];
    vbot = dilData[(tmpDataNdx-1)*valDims[valRank-1]];
    vmid = vbot + ratio*(vtop-vbot);
    [dataPt at: [dilLabel copy: globalZone] 
            insert: [Double create: globalZone setDouble: vmid]];
    vtop = dilSucData[tmpDataNdx*valDims[valRank-1]];
    vbot = dilSucData[(tmpDataNdx-1)*valDims[valRank-1]];
    vmid = vbot + ratio*(vtop-vbot);
    [dataPt at: [dilSucLabel copy: globalZone] 
            insert: [Double create: globalZone setDouble: vmid]];

    // labetalol
    vtop = labData[tmpDataNdx*valDims[valRank-1]];
    vbot = labData[(tmpDataNdx-1)*valDims[valRank-1]];
    vmid = vbot + ratio*(vtop-vbot);
    [dataPt at: [labLabel copy: globalZone] 
            insert: [Double create: globalZone setDouble: vmid]];
    vtop = labSucData[tmpDataNdx*valDims[valRank-1]];
    vbot = labSucData[(tmpDataNdx-1)*valDims[valRank-1]];
    vmid = vbot + ratio*(vtop-vbot);
    [dataPt at: [labSucLabel copy: globalZone] 
            insert: [Double create: globalZone setDouble: vmid]];

    // prazosin
    vtop = praData[tmpDataNdx*valDims[valRank-1]];
    vbot = praData[(tmpDataNdx-1)*valDims[valRank-1]];
    vmid = vbot + ratio*(vtop-vbot);
    [dataPt at: [praLabel copy: globalZone] 
            insert: [Double create: globalZone setDouble: vmid]];
    vtop = praSucData[tmpDataNdx*valDims[valRank-1]];
    vbot = praSucData[(tmpDataNdx-1)*valDims[valRank-1]];
    vmid = vbot + ratio*(vtop-vbot);
    [dataPt at: [praSucLabel copy: globalZone] 
            insert: [Double create: globalZone setDouble: vmid]];

    // proprenolol
    vtop = proData[tmpDataNdx*valDims[valRank-1]];
    vbot = proData[(tmpDataNdx-1)*valDims[valRank-1]];
    vmid = vbot + ratio*(vtop-vbot);
    [dataPt at: [proLabel copy: globalZone] 
            insert: [Double create: globalZone setDouble: vmid]];
    vtop = proSucData[tmpDataNdx*valDims[valRank-1]];
    vbot = proSucData[(tmpDataNdx-1)*valDims[valRank-1]];
    vmid = vbot + ratio*(vtop-vbot);
    [dataPt at: [proSucLabel copy: globalZone] 
            insert: [Double create: globalZone setDouble: vmid]];

  }

  return dataPt;
}


- createHDF5NodeKey: (const char *)nodeName mode: (const char *)modeName
{
  id appKey = [String create: [self getZone] setC: nodeName];

  [appKey catC: "/"];
  [appKey catC: modeName];
  return appKey;
}

- _setValRank_: (int) r {
  if (r < 1)
    raiseEvent(InvalidArgument,"Validation data cannot be a scalar. "
               "Rank must be greater than 0.");
  valRank = r;
  return self;
}

- _setValDims_: (size_t *)d {
  int ndx;

  if (valRank < 1)
    raiseEvent(OffsetOutOfRange,"Validation data cannot be a scalar. "
               "Rank must be greater than 0.");
  for (ndx=0;ndx<valRank;ndx++)
    assert(d[ndx] > 0);

  valDims = d;

  return self;
}

- (int) _loadData_
{
  int errors = -1;
  id <HDF5> jpet297, dsgroup, vdgroup, expgroup, timeObject;
  //  id <HDF5> jpet297Data, sucrosegroup;

  id <HDF5> antgroup, antObject, antSucObject;
  id <HDF5> ategroup, ateObject, ateSucObject;
  id <HDF5> dilgroup, dilObject, dilSucObject;
  id <HDF5> labgroup, labObject, labSucObject;
  id <HDF5> pragroup, praObject, praSucObject;
  id <HDF5> progroup, proObject, proSucObject;
  int ndx; 
  int numDims;

  size_t *dims = (size_t *)nil;

  // Load the dataset
  jpet297 = [HDF5 createBegin: self];
  [jpet297 setName: "./inputs/jpet297-fig2.hdf"];
  jpet297 = [jpet297 createEnd];

  dsgroup = [[[[[[HDF5 createBegin: self] setParent: jpet297] setWriteFlag: NO]
                setDatasetFlag: NO] setName: "DataSwarm"] createEnd];
  vdgroup = [[[[[[HDF5 createBegin: self] setParent: dsgroup] setWriteFlag: NO]
                setDatasetFlag: NO] setName: "ValidationData"] createEnd];
  expgroup = [[[[[[HDF5 createBegin: self] setParent: vdgroup] setWriteFlag: NO]
                setDatasetFlag: NO] setName: "JPET297-fig2-all"] createEnd];

  // Time
  timeObject = [[[[[[HDF5 createBegin: self] setParent: expgroup] setWriteFlag: NO]
                setDatasetFlag: YES] setName: "Time"] createEnd];
  [Telem debugOut: 1 printf: "timeData rank = %d\n", [timeObject getDatasetRank]];
  int i=0;
  for ( i=0 ; i<[timeObject getDatasetRank] ; i++ )
    [Telem debugOut: 1 printf: "\tdim[%d] = %d\n", i, [timeObject getDatasetDimension: i]];

  int timeDim = [timeObject getDatasetDimension: 0];
  timeData = [[self getZone] alloc: timeDim*sizeof(float)];
  [timeObject loadDataset: timeData];

  /*
   * Antipyrine
   */
  antgroup = [[[[[[HDF5 createBegin: self] setParent: expgroup] setWriteFlag: NO]
                 setDatasetFlag: NO] setName: "Antipyrine"] createEnd];
  antObject = [[[[[[HDF5 createBegin: self] setParent: antgroup] setWriteFlag: NO]
                setDatasetFlag: YES] setName: "Antipyrine"] createEnd];

  [Telem debugOut: 1 printf: "drug and sucrose Objects have rank = %d\n",
         [antObject getDatasetRank]];
  for ( i=0 ; i<[antObject getDatasetRank] ; i++ )
    [Telem debugOut: 1 printf: "\tdim[%d] = %d\n", i, 
           [antObject getDatasetDimension: i]];

  antSucObject = [[[[[[HDF5 createBegin: self] setParent: antgroup] setWriteFlag: NO]
                   setDatasetFlag: YES] setName: "Sucrose"] createEnd];

  // rank for time is 1, same rank applies for each subsequent data object
  numDims = [antObject getDatasetRank];
  [self _setValRank_: numDims];

  dims = [[self getZone] alloc: numDims*sizeof(size_t)];
  int dimProduct = 1;
  for ( ndx=0 ; ndx<numDims ; ndx++ ) {
    dims[ndx] = [antObject getDatasetDimension: ndx];
    dimProduct *= dims[ndx];
  }
  [self _setValDims_: dims];

  // sanity check that the time array is the same size as the other
  assert(dims[0] == timeDim);

  // define and load the C arrays
  antData = [[self getZone] alloc: dimProduct*sizeof(float)];
  [antObject loadDataset: antData];
  antSucData = [[self getZone] alloc: dimProduct*sizeof(float)];
  [antSucObject loadDataset: antSucData];

  /*
   * Atenolol
   */
  ategroup = [[[[[[HDF5 createBegin: self] setParent: expgroup] setWriteFlag: NO]
                 setDatasetFlag: NO] setName: "Atenolol"] createEnd];
  ateObject = [[[[[[HDF5 createBegin: self] setParent: ategroup] setWriteFlag: NO]
                setDatasetFlag: YES] setName: "Atenolol"] createEnd];
  ateSucObject = [[[[[[HDF5 createBegin: self] setParent: ategroup] setWriteFlag: NO]
                   setDatasetFlag: YES] setName: "Sucrose"] createEnd];

  // define and load the C arrays
  ateData = [[self getZone] alloc: dimProduct*sizeof(float)];
  [ateObject loadDataset: ateData];
  ateSucData = [[self getZone] alloc: dimProduct*sizeof(float)];
  [ateSucObject loadDataset: ateSucData];

  /*
   * Diltiazem
   */
  dilgroup = [[[[[[HDF5 createBegin: self] setParent: expgroup] setWriteFlag: NO]
                 setDatasetFlag: NO] setName: "Diltiazem"] createEnd];
  dilObject = [[[[[[HDF5 createBegin: self] setParent: dilgroup] setWriteFlag: NO]
                setDatasetFlag: YES] setName: "Diltiazem"] createEnd];
  dilSucObject = [[[[[[HDF5 createBegin: self] setParent: dilgroup] setWriteFlag: NO]
                   setDatasetFlag: YES] setName: "Sucrose"] createEnd];

  // define and load the C arrays
  dilData = [[self getZone] alloc: dimProduct*sizeof(float)];
  [dilObject loadDataset: dilData];
  dilSucData = [[self getZone] alloc: dimProduct*sizeof(float)];
  [dilSucObject loadDataset: dilSucData];

  /*
   * Labetalol
   */
  labgroup = [[[[[[HDF5 createBegin: self] setParent: expgroup] setWriteFlag: NO]
                 setDatasetFlag: NO] setName: "Labetalol"] createEnd];
  labObject = [[[[[[HDF5 createBegin: self] setParent: labgroup] setWriteFlag: NO]
                setDatasetFlag: YES] setName: "Labetalol"] createEnd];
  labSucObject = [[[[[[HDF5 createBegin: self] setParent: labgroup] setWriteFlag: NO]
                   setDatasetFlag: YES] setName: "Sucrose"] createEnd];

  // define and load the C arrays
  labData = [[self getZone] alloc: dimProduct*sizeof(float)];
  [labObject loadDataset: labData];
  labSucData = [[self getZone] alloc: dimProduct*sizeof(float)];
  [labSucObject loadDataset: labSucData];

  /*
   * Prazosin
   */
  pragroup = [[[[[[HDF5 createBegin: self] setParent: expgroup] setWriteFlag: NO]
                 setDatasetFlag: NO] setName: "Prazosin"] createEnd];
  praObject = [[[[[[HDF5 createBegin: self] setParent: pragroup] setWriteFlag: NO]
                setDatasetFlag: YES] setName: "Prazosin"] createEnd];
  praSucObject = [[[[[[HDF5 createBegin: self] setParent: pragroup] setWriteFlag: NO]
                   setDatasetFlag: YES] setName: "Sucrose"] createEnd];

  // define and load the C arrays
  praData = [[self getZone] alloc: dimProduct*sizeof(float)];
  [praObject loadDataset: praData];
  praSucData = [[self getZone] alloc: dimProduct*sizeof(float)];
  [praSucObject loadDataset: praSucData];

  /*
   * Propranolol
   */
  progroup = [[[[[[HDF5 createBegin: self] setParent: expgroup] setWriteFlag: NO]
                 setDatasetFlag: NO] setName: "Propranolol"] createEnd];
  proObject = [[[[[[HDF5 createBegin: self] setParent: progroup] setWriteFlag: NO]
                  setDatasetFlag: YES] setName: "Propranolol"] createEnd];
  proSucObject = [[[[[[HDF5 createBegin: self] setParent: progroup] setWriteFlag: NO]
                     setDatasetFlag: YES] setName: "Sucrose"] createEnd];

  // define and load the C arrays
  proData = [[self getZone] alloc: dimProduct*sizeof(float)];
  [proObject loadDataset: proData];
  proSucData = [[self getZone] alloc: dimProduct*sizeof(float)];
  [proSucObject loadDataset: proSucData];

  // what i really want is a dictionary indexed by compound name

  { // hard-coded labels
    labels = [List create: self];
    timeLabel = [String create: self setC: "Time"];
    [labels addLast: timeLabel];
    antLabel = [String create: self setC: "Antipyrine"];
    [labels addLast: antLabel];
    antSucLabel = [String create: self setC: "Sucrose-with-Antipyrine"];
    [labels addLast: antSucLabel];
    ateLabel = [String create: self setC: "Atenolol"];
    [labels addLast: ateLabel];
    ateSucLabel = [String create: self setC: "Sucrose-with-Atenolol"];
    [labels addLast: ateSucLabel];
    dilLabel = [String create: self setC: "Diltiazem"];
    [labels addLast: dilLabel];
    dilSucLabel = [String create: self setC: "Sucrose-with-Diltiazem"];
    [labels addLast: dilSucLabel];
    labLabel = [String create: self setC: "Labetalol"];
    [labels addLast: labLabel];
    labSucLabel = [String create: self setC: "Sucrose-with-Labetalol"];
    [labels addLast: labSucLabel];
    praLabel = [String create: self setC: "Prazosin"];
    [labels addLast: praLabel];
    praSucLabel = [String create: self setC: "Sucrose-with-Prazosin"];
    [labels addLast: praSucLabel];
    proLabel = [String create: self setC: "Propranolol"];
    [labels addLast: proLabel];
    proSucLabel = [String create: self setC: "Sucrose-with-Propranolol"];
    [labels addLast: proSucLabel];
  }




  {  // report on what we've done
    id <ListIndex> labNdx = [labels listBegin: self];
    id <String> label;

    [Telem debugOut: 1 printf: "DatModel::_loadData_():  dataset rank = %d\n",numDims];
    [Telem debugOut: 1 print: "DatModel::_loadData_():  dims = ["];
    for (ndx=0 ; ndx<numDims ; ndx++) {
      if (ndx > 0) [Telem debugOut: 1 print: ", "];
      [Telem debugOut: 1 printf: "%d", dims[ndx]];
    }
    [Telem debugOut: 1 print: "]\nlabelString = "];
    while ( ([labNdx getLoc] != End)
            && ((label = [labNdx next]) != nil) ) {
      [Telem debugOut: 1 printf: " %s",[label getC]];
    }
    [Telem debugOut: 1 print: "\n"];

    int i=0;
    float dimProduct=1;
    for ( i=0 ; i<numDims ; i++ ) dimProduct *= dims[i];
    [Telem debugOut: 1 printf: "dimProduct = %d\n", (int)dimProduct];

    // time
    for ( i=0 ; i<dims[0] ; i++ )
      [Telem debugOut: 1 printf: "timeData = %f (%x)\n", 
             ((float *)timeData)[i], (unsigned)((float *)timeData)[i]];

    // antipyrine
    for ( i=0 ; i<((int)dimProduct) ; i+=dims[1] ) {
      [Telem debugOut: 1 printf: "antData[%d] = %f\n", i, ((float *)antData)[i]];
    }
    [Telem debugOut: 1 printf: "done with _loadData_ verification\n"];
  }

  [antObject drop]; [antSucObject drop];
  [ateObject drop]; [ateSucObject drop];
  [dilObject drop]; [dilSucObject drop];
  [labObject drop]; [labSucObject drop];
  [praObject drop]; [praSucObject drop];
  [proObject drop]; [proSucObject drop];
  [timeObject drop];
  [expgroup drop]; [vdgroup drop]; [dsgroup drop]; [jpet297 drop];

  return errors;
}

- buildObjects
{
#ifdef DATA_SWARM_DEBUG
  int ndx1,ndx2;
#endif

  if ([self _loadData_] > 0) 
    raiseEvent (LoadError, "Could not load validation Data.\n");

#ifdef DATA_SWARM_DEBUG
  // test data
  [Telem debugOut: 1 print: "DatModel::_loadData_():  valData = \n"];
  [Telem debugOut: 1 print: "[][   ] "];
  for (ndx2=1;ndx2<valDims[1];ndx2++) {
    [Telem debugOut: 1 printf: "[][%10d] ", ndx2];
  }
  [Telem debugOut: 1 print: "\n"];
  for (ndx1=0;ndx1<valDims[0];ndx1++) {
    [Telem debugOut: 1 printf: "[%3d][] ",ndx1];
    for (ndx2=0;ndx2<valDims[1];ndx2++) {
      if (ndx2 == 0)
        [Telem debugOut: 1 printf: "%13.2lf, ",
             ((float *)valData+(ndx1*valDims[1]))[ndx2]];
      else [Telem debugOut: 1 printf: "%13e, ",
                ((float *)valData+(ndx1*valDims[1]))[ndx2]];
    }
    [Telem debugOut: 1 print: "\n"];
  }
#endif

  return self;
}

- step
{
  [Telem monitorOut: 1 print: "\n"];
  [Telem monitorOut: 1 printf: "%s:  ",[self getName]];
  [Telem monitorOut: 1 printf: "%7.2f ",
         timeData[dataNdx]];
  // antipyrine
  [Telem monitorOut: 1 printf: "%13e ",
         antData[dataNdx*valDims[valRank-1]]];
  [Telem monitorOut: 1 printf: "%13e ",
         antSucData[dataNdx*valDims[valRank-1]]];

  // atenolol
  [Telem monitorOut: 1 printf: "%13e ",
         ateData[dataNdx*valDims[valRank-1]]];
  [Telem monitorOut: 1 printf: "%13e ",
         ateSucData[dataNdx*valDims[valRank-1]]];

  // diltiazem
  [Telem monitorOut: 1 printf: "%13e ",
         dilData[dataNdx*valDims[valRank-1]]];
  [Telem monitorOut: 1 printf: "%13e ",
         dilSucData[dataNdx*valDims[valRank-1]]];

  // labetolol
  [Telem monitorOut: 1 printf: "%13e ",
         labData[dataNdx*valDims[valRank-1]]];
  [Telem monitorOut: 1 printf: "%13e ",
         labSucData[dataNdx*valDims[valRank-1]]];

  // prazosin
  [Telem monitorOut: 1 printf: "%13e ",
         praData[dataNdx*valDims[valRank-1]]];
  [Telem monitorOut: 1 printf: "%13e ",
         praSucData[dataNdx*valDims[valRank-1]]];

  // propranolol
  [Telem monitorOut: 1 printf: "%13e ",
         proData[dataNdx*valDims[valRank-1]]];
  [Telem monitorOut: 1 printf: "%13e ",
         proSucData[dataNdx*valDims[valRank-1]]];


  [Telem monitorOut: 1 print: "\n"];

  return [super step]; // increments cycle and dataNdx
}

- (void)drop
{
  
  [[self getZone] free: timeData];
  [[self getZone] free: antData];
  [[self getZone] free: antSucData];
  [[self getZone] free: ateData];
  [[self getZone] free: ateSucData];
  [[self getZone] free: dilData];
  [[self getZone] free: dilSucData];
  [[self getZone] free: labData];
  [[self getZone] free: labSucData];
  [[self getZone] free: praData];
  [[self getZone] free: praSucData];
  [[self getZone] free: proData];
  [[self getZone] free: proSucData];
  //[[self getZone] free: valData];
  [[self getZone] free: valDims];

  [super drop];
}

@end

