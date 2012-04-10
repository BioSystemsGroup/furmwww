/*
 * RootObject - common ancestor for all objects
 *
 * Copyright 2008-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#include <objectbase/SwarmObject.h>

@interface RootObject : SwarmObject
{
  const char *objectName;
}
- setName: (const char *)n;
- (const char *)getName;
@end
