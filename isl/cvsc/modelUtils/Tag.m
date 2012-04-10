#import "Tag.h"
@implementation Tag
PHASE(Creating)
+ create: aZone setName: (const char *) name
{
  Tag *newTag = [Tag createBegin: aZone];
  newTag->myName = [String create: aZone setC: name];
  newTag->properties = [Map create: aZone];
  newTag = [newTag createEnd];
  return newTag;
}
PHASE(Using)
- (const char *)getName
{
  return [myName getC];
}
- copy: (id <Zone>) aZone
{
  const char *newName = ZSTRDUP(aZone, [myName getC]);
  Tag *cpy = [Tag create: aZone setName: newName];

  id <Map> newProp = nil;
  newProp = [Map create: aZone];
  id v=nil, k=nil;
  id <MapIndex> pNdx = [properties mapBegin: scratchZone];
  while (([pNdx getLoc] != End) &&
         ((v = [pNdx next: &k]) != nil)) {
    // at this level, the standard, shallow copy should suffice
    [newProp at: [k copy: aZone] insert: [v copy: aZone]];
  }
  [pNdx drop];

  cpy->properties = newProp;
  return cpy;
}
- (void) drop
{
  [myName drop]; myName = nil;
  [properties deleteAll];
  [properties drop]; properties = nil;
  [super drop];
}
@end
