#import "SoluteTag.h"
@implementation Tag ( SoluteTag )
PHASE(Creating)
PHASE(Using)
const char *st_mc_key = "membraneCrossing";
const char *st_nbs_key = "numBufferSpaces";
const char *st_bd_key = "bufferDelay";
const char *st_br_key = "bileRatio";
- (BOOL) isMembraneCrossing
{
  BOOL result=NO;
  id <String> val = nil;
  id <String> key = [String create: scratchZone setC: st_mc_key];
  val = [properties at: key];
  [key drop]; key = nil;
  if (val != nil && strcmp([val getC], "YES") == 0)
    result=YES;
  return result;
}
- (void) setMembraneCrossing: (BOOL) b
{
  id <String> key = [String create: [self getZone] setC: st_mc_key];
  id <String> val = [properties at: key];
  if (val == nil) {
    if (b == YES)
      [properties at: key 
                  insert: 
                    [String create: [self getZone] 
                            setC: (b == YES ? "YES" : "NO")]];
    // else do nothing because the default value of isMembraneCrossing
    // is NO
  } else if (b == YES && strcmp([val getC], "YES") != 0) {
    [properties at: key
                insert: [String create: [self getZone]
                                setC: "YES"]];
  } else if (b == NO && strcmp([val getC], "NO") != 0) {
    [properties at: key
                insert: [String create: [self getZone]
                                setC: "NO"]];
  } // else nothing need change
}
- (int) getNumBufferSpaces
{
  int result=0U;
  id <Integer> val = nil;
  id <String> key = [String create: scratchZone setC: st_nbs_key];
  val = [properties at: key];
  [key drop]; key = nil;
  if (val != nil 
      && [val respondsTo: @selector(getInt)]) {
    result = [val getInt];
  }
  return result;
}
- (int) getBufferDelay
{
  int result=0U;
  id <Integer> val = nil;
  id <String> key = [String create: scratchZone setC: st_bd_key];
  val = [properties at: key];
  [key drop]; key = nil;
  if (val != nil
      && [val respondsTo: @selector(getInt)]) {
    result = [val getInt];
  }
  return result;
}
- (double) getBileRatio
{
  double result = 0.0F;
  id <Double> val = nil;
  id <String> key = [String create: scratchZone setC: st_br_key];
  val = [properties at: key];
  [key drop]; key = nil;
  if (val != nil
      && [val respondsTo: @selector(getDouble)]) {
    result = [val getDouble];
  }
  return result;
}
@end
