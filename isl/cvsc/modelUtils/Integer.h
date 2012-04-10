/*
 * IPRL - Integer wrapper
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
@interface Integer : SwarmObject <Integer>
{
  int value;
}
+ (char *) intStringValue: (int) i;
+ (char *) hexStringValue: (int) i;
+ (char *) intStringValueOf: (int) i format: (const char *) f places: (int) p;
+ create: (id <Zone>) aZone setInt: (int) val;
- setInt: (int) val;
- (void) increment;
- (id) addInt: (int) i; // because FArguments already defines this
- (int) getInt;
- (char *) intStringValue;
- (char *) hexStringValue;
@end

compare_t int_compare( Integer *obj1, Integer *obj2);
