/*
 * IPRL - Data structure for spaces sandwiched by other spaces
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

#import <LocalRandom.h>
#import "MiddleSpace.h"

static id <Symbol> Inward, Outward;

@implementation MiddleSpace

+ createBegin: aZone
{
  if (Inward == nil) {
    // use globalZone since these are static variables
    Inward = [Symbol create: globalZone setName: "Inward"];
    Outward = [Symbol create: globalZone setName: "Outward"];
  }
  MiddleSpace *obj = [super createBegin: aZone];
  obj->soluteTypes = [List create: aZone];
  return obj;
}

- createEnd
{
  MiddleSpace * obj = [super createEnd];
  obj->in2self_JumpProb = 0.5F;
  obj->self2in_JumpProb = 0.5F;
  obj->self2out_JumpProb = 0.5F;
  obj->out2self_JumpProb = 0.5F;

  if (obj->soluteTypes == nil)
    raiseEvent(LoadError, "[%s(%p) -createEnd] -- soluteTypes recognized is nil.\n",
               [[self getClass] getName], self);
  if ([obj->soluteTypes getCount] == 0U)
    [Telem monitorOut: 1 printf: "Warning!!! [%s(%p) -createEnd] -- |soluteTypes| == 0.\n",
           [[self getClass] getName], self];

  {
    [Telem debugOut: 1 printf: "[%s:%p -createEnd] -- soluteTypes = ", [[self getClass] getName], self];
    id <SoluteTag> type = nil;
    int stNdx = 0U;
    for ( stNdx=0U; stNdx<[soluteTypes getCount] ; stNdx++ ) {
      type = [soluteTypes atOffset: stNdx];
      if (type != nil) {
        [Telem debugOut: 1 printf: "%s%s", [type getName],
               (stNdx == [soluteTypes getCount]-1 ? "\n" : ", ")];
      }
    }
  }

  [Telem debugOut: 5 printf: "[%s:%p -createEnd] -- returning %s:%p\n",
         [[self getClass] getName], self, [[obj getClass] getName], obj];

  return obj;
}

- setInnerSpace: iSpace {
  innerSpace = (FlowSpace *)iSpace;
  return self;
}

- setOuterSpace: oSpace {
  outerSpace = (FlowSpace *)oSpace;
  return self;
}

- (void) setFlowIn2Self: (float) i2s self2In: (float) s2i 
                self2Out: (float) s2o out2Self: (float) o2s
{
  assert( i2s <= 1.0F && s2i <= 1.0F);
  assert( s2o <= 1.0F && o2s <= 1.0F);

  [Telem debugOut: 5 printf: "Setting jumpProbs: "
         "in2self-JumpProb = %f, self2in_JumpProb = %f, "
         "self2out_JumpProb = %f, out2self_JumpProb = %f\n",
         in2self_JumpProb, self2in_JumpProb, self2out_JumpProb, out2self_JumpProb];

  in2self_JumpProb = i2s;
  self2in_JumpProb = s2i;
  self2out_JumpProb = s2o;
  out2self_JumpProb = o2s;
}

- (void) recognize: (id <SoluteTag>) tag
{
  if (tag == nil) raiseEvent(InternalError, "[%s(%p) -recognize: %p] -- tag can't be nil.", 
                             [[self getClass] getName], self, tag);
  if (![soluteTypes contains: tag]) 
    [soluteTypes addLast: tag];
}

- (struct factor_pair) get_overlap_factors: (int)source_x_size 
                                          : (int)source_y_size 
                                          : (int)target_x_size 
                                          : (int)target_y_size 
                                          : (int)source_x_index 
                                          : (int)source_y_index 
                                          : (int)target_x_index 
                                          : (int)target_y_index
{
  //  return [self internal_get_overlap_factors_correct: source_x_size
  //               : source_y_size : target_x_size : target_y_size : source_x_index
  //               : source_y_index : target_x_index : target_y_index ];

  return [self internal_get_overlap_factors_fast: source_x_size 
               : source_y_size 
               : target_x_size  : target_y_size 
               : source_x_index : source_y_index 
               : target_x_index : target_y_index ];
}

  // This was the initial implementation, but was way too slow..

- (struct factor_pair) 
internal_get_overlap_factors_correct: (int)source_x_size 
                                    : (int)source_y_size 
                                    : (int)target_x_size 
                                    : (int)target_y_size 
                                    : (int)source_x_index 
                                    : (int)source_y_index 
                                    : (int)target_x_index 
                                    : (int)target_y_index
{
  // Create a virtual grid box that fits into both source and target
  // grids...  Then count the number of those cells that are in both
  // source and target cells, normalized.

  int grid_x_size = source_x_size * target_x_size;
  int grid_y_size = source_y_size * target_y_size;

  struct factor_pair _factors;
  
  int grid_x_index = 0;
  int grid_y_index = 0;
  int total_grid_in_source = 0;
  int total_grid_in_target = 0;
  int total_grid_in_both = 0;

  // Calculate the corners of the source/target cells, normalized to a
  // (0,1)x(0,1) grid

  double target_x_bottom = ((double)target_x_index)/((double)target_x_size);
  double target_y_bottom = ((double)target_y_index)/((double)target_y_size);
  double target_x_top = ((double)target_x_index + 1.0)/((double)target_x_size);
  double target_y_top = ((double)target_y_index + 1.0)/((double)target_y_size);

  double source_x_bottom = ((double)source_x_index)/((double)source_x_size);
  double source_y_bottom = ((double)source_y_index)/((double)source_y_size);
  double source_x_top = ((double)source_x_index + 1.0)/((double)source_x_size);
  double source_y_top = ((double)source_y_index + 1.0)/((double)source_y_size);

  for (grid_x_index = 0; grid_x_index < grid_x_size; grid_x_index++) {
    for (grid_y_index = 0; grid_y_index < grid_y_size; grid_y_index++) {
      int is_in_source = 0;
      int is_in_target = 0;

      // Calculate the center of mass of this grid
      double x_com = ((double)grid_x_index + 0.5)/((double)grid_x_size);
      double y_com = ((double)grid_y_index + 0.5)/((double)grid_y_size); 

      // Is it in the source grid cell of interest?
      if ((x_com > source_x_bottom) && (x_com < source_x_top) &&
          (y_com > source_y_bottom) && (y_com < source_y_top)) {
        is_in_source = 1;
      }

      // Is it in the target grid cell of interest?
      if ((x_com > target_x_bottom) && (x_com < target_x_top) &&
          (y_com > target_y_bottom) && (y_com < target_y_top)) {
        is_in_target = 1;
      }

      if (is_in_source && is_in_target) {
        total_grid_in_both++;
      }
      if (is_in_source) {
        total_grid_in_source++;
      }
      if (is_in_target) {
        total_grid_in_target++;
      }      
    }
  }

  _factors.source_factor = 
    ((double)total_grid_in_both)/((double)total_grid_in_source);

  _factors.target_factor = 
    ((double)total_grid_in_both)/((double)total_grid_in_target);

  return _factors;
}



// Improved speed, but assuming that one of the grid fits completely
// in the other (eg, all of the boundaries of one grid perfectly
// overlay some, but perhaps not all, the boundaries of the other
// grid).

- (struct factor_pair) 
internal_get_overlap_factors_fast: (int)source_x_size 
                                 : (int)source_y_size 
                                 : (int)target_x_size 
                                 : (int)target_y_size 
                                 : (int)source_x_index 
                                 : (int)source_y_index 
                                 : (int)target_x_index 
                                 : (int)target_y_index
{
  // Create a virtual grid box that fits into both source and target
  // grids...  Then count the number of those cells that are in both
  // source and target cells, normalized.

  int grid_x_size = 
    (source_x_size > target_x_size) ? source_x_size : target_x_size;

  int grid_y_size = 
    (source_y_size > target_y_size) ? source_y_size : target_y_size;

  // find the multipliers between the two grid sizes
  double x_multiplier = 1.0;
  double y_multiplier = 1.0;
  int is_source_finer = 0; // is the source grid finer, or coarser?

  if (grid_x_size == source_x_size) {
    x_multiplier = ((double)target_x_size)/((double)source_x_size);
  } else {
    x_multiplier = ((double)source_x_size)/((double)target_x_size);
    is_source_finer = 1;
  }
  if (grid_y_size == source_y_size) {
    y_multiplier = ((double)target_y_size)/((double)source_y_size);
  } else {
    y_multiplier = ((double)source_y_size)/((double)target_y_size);
    is_source_finer = 1; // this is really redundant, based on the assumption
  }

  struct factor_pair _factors;
  _factors.source_factor = 0;
  _factors.target_factor = 0;

  // Now, take the smaller grid, and figure out if its selected cell
  // hits the larger grid's selected cell
  if (is_source_finer) {
    // normalized to a 1x1 grid, com = center of mass
    double com_x = ((double)source_x_index + 0.5)/((double)source_x_size);
    double com_y = ((double)source_y_index + 0.5)/((double)source_y_size);
    if ((com_x > ((double)target_x_index)/((double)target_x_size)) &&
        (com_x < ((double)target_x_index + 1.0)/((double)target_x_size)) &&
        (com_y > ((double)target_y_index)/((double)target_y_size)) &&	
        (com_y < ((double)target_y_index + 1.0)/((double)target_y_size)))
      {
        _factors.source_factor = 1.0;
        _factors.target_factor = (x_multiplier * y_multiplier);
      } // else, no match--factors are (0,0)
  } else {
    // normalized to a 1x1 grid, com = center of mass
    double com_x = ((double)target_x_index + 0.5)/((double)target_x_size); 
    double com_y = ((double)target_y_index + 0.5)/((double)target_y_size);
    if ((com_x > ((double)source_x_index)/((double)source_x_size)) &&
        (com_x < ((double)source_x_index + 1.0)/((double)source_x_size)) &&
        (com_y > ((double)source_y_index)/((double)source_y_size)) &&	
        (com_y < ((double)source_y_index + 1.0)/((double)source_y_size)))
      {
        _factors.source_factor = (x_multiplier * y_multiplier);
        _factors.target_factor = 1.0;
      } // else, no match--factors are (0,0)
  }
  return _factors;
}





- (id <Map>) calcGridPointExchangeFrom: (FlowSpace *) fromSpace atX: (unsigned) fromX Y: (unsigned) fromY to: (FlowSpace *) toSpace 
{
  MiddleSpace * caller = nil;
  if ([toSpace isKindOf: [MiddleSpace class]]) caller = (MiddleSpace *)toSpace;
  else if ([fromSpace isKindOf: [MiddleSpace class]]) caller = (MiddleSpace *)fromSpace;


  int toSpace_x_size = toSpace->xsize;
  int toSpace_y_size = toSpace->ysize;

  int fromSpace_x_size = [fromSpace getSizeX];
  int fromSpace_y_size = [fromSpace getSizeY];

  Vector2d * vector2d = nil;
  int fromSpace_factor = 0;
  int toSpace_factor = 0;
  unsigned toSpaceX = 0L;
  unsigned toSpaceY = 0L;

  id <Map> exchangeMap = nil;

  /*
   * could also use the below for inter-space moore neighborhood
   */
  if (toSpace_x_size != fromSpace_x_size || toSpace_y_size != fromSpace_y_size) {
    // loop through MiddleSpace targets to find and schedule good receiver points
    id <List> objList = [toSpace listFlowTargetPoints];
    id <ListIndex> objNdx = [objList listBegin: scratchZone];
    while ( ([objNdx getLoc] != End)
            && ( (vector2d = [objNdx next]) != nil) ) {
      toSpaceX = [vector2d getX];
      toSpaceY = [vector2d getY];
      struct factor_pair _fp = [caller get_overlap_factors 
                                     : fromSpace_x_size : fromSpace_y_size
                                     : toSpace_x_size : toSpace_y_size
                                     : fromX : fromY
                                     : toSpaceX : toSpaceY];

      fromSpace_factor = _fp.source_factor;
      toSpace_factor = _fp.target_factor;

      // if both are non-zero, exchange
      if (fromSpace_factor && toSpace_factor) { 
        // Jump from fromSpace to toSpace; 
        // (this cell of toSpace only has access to fromSpace_factor
        // of the total solute in this cell of fromSpace; eg,
        // fromSpace_factor = .5 => 50% of solute is
        // available). Continuous model.

        if (exchangeMap == nil) exchangeMap = [Map create: scratchZone];
        [exchangeMap 
          at: [scratchZone copyIVars: vector2d]
          insert: 
            [Pair 
              create: scratchZone 
              setFirst: 
                [Double create: scratchZone setDouble: fromSpace_factor]
              second: 
                [Double create: scratchZone setDouble: toSpace_factor]]];
      }
    }
    [objNdx drop]; objNdx = nil;
    [objList deleteAll];  // because we deep copied all the vector2d objects
    [objList drop]; objList = nil;

  } else {
    // same size space so just consider this point
    if (exchangeMap == nil) exchangeMap = [Map create: scratchZone];
    [exchangeMap 
      at: [Vector2d create: scratchZone dim1: fromX dim2: fromY]
      insert: [Pair create: scratchZone
                    setFirst: [Double create: scratchZone setDouble: 1.0F]
                    second: [Double create: scratchZone setDouble: 1.0F]]];
  }

  return exchangeMap;
}









- (void) pumpToCell: (Cell *) cell fromSpace: (FlowSpace *) aSpace 
                   : (int)x : (int)y 
{
  id obj = [aSpace getObjectAtX: x Y: y];

  if (obj == nil) return;


  [Telem debugOut: 4 printf: "MiddleSpace::pumpToCell: %s(%p) from Space: %s(%p) "
         ": %d : %d : %lf : %lf -- begin\n", [cell getName], cell,
         [aSpace getName], aSpace, x, y];


  if ( [aSpace isMobile: obj] ) {
    [Telem debugOut: 6 printf: "%s(%p) jumping from %s to %s.\n",
           [[obj getClass] getName], obj, [aSpace getName], 
           [self getName]];
    if ([cell putMobileObject: obj]) { // add to espace
      // if cell accepts the object, remove it from aSpace
      [aSpace removeObjectAtX: x Y: y];
    }
  } 
  /*
   * else its fixed and/or a container and we cant pump it.  if it's a
   * container, we can't just reach in and grab a solute from inside
   * because particles don't necessarily diffuse from within one cell
   * directly into another
   */

  [Telem debugOut: 4 printf: "MiddleSpace::pumpToCell: -- exit\n"];

}


- (void) moveParticle: (Particle *) mobileObj from: (FlowSpace *) fromSpace 
                  atX: (unsigned) fromX Y: (unsigned) fromY 
                   to: (FlowSpace *) toSpace using: (id <Map>) exchangeMap
             withProb: (float) jumpProb
{
  // actually try to move those identified above
  id <Pair> pair = nil;
  Vector2d *vector2d = nil;
  if (exchangeMap != nil) {
    id fromSpaceObj = [fromSpace getObjectAtX: fromX Y: fromY];
    id <MapIndex> exchNdx = [exchangeMap mapBegin: scratchZone];
    while ( ([exchNdx getLoc] != End)
            && ( (pair = [exchNdx next: &vector2d]) != nil) ) {
      double overlapDegree = [((id <Double>) [pair getFirst]) getDouble];
      unsigned toSpaceX = [vector2d getX];
      unsigned toSpaceY = [vector2d getY];
      id obj = [toSpace getObjectAtX: toSpaceX Y: toSpaceY];

      if (obj == nil) {

        double jumpDraw = overlapDegree 
          * [uDblDist getDoubleWithMin: 0.0F withMax: 1.0F];

        if (jumpDraw < jumpProb) {


          if (mobileObj == fromSpaceObj) {
            if ([toSpace putMobileObject: fromSpaceObj atX: toSpaceX Y: toSpaceY]) 
              [fromSpace removeObjectAtX: fromX Y: fromY];
          } else { // fromSpaceObj must be a container
            if ([toSpace putMobileObject: mobileObj atX: toSpaceX Y: toSpaceY])
              mobileObj = [fromSpaceObj removeMobileObject: mobileObj];
          }


        } // else if ([containerObjMap containsKey: obj]) {
//           [toSpace putMobileObject: mobileObj atX: fromX Y: fromY];
//         }
      }
    }

    { // cleanup
      id obj = nil;
      id key = nil;
      [exchNdx setLoc: Start];
      while ( ([exchNdx getLoc] != End)
              && ( (obj = [exchNdx next: &key]) != nil) ) {
        [obj drop]; obj = nil;
        [key drop]; key = nil;
      }
    }
    [exchNdx drop]; exchNdx = nil;
  }
}





// xNdx, yNdx is a point in aSpace that solute could flow from
// one aSpace point to many eSpace points
- (void)inFlowFrom: (FlowSpace *) aSpace 
         mobileObj: (id) mobileObj
             inDir: (id <Symbol>) dir
               atX: (unsigned) xNdx Y: (unsigned) yNdx 
          withProb: (float) jumpProb
{
  /*
   * test for solute type to see if I handle that type
   */
  {

    // if I don't handle that object, transfer directly to my outerSpace
    id <SoluteTag> type = nil;
    type = [mobileObj getType];
    if (type == nil) {
      raiseEvent(InternalError, "[%s:%p -inFlowFrom: %s:%p ...] -- "
                 "[%s:%p -getType] returns nil.\n", 
                 [[self getClass] getName], self,
                 [[aSpace getClass] getName], aSpace,
                 [[mobileObj getClass] getName], mobileObj);
    }

    if (![soluteTypes contains: type]) {

      [Telem debugOut: 5 printf: "[%s(%p) -inFlowFrom:...] -- soluteTypes does not contain %s\n", [[self getClass] getName], self, [type getName]];

      // set direction of the transfer
      id tgtSpace = (dir == Outward ? outerSpace : innerSpace);
      if (![tgtSpace isKindOf: [MiddleSpace class]])
        raiseEvent(InternalError, "[%s:%p -inFlowFrom: %s:%p ...] -- "
                   "Trying to pass on type = %s; but %s:%p is not a MiddleSpace!\n",
                   [[self getClass] getName], self, 
                   [[aSpace getClass] getName], aSpace,
                   [type getName],
                   [[tgtSpace getClass] getName], tgtSpace);

      [tgtSpace inFlowFrom: aSpace mobileObj: mobileObj inDir: dir atX: xNdx Y: yNdx withProb: jumpProb];

      [Telem debugOut: 5 printf: "\tsent %s to %s(%p)\n", [type getName], [[tgtSpace getClass] getName], tgtSpace];
      return;
    }
  }


  id <Map> exchangeMap = [self calcGridPointExchangeFrom: aSpace atX: xNdx Y: yNdx to: self ];
  [self moveParticle: mobileObj from: aSpace atX: xNdx Y: yNdx to: self using: exchangeMap withProb: jumpProb];

  [exchangeMap removeAll];
  [exchangeMap drop]; exchangeMap = nil;

  [Telem debugOut: 5 printf: "[%s:%p -inFlowFrom: %s(%p) inDir: %s atX: %u Y: %u -- end\n",
         [[self getClass] getName], self, [aSpace getName], aSpace, [dir getName], xNdx, yNdx];
}

- (void)inFlowFrom: (FlowSpace *) aSpace 
             inDir: (id <Symbol>) dir
               atX: (unsigned) xNdx Y: (unsigned) yNdx 
          withProb: (float) jumpProb
{

  [Telem debugOut: 5 printf: "[%s:%p -inFlowFrom: %s(%p) inDir: %s atX: %u Y: %u] -- begin\n",
         [[self getClass] getName], self, [aSpace getName], aSpace, 
         [dir getName], xNdx, yNdx];
    /*
     * If aSpaceObj is mobile, use it as the mobileObj.
     *
     * But if aSpaceObj is a container, try to get a mobile object from
     * that container.
     *
     * If none of the above, mobileObj == nil;
     */
    id aSpaceObj = [aSpace getObjectAtX: xNdx Y: yNdx];
    id mobileObj = nil;
    if ([aSpace isMobile: aSpaceObj]) {
      mobileObj = aSpaceObj;
    } else {
      if ([aSpaceObj conformsTo: @protocol(ContainerObj)]) {
        mobileObj = [aSpaceObj getMobileObject];
      }
    }
    if (mobileObj == nil) return;

    [self inFlowFrom: aSpace mobileObj: mobileObj inDir: dir atX: xNdx Y: yNdx withProb: jumpProb];

}

// xNdx, yNdx are points in MiddleSpace to take solute from
// one spot in MiddleSpace to many spots in aSpace
- (void) outFlowTo: (FlowSpace *) aSpace outDir: (id <Symbol>) dir 
               atX: (unsigned) xNdx Y: (unsigned) yNdx 
          withProb: (float) jumpProb
{

  if ([aSpace isKindOf: [MiddleSpace class]]) 
    [((MiddleSpace *)aSpace) inFlowFrom: self inDir: dir atX: xNdx Y: yNdx withProb: jumpProb];
  else {
    /*
     * If selfSpaceObj is mobile, use it as the mobileObj.
     *
     * But if selfSpaceObj is a container, try to get a mobile object
     * from that container.
     *
     * If none of the above, mobileObj == nil;
     */
    id selfSpaceObj = [self getObjectAtX: xNdx Y: yNdx];
    id mobileObj = nil;
    if ([self isMobile: selfSpaceObj]) {
      mobileObj = selfSpaceObj;
    } else {
      if ([selfSpaceObj conformsTo: @protocol(ContainerObj)]) {
        mobileObj = [selfSpaceObj getMobileObject];
      }
    }
    if (mobileObj == nil) return;

    id <Map> exchangeMap = [self calcGridPointExchangeFrom: self atX: xNdx Y: yNdx to: aSpace];
    [self moveParticle: mobileObj from: self atX: xNdx Y: yNdx to: aSpace using: exchangeMap withProb: jumpProb];
    [exchangeMap removeAll];
    [exchangeMap drop]; exchangeMap = nil;

  }

}

- flow
{
  id <List> flowPoints = nil;
  id <ListIndex> ptNdx = nil;
  id <Zone> tmpZone = [Zone create: scratchZone];
  Vector2d *point = nil;

  [Telem debugOut: 6 printf: "MiddleSpace::flow -- in from innerSpace\n"];

  // inflow from sSpace
  flowPoints = [innerSpace listFlowSourcePoints: tmpZone];
  ptNdx = [flowPoints listBegin: tmpZone];
  while ( ([ptNdx getLoc] != End)
          && ( (point = [ptNdx next]) != nil) ) {
    [self inFlowFrom: innerSpace inDir: Outward atX: point->x Y: point->y withProb: in2self_JumpProb];
  }
  [ptNdx drop]; ptNdx = nil;
  [flowPoints deleteAll];  // because listFlowSourcePoints is a deep copy
  [flowPoints drop]; flowPoints = nil;

  [Telem debugOut: 6 printf: "MiddleSpace::flow -- in from outerSpace\n"];

  // inflow from outerSpace
  flowPoints = [outerSpace listFlowSourcePoints: tmpZone];
  ptNdx = [flowPoints listBegin: tmpZone];
  while ( ([ptNdx getLoc] != End)
          && ( (point = [ptNdx next]) != nil) ) {
    [self inFlowFrom: outerSpace inDir: Inward atX: point->x Y: point->y withProb: out2self_JumpProb];
  }
  [ptNdx drop]; ptNdx = nil;
  [flowPoints deleteAll];
  [flowPoints drop]; flowPoints = nil;

  [Telem debugOut: 6 printf: "MiddleSpace::flow -- out to innerSpace\n"];

  flowPoints = [self listFlowSourcePoints: tmpZone];
  ptNdx = [flowPoints listBegin: tmpZone];
  while ( ([ptNdx getLoc] != End)
          && ( (point = [ptNdx next]) != nil) ) {
    [self outFlowTo: innerSpace outDir: Inward atX: point->x Y: point->y withProb: self2in_JumpProb];
  }
  [ptNdx drop]; ptNdx = nil;
  [flowPoints deleteAll];
  [flowPoints drop]; flowPoints = nil;

  [Telem debugOut: 6 printf: "MiddleSpace::flow -- out to outerSpace\n"];

  flowPoints = [self listFlowSourcePoints: tmpZone];
  ptNdx = [flowPoints listBegin: tmpZone];
  while ( ([ptNdx getLoc] != End)
          && ( (point = [ptNdx next]) != nil) ) {
    [self outFlowTo: outerSpace outDir: Outward atX: point->x Y: point->y withProb: self2out_JumpProb];
  }
  [ptNdx drop]; ptNdx = nil;
  [flowPoints deleteAll];
  [flowPoints drop]; flowPoints = nil;
  [tmpZone drop]; tmpZone = nil;

  return self;
}

- (void) describe: outputCharStream withDetail: (short int) d
{ 
  [outputCharStream catC: "middleSpace:"];
  [super describe: outputCharStream withDetail: d];
}

@end
