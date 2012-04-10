/*
 * modelUtils Vector utility
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
enum dir {hold, east, northEast, north, northWest, west, 
          southWest, south, southEast };

#import "modelUtils.h"

#import <objectbase/SwarmObject.h>
@interface Vector: SwarmObject
{
}
@end

@interface Vectormd: Vector <Vectormd>
{
@public
  unsigned dim;
  double *v;
}
+create: (id <Zone>) aZone setDim: (unsigned) d;
+create: (id <Zone>) aZone copyVector: (id <Vectormd>)vec;
- (unsigned)getDim;
- (void)setVal: (double)val at: (unsigned)i;
- (double)getValAt: (unsigned)i;
- multByScalar: (double)val;
- add: (id <Vectormd>)vec;
- sub: (id <Vectormd>)vec;
- div: (id <Vectormd>)vec;
- mul: (id <Vectormd>)vec;
- (double)dotProduct: (id <Vectormd>)vec;
- (double)norm;
- (void) print;
- (id <String>) toString;
- copyVector: (id <Vectormd>)v;
- reflectThru: (id <Vectormd>)v withRatio: (double)alpha;
- contractThru: (id <Vectormd>)v withRatio: (double)beta;
- expandThru: (id <Vectormd>)v withRatio: (double)beta;
- (void) drop;
@end


@interface Vector2d: Vector <Vector2d>
{
@public
  int x;
  int y;
}
+create: (id <Zone>) aZone dim1: (int) dim1 dim2: (int) dim2;
- setX: (int) dim1;
- setY: (int) dim2;
- (int)getX;
- (int)getY;
@end

@interface VectorMoore: Vector
{
@public
  float probV[9];
}
- setProbVFromTurbo: (double) pv;
@end

