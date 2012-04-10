/*
 * IPRL - Long wrapper
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <objectbase/SwarmObject.h>
#import "modelUtils.h"
@interface Long : SwarmObject <Long>
{
  long value;
}
+ (char *) longStringValue: (long) l;
+ (char *) hexStringValue: (long) l;
+ (char *) longStringValueOf: (long) l format: (const char *) f places: (long) p;
+ create: (id <Zone>) aZone setLong: (long) val;
- setLong: (long) val;
- (void) increment;
- (id) addLong: (long) l; // because FArguments already defines this
- (long) getLong;
- (char *) longStringValue;
- (char *) hexStringValue;
@end

int long_compare( Long *obj1, Long *obj2);
