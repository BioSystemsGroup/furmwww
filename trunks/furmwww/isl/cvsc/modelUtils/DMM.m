/*
 * DMM - Data Management Module
 * 
 * Copyright 2003-2007 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#undef NDEBUG
#include <assert.h>
#include <errno.h>
#import <simtools.h>
#include <collections.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <limits.h>

#include <dirent.h>
#include <fnmatch.h>

#include "DMM.h"
#import "ParameterManagerUtils.h"

#include <stdarg.h> // for vfprintf

@implementation DMM

/*
 * File utilities
 */
+ (FILE *)openAppendFile: (id <String>) f
{
  FILE *file;

  if ((file = fopen([f getC], "a")) == NULL)
    raiseEvent(LoadError, "Couldn't open file %s. %s\n",
               [f getC], strerror(errno));
  return file;
}

+ (FILE *)openNewFile: (id <String>) f
{
  FILE *file;

  [self checkAndCreatePath: f];

  if ((file = fopen([f getC], "w")) == NULL)
    raiseEvent(LoadError, "Couldn't open file %s.  %s.\n", [f getC], strerror(errno));
  return file;
}

+ (FILE *) openInputFile: (id <String>) f
{
  FILE *file;
  if ((file = fopen([f getC], "r")) == NULL)
    raiseEvent(LoadError, "Couldn't open file %s.  %s.\n", [f getC], strerror(errno));
  return file;
}

+ (void)closeFile: (FILE *) f
{
  if (fclose(f) != 0)
    raiseEvent(WarningMessage, "Couldn't close file.  %s.\n", strerror(errno));
}

// YES => create your file,  NO => leave it alone
+ (BOOL) checkFile: (FILE *) fd 
          fileName: (id <String>) f 
           against: (id <String>) nf 
{
  if (fd != (FILE *)nil && fd != stderr && fd != stdout) {
    if (f != nil) {
      if ([f compare: nf] == 0) {
        raiseEvent(WarningMessage, "File %s is already open.\n",[f getC]);
        return NO;
      }
    }
    [self closeFile: fd];
  }

  if (f != nil) [f drop];

  return YES;
}

/*
 * check the existence of a directory based on POSIX.1 standard
 */
+ (BOOL) checkDir: (id <String>) dir
{
  BOOL retVal = NO;
  DIR *dirStream = opendir([dir getC]);
  if (dirStream != NULL) {
    if (closedir(dirStream) == 0) {
      retVal = YES;
    } else {
      raiseEvent(LoadError, "Opened but could not close %s directory.  %s.\n",
                 [dir getC], strerror(errno));
    }
  }
  return retVal;
}

/*
 * create a directory based on POSIX.1 standard
 */
+ (BOOL) createDir: (id <String>) dir
{
  BOOL retVal = NO;
  int success = mkdir([dir getC], S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
  if ( success == 0 || errno == EEXIST ) {
    retVal = YES;
  } else {
    raiseEvent(SaveError, "Failed to mkdir( %s ).  %s.\n",
               [dir getC], strerror(errno));
  }
  return retVal;
}

+ (void) checkAndCreateDir: (id <String>) dir
{
  if(![DMM checkDir: dir]) 
    if (![DMM createDir: dir])
      raiseEvent(SaveError, "Could not find or create %s directory.  %s.\n",
                 [dir getC], strerror(errno));
}

/*
 * remove a directory
 */
+ (BOOL) removeDir: (id <String>) dir
{
  BOOL retVal = NO;
	char buf[1028];
	sprintf(buf, "rm -fr %s", [dir getC]);
  if (system(buf) != -1)
    retVal = YES;
  return retVal;
}

/**
 * retrieve the 0th char to the last slash in the path
 * SIDE EFFECT!!! -- sets parent to the path without the leaf
 * returns the leaf it removed
 */
+ (id <String>) upFrom: (id <String>) child to: (id <String>) parent
{
   id <String> retVal = nil;
   const char *child_chr = [child getC];
   // need [0] since DIR_SEPARATOR is a string
   const char *last_slash = strrchr(child_chr, DIR_SEPARATOR[0]); 
   if (last_slash != NULL) {
      int pl = strlen(child_chr) - strlen(last_slash);
      char *tmp = (char *) calloc(pl+1, sizeof(char));
      if (parent != nil) {
         strncpy(tmp, child_chr, pl);
         [parent setC: tmp];
      } else
         raiseEvent(InvalidArgument, "%s(%p)::upFrom:to: -- "
                    "Destination String object cannot be nil.\n",
                    [[self class] getName], self);
      free(tmp);
      retVal = [String create: scratchZone setC: last_slash+1];
   } else if (strcmp(child_chr, "") != 0) {
      // then this is a relative path and we need to return a null
      // parent and the child as the leaf
      [parent setC: ""];
      retVal = [child copy: scratchZone];
   }

   return retVal;
}

/**
 * This just iterates up the path verifying that each directory exists
 * and is writable.  If it's not, it tries to make it so.
 *
 * Assuming path is something like '/somedir/somedir/somefile'
 */
+ (void) checkAndCreatePath: (id <String>) path
{
   id <String> newPath = [path copy: scratchZone];
   id <String> leaf = nil;
   id <Array> filo = [Array create: scratchZone];
   id <String> parent = nil;
   int ndx = 0;

   struct stat *fs = (struct stat *) malloc(sizeof(struct stat));
   int success = stat([newPath getC], fs);

   if ( !(S_ISREG(fs->st_mode) || S_ISDIR(fs->st_mode)) ) {

      // if file is neither regular nor a directory, go up
      while (!(S_ISREG(fs->st_mode) || S_ISDIR(fs->st_mode) || strcmp([newPath getC],"") == 0 )) {
         if (parent != nil) [parent drop];
         parent = [String create: scratchZone setC: ""];
         leaf = [self upFrom: newPath to: parent];
         [filo setCount: [filo getCount]+1];
         [filo atOffset: [filo getCount]-1 put: leaf]; // offsets are cardinal
         success = stat([parent getC], fs);
         [newPath drop]; newPath = [parent copy: scratchZone];
      }
      free(fs);

      /* now parent contains an extant file/dir and filo contains the sub-dirs to create
       * don't bother if the dir is there but the file is missing */
      //newPath = [parent copy: scratchZone];
      [parent drop]; parent = nil;
      for ( ndx=[filo getCount]-1 ; ndx>0 ; ndx--) {
         // if path has contents, then append a slash, otherwise don't to handle "./"
         if ([newPath getCount] > 0) [newPath catC: DIR_SEPARATOR];
         // append the next node
         [newPath catC: [(id <String>)[filo atOffset: ndx] getC]];
         [self checkAndCreateDir: newPath];
         [[filo atOffset: ndx] drop];
         [filo atOffset: ndx put: nil];
      }
      [newPath drop];
      [filo drop];
   }
}

+ (id <List>) getFileList: (id <String>) dirName pattern:(const char *) pattern 
{
	DIR *dirp; // a directory
	struct dirent *direntp; // directory entry data structure

	id <List> retList = [List create:scratchZone];
	dirp = opendir([dirName getC]); 
	id <String> fn = nil;
	while((direntp = readdir(dirp)) != NULL) 
	{
		if(fnmatch(pattern, direntp->d_name, FNM_NOESCAPE) == 0)   
		{
			fn = [dirName copy: scratchZone];
			[fn catC: DIR_SEPARATOR];
			[fn catC: direntp->d_name]; 
 			[retList addLast: fn];
		}
	}
	return retList;
}

+ (void) increment: (int *) val
{
	*val = *val + 1;
}

/*
 * Format and data type utilities
 */

+ (const char *) stringValue: d
{
  const char *buff = (const char *)NULL;

  if ([d conformsTo: @protocol(String)])
    buff = [(id <String>)d getC];
  else if ([d isKindOf: [Integer class]])
    buff = [(id <Integer>)d intStringValue];
  else if ([d isKindOf: [Double class]])
    buff = [(id <Double>)d doubleStringValue];
  else
    raiseEvent(InvalidArgument, "%s(%p)::stringValue: -- "
               "Could not deal with data type %s.\n",
               [[self class] getName], self, [[d class] getName]);

  return buff;
}

/*
 * Data Structure utilities
 */

/* 
 * extract the averaged runMap from the outMap In the case where we've
 * done parameter sweeps as well as monte-carlo runs, this requires
 * the parameter set of interest.
 */

+ (id <List>) getAverageDataListFromMap: (id<Map>) outMap 
                               paramSet: pm
{
//  assert([subDMM respondsTo: @selector(getAverageDataListFromMap:paramSet:)]);
//  return [subDMM getAverageDataListFromMap: outMap paramSet: pm];
//    return [self subclassResponsibility: @selector(getAverageDataListFromMap:paramSet:)];


  id <Map> runMap = nil;
  {
    id tempPM = nil;
    tempPM = [ParameterManagerUtils create: scratchZone];
    [tempPM setMonteCarloSet: 0xffffffff];
    // get the avg runMap for parameter set pm
    runMap = [[outMap at: tempPM] at: pm];
    [tempPM drop];
  }

  unsigned num_cols = [self getPointSizeFrom: runMap withTime: NO];
  unsigned num_rows = [runMap getCount];

  [Telem debugOut: 3 
         printf: "[runMap getCount] = %d, num_cols = %d, num_rows = %d\n",
         [runMap getCount], num_cols, num_rows];


  double cv_data_array [num_cols][num_rows];
  unsigned c_index;
  unsigned r_index;
  for (c_index = 0; c_index < num_cols; c_index++) {
    id <List> temp_list = 
      [self getDataListFromMap: runMap pointIndex: c_index];

    for (r_index = 0; r_index < num_rows; r_index++) {
      cv_data_array[c_index][r_index] = [[temp_list atOffset: r_index] getDouble];
    }
    [temp_list drop];

  }

  // Now step through, calculating mean
  //  double cv_data_mean[num_rows];
  id <List> cv_data_mean = [List create: scratchZone];
  for (r_index = 0; r_index < num_rows; r_index++)
    {
      double sum = 0;
      double num_entries = 0;
      for (c_index = 0; c_index < num_cols; c_index++) 
	{
	  sum +=  cv_data_array[c_index][r_index];
	  num_entries++;
	}
      double value = sum / num_entries;
      id <Double> d_value = [Double create: scratchZone setDouble: value];
      [cv_data_mean addLast: d_value];
    }
  return cv_data_mean;
  
}

/*
 * Flatten the whole data map
 */
+ (id <List>) getDataListFromMap: (id <Map>) runMap
{
  return [self getDataListFromMap: runMap pointIndex: -1];
}

/*
 * Project the data from one column down to a simple list.
 * - if _index != -1, then 0 means the "first column that is not time"
 */
+ (id <List>) getDataListFromMap: (id <Map>) runMap 
                      pointIndex: (int) _index
{
  id <List> data_list = nil;

  [Telem debugOut: 7 print: [[self runMapToString: runMap] getC]];

  data_list = [List create: scratchZone];
  {
    id <MapIndex> ptNdx = nil;
    id <String> key = nil;

    {
      id <MapIndex> rmNdx=nil;
      Double *time=nil;
      id <Map> point=nil;
      Double *outVal=nil;
      
      unsigned time_index = 0;
      rmNdx = [runMap mapBegin: scratchZone];
      while (( [rmNdx getLoc] != End)
             && ( (point = [rmNdx next: &time]) != nil) ) {
        ptNdx = [point mapBegin: scratchZone];
        unsigned point_index = 0;
        while (( [ptNdx getLoc] != End)
               && ((outVal = [ptNdx next: &key]) != nil) ) {
          if (key == nil)
            raiseEvent(InvalidLocSymbol, 
                       "%s::getDataListFromMap:pointIndex:  "
                       "Null key in runMap (%p)\n",
                       [[self class] getName], runMap);
          if (strcmp([key getC], "Time") != 0) {
            if ((point_index == _index) || (_index == -1)) {
              // keep nil's as placeholders, if we need them later
              [data_list addLast: outVal]; 
            }
            point_index++;
          }

        }
        [ptNdx drop];
        time_index++;
      }
      [rmNdx drop];
    }
  }

  return data_list;
}
/*
 * Project the data from one column down to a simple list.
 * 
 */

+ (id <List>) getDataListFromMap: (id <Map>) runMap 
                       withLabel: (id <String>) label
{
  id <List> data_list = nil;

  [Telem debugOut: 7 print: [[self runMapToString: runMap] getC]];

  data_list = [List create: scratchZone];
  {
    id <MapIndex> ptNdx = nil;
    id <String> key = nil;
    {
      id <MapIndex> rmNdx=nil;
      Double *time=nil;
      id <Map> point=nil;
      Double *outVal=nil;
      
      unsigned time_index = 0;
      rmNdx = [runMap mapBegin: scratchZone];
      while (( [rmNdx getLoc] != End)
             && ( (point = [rmNdx next: &time]) != nil) ) {
        ptNdx = [point mapBegin: scratchZone];
       
        while (( [ptNdx getLoc] != End)
               && ((outVal = [ptNdx next: &key]) != nil) ) {
          if (key == nil)
            raiseEvent(InvalidLocSymbol, 
                       "%s::getDataListFromMap:pointIndex:  "
                       "Null key in runMap (%p)\n",
                       [[self class] getName], runMap);
          if (strcmp([key getC], [label getC]) == 0) {
            [data_list addLast: outVal]; 
          }

        }
        [ptNdx drop];
        time_index++;
      }
      [rmNdx drop];
    }
  }

  return data_list;
}

+ (int) getPointSizeFrom: (id <Map>) runMap withTime: (BOOL) includeTime
{
  id <String> label = nil;
  id <Map> point = [runMap getFirst];
  int counter = 0L;
  id <MapIndex> pointNdx = [point mapBegin: scratchZone];

  while ( ([pointNdx getLoc] != End) && ([pointNdx next: &label]) ) {
    if (includeTime || (strcmp([label getC], "Time") != 0L) )
      counter++;
  }

  return counter;
}

+ (id <List>) getKeyListFrom: (id <Map>) m
{
  id <List> keyList = [List create: globalZone];
  id key=nil;
  id <MapIndex> mNdx = [m mapBegin: scratchZone];

  while ( ([mNdx getLoc] != End)
          && ( ([mNdx next: &key]) && (key != nil) ) ) {
    /*
     *  because we're using symbols and because the constituent
     *  symbols are created once and used everywhere, this should
     *  make the following identify unique keys
     */
    if (![keyList contains: key]) [keyList addLast: key];
  }

  [mNdx drop];
  return keyList;
}

+ (void) showExpMap: (id <Map>) eMap paramSet: pm
{
  id <Integer> runs;
  id <Map> rMap = nil;
  id <Map> aMap = [eMap getFirst];
  id <MapIndex> amNdx = [aMap mapBegin: scratchZone];
  while(([amNdx getLoc] != End) && ((rMap = [amNdx next: &runs]) != nil))
    {
      printf("Runs [%d] \n", [runs getInt]);
      [self showRunMap: rMap paramSet: pm];
    }
  [amNdx drop];
}

+ (void) showRunMap: (id <Map>) rMap paramSet: pm
{
  id <Double> time = nil;
  id <Map> ptMap = nil;
  id <MapIndex> rmNdx = [rMap mapBegin: scratchZone];
  while(([rmNdx getLoc] != End) && ((ptMap = [rmNdx next: &time]) != nil))
    {
      printf("Time[%g] => ", [time getDouble]);  
      [self showPoint: ptMap paramSet: pm];
    }
  [rmNdx drop];
}

+ (void) showPoint: (id <Map>) point paramSet: pm 
{
  id <String> key = nil;
  id <Double> value = nil;
  id <MapIndex> pNdx = [point mapBegin: scratchZone];
  while(([pNdx getLoc] != End) && ((value = [pNdx next: &key]) != nil))
    {
      printf("(%s,%g) ", [key getC], [value getDouble]);
    }
  printf("\n");
  [pNdx drop];
}

+ (void) getArrayDimensions: (id <Map>) aMap 
         width: (unsigned *) columns height: (unsigned *) rows
	 paramSet: pm
{
     id<Map> mcMap = [aMap at: pm];
     *rows = [[mcMap getFirst] getCount];     
     *columns = [DMM getPointSizeFrom: [mcMap getFirst] withTime: YES];	   
}

+ (void) convertMapToArray: (id <Map>) aMap 
	 keys: (char *) localKeys  values: (double *) localValues  
         paramManager: pm
{
  int idx = 0;

  id <MapIndex> mNdx = [[aMap getFirst] mapBegin: scratchZone];
  id <Map> map = nil;
  while(([mNdx getLoc] != End) && ((map = [mNdx next]) != nil))
    {
      id <Map> point = nil;
      id <MapIndex> rmNdx = [map mapBegin: scratchZone];
      while(([rmNdx getLoc] != End) && ((point = [rmNdx next]) != nil))
	{
	  id <String> key = nil;
	  id outVal = nil;
	  id <MapIndex> ptNdx = [point mapBegin: scratchZone];  
	  while(([ptNdx getLoc] != End) && ((outVal = [ptNdx next: &key]) != nil))
	    {
	      sprintf((localKeys+idx*128), "%s", [key getC]); // a 128 byes for each key
	      localValues[idx++] = [outVal getDouble];
	    } 
	  [ptNdx drop];
	}
      [rmNdx drop];
    }
  [mNdx drop];
}
 


/*
 * Setup methods for singleton instance
 */
- createEnd
{
  DMM *obj = [super createEnd];
  obj->experAgent = nil;
  obj->runFile = (FILE *)nil;
  obj->runFileName = nil;
  obj->runFileNameBase = nil;
  obj->pmFileNameBase = nil;
  obj->graphFileName = nil;
  obj->graphFileNameBase = nil;
  obj->graphFileNameExtension = [String create: [self getZone] setC: ".gml"];
  obj->snapDirBase = nil;
  obj->snapDir = nil;
  obj->runNumber = UINT_MAX;
  obj->monteCarloSet = UINT_MAX;
  return obj;
}

- setExperAgent: ea
{
  assert(ea != nil);
  experAgent = ea;
  return self;
}

- (void) setRunFileNameBase: (const char *) s
{
  if ( s != (const char *)nil && strcmp(s,"") != 0)
    if (runFileNameBase != nil)
      [runFileNameBase setC: s];
    else
      runFileNameBase = [String create: [self getZone] setC: s];
  else
    if (runFileNameBase != nil)
      [runFileNameBase setC: "run"];
    else
      runFileNameBase = [String create: [self getZone] setC: "run"];
}

- (void) setGraphFileNameBase: (const char *) s
{
  [Telem debugOut: 3 printf: "%s::setGraphFileNameBase: %s(%p) -- begin\n",
         [[self getClass] getName], s, s];

  if (s == (const char *)nil || strcmp(s,"") == 0)
    s = "graph";

  if (graphFileNameBase != nil)
    [graphFileNameBase setC: s];
  else
    graphFileNameBase = [String create: [self getZone] setC: s];
}

int _readLSLine(unsigned *num, FILE *file, id <Zone> aZone)
{
  char ch;
  char buf[2];
  char delim=' ';
  int numCount=0;
  int maxNums=10;  // this should be big enough for most things

  [Telem debugOut: 4 printf: "DMM::_readLine() - \n"];

  do {
    id <String> num_s=[String create: scratchZone setC: ""];
    // read the numbers
    buf[1] = '\0';
    while ((ch = fgetc(file)) != EOL) {
      if (ch == '#') {
        while ((ch = fgetc(file)) != EOL);
      } else if (isdigit(ch) != 0) {
        buf[0] = ch;
        [num_s catC: buf];
      } else if ((ch == delim) && (strcmp([num_s getC],"") != 0)) {
        break;
      } else {
        continue;
      }
    } 

    if (ch == EOL) break;

    num[numCount] = atoi([num_s getC]);
    [num_s drop];

    [Telem debugOut: 4 printf: "%3d", num[numCount]];

    numCount++;
    if (numCount >= maxNums) {
      unsigned *tmpNums = (unsigned *) [scratchZone alloc: 2*maxNums*sizeof(unsigned)];
      int i=0;
      for ( i=0 ; i<maxNums ; i++ )
        tmpNums[i] = num[i];
      [scratchZone free: num];
      num = tmpNums;
      maxNums *= 2;
    }
  } while (ch != EOL);


  [Telem debugOut: 4 printf: "\n"];

  return numCount;
}

#include <stdio.h>
#include <time.h>
char *getTimeString()
{
  time_t current_ts;
  char *current_s;
  char * ndx;
  char * current_s_copy;

  time(&current_ts);
  current_s = ctime(&current_ts);
  while ( (ndx = strchr(current_s, ' ')) != NULL)
    memset(ndx, '_', 1);

  current_s_copy = (char *)malloc(strlen(current_s)*sizeof(char));
  current_s_copy = ZSTRDUP(globalZone, current_s);
  return(current_s_copy);
}

- (id) loadObject: (const char *) scmKey into: (id <Zone>) aZone
{
  return [self subclassResponsibility: @selector(loadObject:into:)];
}

/*
 * Run Logging utilities
 */
+ (void) _printDatum: d toFile: (FILE *) f
{
  if ([d conformsTo: @protocol(String)])
    fprintf(f, "%s", [(id <String>)d getC]);
  else if ([d isKindOf: [Integer class]])
    fprintf(f, "%d", [(id <Integer>)d getInt]);
  else if ([d isKindOf: [Double class]])
    fprintf(f, "%g", [(id <Double>)d getDouble]);
  else
    raiseEvent(InvalidArgument, "Could not deal with run file data type \n.");
  fflush(f);
}

+ (const char *) pointStringValue: (id <Map>) pt
{
  id <String> tmp = [String create: scratchZone setC: "("];
  const char *buff = (const char *)NULL;
  id val = nil;
  id <MapIndex> ptNdx = [pt mapBegin: scratchZone];

  
  if ( ([ptNdx getLoc] != End) && ( (val = [ptNdx next]) != nil) ) {
    [tmp catC: [self stringValue: val]];
  }
  while ( ([ptNdx getLoc] != End)
          && ( (val = [ptNdx next]) != nil) ) {
    [tmp catC: ", "];
    [tmp catC: [self stringValue: val]];
  }
  [tmp catC: ")\n"];

  buff = ZSTRDUP(scratchZone, [tmp getC]);

  [tmp drop];
  [ptNdx drop];

  return buff;
}


- (void) logParameters: pm
{
  id <String> pmFileName;
  FILE *pmFile;
  id <OutputStream> pmStream;

  // open new parameter file
  pmFileName = [pmFileNameBase copy: scratchZone];
  [pmFileName 
    catC: [Integer intStringValueOf: [pm getMonteCarloSet]
                   format: "%d"
                   places: 4]];
  [pmFileName catC: ".scm"];
  pmFile = fopen([pmFileName getC], "w");
  pmStream = [OutputStream create: globalZone setFileStream: pmFile];

  [pm lispOutShallow: pmStream];
  [pmStream catC: "\n"];

  [DMM closeFile: pmFile];
  pmFile = (FILE *)NULL;
  [pmFileName drop];
  [pmStream drop];
}
  // end of addition

- (void) stop
{
  [DMM closeFile: artResultsFile];
  artResultsFile = (FILE *)nil;
  [DMM closeFile: refResultsFile];
  refResultsFile = (FILE *)nil;
  [DMM closeFile: datResultsFile];
  datResultsFile = (FILE *)nil;
  [DMM closeFile: simResultsFile];
  simResultsFile = (FILE *)nil;
  [DMM closeFile: simSeriesFile];
  simSeriesFile = (FILE *)nil;
  [DMM closeFile: optResultsFile];
  optResultsFile = (FILE *)nil;
}

- (void) endRun
{

  [Telem debugOut: 3 printf: "%s::endRun -- begin\n", [[self getClass] getName]];

  // close out the data file
  [runFileName drop]; runFileName = nil;
  fclose(runFile);

  [Telem debugOut: 3 printf: "%s::endRun -- end\n", [[self getClass] getName]];

}

- (void) beginRun: (unsigned) run mcSet: (unsigned) mcSet
{

  [Telem debugOut: 3 printf: "%s::beginRun: %d mcSet: %d -- begin\n",
         [[self getClass] getName], run, mcSet];

  // save for intermediate operations
  runNumber = run;
  monteCarloSet = mcSet;

  // open new run file
  if (runFileName != nil) [runFileName drop];
  runFileName = [runFileNameBase copy: [self getZone]];
  [runFileName catC: "_"];
  [runFileName 
    catC: [Integer intStringValueOf: monteCarloSet
                   format: "%d"
                   places: 4]];
  [runFileName catC: "_"];
  [runFileName 
    catC: [Integer intStringValueOf: runNumber
                   format: "%d"
                   places: 4]];
  [runFileName catC: ".csv"];
  runFile = fopen([runFileName getC], "w");

  // reset the snapshot directory name with new run data
  if (snapDir != nil) [snapDir drop];
  snapDir = [snapDirBase copy: [self getZone]];
  [snapDir catC: "_"];
  [snapDir 
    catC: [Integer intStringValueOf: monteCarloSet
                   format: "%d"
                   places: 4]];
  [snapDir catC: "_"];
  [snapDir 
    catC: [Integer intStringValueOf: runNumber
                   format: "%d"
                   places: 4]];

  // check for that dir and create if necessary
  if (![DMM checkDir: snapDir])
    if (![DMM createDir: snapDir])
      raiseEvent(SaveError, "Could not create directory: %s\n", [snapDir getC]);

  [Telem debugOut: 3 printf: "%s::beginRun: %d mcSet: %d -- end\n",
         [[self getClass] getName], runNumber, monteCarloSet];
}

- (void) writeRunFileHeader: (id <List>) h
{
  id <ListIndex> labelNdx = [h listBegin: scratchZone];
  id <String> label = nil;
  int count=0;

  while (([labelNdx getLoc] != End) &&
         ( (label = [labelNdx next]) != nil)) {
    if (count != 0) fprintf(runFile, ", ");
    [Telem debugOut: 4 printf: "runFile = %p; label(%p) = %s\n",
           runFile, label, [label getC]];
    fprintf(runFile, "%s",[label getC]);
    count++;
  }
  fprintf(runFile,"\n");
  fflush(runFile);

  [labelNdx drop];
}

- (void) writeRunFileData: (id <List>) d
{
  id <ListIndex> dataNdx = [d listBegin: scratchZone];
  id datum=nil;

  if ( ([dataNdx getLoc] != End)
      && ( (datum = [dataNdx next]) != nil) )
    [DMM _printDatum: datum toFile: runFile];

  while ( ([dataNdx getLoc] != End)
          && ( (datum = [dataNdx next]) != nil) ) {
    fprintf(runFile, ", ");
    [DMM _printDatum: datum toFile: runFile];
  }
  fprintf(runFile, "\n"); fflush(runFile);
  [dataNdx drop];

}

/**
 * [DMM +countConstituents: (id <List>) createIn: (id <Zone>)] walks
 * the list and creates a map of the contents.
 *
 * The keys for the map are extracted from the objects in the list
 * _if_ the objects respond to the -getType method.  If they don't
 * respond to -getType _or_ if the return value from -getType is nil,
 * then a plain Symbol (Swarm library) is created to index all the
 * objects that don't respond to -getType or return nil when queried.
 *
 * Note that Tags adhere to the Symbol protocol.
 */
static id <Symbol> nilType = nil;
+ (id <Map>) countConstituents: (id <List>) aList createIn: (id <Zone>) aZone
{
  id <Map> count = nil;

  if (aList != nil) {

    id mObj = nil;
    id <ListIndex> elemNdx = [aList listBegin: aZone];
    while ( ([elemNdx getLoc] != End)
            && ( (mObj = [elemNdx next]) != nil) ) {
      if (count == nil) count = [Map create: aZone];
      id <Symbol> type = nil;
      if ( (![mObj respondsTo: @selector(getType)] )
           || ((type = [mObj getType]) == nil) ) {
        if (nilType == nil) 
          nilType = [Symbol create: globalZone 
                            setName: "Not-Typed"];
        type = nilType;
      }
      if ([count containsKey: type]) {
        id <Integer> prevNum = [count at: type];
        int prevNum_value = [prevNum getInt];
        int newNum = prevNum_value + 1;
        [prevNum setInt: newNum];
      } else {
        [count at: type insert: [Integer create: aZone setInt: 1L]];
      }
    }
    [elemNdx drop];
  } // else aList = nil .: count => nil

  return count;
}

/*
 * takes the pairs in data, constructs a header from the firsts and 
 * a row from the seconds.
 */
- (void) logSimilarityResult: (id <List>) data
{
  id <ListIndex> dataNdx = [data listBegin: scratchZone];
  id <Pair> pair = nil;
  id <Double> val = nil;
  id <String> key = nil;
  id <List> simSeries = nil;

  // do the first one
  pair = [dataNdx next];
  key = [pair getFirst];
  val = [pair getSecond];
  if (val != nil && key != nil) {
    id <String> header = [String create: scratchZone setC: ""];
    id <String> record = [String create: scratchZone setC: ""];
    [header catC: [key getC]];
    [record catC: [DMM stringValue: val]];
    // do the rest
    while ( ([dataNdx getLoc] != End)
            && ( (pair = [dataNdx next]) != nil) ) {
      key = [pair getFirst];
      val = [pair getSecond];

      if (strcmp([key getC], "Series") != 0) {
        [header catC: ", "];
        [header catC: [key getC]];

        [record catC: ", "];
        [record catC: [DMM stringValue: val]];
      } else {
        // just store the series to print later
        simSeries = (id <List>)val;
      }
    }

    fprintf(simResultsFile, "%s\n", [header getC]);
    fprintf(simResultsFile, "%s\n", [record getC]);

    [header drop];
    [record drop];

    // print the series
    if (simSeries != nil) {
      id <ListIndex> seriesNdx = [simSeries listBegin: scratchZone];
      id <List> row = nil;
      id val = nil;
      id <String> record = [String create: scratchZone setC: ""];
      id <ListIndex> rowNdx = nil;
      while( ([seriesNdx getLoc] != End)
             && ( (row = [seriesNdx next]) != nil) ) {
        [record setC: ""];
        rowNdx = [row listBegin: scratchZone];

        val = [rowNdx next];
        if (val != nil) [record catC: [DMM stringValue: val]];
        while ( ([rowNdx getLoc] != End)
                && ( (val = [rowNdx next]) != nil) ) {
          [record catC: ", "];
          [record catC: [DMM stringValue: val]];
        }
        [rowNdx drop];

        fprintf(simSeriesFile, "%s\n", [record getC]);
      }
      [seriesNdx drop];
      [record drop];
    }

  } // if (val != nil && key != nil) {

}
- (int)  logOptResultsPrintf: (const char *) fmt, ... 
{
  int retVal = 0;

    va_list ap;
    if (!fmt)
      raiseEvent(InvalidArgument, "Cannot print nil to optimization output.\n");
    va_start(ap, fmt);
    retVal = vfprintf(optResultsFile, fmt, ap);
    va_end(ap);
    fflush(optResultsFile);

  return retVal;	
}

- (BOOL) isPM: (id <ParameterManager>) pm maskedBy: (id <Map>) mask
{
  BOOL masked=NO;

  if (mask != nil) {
    id <MapIndex> maskNdx = [mask mapBegin: scratchZone];
    id maskItem=nil;
    id <String> maskKey=nil;
    unsigned plotVal = [pm getMonteCarloSet];
        
    // if the current pm is in the mask, skip this iterate
    while (([maskNdx getLoc] != End) 
           && ((maskItem = [maskNdx next: &maskKey]) != nil) ) {
      if (strcmp([maskKey getC],"range") == 0) {
        unsigned min = [maskItem getX];
        unsigned max = [maskItem getY];
        if (min <= plotVal && plotVal <= max) masked = YES;
      } else
        raiseEvent(WarningMessage, 
                   "%s::isPM:maskedBy: "
                   "Non-Range masks not supported.\n",
                   [self getName]);
    }
  }
  return masked;
}

/*
 * Observation methods
 */
- (id <Map>) getArtMap { return artOut; }
- (id <Map>) getRefMap { return refOut; }
- (id <Map>) getDatMap { return datOut; }
- (id <String>) getOutFileBase { return outFileBase; }
- (id <String>) getCsvFileBase { return csvFileBase; }
- (id <String>) getGraphFileNameExtension { return graphFileNameExtension; }
- setArtMap: (id <Map>) map
{
  artOut = map;
  return self;
}

- (int) writePNG: (gdImagePtr) img withID: (int) pid spaceName: (const char *) sn
{
  int err = 0;
  FILE *pngout;
  id <String> fileName = nil;

  fileName = [snapDir copy: scratchZone];

  [fileName catC: DIR_SEPARATOR];
  [fileName catC: "Sinusoid_"];
  [fileName 
    catC: [Integer intStringValueOf: pid
                   format: "%d"
                   places: 4]];
  if (![DMM checkDir: fileName])
    if (![DMM createDir: fileName])
      raiseEvent(SaveError, "Could not create directory: %s\n", [fileName getC]);


  // append the space name only if there is one
  if (sn != (const char *)nil) {
    [fileName catC: DIR_SEPARATOR];
    [fileName catC: sn];
    if (![DMM checkDir: fileName])
      if (![DMM createDir: fileName])
        raiseEvent(SaveError, "Could not create directory: %s\n", [fileName getC]);
  }
  [fileName catC: DIR_SEPARATOR];
  [fileName catC: [Integer intStringValue: getCurrentTime()]];
  [fileName catC: ".png"];

  if ((pngout = fopen([fileName getC], "wb")) == (FILE *)nil) {
    err--;
    raiseEvent(WarningMessage, "%s -- Could not open file: %s\n",
               [[self getClass] getName], [fileName getC]);
  } else {
    gdImagePng(img, pngout);
    if (fclose(pngout) != 0) {
      err--;
      raiseEvent(WarningMessage, "%s -- Could not close file: %s\n",
                 [[self getClass] getName], [fileName getC]);
    }    
  }
  [fileName drop];

  return err;
}

+ (id <String>) runMapToString: (id <Map>) runMap
{
  id <MapIndex> ndx1 = nil;
  id <MapIndex> ndx2 = nil;
  id <Map> dp = nil;
  id <Double> t = nil;
  id <String> label = nil;
  id <Double> value = nil;
  id <String> output = [String create: scratchZone setC: "runMap = \n"];

  ndx1 = [runMap mapBegin: scratchZone];

  while ( ([ndx1 getLoc] != End)
          && ( (dp = [ndx1 next: &t]) != nil)
          && (t != nil) ) {

    ndx2 = [dp mapBegin: scratchZone];
    [output catC: "\tTime = "];
    [output catC: [t doubleStringValue]];
    [output catC: "\n"];

    while ( ([ndx2 getLoc] != End)
            && ( (value = [ndx2 next: &label]) != nil) ) {

      [output catC: "\t"];
      [output catC: [label getC]];
      [output catC: " = "];

      char *tmpStr = [value doubleStringValue];
      [output catC: tmpStr];

      //[output catC: [value doubleStringValue]];
      [output catC: "\n"];
    }
  }
  [ndx1 drop];
  [ndx2 drop];

  return output;
}
- (void) setSubDMM: sd { subDMM = sd; }
@end
