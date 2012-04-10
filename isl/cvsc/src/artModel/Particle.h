/*
 * RootObject - common ancestor for all objects
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
//#import <objectbase/SwarmObject.h>
#import "../RootObject.h"
@interface Particle: RootObject
{
  int myNumber;
  int mySegNum;
}
- setNumber: (int) n;
- setSegNum: (int) n;
- (int)getNumber;
- (int)getSegNum;
@end
