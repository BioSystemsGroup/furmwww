/*
 * IRPL - Dosage abstract class
 * 
 * Copyright 2005 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "Dosage.h"
@implementation Dosage
- (void) setParams: (id <Array>) p
{
  if (p == nil) 
    raiseEvent(InternalError, "Dosage parameters are nil.\n");
  params = p;
}
- (void) setTimes: (id <Array>) t
{
  if (t == nil)
    raiseEvent(InternalError, "Dosage timeline is nil.\n");
  times = t;
}
- (unsigned) dosage: (unsigned) arg
{
  return (unsigned)(unsigned long)[self subclassResponsibility: @selector(dosage:)];
}
@end
