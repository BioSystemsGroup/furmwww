/*
 * RootObject - common ancestor for all objects
 *
 * Copyright 2008 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <modelUtils.h>
#import "RootObject.h"
@implementation RootObject
- setName: (const char *)n {
  objectName = n;
  return self;
}
- (const char *)getName { return objectName; }
- createEnd
{
  RootObject *obj;
  obj = [super createEnd];
  obj->objectName = [[obj getClass] getName];
  return obj;
}
-(void) drop
{
  [Telem debugOut: 6 printf: "%s(%p) dropped.\n", [[self getClass] getName], self];
}
@end
