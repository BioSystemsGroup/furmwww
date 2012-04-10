/*
 * IPRL - Endothelial Cell
 *
 * Copyright 2003 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "Cell.h"
@interface ECell : Cell
{
}
+ create: aZone;
- (void) checkForUptake;
@end
