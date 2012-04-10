/*
 * IPRL - Telemetry object
 *
 * Copyright 2003 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#include <objectbase/SwarmObject.h>

#include "modelUtils.h"

@interface Telem: SwarmObject <Telem>
{
}

+(void)setDebug: (BOOL) b;
+setDebugMode: (int) m;
+setDebugFile: (id <String>) f;
+(int)debugOut: (int) level printf: (const char *) fmt, ...;
+(int)debugOut: (int) level print: (const char *) str;
+ (int) debugOut: (int) level printPoint: (id <Map>) pt;
+(void)setMonitor: (BOOL) b;
+setMonitorMode: (int) m;
+setMonitorFile: (id <String>) f;
+(int)monitorOut: (int) level printf: (const char *) fmt, ...;
+(int)monitorOut: (int) level print: (const char *) str;

+(int)monitorOut: (int) level describe: obj withDetail: (short int) d;
+(int) debugOut: (int) level describe: obj;

@end
