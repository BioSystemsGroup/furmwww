#import "LiverNode.h"
#import "FlowLink.h"
@implementation FlowLink
- (id <List>) moveSoluteFrom: (id <List>) l
{
  id <List> retList = [(LiverNode *)to takeSolutesFrom: l];
  return retList;
}

@end
