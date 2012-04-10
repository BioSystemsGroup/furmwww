/*
 * IPRL - Double wrapper
 *
 * Copyright 2003-2005 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "modelUtils.h"
#import <objectbase/SwarmObject.h>

@interface Double : SwarmObject <Double>
{
  double val;
}
+ create: (id <Zone>) aZone setDouble: (double) val;
+ (char *) doubleStringValue: (double) d;
- setDouble: (double) value;
- (double) getDouble;
- (char *) doubleStringValue;
//- (void) addDouble: (double) value;
- (void) divideDouble: (double) value;
@end

compare_t double_compare( Double *obj1, Double *obj2);

