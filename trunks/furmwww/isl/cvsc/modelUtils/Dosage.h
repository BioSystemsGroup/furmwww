/*
 * IPRL - Dosage class
 *
 * Copyright 2005 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "modelUtils.h"

#import <objectbase/SwarmObject.h>
@interface Dosage: SwarmObject <Dosage>
{
  id <Array> params;
  id <Array> times;
}
- (void) setParams: (id <Array>) p;
- (void) setTimes: (id <Array>) t;
- (unsigned) dosage: (unsigned) arg;
@end
