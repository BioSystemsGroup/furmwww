/*
 * ISL - CSV formatted DatModel
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

#import "DatModel.h"

#define DRUG_NAME_DELIMITER '-'
#define NO_D2S_TARGET -1

@interface CSVDatModel: DatModel
{
  unsigned numRows; // number of observations
  unsigned numColumns; // number of labels/solute
  float **data;
  int *d2sMap; // map from drug -> sucrose accompaniment
}

@end
