#include <objectbase/SwarmObject.h>

#include "modelUtils.h"
@interface Pair: SwarmObject <Pair>
{
  id first;
  id second;
}
+create: aZone setFirst: f second: s;
-setFirst: f;
-getFirst;
-setSecond: s;
-getSecond;
-(void) deleteMembers;
@end
