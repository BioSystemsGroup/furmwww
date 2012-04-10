/*
 * IPRL - Space with a flow field
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <assert.h>
#include <math.h>
#include <float.h>
#import "FlowSpace.h"
#import "Sinusoid.h"
#import <modelUtils.h>
#import <LocalRandom.h>
#import "protocols.h"
@implementation FlowSpace

- setParent: p {
  assert ( p!=nil );
  _parent = (Sinusoid *)p;
  return self;
}

/*
 * setFlowFromTurbo() - will only work as long as the vectors in
 *                      the space are multiple refs to the same
 *                      vector.  Rewrite for multiple vectors.
 */
- setFlowFromTurbo: (double) pv {
  defaultFlowVector = [VectorMoore create: [self getZone]];
  [defaultFlowVector setProbVFromTurbo: pv];
  [flow fastFillWithObject: defaultFlowVector];
  return self;
}

- flow
{
  Vector2d *newPos = nil;
  int xNdx=0, yNdx=0;
  id obj = nil;
  id tgtObj = nil;

  // iterate the last row on the annulus
  for ( xNdx=0 ; xNdx<xsize ; xNdx++ ) {
    obj = [self getObjectAtX: xNdx Y: ysize-1];


    if ( obj != nil ) {
      unsigned newX = 0L, newY = 0L;
      newPos = [self getNewPosFor: obj atX: xNdx Y: ysize-1];
      newX = [newPos getX];
      newY = [newPos getY];

      if ( [self isMobile: obj] ) {

        if ( newY  >= ysize-1 ) {
          // off the end of the segment
          if ([_parent findOutFlowFor: obj]) {
            [self removeObjectAtX: xNdx Y: ysize-1];
          } // else stay right here
        } else if ((tgtObj = [self getObjectAtX: newX Y: newY]) == nil) {
          if ( newX != xNdx || newY != ysize-1 ) {
            [self removeObjectAtX: xNdx Y: ysize-1];
            [self putObject: obj atX: newX Y: newY];
          }
        } else if ( [containerObjMap containsKey: tgtObj] ) {

          // if the target is a container try to put it in there
          if ([((id <ContainerObj>) tgtObj) putMobileObject: obj])
            [self removeObjectAtX: xNdx Y: ysize-1];
          // if you fail, then do nothing

        } // do nothing with the object

      } else if ( [containerObjMap containsKey: obj] ) {
        // if it's a container object, get a mobile object from it
        id cObj = (id <ContainerObj>) obj;
        id subObj = [cObj getMobileObject];
        if (subObj != nil) {
          if ( newY >= ysize-1 ) {
            // off the end of the segment
            if ([_parent findOutFlowFor: subObj]) {
              [cObj removeMobileObject: subObj];
            } // else leave the object inside the container
          } else if ((tgtObj = [self getObjectAtX: newX Y: newY]) == nil) {
            if ( newX != xNdx || newY != ysize-1 ) {
              [cObj removeMobileObject: subObj];
              [self putObject: subObj atX: newX Y: newY];
            }
          } else if ( [containerObjMap containsKey: tgtObj] ) {
            // tgtObj is non-nil and is a container

            // if the target is a container try to put it in there
            if ([((id <ContainerObj>) tgtObj) putMobileObject: subObj])
              [cObj removeMobileObject: subObj];
            // if you fail, then do nothing

          } // else we do nothing with that subObj

        }
        
      } // else
        //    only other case is that it's fixed but not a container
        //    so move on silently.
      [newPos drop]; newPos = nil;
    }
  }

  // iterate the rest of the cylinder
  yNdx=ysize-1-1;
  while (yNdx >= 0) {
    for ( xNdx=0 ; xNdx<xsize ; xNdx++) {
      obj = [self getObjectAtX: xNdx Y: yNdx];

      if ( obj != nil ) {
        unsigned newX = 0L, newY = 0L;
        newPos = [self getNewPosFor: obj atX: xNdx Y: yNdx];
        newX = [newPos getX];
        newY = [newPos getY];

        if ( [self isMobile: obj] ) {
          tgtObj = [self getObjectAtX: newX Y: newY];

          if ( tgtObj == nil ) {
            [self removeObjectAtX: xNdx Y: yNdx];
            [self putObject: obj atX: newX Y: newY];
          } else if ( [containerObjMap containsKey: tgtObj] ) {
            if (newX != xNdx || newY != yNdx) {
              if ([tgtObj putMobileObject: obj])
                [self removeObjectAtX: xNdx Y: yNdx];
            }
          }
        } else if ( [containerObjMap containsKey: obj] ) {
          id <ContainerObj> cObj = (id <ContainerObj>) obj;
          id subObj = [cObj getMobileObject];
          if ( subObj != nil ) {
            if ( (tgtObj = [self getObjectAtX: newX Y: newY]) == nil ) {
              if (newX != xNdx || newY != yNdx) {
                [cObj removeMobileObject: subObj];
                [self putObject: subObj atX: newX Y: newY];
              }
            } else if ( [containerObjMap containsKey: tgtObj] ) {
              if ([((id <ContainerObj>) tgtObj) putMobileObject: subObj])
                [cObj removeMobileObject: subObj];
            } // else do nothing with that subObj
          }
          obj = nil;
        } // else
          //    only other case is that it's fixed but not a container
          //    so move on silently
        [newPos drop]; newPos = nil;
      }
    }
    yNdx--;
  }

  return self;
}

/*
 * Same as flow() except that solutes are not allowed off the annulus (recirculation is an option)
 *
 */
- blocked_flow: (BOOL) recirculate
{
  Vector2d *newPos = nil;
  int xNdx=0, yNdx=0;
  id tgtObj = nil;

  // iterate the last row on the annulus
  for ( xNdx=0 ; xNdx<xsize ; xNdx++ ) {
    id obj = nil;
    obj = [self getObjectAtX: xNdx Y: ysize-1];

    if ( obj != nil ) {
      unsigned newX = 0L, newY = 0L;
      newPos = [self getNewPosFor: obj atX: xNdx Y: ysize-1];
      newX = [newPos getX];
      newY = [newPos getY];

      if ( [self isMobile: obj] ) {

        if ( newY  >= ysize-1 ) {
          // stay or recirculate back to beginning edge of annulus
          if (recirculate) {
        //  printf("FlowSpace::blocked_flow - %s(%p) recirculated1\n", [[obj getClass] getName], obj);
            if (![self putMobileObject: obj atX: newX Y: 0L]) {
              unsigned tmpX=0;
              for (tmpX = 0; tmpX < xsize; tmpX++) {
                if ([self putMobileObject: obj atX: tmpX Y: 0L]) {
                  [self removeObjectAtX: xNdx Y: ysize-1];
                  break;
                }
              }
            }
            else {
              // successful move
              [self removeObjectAtX: xNdx Y: ysize-1];
            }
          }
        } else if ((tgtObj = [self getObjectAtX: newX Y: newY]) == nil) {
          if ( newX != xNdx || newY != ysize-1 ) {
            [self removeObjectAtX: xNdx Y: ysize-1];
            [self putObject: obj atX: newX Y: newY];
          }
        } else if ( [containerObjMap containsKey: tgtObj] ) {

          // if the target is a container try to put it in there
          if ([((id <ContainerObj>) tgtObj) putMobileObject: obj])
            [self removeObjectAtX: xNdx Y: ysize-1];
          // if you fail, then do nothing

        } // do nothing with the object

      } else if ( [containerObjMap containsKey: obj] ) {
        // if it's a container object, get a mobile object from it
        id cObj = (id <ContainerObj>) obj;
        id subObj = [cObj getMobileObject];
        if (subObj != nil) {
          if ( newY >= ysize-1 ) {
            //stay or recirculate back to beginning edge of annulus
            if (recirculate) {
             // printf("FlowSpace::blocked_flow - %s(%p) recirculated2\n", [[subObj getClass] getName], subObj);
              // try putting it back into the beginning of annulus
              if (![self putMobileObject: subObj atX: newX Y: 0L]) {
                unsigned tmpX=0;
                for (tmpX = 0; tmpX < xsize; tmpX++) {
                  if ([self putMobileObject: subObj atX: tmpX Y: 0L]) {
                    [cObj removeMobileObject: subObj];
                    break;
                  }
                }
              }
              else {
                // successful move
                [cObj removeMobileObject: subObj];
              }
            }
          } else if ((tgtObj = [self getObjectAtX: newX Y: newY]) == nil) {
            if ( newX != xNdx || newY != ysize-1 ) {
              [cObj removeMobileObject: subObj];
              [self putObject: subObj atX: newX Y: newY];
            }
          } else if ( [containerObjMap containsKey: tgtObj] ) {
            // tgtObj is non-nil and is a container

            // if the target is a container try to put it in there
            if ([((id <ContainerObj>) tgtObj) putMobileObject: subObj])
              [cObj removeMobileObject: subObj];
            // if you fail, then do nothing

          } // else we do nothing with that subObj

        }
        
      } // else
        //    only other case is that it's fixed but not a container
        //    so move on silently.
      [newPos drop]; newPos = nil;
    }
  }

  // iterate the rest of the cylinder
  yNdx=ysize-1-1;
  while (yNdx >= 0) {
    for ( xNdx=0 ; xNdx<xsize ; xNdx++) {
      id obj = nil;
      obj = [self getObjectAtX: xNdx Y: yNdx];

      if ( obj != nil ) {
        unsigned newX = 0L, newY = 0L;
        newPos = [self getNewPosFor: obj atX: xNdx Y: yNdx];
        newX = [newPos getX];
        newY = [newPos getY];

        if ( [self isMobile: obj] ) {
          tgtObj = [self getObjectAtX: newX Y: newY];

          if ( tgtObj == nil ) {
            [self removeObjectAtX: xNdx Y: yNdx];
            [self putObject: obj atX: newX Y: newY];
          } else if ( [containerObjMap containsKey: tgtObj] ) {
            if (newX != xNdx || newY != yNdx) {
              if ([tgtObj putMobileObject: obj])
                [self removeObjectAtX: xNdx Y: yNdx];
            }
          }
        } else if ( [containerObjMap containsKey: obj] ) {
          id <ContainerObj> cObj = (id <ContainerObj>) obj;
          id subObj = [cObj getMobileObject];
          if ( subObj != nil ) {
            if ( (tgtObj = [self getObjectAtX: newX Y: newY]) == nil ) {
              if (newX != xNdx || newY != yNdx) {
                [cObj removeMobileObject: subObj];
                [self putObject: subObj atX: newX Y: newY];
              }
            } else if ( [containerObjMap containsKey: tgtObj] ) {
              if ([((id <ContainerObj>) tgtObj) putMobileObject: subObj])
                [cObj removeMobileObject: subObj];
            } // else do nothing with that subObj
          }
          obj = nil;
        } // else
          //    only other case is that it's fixed but not a container
          //    so move on silently
        [newPos drop]; newPos = nil;
      }
    }
    yNdx--;
  }
  return self;
}
// end blocked_flow 

- (Vector2d *) getNewPosFor: obj atX: (unsigned) x Y: (unsigned) y
{
  Vector2d *newPos=[Vector2d create: fsScratchZone dim1: x dim2: y];
  VectorMoore *fv=nil;
  double rnd=0.0F;
  unsigned tries=0L;
  id tgtObj = nil;

  fv = [flow getObjectAtX: x Y: y];
  assert( fv != nil );

  do {
    unsigned xm1=0L, xp1=0L;
    double probStateSpace=0.0F;

    // to accomodate independent modifications to this probability vector
    probStateSpace = fv->probV[southEast];
    do {
      rnd = [uDblDist getDoubleWithMin: 0.0F withMax: probStateSpace+FLT_MIN];
    } while ( !(0.0F <= rnd && rnd <= probStateSpace) );

    xm1 = (x + xsize - 1) % xsize;
    xp1 = (x + 1) % xsize;

    if ( (0.0F < rnd) && (rnd <= fv->probV[hold]) ) {
      [newPos setX: x];
      [newPos setY: y];
    } else if ( (fv->probV[hold] < rnd) && (rnd <= fv->probV[east]) ) {
      [newPos setX: xp1];
      [newPos setY: y];
    } else if ( (fv->probV[east] < rnd) && (rnd <= fv->probV[northEast]) ) {
      [newPos setX: xp1];
      [newPos setY: y-1];
    } else if ( (fv->probV[northEast] < rnd) && (rnd <= fv->probV[north]) ) {
      [newPos setX: x];
      [newPos setY: y-1];
    } else if ( (fv->probV[north] < rnd) && (rnd <= fv->probV[northWest]) ) {
      [newPos setX: xm1];
      [newPos setY: y-1];
    } else if ( (fv->probV[northWest] < rnd) && (rnd <= fv->probV[west]) ) {
      [newPos setX: xm1];
      [newPos setY: y];
    } else if ( (fv->probV[west] < rnd) && (rnd <= fv->probV[southWest]) ) {
      [newPos setX: xm1];
      [newPos setY: y+1];
    } else if ( (fv->probV[southWest] < rnd) && (rnd <= fv->probV[south]) ) {
      [newPos setX: x];
      [newPos setY: y+1];
    } else if ( (fv->probV[south] < rnd) && (rnd <= fv->probV[southEast]) ) {
      [newPos setX: xp1];
      [newPos setY: y+1];
    } else {
      raiseEvent(InternalError, "%s(%p) rnd (%g) out of bounds.\n",
             [[self class] getName], self, rnd);
    }

    // safety
    if ( [newPos getY] < 0L ) [newPos setY: 0U];

  } while ( [newPos getY] < ysize && tries++ < 9
            && (tgtObj = [self getObjectAtX: [newPos getX] Y: [newPos getY]]) != nil
            && ![containerObjMap containsKey: tgtObj] );

  // If we maxed out on tries, then we stay put
  if (tries > 9 ) {
    [newPos setX: x];
    [newPos setY: y];
  }
  return newPos;
}

// objects are mobile by default
- (void) putObject: (id) anObject atX: (unsigned) x Y: (unsigned) y
{
  id obj = nil;

  assert(0U <= y && y < ((Grid2d *)flow)->ysize);
  assert(0U <= x && x < ((Grid2d *)flow)->xsize);

  obj = [self getObjectAtX: x Y: y];

  if ( obj==nil ) {
    [self storeObject: anObject in: mobileObjMap atX: x Y: y];
  } else {
    raiseEvent(WarningMessage, "\n%s::putObject: %s(%p) atX: %d Y: %d -- "
               "Tried to overwrite object of type %s(%p).\n",
               [self getName], (anObject != nil ? [[anObject getClass] getName] : "nil"), 
               anObject, x, y, [[obj getClass] getName], obj);
    return;
  }
}

- (id) removeObjectAtX: (unsigned) x Y: (unsigned) y
{
  id obj = [self getObjectAtX: x Y: y];
  if (obj != nil && ![fixedObjMap containsKey: obj]) {

    Vector2d *v = [posMap removeKey: obj];

    [mobileObjMap removeKey: obj];
    [fixedObjMap removeKey: obj];
    [containerObjMap removeKey: obj];

    if (v != nil) { [v drop]; v = nil; }

    [super putObject: nil atX: x Y: y];
  }
  return obj;
}

- (void) storeObject: (id) anObject in: (id <Map>) objMap 
                 atX: (unsigned) x Y: (unsigned) y
{
  id obj = nil;
  assert(anObject != nil);


  if (![anObject isKindOf: [Solute class]] &&
      ![anObject conformsTo: @protocol(ContainerObj)]) {
    raiseEvent(InternalError, "\n\n!! Error! [%s(%p) -storeObject: %s(%p) in: %s(%p) atX: %d Y: %d] -- "
               "%s is neither a Solute nor a ContainerObj.\n\n", [[self getClass] getName], self,
               (anObject != nil ? [[anObject getClass] getName] : "nil"), anObject,
               [[objMap getClass] getName], objMap, x, y, [[anObject getClass] getName]);
  }


  obj = [self getObjectAtX: x Y: y];
  if (obj != nil) {
    raiseEvent(WarningMessage, 
               "\n%s::storeObject: %s(%p) in: %s(%p) atX: %d Y: %d -- "
               "Tried to overwrite object of type %s(%p).\n",
               [self getName], (anObject != nil ? 
                                [[anObject getClass] getName] : "nil"), 
               anObject, [[objMap getClass] getName], objMap, 
               x, y, [[obj getClass] getName], obj);
    return;
  }
  Vector2d *v = [Vector2d create: [self getZone]
                          dim1: (int)x dim2: (int)y];
  [posMap at: anObject insert: v];
  [objMap at: anObject insert: v];
  [super putObject: anObject atX: x Y: y];
}

- (BOOL) putMobileObject: (id) anObject atX: (unsigned) x Y: (unsigned) y
{
  id obj = nil;
  BOOL retVal = NO;
  assert(anObject != nil);

  obj = [self getObjectAtX: x Y: y];

  if (obj == nil) {
    [self storeObject: anObject in: mobileObjMap atX: x Y: y];
    retVal = YES;
  } else if ([containerObjMap containsKey: obj]) {
    if ([((id <ContainerObj>) obj) putMobileObject: anObject]) {
      retVal = YES;
    }
  } else {
    raiseEvent(WarningMessage, "\n%s::putMobileObject: %s(%p) atX: %d Y: %d -- "
               "Tried to overwrite object of type %s(%p).\n",
               [self getName], (anObject != nil ? [[anObject getClass] getName] : "nil"), 
               anObject, x, y, [[obj getClass] getName], obj);
  }

  return retVal;
}

- (void) putContainerObject: (id) anObject atX: (unsigned) x Y: (unsigned) y
{
  id obj = nil;
  assert(anObject != nil);

  if (![anObject respondsTo: M(putMobileObject:)])
    raiseEvent(InternalError, 
               "%s::putContainerObject: %s(%p) atX: %d Y: %d -- "
               "object does not respond to putObject:atX:Y\n",
               [[self getClass] getName], [[anObject getClass] getName], 
               anObject);

  obj = [self getObjectAtX: x Y: y];

  if (obj == nil) {
    [self storeObject: anObject in: containerObjMap atX: x Y: y];
  } else {
    if (![containerObjMap containsKey: obj]) {
      // if obj is not a container, repl with anObject and put obj in anObject
      [self removeObjectAtX: x Y: y];
      if ([((id <ContainerObj>) anObject) putMobileObject: obj])
        [self storeObject: anObject in: containerObjMap atX: x Y: y];
      else // if the container doesn't accept the replaced object
        raiseEvent(WarningMessage, 
                   "\n%s::putContainerObject: %s(%p) atX: %d Y: %d -- "
                   "Overwrote object of type %s(%p), which is now lost.\n",
                   [self getName], (anObject != nil ? 
                                    [[anObject getClass] getName] : "nil"),
                   anObject, x, y, [[obj getClass] getName], obj);
    } else {
      raiseEvent(WarningMessage, 
                 "\n%s::putContainerObject: %s(%p) atX: %d Y: %d -- "
                 "Tried to overwrite object of type %s(%p).\n",
                 [self getName], (anObject != nil ? 
                                  [[anObject getClass] getName] : "nil"),
                 anObject, x, y, [[obj getClass] getName], obj);
      return;
    }  
  }
}

- (void) putFixedObject: (id) anObject container: (BOOL) c 
                    atX: (unsigned) x Y: (unsigned) y
{
  id obj = nil;
  Vector2d *v = nil;
  assert (anObject != nil);

  obj = [self getObjectAtX: x Y: y];

  if (c) {
    if (obj == nil) {
      [self putContainerObject: anObject atX: x Y: y];
      v = [containerObjMap at: anObject];
      if (v != nil) [fixedObjMap at: anObject insert: v];
    } else {
      raiseEvent(WarningMessage, 
                 "\n%s::putFixedObject: %s(%p) atX: %d Y: %d -- "
                 "Tried to overwrite object of type %s(%p).\n",
                 [self getName], (anObject != nil ? 
                                  [[anObject getClass] getName] : "nil"),
                 anObject, x, y, [[obj getClass] getName], obj);
      return;
    }
  } else {
    [self storeObject: anObject in: fixedObjMap atX: x Y: y];
  }
}

- (BOOL) isMobile: (id) obj
{
  BOOL foundIt = NO;
  foundIt = [mobileObjMap containsKey: obj];
  return foundIt;
}

- (Vector2d *) getPosOfObject: anObject {
  return [posMap at: anObject];
}

- (id <List>) getObjects
{
  id <List> objects = [List create: [self getZone]];
  id <MapIndex> objNdx = [posMap mapBegin: fsScratchZone];
  id obj = nil;
  while ( ([objNdx getLoc] != End) 
          && [objNdx next: &obj] ) {
    if (obj != nil) [objects addLast: obj];
  }
  [objNdx drop]; objNdx = nil;
  return objects;
}

- (id <Map>) getPositionMap
{
  return posMap;
}

- (id <Map>) getMobileObjMap
{
  return mobileObjMap;
}

- (id <List>) getOpenPoints
{
  unsigned xNdx=0L;
  unsigned yNdx=0L;
  id <List> retVal = [List create: fsScratchZone];

  for ( xNdx=0 ; xNdx<xsize ; xNdx++ ) {
    for ( yNdx=0 ; yNdx<ysize ; yNdx++ ) {
      if ([self getObjectAtX: xNdx Y: yNdx] == nil) {
        [retVal addLast: 
                  [Vector2d create: fsScratchZone 
                            dim1: xNdx 
                            dim2: yNdx]];
      }
    }
  }
  return retVal;
}

- (id <Map>) countMobileObjects: (id <Zone>) aZone
{
  id <MapIndex> cNdx = [containerObjMap mapBegin: fsScratchZone];
  id <ContainerObj> cObj = nil;
  Vector2d *v = nil;
  id <Map> tmpMap = nil;
  id <Map> retVal = nil;

  // get number of mobile objects inside the container objects
  while ( ([cNdx getLoc] != End)
          && ( (v = [cNdx next: &cObj]) != nil) ) {
    if (cObj == nil)
      raiseEvent(InternalError, "\nmissing container object key "
                 "associated with vector value.\n");
    tmpMap = [cObj countMobileObjects: aZone];

    if (tmpMap != nil) {
      id <MapIndex> tmpNdx = [tmpMap mapBegin: fsScratchZone];
      id <Integer> num = nil;
      id <Symbol> type = nil;
      while ( ([tmpNdx getLoc] != End)
              && ( (num = [tmpNdx next: &type]) != nil) ) {
        if (retVal == nil) retVal = [Map create: fsScratchZone];
        if ([retVal containsKey: type]) {
          id <Integer> prevNum = [retVal at: type];
          int prevNum_value = [prevNum getInt];
          int newNum = prevNum_value + [num getInt];
          [prevNum setInt: newNum];
        } else {
          [retVal at: type insert: [fsScratchZone copyIVars: num]];
        }
      }
      [tmpNdx drop]; tmpNdx = nil;
      [tmpMap deleteAll];
      [tmpMap drop]; tmpMap = nil;
    }
  }
  [cNdx drop]; cNdx = nil;

  // add in the free ones in the space
  id <MapIndex> mNdx = [mobileObjMap mapBegin: fsScratchZone];
  id mObj = nil;
  while ( ([mNdx getLoc] != End)
          && ( (v = [mNdx next: &mObj]) != nil) ) {
    if ([mObj respondsTo: @selector(getType)]) {
      id <Symbol> type = [mObj getType];
      if (retVal == nil) retVal = [Map create: fsScratchZone];
      if ([retVal containsKey: type]) {
        id <Integer> prevNum = [retVal at: type];
        int prevNum_value = [prevNum getInt];
        int newNum = prevNum_value + 1;
        [prevNum setInt: newNum];
      } else {
        [retVal at: type insert: [Integer create: fsScratchZone setInt: 1L]];
      }
    }
  }
  [mNdx drop]; mNdx = nil;

  return retVal;
}

// have to use a deep copy because our clients will be using these lists
// to move things around and moving a mobile object automatically drops the
// position vector
- (id <List>) listFlowSourcePoints: (id <Zone>) aZone
{
  id <List> retVal = [List create: fsScratchZone];

  {    // get number of mobile objects inside the container objects

    id <MapIndex> cNdx = [containerObjMap mapBegin: fsScratchZone];
    id <ContainerObj> cObj = nil;
    Vector2d *v = nil;

    while ( ([cNdx getLoc] != End)
            && ( (v = [cNdx next: &cObj]) != nil) ) {
      if (cObj == nil)
        raiseEvent(InternalError, "\nmissing container object key "
                   "associated with vector value.\n");
      if ([cObj countMobileObjects: aZone] > 0) 
        [retVal addLast: [fsScratchZone copyIVars: v]];
    }
    [cNdx drop]; cNdx = nil;
  }

  {   // add in the free ones in the space
    id <MapIndex> mNdx = [mobileObjMap mapBegin: fsScratchZone];
    Vector2d *v = nil;
    while ( ([mNdx getLoc] != End)
            && ( (v = [mNdx next]) != nil) ) {
      [retVal addLast: [fsScratchZone copyIVars: v]];
    }
    [mNdx drop]; mNdx = nil;
  }

  return retVal;
}

- (id <List>) listFlowTargetPoints
{
  // get the open points (returns new list in scrachZone)
  id <List> retVal = [self getOpenPoints];
  Vector2d *v = nil;

  // append the container objects
  id <MapIndex> cNdx = [containerObjMap mapBegin: fsScratchZone];
  while ( ([cNdx getLoc] != End)
          && ( (v = [cNdx next]) != nil) ) {
    [retVal addLast: [fsScratchZone copyIVars: v]];
  }
  [cNdx drop]; cNdx = nil;

  return retVal;
}

- (void) setSnaps: (BOOL) s
{
  snapOn = s;

  if (snapOn && pngImg == (void *)0) {
    // create the image
    pngImg = gdImageCreate(xsize, ysize);

    /* Allocate the colors.  The first color in a new image, will be the
     * background color. */
    pngColors = [List create: scratchZone];
    black = gdImageColorAllocate(pngImg, 0, 0, 0);  // do this first for black bg
    white = gdImageColorAllocate(pngImg, 255, 255, 255);  // do this first for black bg

    [pngColors addLast: (id)(unsigned long)gdImageColorAllocate(pngImg, 255, 0, 0)];
    [pngColors addLast: (id)(unsigned long)gdImageColorAllocate(pngImg, 0, 255, 0)];
    [pngColors addLast: (id)(unsigned long)gdImageColorAllocate(pngImg, 0, 0, 255)];

    [pngColors addLast: (id)(unsigned long)gdImageColorAllocate(pngImg, 0, 255, 255)];
    [pngColors addLast: (id)(unsigned long)gdImageColorAllocate(pngImg, 255, 0, 255)];
    [pngColors addLast: (id)(unsigned long)gdImageColorAllocate(pngImg, 255, 255, 0)];

  } // end image and color creation

}

- (gdImagePtr) takeSnapshot
{
  if (snapOn == YES) {

    // blank the image
    gdImageFilledRectangle(pngImg, 0, 0, xsize, ysize, black);

    /* draw a pixel for every object you contain */
    id <MapIndex> vecNdx = [posMap mapBegin: scratchZone];
    id obj = nil;
    Vector2d *vec = nil;
    int xNdx = 0U, yNdx = 0U;

    id <Map> mobileTypes = [Map create: scratchZone];  // temp map to track mobile types
    id <ListIndex> colorNdx = [pngColors listBegin: scratchZone];
    while ( ([vecNdx getLoc] != End)
            && ((vec = [vecNdx next: &obj]) != nil) ) {
      xNdx = vec->x;
      yNdx = vec->y;
      unsigned long color = black;
      if (![self isMobile: obj]) 
        color = white;  // fixed objects are white
      else {
        if ([obj respondsTo: @selector(getType)]) {
          id <Symbol> t = [(Solute*)obj getType];
          if ([mobileTypes containsKey: t])
            color = (int)(unsigned long)[mobileTypes at: t];
          else {
            if ([colorNdx getLoc] == End) [colorNdx setLoc: Start];
            unsigned long newColor = (unsigned long)[colorNdx next];
            [mobileTypes at: t insert: (id)newColor];
            color = newColor;
          }
        } else
          color = black; // don't know what this is so ignore it.
      }
      gdImageSetPixel(pngImg, xNdx, yNdx, color);
    }
    [vecNdx drop]; vecNdx = nil;
    [colorNdx drop]; colorNdx = nil;
    [mobileTypes removeAll];
    [mobileTypes drop]; mobileTypes = nil;

  } else {
    raiseEvent(WarningMessage, "%s::takeSnapshot -- Cannot call this "
               "method when Snapshots are off.  Will not take snapshots.\n",
               [[self getClass] getName]);
  }

  return pngImg;
}

- (void) describe: outputCharStream withDetail: (short int) d
{
  id <OutputStream> os = outputCharStream;
  id <Map> mobileObjects = [self countMobileObjects: fsScratchZone];
  id <Integer> num = nil;
  id <Symbol> type = nil;

  [os catC: " ("];
  if (mobileObjects != nil) {
    id <MapIndex> mNdx = [mobileObjects mapBegin: fsScratchZone];
    if ([mNdx getLoc] != End) num = [mNdx next: &type];
    if (num != nil && type != nil) {
      [os catC: [type getName]];
      [os catC: ": "];
      [os catC: [num intStringValue]];
    }
    while ( ([mNdx getLoc] != End)
            && ( (num = [mNdx next: &type]) != nil) ) {
      [os catC: ", "];
      [os catC: [type getName]];
      [os catC: ": "];
      [os catC: [num intStringValue]];
      [os catC: " "];
    }
    [mNdx drop]; mNdx = nil;
    [mobileObjects deleteAll];
    [mobileObjects drop]; mobileObjects = nil;
  }
  [os catC: ") "];
  
}
- setName: (const char *)n {
  spaceName = n;
  return self;
}
- (const char *)getName { return spaceName; }

+ createBegin: aZone
{
  FlowSpace *obj = [super createBegin: aZone];
  obj->snapOn = NO;
  return obj;
}

- createEnd
{
  FlowSpace *obj = [super createEnd];

  obj->flow = [Grid2d create: [self getZone] setSizeX: xsize Y: ysize];

  obj->spaceName = [[obj getClass] getName];

  obj->posMap = [Map createBegin: [self getZone]];
  //[obj->posMap setCompareFunction: obj_compare];
  obj->posMap = [obj->posMap createEnd];

  obj->fixedObjMap = [Map createBegin: [self getZone]];
  //[obj->fixedObjMap setCompareFunction: obj_compare];
  obj->fixedObjMap = [obj->fixedObjMap createEnd];

  obj->mobileObjMap = [Map createBegin: [self getZone]];
  //[obj->mobileObjMap setCompareFunction: obj_compare];
  obj->mobileObjMap = [obj->mobileObjMap createEnd];

  obj->containerObjMap = [Map createBegin: [self getZone]];
  //[obj->containerObjMap setCompareFunction: obj_compare];
  obj->containerObjMap = [obj->containerObjMap createEnd];

  obj->fsScratchZone = [Zone create: [self getZone]];

  return obj;
}

- (void) drop
{
  if (snapOn && pngImg != (gdImagePtr)nil) {
    /* Destroy the image in memory. */
    gdImageDestroy(pngImg);
    [pngColors removeAll];
    [pngColors drop]; pngColors = nil;
  }

  [super drop];
}
@end

