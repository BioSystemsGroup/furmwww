#import "ExperAgent.h"
@interface ParallelEA : ExperAgent
{
  int rank; // processor id
  int np; // number of processors
  int pLevel; // parallelization level
  int totalRuns; // total number of Monte-Carlo runs in EXPERIMENTAL_LEVEL
}
- (void) setRank: (int) rk;
- (void) setNumberOfProcessors: (int) size;
- (void) setParallelLevel: (int) level;
- (id <Map>) collectLocalResults: (id <Map>) inputMap;
@end
