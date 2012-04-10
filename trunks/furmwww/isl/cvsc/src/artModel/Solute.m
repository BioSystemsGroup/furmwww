/*
 * ISL - Solute object
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "Solute.h"

@implementation Solute
- setType: (id <SoluteTag>) st
{
  type = st;
  return self;
}
- (id <SoluteTag>) getType
{
  return type;
}
- createEnd
{
  [Telem debugOut: 6 printf: "[%s(%p) -createEnd] -- Solute created.\n",
	 [[self getClass] getName], self];
  return [super createEnd];
}
-(void) drop
{
  [Telem debugOut: 6 printf: "[%s(%p) -drop] -- Solute destroyed.\n",
	 [[self getClass] getName], self];
  [super drop];
}
@end
