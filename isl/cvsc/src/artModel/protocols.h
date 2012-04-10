#import "../protocols.h"
@protocol ContainerObj
- (id) getMobileObject;
- (id) removeMobileObject: (id) anObj;
- (BOOL) putMobileObject: (id) anObj;
- (id <Map>) countMobileObjects: (id <Zone>) aZone;
@end

@protocol SoluteTag <Tag>
- (BOOL) isMembraneCrossing;
- (void) setMembraneCrossing: (BOOL) b;
- (int) getNumBufferSpaces;
- (int) getBufferDelay;
- (double) getBileRatio;
@end

@protocol SerialInjection <Dosage>
@end

@class ContainerObj;
@class SoluteTag;
@class SerialInjection;
