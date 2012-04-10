/*
 * IRPL - Telemetry object
 * 
 * Copyright 2003-2007 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#include <stdarg.h> // for vfprintf
#include <stdio.h>

#import <collections.h>

#include "Telem.h"

static int debugMode=0;  // -1 = off, 0 = sparse, 1 = medium, 2 = detailed
static BOOL logDebug=YES;       // YES = writes to a file, NO = doesn't
static id <String> debugFileName=nil;
static FILE *debugFile=(FILE *)nil;
static id <OutputStream> debugStream=nil;
static int monitorMode=2;  // -1 = off, 0 = sparse, 1 = medium, 2 = detailed
static id <String> monitorFileName=nil;
static FILE *monitorFile=(FILE *)nil;
static id <OutputStream> monitorStream=nil;
static BOOL logMonitor=YES;

@implementation Telem

// debug methods
+ (void)setDebug: (BOOL) b {
  logDebug = b;
}

+ setDebugMode: (int) m {
  debugMode = m;
  return self;
}

+ setDebugFile: (id <String>) f
{
  //debugFile = '\0'; //  temporary bypass for PISL 
  //debugFileName = '\0'; // temporary bysspass for PISL

  if ([DMM checkFile: debugFile fileName: debugFileName against: f]) {
    debugFile = [DMM openNewFile: f];
    debugFileName = f;

    debugStream = 
      [OutputStream create: globalZone setFileStream: debugFile];
  }
  return self;
}

+ (int) debugOut: (int) level printf: (const char *) fmt, ...
{
  int retVal = 0;

  if (logDebug && level <= debugMode) {
    va_list ap;
    if (!fmt)
      raiseEvent(InvalidArgument, "Cannot print nil to debug output.\n");
    va_start(ap, fmt);
    retVal = vfprintf(debugFile, fmt, ap);
    va_end(ap);
    fflush(debugFile);
  }

  return retVal;
}

+ (int) debugOut: (int) level print: (const char *) str
{
  int retVal=0;
  if (logDebug && level <= debugMode) {
    retVal = fprintf(debugFile, "%s", str);
    fflush(debugFile);
  }
  return retVal;
}

+ (int) debugOut: (int) level describe: obj
{
  if (logDebug && level <= debugMode) {
    [obj describe: debugStream];
    if ([obj respondsTo: M(describeForEach:)]) 
      [((id <ForEach>)obj) describeForEach: debugStream];
  }
  return 0U;
}

+ (int) debugOut: (int) level describe: obj withDetail: (short int) d
{
  int retVal=0;
  if (logDebug && level <= debugMode) 
    [((id <Describe>) obj) describe: debugStream withDetail: d];
  return retVal;
}

+ (int) debugOut: (int) level printPoint: (id <Map>) pt
{
  int retVal=0U;
  if (logDebug && level <= debugMode) {
    id <MapIndex> dpNdx = [pt mapBegin: scratchZone];
    id val=nil;
    id <String> key=nil;
    retVal = fprintf(debugFile, "[ ");
    while (([dpNdx getLoc] != End) && ((val = [dpNdx next: &key]) != nil)) {
      retVal = fprintf(debugFile, "%s => %6g, ", [key getC], [val getDouble]);
    }
    retVal = fprintf(debugFile, " ]\n");
    [dpNdx drop];
  }
  return retVal;
}


// monitor methods
+ (void)setMonitor: (BOOL) b {
  logMonitor = b;
}

+ setMonitorMode: (int) m {
  monitorMode = m;
  return self;
}

+ setMonitorFile: (id <String>) f
{
  if ([DMM checkFile: monitorFile fileName: monitorFileName against: f]) {
    [DMM checkAndCreatePath: f];
    monitorFile = [DMM openNewFile: f];
    monitorFileName = f;
      
    monitorStream = 
      [OutputStream create: globalZone setFileStream: monitorFile];
  }
  return self;
}

+ (int) monitorOut: (int) level printf: (const char *) fmt, ...
{
  int retVal=0;

  if (logMonitor && level <= monitorMode) {
    va_list argptr;
    if (!fmt)
      raiseEvent(InvalidArgument, "Cannot print nil to monitor output.\n");
    va_start(argptr, fmt);
    retVal = vfprintf(monitorFile, fmt, argptr);
    va_end(argptr);
    fflush(monitorFile);
  }
  return retVal;
}

+ (int) monitorOut: (int) level print: (const char *) str
{
  int retVal=0;

  if (logMonitor && level <= monitorMode) {
    retVal = fprintf(monitorFile, "%s", str);
    fflush(monitorFile);
  }
  return retVal;
}

+ (int) monitorOut: (int) level describe: obj withDetail: (short int) d
{
  int retVal=0;
  [((id <Describe>) obj) describe: monitorStream withDetail: d];
  return retVal;
}

@end

