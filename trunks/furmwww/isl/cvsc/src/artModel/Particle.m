#import "Particle.h"
@implementation Particle
- setNumber: (int) n {
  myNumber = n;
  return self;
}
- setSegNum: (int) n {
  mySegNum = n;
  return self;
}
- (int) getNumber {
  return myNumber;
}
- (int) getSegNum {
  return mySegNum;
}
@end
