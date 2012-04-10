#import "modelUtils.h"
#import <objectbase/SwarmObject.h>
@interface Tag : SwarmObject <Tag>
{
  id <String> myName;
  id <Map> properties;
}
+ create: aZone setName: (const char *) name;
- copy: (id <Zone>) aZone;
@end
