/*
 * IPRL - Sinusoidal Segment
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
#import <math.h>
#import "ECell.h"
#import "Hepatocyte.h"
#import <LocalRandom.h>

#import "Sinusoid.h"

@implementation Sinusoid

- stepPhysics
{
  [sSpace flow];

  // send -flow to all the buffer spaces
  [buffSpaces forEach:  @selector(flow)];

  [eSpace flow];
  [sod flow];
  [bileCanal flow];
  return self;
}

- (BOOL) findOutFlowFor: obj
{
  id <List> tempList = [List create: scratchZone];
  unsigned numTaken=0;
  BOOL retVal=NO;

  [Telem debugOut: 3 printf: "[%s(%p) -findOutFlowFor: %s(%p)] -- begin.\n",
         [[self getClass] getName], self, [[obj getClass] getName], obj];

  if ([obj isKindOf: [Solute class]]) {
      // look in toList and find a place for this dude to go
      // using a new list is a bit wasteful... but it reuses code
      [tempList addLast: obj];
      id <List> taken = [self distributeSolutesFrom: tempList];
      numTaken = [taken getCount];
      [taken drop]; taken = nil;
      if (numTaken < 1) retVal = NO;
      else {
        retVal = YES;
        // don't forget to move it out of the solutes list
        [solutes remove: obj];
      }
      [tempList removeAll];
      [tempList drop]; tempList = nil;
  } // end if ([obj isKindOf: [Solute class]])

  return retVal;
}

- (BOOL) findBileOutFlowFor: (Solute *) obj
{
  [Telem debugOut: 3 printf: "[%s:%d(%p) -findBileOutFlowFor: %s(%p)] -- begin\n",
         [[self getClass] getName], [self getNumber], self, [[obj getClass] getName], obj];

  BOOL retVal=NO;
  // metabolites go directly to bileCanal, which means this code
  // is very different from the code that handles injected solute

  // walk the toList and find a bileCanal to put it in
  id <Permutation> p = 
    [[[[Permutation createBegin: scratchZone]
        setUniformRandom: uUnsDist]
       setCollection: toList]
      createEnd];
  int toNdx = 0;
  for ( toNdx=0 ; toNdx<[p getCount] ; toNdx++ ) {
    FlowLink *fl = nil;
    fl = [[p atOffset: toNdx] getItem];
    LiverNode *toNode = (LiverNode *)[fl getTo];
    // if SS check if there is enough room
    if ([toNode isKindOf: [Sinusoid class]])
      if ([((FlowTube *)((Sinusoid *)toNode)->bileCanal) getHolesAtY: 0] < 1)
	continue;

    [Telem debugOut: 3 printf: "[%s(%p) -findBileOutFlowFor: %s(%p)] -- sending solute to %s(%p)\n",
           [[self getClass] getName], self, [[obj getClass] getName], obj,
           [[toNode getClass] getName], toNode];

    [toNode takeMetabolite: obj];
    [bileCanal removeObject: obj at: length-1];
    [solutes remove: obj];
    retVal = YES;
    break;
    // else continue to the next to output
  } // end for over toList

  [Telem debugOut: 3 printf: "[%s:%d(%p) -findBileOutFlowFor: %s(%p)] -- end\n",
         [[self getClass] getName], [self getNumber], self, [[obj getClass] getName], obj];

  return retVal;
}
  
/*
 * calcCC - for the sinusoid, there can be a significant error
 *          between what getCC reports and what actually flows
 *          into the sinusoid.
 */
- (unsigned) calcCC 
{
  unsigned myCC=0;
  myCC = [self intakeRuleEst];
  _cc_ = myCC;
  return _cc_;
}

- (id <List>) takeSolutesFrom: (id <List>) fl {
  id <List> retList = [self intakeRule: fl];
  return retList;
}

/* 
 * called from other SSes
 */
- (void) takeMetabolite: (Solute *) m
{
  [super takeMetabolite: m];
  [bileCanal storeObject: m at: 0];
}

/*
 * called from Hepatocyte that created the metabolite
 */
- (void) takeMetabolite: (Solute *) s from: (Hepatocyte *) h
{
  Vector2d *v = [sod getPosOfObject: h];
  [super takeMetabolite: s];
  [bileCanal storeObject: s at: v->y];
}

/*
 * intakeRuleEst() -- just the area implied by the circumference of
 *                    the tube.
 */
- (unsigned) intakeRuleEst 
{
  return [SinusoidalSpace calcAreaFromCirc: sSpace->xsize];
}

/*
 * the BUFFER_INTAKE switch allows solute to be placed directly into a
 * buffer space, rather than going through the sSpace first.
 * BUFFER_INTAKE = YES means allow solute into buffer spaces.
 */
#define BUFFER_INTAKE YES

- (id <List>) intakeRule: (id <List>) inList 
{
  unsigned numTaken=0;
  id <List> retList = nil;
  unsigned xNdx=0;
  unsigned numHoles=0;
  id <List> moveList = [List create: scratchZone];
  id <ListIndex> moveNdx = nil;
  id obj = nil;

  /*
   * using beginPermuted resulted in multiple copies of the same
   * solute being added to the moveList.  It only appeared after ~ 20
   * mc trials, though, which means _if_ it's a bug in swarm's
   * permuted index, it's very rare.  
   * -- gepr 2009-09-21
   */

  // add some to the outer ring of the space and to the buffers
//  id <PermutedIndex> xferNdx = nil;
//  xferNdx = [inList beginPermuted: scratchZone]; // really should use model rng
  id <ListIndex> xferNdx = [inList listBegin: scratchZone];

  int numBuffers = [(id <ArtModel>)_parent getNumBuffSpaces];
  if (BUFFER_INTAKE && numBuffers > 0) {
    id <List> spaceList = [List create: scratchZone];
    [spaceList addLast: sSpace];
    int bsNdx = 0U;
    for ( bsNdx = 0U ; bsNdx < numBuffers ; bsNdx++ ) {
      [spaceList addLast: [buffSpaces atOffset: bsNdx]];
    }
    // should use model rng
    id <PermutedIndex> spaceNdx = [spaceList beginPermuted: scratchZone];
    FlowSpace *space = nil;
    while (([spaceNdx getLoc] != End)
           && (space = [spaceNdx next]) != nil) {
      for ( xNdx=0 ; xNdx<space->xsize ; xNdx++ ) {
        if ( [space getObjectAtX: xNdx Y: 0] == nil) {
          if ( [xferNdx getLoc] != End ) {
            if ((obj = [xferNdx next]) != nil) {
              if ( [space isKindOf: [MiddleSpace class]] && [((MiddleSpace *)space)->soluteTypes contains: [obj getType]]) {
                if ( [space putMobileObject: (Solute *)obj atX: xNdx Y: 0]) {
		  if ([solutes contains: obj])
		    raiseEvent(InternalError, "%s(%p) already in %s(%p)\n", [[obj getClass] getName], obj, [[solutes getClass] getName], solutes);
                  [solutes addLast: obj];
                  numTaken++;
                  [moveList addLast: obj];
                } // end if put worked
              } // end if space is MiddleSpace && MiddleSpace recognizes solute
            } // end if the next solute != nil
          } // end if we still have solute to move
        } // end if <xNdx,0> == nil
      } // end for (circumference of that space)
    } // end while(spaceNdx)
    [spaceNdx drop]; spaceNdx = nil;
    [spaceList removeAll];
    [spaceList drop]; spaceList = nil;
    
  } else { // no buffer spaces

    for ( xNdx=0 ; xNdx<sSpace->xsize ; xNdx++ ) {
      if ( [sSpace getObjectAtX: xNdx Y: 0] == nil ) {
        if ( [xferNdx getLoc] != End ) {
          if ((obj = [xferNdx next]) != nil) {
            if ([sSpace putMobileObject: (Solute *)obj atX: xNdx Y: 0]) {
	      if ([solutes contains: obj])
		raiseEvent(InternalError, "%s(%p) already in %s(%p)\n", [[obj getClass] getName], obj, [[solutes getClass] getName], solutes);
              [solutes addLast: obj];
              numTaken++;
              [moveList addLast: obj];
            } // end of if-test to see if sspace accepted mobile object
          }
        }
      } 
    }
  } // end if (numBuffer > 0)
  [xferNdx drop]; xferNdx = nil;

  // clear the moved ones out of the original list
  moveNdx = [moveList listBegin: scratchZone];
  while ( ([moveNdx getLoc] != End)
          && ((obj = [moveNdx next]) != nil) ) {
    [inList remove: obj];
  }
  [moveNdx drop]; moveNdx = nil;

  // add the moved ones to the return list
  retList = [moveList copy: [self getZone]];

//   if ( duplicates(retList) )
//     [Telem debugOut: 0 printf: "[Sinusoid -intakeRuleEst:] 241 -- retList has duplicates\n"];

  [moveList removeAll];
  [moveList drop]; moveList = nil;

  // add the rest to the core and solutes list
  numHoles = [sSpace->core getHolesAtY: 0];
  if ( numHoles>0 ) {
    id <List> xferList = [List create: scratchZone];
    numTaken += [self slice: numHoles solutesFrom: inList to: xferList];
    [sSpace add: xferList toCoreAtY: 0];
    list_add(retList, xferList); // record to return before placing in solutes
    [self slice: [xferList getCount] solutesFrom: xferList to: solutes];
    [xferList drop]; xferList = nil;
  }

//   if ( duplicates(retList) )
//     [Telem debugOut: 0 printf: "[Sinusoid -intakeRuleEst:] 258 -- retList has duplicates\n"];

  return retList;
}

- stepBioChem
{
  // run checkForUpdate on the ECells

  [Telem debugOut: 6 printf: "%s(%p)::stepBioChem -- enter -- there are %d hepatocytes\n",
         [[self getClass] getName], self, [hepatocytes getCount]];

  // step the Hepatocytes
  [hepatocytes forEach: @selector(step)];
  [eCells forEach: @selector(step)];
  
  [Telem debugOut: 6 printf: "%s(%p)::stepBioChem -- exit.\n",
         [[self getClass] getName], self];

  return self;
}

//- (void) incMetabolizedSoluteType: (id <SoluteTag>) t
- (void) incMetabolizedSolute: (Solute *) s
{
	id <SoluteTag> t = [s getType];

  if (amountMetabolized == nil) {
    amountMetabolized = [Map create: [self getZone]];
		metabolizedSoluteList = [List create: scratchZone];
  }
  [metabolizedSoluteList addLast:[Pair create:scratchZone 
                                       setFirst:t 
                                       second:[Integer create:scratchZone setInt:[s getNumber]]]];
  if ([amountMetabolized containsKey: t]) {
    [(id <Integer>) [amountMetabolized at: t] increment];
  } else {
    id <Integer> intObj = [Integer create: [self getZone] setInt: 1];
    [amountMetabolized at: t insert: intObj];
  }
}


// observation methods

- (void) describe: outputCharStream withDetail: (short int) d
{
  id <OutputStream> os = outputCharStream;
  id <Integer> tmpInt = [Integer create: scratchZone setInt: 0L];

  [os catC: [[self class] getName]];
  [os catC: ":"];
  [os catC: [[tmpInt setInt: myNumber] intStringValue]];
  [os catC: " ("];
  [os catC: [[tmpInt setInt: [self getCirc]] intStringValue]];
  [os catC: ", "];
  [os catC: [[tmpInt setInt: [self getLength]] intStringValue]];
  [os catC: ", "];
  [os catC: [[tmpInt setInt: [solutes getCount]] intStringValue]];
  [os catC: ")"];

  [os catC: " -- "];

  [sSpace describe: os withDetail: d];

  // describe the buffer spaces
  long d_l = (long)d;
  [buffSpaces forEach:  @selector(describe: withDetail:) : os : (id)d_l];


  [eSpace describe: os withDetail: d];
  [sod describe: os withDetail: d];

  [bileCanal describe: os withDetail: d];

  [os catC: "\n"];
  [tmpInt drop]; tmpInt = nil;
}

- (void) setSnaps: (BOOL) s
{
  assert(sSpace != nil);

  if ([buffSpaces getCount] > 0)
    assert ([buffSpaces atOffset: 0] != nil);
  assert(eSpace != nil);
  assert(sod != nil);

  snapOn = s;

  [sSpace setSnaps: snapOn];

  long snapOn_l = (long) snapOn;
  [buffSpaces forEach: @selector(setSnaps:) : (id)snapOn_l];

  [eSpace setSnaps: snapOn];
  [sod setSnaps: snapOn];
}

- (void) writeToPNG: (id <LiverDMM>) dMM
{
  // assume all the spaces are the same grid size
  if (snapOn == YES) {
	gdImagePtr img;
	img = [sSpace takeSnapshot];
	int width = gdImageSX(img);
	int height = gdImageSY(img);
	gdImagePtr pngImg = gdImageCreateTrueColor(width, height * 3); // final image
	gdImageAlphaBlending(pngImg, 0); // turns off in-library blending; instead alpha is written to alpha channel
	gdImageSaveAlpha(pngImg, 1);
	gdImageCopy(pngImg,img,0,0,0,0,width,height);

   // snap and paste images for all buffSpaces
   id <ListIndex> bsNdx = [buffSpaces listBegin: scratchZone];
   MiddleSpace *bs = nil;
   while (([bsNdx getLoc] != End) 
          && (bs = [bsNdx next]) != nil) {
     img = [bs takeSnapshot];
     gdImageCopy(pngImg, img, 0, height, 0, 0, width, height);
   }
   [bsNdx drop]; bsNdx = nil;

	img = [eSpace takeSnapshot];
	gdImageCopy(pngImg,img,0,height,0,0,width,height);
	img = [sod takeSnapshot];
	gdImageCopy(pngImg,img,0,height * 2,0,0,width,height);
	if ([dMM writePNG: pngImg withID: myNumber spaceName: (const char *)nil] < 0)
	raiseEvent(WarningMessage, "%s:%d Could not save composite snapshot.\n",
			   [[self getClass] getName], myNumber);
	gdImageDestroy(pngImg);
  }
}

// accessors

- (unsigned) getCirc {
  return circ;
}

- (unsigned) getLength
{
  return length;
}

/*
 * getCC - overridden because we *always* want to use calcCC
 */
- (unsigned) getCC {
  return [self calcCC];
}
- (float) getAIREMult {
  return 0.65;
}
- (id <List>) getHepatocytes
{
  return hepatocytes;
}
- (id <List>) getECs
{
  return eCells; 
}

- (id <Map>) getAmountMetabolized
{
  return amountMetabolized;
}

// construction methods

- createEnd
{
  Sinusoid *obj=nil;

  obj = [super createEnd];
  obj->circ = UINT_MAX;
  obj->length = UINT_MAX;
  obj->turbo = 0.0F;
  obj->coreFlowRate = UINT_MAX;
  obj->hepatocytes = [List create: [self getZone]];
  obj->eCells = [List create: [self getZone]];
  obj->sSpace = nil;
  obj->bileCanal = nil;
  obj->bileCanalCirc = UINT_MAX;
  obj->buffSpaces = [List create: [self getZone]];
  obj->eSpace = nil;
  obj->sod = nil;
  obj->sScale = UINT_MAX;
  obj->eScale = UINT_MAX;
  obj->dScale = UINT_MAX;

  return obj;
}

- setCirc: (unsigned) c length: (unsigned) l
{
  assert( c > 0U);
  assert( l > 0U);
  circ = c;
  length = l;

  return self;
}

- setBileCanalCirc: (unsigned) c
{
  assert( c > 0U );
  bileCanalCirc = c;
  return self;
}

- setTurbo: (double) t
{
  assert( t >= 0.0F );
  turbo=t;
  return self;
}
- (void) setCoreFlowRate: (unsigned) cfr
{
  assert(cfr > 0);
  coreFlowRate = cfr;
}

- (void) setScaleS: (unsigned) s E: (unsigned) e D: (unsigned) d
{
  sScale = s;
  eScale = e;
  dScale = d;
}

- (void) create: (int) numBuffSpaces subSpacesWithAmounts: (id <Map>) nbsc
{
  // ensure that prerequisite variables make sense first
  assert(circ > 0L);
  assert(length > 0L);
  assert(turbo >= 0.0F);
  assert(numBuffSpaces >= 0);
  assert([nbsc getCount] > 0);


  if (sSpace != nil) {
    [sSpace drop]; sSpace = nil;
  }

  sSpace = [SinusoidalSpace create: [self getZone] 
                            setSizeX: circ*sScale Y: length*sScale];
  [sSpace setFlowFromTurbo: turbo];
  [sSpace setCoreFlowRate: coreFlowRate];
  [sSpace setParent: self];

  {
    // copy the nbsc so we can decrement it as its used
    id <Map> counter = [Map create: scratchZone];
    id <MapIndex> cNdx = [nbsc mapBegin: scratchZone];
    id <SoluteTag> tag = nil;
    id <Integer> val = nil;
    while (([cNdx getLoc] != End)
           && ((val = [cNdx next: &tag]) != nil)) {
      [counter at: tag insert: [val copy: scratchZone]];
    }
    [cNdx drop]; cNdx = nil;

    [buffSpaces deleteAll];
    int bsNdx_i = 0U;
    MiddleSpace *bs = nil;
    for ( bsNdx_i = 0U ; bsNdx_i < numBuffSpaces ; bsNdx_i++ ) {
      bs = [[MiddleSpace createBegin: [self getZone]] setSizeX: circ*sScale Y: length*sScale];

      // set recognized solute types by decremenging the counter for each solute type
      cNdx = [counter mapBegin: scratchZone];
      while (([cNdx getLoc] != End)
             && ((val = [cNdx next: &tag]) != nil)) {
        int count = [val getInt];
        if (count > 0) {
          [bs recognize: tag];
          [val setInt: count-1];
        }
      }
      [cNdx drop]; cNdx = nil;

      bs = [bs createEnd];
      [bs setFlowFromTurbo: turbo];
      [bs setParent: self];
      [buffSpaces addLast: bs];
    }

    [counter deleteAll]; [counter drop]; counter = nil;

  }

  if (eSpace != nil) {
    [eSpace drop]; eSpace = nil;
  }

  eSpace = [[ESpace createBegin: [self getZone]] setSizeX: circ*eScale Y: length*eScale];
  // set ESpace to recognized all solute types
  id <MapIndex> cNdx = [nbsc mapBegin: scratchZone];
  id <SoluteTag> tag = nil;
  while (([cNdx getLoc] != End) && ([cNdx next: &tag]))
    [eSpace recognize: tag];
  [cNdx drop]; cNdx = nil;
  eSpace = [eSpace createEnd];

  [eSpace setFlowFromTurbo: 0.0F];  // provides intra-space movement
  [eSpace setParent: self];

  if (sod != nil) {
    [sod drop]; sod = nil;
  }

  sod = [DisseSpace create: [self getZone] setSizeX: circ*dScale Y: length*dScale];
  [sod setFlowFromTurbo: 0.0F]; // 2d random walk
  [sod setParent: self];

  
  bileCanal = [BileCanal create: [self getZone] length: length*dScale
                         flowRate: coreFlowRate 
                         area: [SinusoidalSpace calcAreaFromCirc: bileCanalCirc]];
  [bileCanal setBackProb: sSpace->defaultFlowVector->probV[north]
             fwdProb: sSpace->defaultFlowVector->probV[south]
             stayProb: sSpace->defaultFlowVector->probV[hold]];
  [bileCanal setParent: self];

  // if there are buffer spaces, include them
  if ([buffSpaces getCount] > 0) {
    MiddleSpace *bs = [buffSpaces getFirst];
    [sSpace setOutSpace: bs];
    [bs setInnerSpace: sSpace];

    MiddleSpace *prior = bs;
    MiddleSpace *post = nil;
    int bsNdx_i = 1U;
    for ( bsNdx_i = 1U ; bsNdx_i < [buffSpaces getCount] ; bsNdx_i++ ) {
      bs = [buffSpaces atOffset: bsNdx_i];
      [prior setOuterSpace: bs];
      [bs setInnerSpace: prior];
      if ( bsNdx_i == [buffSpaces getCount] - 1 )
        post = eSpace;
      else if ((post = [buffSpaces atOffset: bsNdx_i + 1]) != nil);
      else raiseEvent(OffsetOutOfRange, "Problem setting MiddleSpace links.");
      [bs setOuterSpace: post];
      prior = bs;
    }
    [eSpace setInnerSpace: [buffSpaces getLast]]; 

    // output print
    [Telem debugOut: 4 printf: "There are %d buffer spaces.\n", [buffSpaces getCount]];
    for ( bsNdx_i = 0U ; bsNdx_i < [buffSpaces getCount] ; bsNdx_i++ ) {
      bs = [buffSpaces atOffset: bsNdx_i];
      [Telem debugOut: 4 printf: "bs(%p:%d) <=> bs(%p:%d) <=> bs(%p:%d)\n",
              bs->innerSpace, bsNdx_i - 1, bs, bsNdx_i, bs->outerSpace, bsNdx_i + 1];
    }

  } else {
    [sSpace setOutSpace: eSpace];
    [eSpace setInnerSpace: sSpace];
  }

  [sod setInSpace: eSpace];
  [eSpace setOuterSpace: sod];

}

- (void) setSpaceJumpProbsS2E: (float) ss2es 
                          e2S: (float) es2ss e2D: (float) es2ds d2E: (float) ds2es
{
  
  if ([buffSpaces getCount] > 0) {
     assert ([buffSpaces atOffset: 0] != nil);
     // for now just use same values for buf and e spaces
     // can't use forEach because we have 4 args
     id <ListIndex> bsNdx = [buffSpaces listBegin: scratchZone];
     MiddleSpace *bs = nil;
     while (([bsNdx getLoc] != nil) 
            && (bs = [bsNdx next]) != nil) {
       [bs setFlowIn2Self: ss2es self2In: es2ss self2Out: es2ds out2Self: ds2es];
     }
     [bsNdx drop]; bsNdx = nil;
  }

  assert(eSpace != (void *)nil);
  // since the ESpace is in control, send these numbers there
  [eSpace setFlowIn2Self: ss2es self2In: es2ss self2Out: es2ds out2Self: ds2es];
}

- (void) createHepatocytesWithDensity: (float) hd
{
  unsigned hNdx=0L;
  id <List> openSpots = [sod getOpenPoints]; // list of pairs of ints
  Vector2d *spot = nil;

  unsigned numHep = hd * [openSpots getCount];

  for ( hNdx=0 ; hNdx<numHep ; hNdx++ ) {
    // create it and add it to my ledger
    Hepatocyte *h = [Hepatocyte create: [self getZone]];
    [h setParent: self];
    [h setNumber: hNdx];
    
    [hepatocytes addLast: h];

    // add it to the space (we set parameters later)
    spot = [openSpots 
             atOffset: [uUnsDist getUnsignedWithMin: 0L 
                                 withMax: [openSpots getCount]-1]];
    [sod putFixedObject: h container: YES atX: [spot getX] Y: [spot getY]];

    [openSpots remove: spot];
    [spot drop]; spot = nil;
  }

  { // getOpenPoints returns a scratchZone data structure
    [openSpots deleteAll];  
    [openSpots drop]; openSpots = nil;
  }
}

- (void) createECellsWithDensity: (float) ecd 
{
  unsigned eNdx=0L;
  id <List> openSpots = [eSpace getOpenPoints]; // list of pairs of ints
  Vector2d *spot = nil;

  unsigned numECs = ecd * [openSpots getCount];

  for ( eNdx=0 ; eNdx<numECs ; eNdx++ ) {
    // create it and add it to my ledger
    ECell *e = [ECell create: [self getZone]];
    [e setParent: self];
    [e setNumber: eNdx];
    
    [eCells addLast: e];

    // add it to the space
    spot = [openSpots atOffset: 
                        [uUnsDist getUnsignedWithMin: 0L 
                                  withMax: [openSpots getCount]-1]];
    [eSpace putFixedObject: e container: YES atX: [spot getX] Y: [spot getY]];

    [openSpots remove: spot];
    [spot drop]; spot = nil;
  }

  { // getOpenPoints returns a scratchZone data structure
    [openSpots deleteAll];  
    [openSpots drop]; openSpots = nil;
  }
}
- activateCellSchedulesIn: (id) aSwarmContext
{
  [hepatocytes forEach: @selector(activateScheduleIn:): (id) aSwarmContext];
  [eCells forEach: @selector(activateScheduleIn:): (id) aSwarmContext];
  return self;
}

- (void) drop
{
  [sSpace drop]; sSpace = nil;
  [buffSpaces deleteAll];
  [eSpace drop]; eSpace = nil;
  [sod drop]; sod = nil;
  [eCells deleteAll];
  [eCells drop]; eCells = nil;
  [hepatocytes deleteAll];
  [hepatocytes drop]; hepatocytes = nil;

  [super drop];
}
@end
