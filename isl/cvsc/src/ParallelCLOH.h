#import "parallel/Parallelism.h"
#import "CommandLineOptionHandler.h"
@interface ParallelCLOH: CommandLineOptionHandler
{
  int  pLevel; // the degree of PISL parallelism
}
- (int) getParallelLevelArg;
@end
