/*
 * IPRL - Integer wrapper
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "Integer.h"

compare_t int_compare ( Integer *obj1, Integer *obj2 )
{
   compare_t retVal = (compare_t)0;
  if (obj1 == nil || obj2 == nil) retVal = (compare_t)0xffffffff;
  if ([obj1 getInt] < [obj2 getInt]) retVal = (compare_t) -1;
  if ([obj1 getInt] > [obj2 getInt]) retVal = (compare_t) 1;
  return retVal;
}

@implementation Integer
PHASE(Creating)
+ create: (id <Zone>) aZone setInt: (int) val
{
  Integer *obj;
  obj = [Integer createBegin: aZone];
  obj->value = val;
  obj = [obj createEnd];
  return obj;
}
PHASE(Using)
int _numDigits(int x, int base) 
{
  if (x < base) return (1);
  else return (1 + _numDigits(x/base, base));
}

+ (char *) intStringValueOf: (int) i format: (const char *) f places: (int) p
{
  int base = 10;
  int numDigits = 0;

  if (strcmp(f,"%x") == 0) base = 16;
  else if (strcmp(f, "%d") == 0) base = 10;
  numDigits = _numDigits(i,base);
  if (p > numDigits) numDigits = p;

  char *buff = (char *)[scratchZone alloc: (numDigits+1)*sizeof(char)];
  char *format = (char *)[scratchZone alloc: (_numDigits(p,10) + 4)*sizeof(char)];
  sprintf(format, "%c0%d%c", '%', p, (base == 10 ? 'd' : 'x'));
  if (sprintf(buff, (const char *)format, i) != numDigits)
    raiseEvent(InternalError, "Problem allocating space for %d digits.\n",
               numDigits);
  [scratchZone free: format];
  return buff;
}

+ (char *) intStringValue: (int) i
{
  return [self intStringValueOf: i format: "%d" places: 0];
}

+ (char *) hexStringValue: (int) i
{
  return [self intStringValueOf: i format: "%x" places: 0];
}

- setInt: (int) val {
  value=val;
  return self;
}
- (void) increment
{
  value++;
}
- (id) addInt: (int) i
{
  value += i;
  return self;
}
- (int) getInt {
  return value;
}

- (char *) intStringValue
{
  return [Integer intStringValue: value];
}
- (char *) hexStringValue
{
  return [Integer hexStringValue: value];
}
- copy: (id <Zone>) aZone 
{
  return [aZone copyIVars: self];
}

@end
