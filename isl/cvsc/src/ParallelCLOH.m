#import "ParallelCLOH.h"

@implementation ParallelCLOH
+ createBegin: aZone
{
  ParallelCLOH *args = [super createBegin: aZone];
  [args addOption: "parallel-level" key: 'P' arg: "LEVEL" flags: 0 doc: "set parallelism level; 0 for group level and 1 for experiment level" group: 5];
  return args;
}
- (int) parseKey: (int) key arg: (const char*) arg
{
  int retVal;
  if (key == 'P') { 
    pLevel = [Parallelism getParallelLevel: arg];
    retVal = 0;
  } else {
    retVal = [super parseKey: key arg: arg];
  }
  return retVal;
}
- (int) getParallelLevelArg
{
  return pLevel;
}

@end
