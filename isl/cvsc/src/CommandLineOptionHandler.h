/*
 * IPRL - Handler for command line options
 *
 * Copyright 2003-2008 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <defobj/Arguments.h>

@interface CommandLineOptionHandler: Arguments_c
{
  char *paramFileName; // a single parameter file name
  char *paramDirName; // parameter directory name 
  char *sweepTblName; // parameter sweeping table file name
  int dLevel;  // display level of simulation progress message
  char *enableTrace; // "yes" or "no" for enable/disable solute trace 
}

+ createBegin: aZone;

+ (BOOL) exist: (const char *) key In: args;
- (int) getDisplayLevelArg;
- (const char *) getParameterFileNameArg;
- (const char *) getParameterDirectoryNameArg;
- (const char *) getParameterSweepingTableFileNameArg;
- (const char *) getParameterEnableTraceArg;

@end
