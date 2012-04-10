/*
 * IPRL - Long wrapper
 *
 * Copyright 2003-2009 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import "Long.h"

int long_compare ( Long *obj1, Long *obj2 )
{
  if (obj1 == nil || obj2 == nil) return 0xffffffff;
  if ([obj1 getLong] < [obj2 getLong]) return -1;
  if ([obj1 getLong] > [obj2 getLong]) return 1;
  return 0;
}

@implementation Long
PHASE(Creating)
+ create: (id <Zone>) aZone setLong: (long) val
{
  Long *obj;
  obj = [Long createBegin: aZone];
  obj->value = val;
  obj = [obj createEnd];
  return obj;
}
PHASE(Using)
long _numDigitsInLong(long x, long base) 
{
  if (x < base) return (1);
  else return (1 + _numDigitsInLong(x/base, base));
}

+ (char *) longStringValueOf: (long) l format: (const char *) f places: (long) p
{
  long base = 10;
  long numDigits = 0;

  if (strcmp(f,"%x") == 0) base = 16;
  else if (strcmp(f, "%d") == 0) base = 10;
  numDigits = _numDigitsInLong(l,base);
  if (p > numDigits) numDigits = p;

  char *buff = (char *)[scratchZone alloc: (numDigits+1)*sizeof(char)];
  char *format = (char *)[scratchZone alloc: (_numDigitsInLong(p,10) + 8)*sizeof(char)];
  sprintf(format, "%c0%ld%c", '%', p, (base == 10 ? 'd' : 'x'));
  if (sprintf(buff, (const char *)format, l) != numDigits)
    raiseEvent(InternalError, "Problem allocating space for %d digits.\n",
               numDigits);
  [scratchZone free: format];
  return buff;
}

+ (char *) longStringValue: (long) l
{
  return [self longStringValueOf: l format: "%ld" places: 0];
}

+ (char *) hexStringValue: (long) l
{
  return [self longStringValueOf: l format: "%lx" places: 0];
}

- setLong: (long) val {
  value=val;
  return self;
}
- (void) increment
{
  value++;
}
- (id) addLong: (long) l
{
  value += l;
  return self;
}
- (long) getLong {
  return value;
}

- (char *) longStringValue
{
  return [Long longStringValue: value];
}
- (char *) hexStringValue
{
  return [Long hexStringValue: value];
}
- copy: (id <Zone>) aZone 
{
  return [aZone copyIVars: self];
}

@end
