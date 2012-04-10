/*
 * IPRL - Handler for command line options
 *
 * Copyright 2003-2005 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <stdlib.h>
#import "CommandLineOptionHandler.h"

@implementation CommandLineOptionHandler 

+ createBegin: aZone
{
   static struct argp_option options[] = {
     // name, key, argument, flag, doc, group 
     {"param-file", 'F', "NAME", 0, "set a parameter file name",  0},
     {"param-dir", 'D', "NAME", 0, "set a parameter directory name",  1},
     {"sweep-table", 'T', "NAME", 0, "set parameter sweeping table file name", 2},
     {"display-level", 'd', "LEVEL", 0, "Show simulation progress message", 3},
     {"enable-trace", 'E', "BOOL", 0, "enable or disable solute trace", 4},
     { 0 }
   };
   CommandLineOptionHandler *args = [super createBegin: aZone];
   [args addOptions: options];

   return args;
}

+ (BOOL) exist: (const char *) key In: args
{
  int cnt = [args getArgc];
  const char **options = [args getArgv];
  int idx;
  for(idx = 0; idx < cnt; idx++) 
     if(strstr(options[idx], key) != NULL) return YES; 
  return NO;
}

- (int) parseKey: (int)key arg: (const char*)arg
{
  if(key == 'F')
    {
      paramFileName = (char *)arg;
      return 0;
    }
  else if(key == 'D')
    {
      paramDirName = (char *)arg;
      return 0;
    }
  else if(key == 'T')
    {
      sweepTblName = (char *)arg;
      return 0;
    }
  else if(key == 'd')
    {
      dLevel = atoi(arg);
      return 0;
    }
  else if(key == 'E')
    {
      enableTrace = (char *)arg;
      return 0;
    }
  else
    return [super parseKey: key arg: arg];
}
     
- (const char *) getParameterFileNameArg
{
  return paramFileName;
}

- (const char *) getParameterDirectoryNameArg
{
  return paramDirName;
}

- (const char *)getParameterSweepingTableFileNameArg
{
  return sweepTblName;
}

- (const char *)getParameterEnableTraceArg
{
  return enableTrace;
}

- (int) getDisplayLevelArg
{
  return dLevel;
}
@end

