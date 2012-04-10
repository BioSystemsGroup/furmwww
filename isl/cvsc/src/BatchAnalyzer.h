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
//#include <objectbase/SwarmObject.h>
#import "RootObject.h"
#include <modelUtils.h>

@interface BatchAnalyzer : RootObject
{
  int rank; // processor id
  FILE *sfp; 
  FILE *tfp;
  char *baseDir;
}

// analystic works
- (double) findMaxSimilarity: (double *) result length: (int) size;
- (double) findMaxSimilarity: (double *) result length: (int) size in: (int *) idx;
- (double) findMinSimilarity: (double *) result length: (int) size;
- (double) findMinSimilarity: (double *) result length: (int) size in: (int *) idx;
- (double) findMaxExecutionTime: (double *) result length: (int) size;
- (double) findMaxExecutionTime: (double *) result length: (int) size in: (int *) idx;

// record messages
- createFileForProcessor: (int) number;
- createFileForProcessor: (int) number baseDir: (const char*) dirx;
- recordAllSimilarities: (double *) values  withNames: (char [][256]) names length: (int) size;
- recordAllSimilarities: (double *) values  withNames: (char [][256]) names length: (int) size
                          withMessage: (char *) msg;
- recordAllExecutionTime: (double *) values  withNames: (char [][256]) names length: (int) size;
- recordAllExecutionTime: (double *) values  withNames: (char [][256]) names length: (int) size
                          withMessage: (char *) msg;
- recordSimilarity: (double) value withMessage: (char *) msg;
- recordSimilarity: (double) value withName: (char *) name withMessage: (char *) msg;
- recordExecutionTime: (double) value withName: (char *) name withMessage: (char *) msg;
- recordMessage: (char *) msg to: (FILE *)fp;

// misc
- setBaseDir: (const char *) dir;

// object life cycle
+ createBegin: aZone;
- createEnd;
- drop;

@end
