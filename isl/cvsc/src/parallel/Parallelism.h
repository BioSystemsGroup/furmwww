#import <objc/Object.h>

#define GROUP_LEVEL 0
#define EXPERIMENTAL_LEVEL 1
#define FINEST_PARALLEL_LEVEL EXPERIMENTAL_LEVEL
#define NON_SUPPORTED_PARALLELISM -1

@interface Parallelism

+ (int) getParallelLevel: (const char *) str; 
+ (BOOL) isSupportedParallelism: (const char *) str;

@end
