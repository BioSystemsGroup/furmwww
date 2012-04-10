// DataSwarm.h
#import "DatModel.h"
#import <space.h>

@interface HDFDatModel: DatModel
{
  int valRank;
  size_t *valDims;
  float *timeData, *antData, *ateData, *dilData, *labData, *praData, *proData;
  float *antSucData, *ateSucData, *dilSucData, *labSucData, *praSucData, *proSucData;
  id <String> timeLabel, antLabel, ateLabel, dilLabel, labLabel, praLabel, proLabel;
  id <String> antSucLabel, ateSucLabel, dilSucLabel, labSucLabel, praSucLabel, proSucLabel;

}

- createHDF5NodeKey: (const char *)nodeName mode: (const char *)modeName;

@end


