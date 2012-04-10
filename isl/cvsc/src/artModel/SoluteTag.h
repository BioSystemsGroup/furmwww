#import <Tag.h>
#import "protocols.h"
@interface Tag ( SoluteTag ) <SoluteTag>
- (BOOL) isMembraneCrossing;
- (void) setMembraneCrossing: (BOOL) b;
- (int) getNumBufferSpaces;
- (int) getBufferDelay;
- (double) getBileRatio;
@end
