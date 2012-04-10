#import "modelUtils.h"
#import "Vector.h"

#import <objectbase/SwarmObject.h>

@interface Simplex: SwarmObject
{
@public
  unsigned dim;
  id <Vectormd> *v;
}
+ create: (id <Zone>) aZone setDim: (unsigned) d;
- (unsigned)getDim;
- (void)createV: (id <Zone>) aZone;
- (void)setDim: (unsigned)d;
- (void)createVertex: (unsigned)i copyVector:(id <Vectormd>)val;
- (id <Vectormd>)getVertex: (unsigned)i;
- shrinkTowardVertex: (unsigned)j WithRatio: (double)sigm;
- (void) print;
- (id <String>) toString;
- vertex: (unsigned)i copyVector: (id <Vectormd>)v;
- (void) drop;
@end

