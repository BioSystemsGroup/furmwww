/*
 * IPRL - Vascular node in the liver
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <math.h> // for ceil()
#import <modelUtils.h>
#import <LocalRandom.h>
#import "FlowLink.h"
#import "Solute.h"
#import "LiverNode.h"
#import "Vas.h"
@implementation LiverNode

- stepPhysics {
  return [self subclassResponsibility: @selector(stepPhysics)];
}
- (unsigned) calcCC {
  return [self subclassResponsibility: @selector(calcCC)], 0;
}
- (id <List>) takeSolutesFrom: (id <List>) fl {
  return [self subclassResponsibility: @selector(takeSolutesFrom:)], nil;
}

- (void) takeMetabolite: (Solute *) m
{
  if ([solutes contains: m])
    raiseEvent(InternalError, "[%s(%p) -takeMetabolite: %s(%p)] -- solutes list already contains that metabolite.\n",
	       [[self getClass] getName], self, [[m getClass] getName], m);
  [solutes addLast: m];
}

- (unsigned) chooseFrom: (unsigned) total solutesToSendToN: (int) flNdx
{
  unsigned retVal = 0U;
  double retVal_d = 0.0;
  Double *outCC = [outCCRatios atOffset: flNdx];
  retVal_d = ceil(((double)total * [outCC getDouble]) - 0.5);

  if (retVal_d < 0.5) 
    retVal = 1U;
  else 
    retVal = (unsigned) retVal_d;

  return retVal;
}

/*
 * distributeSolutes (to out links) - 
 *   The vasa try to distribute the solutes amongst the sinusoids
 *   EQUALLY.  But, the sinusoids should have different flow dynamics
 *   that suck up more or fewer solutes, depending on their size,
 *   velocity, etc.
 */
#define MAX_FLUX_TRIES 1 // limits the number of push tries
- (id <List>) distributeSolutesFrom: (id <List>) sl
{
  FlowLink *fl=nil;
  unsigned numTaken=0U;
  id <List> taken = [List create: [self getZone]];
  unsigned expectedEFlux=[sl getCount];
  unsigned tryToTake=0UL;
  id <List> buffList = [List create: scratchZone];
  unsigned numberIgnored = 0U;

  [Telem debugOut: 5 printf: "LiverNode (%d) picking from %d solute.\n",
         [self getNumber], [sl getCount]];

  // provide each node in my to-list the opportunity of taking
  // some solute until all my available solute is gone

  if ([toList getCount] <= 0) {
    raiseEvent(InternalError, "LiverNode %d has no outlets!!!\n",
               myNumber);
  }

  {
    /* Randomize the placement amongst the toList by:
     * o create a temporary list of indices
     * o shuffle the list
     * o use that list to index the toList
     */
    id <List> tmpNdxList = [List create: scratchZone];
    unsigned ndx = 0U;
    for ( ndx=0U ; ndx<[toList getCount] ; ndx++ ) {
      [tmpNdxList addLast: [Integer create: scratchZone setInt: ndx]];
    }
    id <List> tmpNdxList_s = shuffle(tmpNdxList, uUnsFixDist, scratchZone);
  
    for ( ndx=0U ; ndx<[tmpNdxList_s getCount] ; ndx++ ) {
      unsigned toNdx = [(id <Integer>)[tmpNdxList_s atOffset: ndx] getInt];
      fl = [toList atOffset: toNdx];
      if (fl == nil) raiseEvent(InternalError, "[%s:%d(%p) toLink %d is nil.\n",
				[[self getClass] getName], [self getNumber], self, toNdx);

      tryToTake = [self chooseFrom: expectedEFlux solutesToSendToN: toNdx];

      // if buffList isn't full, add more up to tryToTake
      unsigned bl = [buffList getCount];
      if ( bl < tryToTake )
	[self slice: tryToTake-bl solutesFrom: sl to: buffList];

      id <List> moved = [fl moveSoluteFrom: buffList];
      numTaken = [moved getCount];
      list_add(taken, moved);
      [moved drop]; moved = nil;

    } // end toNdx loop over toList
    [tmpNdxList drop]; tmpNdxList = nil;
    [tmpNdxList_s deleteAll]; [tmpNdxList_s drop]; tmpNdxList_s = nil;
  }

  // if they didn't take them all, put the leftovers back
  numberIgnored = [buffList getCount];
  if ( numberIgnored > 0) {
    [self slice: numberIgnored solutesFrom: buffList to: sl];
  }
  [buffList drop]; buffList = nil;

  return taken;
}

/*
 * slice:solutesFrom:to - moves n solute objects from one list
 *                          to another.  Note that if n is greater
 *                          than the number of elements on the from
 *                          list, then it moves all of them.
 */
- (unsigned) slice: (unsigned) n solutesFrom: (id <List>) fl to: (id <List>) tl {
  Solute *sol;
//  id <PermutedIndex> soluteNdx;
  unsigned removedCount = 0U;
  unsigned flSize;
  id <List> moveList=[List create: scratchZone];
  id <ListIndex> moveNdx=nil;
  id obj=nil;

  if ( n==0 ) return 0U;

//   soluteNdx = [fl beginPermuted: [self getZone]];

//   if ( n > (flSize = [fl getCount]) ) n=flSize; 
//   while ( (removedCount < n)
//           && ([soluteNdx getLoc] != End) 
//           && ((sol = [soluteNdx next]) != nil) ) {

//     [tl addLast: sol];
//     removedCount++;
//     [moveList addLast: sol];

//   }
//   [soluteNdx drop]; soluteNdx = nil;


  unsigned soluteNdx = 0U;
  if ( n >= (flSize = [fl getCount]) ) {
    // move them all
    n = flSize;
  } 
  while (removedCount < n) {
    //    soluteNdx = (n==flSize ?
    //		 removedCount :
    //		 [uUnsDist getUnsignedWithMin: 0U withMax: flSize-1]);
    soluteNdx = removedCount;
    sol = [fl atOffset: soluteNdx];
    if ([tl contains: sol]) {
      raiseEvent(InternalError, "[%s(%p) -slice: %d solutesFrom: %s(%p) to: %s(%p)] -- "
		 "%s(%p) is already in the target list.\n", 
		 [[self getClass] getName], self, n, [[fl getClass] getName], fl,
		 [[tl getClass] getName], tl, [[sol getClass] getName], sol);
    } 
    [tl addLast: sol];
    removedCount++;
    [moveList addLast: sol];
    [Telem debugOut: 6 printf: "[%s(%p) -slice: %d solutesFrom: %s(%p) to: %s(%p)] -- "
	   "moving %s(%p)\n",
	   [[self getClass] getName], self, n, [[fl getClass] getName], fl,
	   [[tl getClass] getName], tl, [[sol getClass] getName], sol];
  }

  moveNdx = [moveList listBegin: scratchZone];
  while ( ([moveNdx getLoc] != End)
          && ((obj = [moveNdx next]) != nil) ) {
    [fl remove: obj];
  }
  [moveNdx drop]; moveNdx = nil;
  [moveList drop]; moveList = nil;

  return removedCount;
}

- stepBioChem {
  return [self subclassResponsibility: @selector(stepBioChem)];
}

//- (void) incMetabolizedSoluteType: (id <SoluteTag>) t
- (void) incMetabolizedSolute: (Solute *) s
{
//  [self subclassResponsibility: @selector(trackMetabolizedSoluteType:)];
  [self subclassResponsibility: @selector(trackMetabolizedSolute:)];
}


// observation methods
- (void) describe: outputCharStream withDetail: (short int) d
{
  [self describe: outputCharStream];
}

- printToLinks: os {
  id <ListIndex> toNdx=nil;
  FlowLink *sl;
  BOOL end=YES;

  if ( ![self isKindOf: [Vas class]] ) {
    [self describe: os withDetail: 0];
  }

  toNdx = [[self getToLinks] listBegin: scratchZone];
  while ( ( [toNdx getLoc] != End )
          && ( (sl = [toNdx next]) != nil )
          && ( ![[sl getTo] isKindOf: [Vas class]] ) ) {
    end=NO;
    [os catC: " => "];
    [[sl getTo] printToLinks: os];
  }
  [toNdx drop]; toNdx = nil;

  if (end) [os catC: "\n"];

  return self;
}

- (void) setSnaps: (BOOL) s
{
  [self subclassResponsibility: @selector(setSnaps:)];
}
- (void) writeToPNG: (id <LiverDMM>) dMM
{
  [self subclassResponsibility: @selector(writeToPNG)];
}

- (id <Map>) getAmountMetabolized
{
  return [self subclassResponsibility: @selector(getAmountMetabolized)];
}

- (id <List>) getMetabolizedSoluteList
{
  return metabolizedSoluteList;
}

- (void) clearMetabolizedSoluteList
{
  if(metabolizedSoluteList != nil) [metabolizedSoluteList removeAll];
}

- setMetFileDescriptor: (FILE *) f
{
  mfp = f;
  return self;
}


// accessor methods

- getSolutes {
  return solutes;
}
- (unsigned) getCC {
  return (_ccNeedsUpdate_ ? [self calcCC] : _cc_);
}

- (FILE *) getMetFileDescriptor
{
  return mfp;
}

- (void) closeMetFileDescriptor
{
  fclose(mfp);
}

// construction methods

+ createBegin: (id <Zone>) zone 
{
  LiverNode *newObj = [super createBegin: zone];
  newObj->solutes = [List create: zone];
  newObj->outCCRatios = [List create: zone];
  return newObj;
}

// override the following in order to keep CC up-to-date
- addFrom: aLink {
  _ccNeedsUpdate_ = YES;
  return [super addFrom: aLink];
}
- addTo: aLink {
  _ccNeedsUpdate_ = YES;
  return [super addTo: aLink];
}
- removeFrom: which {
  _ccNeedsUpdate_ = YES;
  return [super removeFrom: which];
}
- removeTo: which {
  _ccNeedsUpdate_ = YES;
  return [super removeTo: which];
}

- (void) drop
{
  [solutes deleteAll];
  [solutes drop]; solutes = nil;
	if(mfp) fclose(mfp);

  [super drop];
}

@end
