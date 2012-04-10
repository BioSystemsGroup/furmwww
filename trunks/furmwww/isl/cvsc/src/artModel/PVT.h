/*
 * ISL - PVT - Portal Vein Tract object
 *
 * Copyright 2008 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "../RootObject.h"
@interface PVT : RootObject
{
  id <Map> solutes; // <Solute => bufferTimer>
}
- (void) decrementAll;
- (id <List>) whichCanBeMoved: (id <List>) candidates;
- (void) removeSolutes: (id <List>) moved;
@end
