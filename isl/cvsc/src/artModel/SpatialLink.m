/*
 * IPRL ArtModel SpatialLink - This object handles space-mediated
 * signals between SS nodes.
 *
 * Copyright 2003-2005 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <defobj.h>
#import <defobj/version.h>
#import "SpatialLink.h"
@implementation SpatialLink


PHASE(Creating)

+ create: (id <Zone>)aZone setSizeX: (unsigned)x Y: (unsigned)y {
  SpatialLink *newObj;
  newObj = [self createBegin: aZone];
  newObj->medium = [Discrete2d create: aZone setSizeX: x Y: y];
  newObj = [newObj createEnd];
  return newObj;
}

// forwards
- setSizeX: (unsigned)x Y: (unsigned)y {
  return [medium setSizeX: x Y: y];
}
- (id *)allocLattice {
  return [medium allocLattice];
}
- makeOffsets {
  return [medium makeOffsets];
}

PHASE(Setting)

// forwards
- setLattice: (id *)lattice {
  return [medium setLattice: lattice];
}

PHASE(Using)

// forwards
- putObject: anObject atX: (unsigned)x Y: (unsigned)y {
  return [medium putObject: anObject atX: x Y: y];
}
- putValue: (long)v atX: (unsigned)x Y: (unsigned)y {
  return [medium putValue: v atX: x Y: y];
}
- fastFillWithValue: (long)aValue {
  return [medium fastFillWithValue: aValue];
}
- fastFillWithObject: anObj {
  return [medium fastFillWithObject: anObj];
}
- fillWithValue: (long)aValue {
  return [medium fillWithValue: aValue];
}
- fillWithObject: anObj {
  return [medium fillWithObject: anObj];
}
- (int)setDiscrete2d: (id <Discrete2d>)a toFile: (const char *)filename {
  return [medium setDiscrete2d: a toFile: filename];
}
- copyDiscrete2d: (id <Discrete2d>)a toDiscrete2d: (id <Discrete2d>)b {
  return [medium copyDiscrete2d: a toDiscrete2d: b];
}

// from GridData protocol
- (unsigned)getSizeX {
  return [medium getSizeX];
}
- (unsigned)getSizeY {
  return [medium getSizeY];
}
- (id *)getLattice {
  return [medium getLattice];
}
- (long *)getOffsets {
  return [medium getOffsets];
}
- getObjectAtX: (unsigned)x Y: (unsigned)y {
  return [medium getObjectAtX: x Y: y];
}
- (long)getValueAtX: (unsigned)x Y: (unsigned)y {
  return [medium getValueAtX: x Y: y];
}
- (void)setObjectFlag: (BOOL) objectFlag {
  return [medium setObjectFlag: objectFlag];
}

@end
