#ifdef NDEBUG
#undef NDEBUG
#endif
#include <assert.h>

#import "LiverLink.h"
#import "LiverNode.h"
@implementation LiverLink
- (unsigned) getCC
{
  assert ( to != nil);
  return [(LiverNode *)to getCC];
}
@end
