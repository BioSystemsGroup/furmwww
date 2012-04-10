#import <objc/objc.h>
#import "modelUtils.h"
int obj_compare ( id <Comparable> obj1, id <Comparable> obj2 )
{
  if (obj1 == nil && obj2 != nil) return -1;
  if (obj1 != nil && obj2 == nil) return  1;
  if (obj1 == nil && obj2 == nil) return 0;
  if ([obj1 getNumber] < [obj2 getNumber]) return -1;
  if ([obj1 getNumber] > [obj2 getNumber]) return 1;
  return 0;
}

/*
 * add elements of src to dst
 */
void list_add( id <List> dst, id <List> src)
{
  if (dst == nil) raiseEvent(InvalidArgument, "Destination list is nil.\n");
  if (src == nil) raiseEvent(InvalidArgument, "Source list is nil.\n");
  id obj = nil;
  id <ListIndex> srcNdx = [src listBegin: scratchZone];
  while ( ([srcNdx getLoc] != End)
          && ((obj = [srcNdx next]) != nil) ) {
    [dst addLast: obj];
  }
  [srcNdx drop]; srcNdx = nil;
}

/*
 * remove elements of operand from result
 */
void list_subtract( id <List> result, id <List> operand, BOOL strict)
{
  if (result == nil) raiseEvent(InvalidArgument, "Result list is nil.\n");
  if (operand == nil) raiseEvent(InvalidArgument, "Operand list is nil.\n");
  id obj = nil;
  unsigned ndx = 0U;
  for ( ndx=0U ; ndx<[operand getCount] ; ndx++ ) {
    obj = [operand atOffset: ndx];
    if (strict && ![result contains: obj])
      [Telem debugOut: 0 printf: "list_subtract(%s(%p), %s(%p)) -- "
                 "%s(%p) not in result list.\n", [[result getClass] getName],
                 result, [[operand getClass] getName], operand,
                 [[obj getClass] getName], obj];
    [result remove: obj];
  }
}
/*
 * counts the number of times obj shows up in the list
 */
unsigned countEntries ( id <List> list, id obj)
{
  unsigned retVal = 0U;
  unsigned ndx=0U;
  for ( ndx=0U ; ndx<[list getCount] ; ndx++ ) {
    id lobj = [list atOffset: ndx];
    if (lobj == obj) retVal++;
  }
  return retVal;
}

/*
 * check a list for duplicate entries
 */
BOOL duplicates( id <List> list )
{
  BOOL retVal = NO;
  unsigned ndx1=0U;
  for ( ndx1=0U ; ndx1<[list getCount] ; ndx1++ ) {
    unsigned ndx2=0U;
    id obj1 = [list atOffset: ndx1];
    for ( ndx2=ndx1+1 ; ndx2<[list getCount] ; ndx2++ ) {
      id obj2 = [list atOffset: ndx2];
      if ( obj1 == obj2 ) {
	retVal = YES;
	return retVal;
      }
    }
  }
  return retVal;
}

/*
 * check for sub-list
 */
BOOL isSubList( id <List> list, id <List> sub)
{
  BOOL retVal = YES;
  unsigned ndx = 0U;
  for ( ndx=0U ; ndx<[sub getCount] ; ndx++ ) {
    id obj = [sub atOffset: ndx];
    if ( ![list contains: obj] ) {
      retVal = NO;
      [Telem debugOut: 0 printf: "isSubList() -- sub(%d) = %s(%p) not in list.\n",
	     ndx, [[obj getClass] getName], obj];
     }
  }
  return retVal;
}

/*
 * return a shuffled copy of the src list
 */
id <List> shuffle( id <List> src, id <UniformUnsignedDist> rnd, id <Zone> z)
{
  unsigned ndx = 0U;
  id <List> cpy = [src copy: z];
  unsigned cpySize = [cpy getCount];
  if (cpySize > 1) {
    for ( ndx=0U ; ndx<cpySize ; ndx++ ) {
      id old = [cpy atOffset: ndx];
      unsigned draw = [rnd getUnsignedWithMin: ndx withMax: cpySize-1];
      id new = [cpy atOffset: draw];
      [cpy atOffset: ndx put: new];
      [cpy atOffset: draw put: old];
    }
  }
  return cpy;
}
