/*
 * modelUtils Vector utility
 *
 * Copyright 2003-2005 - Regents of the University of California, San Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#include <assert.h>
#include <math.h>
#import "Vector.h"
@implementation Vector
@end


@implementation Vectormd
+create: (id <Zone>) aZone setDim: (unsigned)d 
{
  Vectormd *obj = [super createBegin: aZone];
  [obj setDim: d];
  [obj createV: aZone];
  return [obj createEnd];
}
+create: (id <Zone>) aZone copyVector: (id <Vectormd>)vec
{
  Vectormd *obj = [super createBegin: aZone];
  [obj setDim: [vec getDim]];
  [obj createV: aZone];
  [obj add: vec];
  return [obj createEnd];
}
- (void)createV: (id <Zone>)aZone
{
  if (dim > 0U) {
    //v = (double *) malloc(sizeof(double)*dim);
    v = (double *)[aZone alloc: (sizeof(double)*dim)];
    unsigned i;
    for(i=0; i<dim; i++) v[i]=0;  
  }
}
- (void)setDim: (unsigned)d
{
  dim = d;
}
- (unsigned)getDim;
{ 
  return dim;
}
- (void)setVal: (double)val at: (unsigned)i
{
  if ((dim > 0U) &&
      (0U <= i && i < dim))
    v[i] = val;
  else
    raiseEvent(InvalidArgument, "\tvector dimension = %d\n"
               "\targument = %d\n", dim, i);
}
- (double)getValAt: (unsigned)i
{
  double retVal = NAN;
  if ((dim > 0U) &&
      (0U <= i && i < dim))
    retVal = v[i];
  else
    raiseEvent(InvalidArgument, "\tvector dimension = %d\n"
               "\targument = %d\n", dim, i);
  return retVal;
}
- multByScalar: (double)val
{
  unsigned i;
  for(i=0;i<dim;i++){
	  v[i] = v[i]*val;
  }
  return self;
}
- add: (id <Vectormd>)vec
{
  unsigned i;
  for(i=0;i<dim;i++){
	  v[i] = v[i]+[vec getValAt: i];
  }
  return self;
}
- sub: (id <Vectormd>)vec
{
  unsigned i;
  for(i=0;i<dim;i++){
	  v[i] = v[i]-[vec getValAt: i];
  }
  return self;
}
- div: (id <Vectormd>)vec
{
  unsigned i;
  for(i=0;i<dim;i++){
	  v[i] = v[i]/[vec getValAt: i];
  }
  return self;
}
- mul: (id <Vectormd>)vec
{
  unsigned i;
  for(i=0;i<dim;i++){
	  v[i] = v[i]*[vec getValAt: i];
  }
  return self;
}
- (double) dotProduct: (id <Vectormd>)vec
{
  double retVal=0;
  unsigned i;
  for(i=0;i<dim;i++){
	  retVal += v[i]*[vec getValAt: i];
  }
  return retVal;
}
- (double) norm{
  double retVal=0;
  unsigned i;
  for(i=0;i<dim;i++){
	  retVal += v[i]*v[i];
  }
  return sqrt(retVal);	
}
- (void) print {
  unsigned i;
  for (i=0; i<dim-1 ; i++){
  	  printf("%f,",v[i]);
  }
  printf("%f",v[dim-1]);
}

- (id <String>) toString{
  id <String> retVal = [String create: [self getZone] setC: "("];
  if (dim>0){
    unsigned i;
    for (i=0; i<dim-1 ; i++){
      [retVal catC: [Double doubleStringValue: v[i]]];
      [retVal catC: " ,"];
    }
    [retVal catC: [Double doubleStringValue: v[dim-1]]];
  }
  [retVal catC: ")"];
  
  return retVal;
}
- (void) drop{
  [[self getZone] free:v];
  [super drop];
}
- copyVector: (id <Vectormd>) vec{
  unsigned i;
  for(i=0;(i<dim)&&(i<[vec getDim]);i++){
	  v[i] = [vec getValAt: i];
  }
  return self;
}
- reflectThru: (id <Vectormd>)vec withRatio: (double)alpha
{
  id <Vectormd> vCopy = [Vectormd create: [self getZone] copyVector: vec];
  // retVal=(1+alpha)*v-(alpha)*self
  [vCopy multByScalar: (1+alpha)];
  [self  multByScalar: -alpha];
  [self  add: vCopy];
  
  [vCopy drop];
  return self;
}
- contractThru: (id <Vectormd>)vec withRatio: (double)beta
{
  assert((0.0<=beta)&&(beta<=1));
  id <Vectormd> vCopy = [Vectormd create: [self getZone] copyVector: vec];
  // retVal=(1-beta)*v+(beta)*self     0<beta<1
  [vCopy multByScalar: (1-beta)];
  [self  multByScalar: beta];
  [self  add: vCopy];
  
  [vCopy drop];
  return self;
}
- expandThru: (id <Vectormd>)vec withRatio: (double)beta
{  
  assert(1.0<=beta);
  id <Vectormd> vCopy = [Vectormd create: [self getZone] copyVector: vec];
  // retVal=(1-beta)*v+(beta)*self      1<beta
  [vCopy multByScalar: (1-beta)];
  [self  multByScalar: beta];
  [self  add: vCopy];
  
  [vCopy drop];
  return self;
}
@end

@implementation Vector2d
+create: (id <Zone>) aZone dim1: (int) dim1 dim2: (int) dim2 {
  Vector2d *obj = [super createBegin: aZone];
  obj->x = dim1;
  obj->y = dim2;
  return [obj createEnd];
}
- setX: (int) dim1 {
  x=dim1;
  return self;
}
- setY: (int) dim2 {
  y=dim2;
  return self;
}
- (int) getX {
  return x;
}
- (int) getY {
  return y;
}
@end

@implementation VectorMoore
- setProbVFromTurbo: (double) pv
{
  double northDrift = ((1.0 - pv) * 2.0)/18;
  double southDrift = (1.0 + 2 * pv)/9;
  unsigned ndx=0;

  for ( ndx=hold ; ndx<southWest ; ndx++ )
    probV[ndx] = (ndx+1)*northDrift;

  for ( ndx=southWest ; ndx<=southEast ; ndx++ )
    probV[ndx] = probV[west] + (ndx-southWest+1)*southDrift;

  return self;
}
@end
