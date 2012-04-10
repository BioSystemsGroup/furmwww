#import "Simplex.h"

@implementation Simplex
+ create: (id <Zone>) aZone setDim: (unsigned) d{
  Simplex *obj = [super createBegin: aZone];
  [obj setDim: d];
  [obj createV: aZone];
  return [obj createEnd];

}
- (void)createV: (id <Zone>) aZone
{
  //v = (Vectormd *) malloc(sizeof(Vectormd)*dim);
  v = (Vectormd **)[aZone alloc: (sizeof(Vectormd)*dim)];
}
- (void)setDim: (unsigned)d
{
  dim = d;
}
- (unsigned)getDim{
  return dim;
}
- (void)createVertex: (unsigned)i copyVector:(id <Vectormd>)val {
  v[i] = [Vectormd create: [self getZone] copyVector: val];
}
- (id <Vectormd>)getVertex: (unsigned)i{
  return v[i];
}
- shrinkTowardVertex: (unsigned)j WithRatio: (double)sigma{
  unsigned i;
  for (i=0; i<dim; i++){
    if (i != j){
      [v[i] contractThru: v[j] withRatio: sigma];
    }    
  }
  return self;
}
- (void) print{
  unsigned i;
  for (i=0; i<dim ; i++){
    printf("v[%d]=",i);
    [v[i] print];
    printf("\n");
  }
}
- (id <String>) toString{
  unsigned i;
  id <String> retVal = [String create: [self getZone] setC: "\n"];
  
  for (i=0; i<dim ; i++){
    //[Telem debugOut: level printf:"v[%d]=",i];
    //[v[i] TelemDebugOut: level];
    //[Telem debugOut: level printf:"\n"];
    [retVal catC: "Vertex("];
    [retVal catC: [Integer intStringValue: i]]; 
    [retVal catC: ")="];
    [retVal catC: [[v[i] toString] getC]] ;
    [retVal catC: "\n"];  
  }
  
  return retVal;
}
- vertex: (unsigned)i copyVector: (id <Vectormd>)val{
  [v[i] copyVector: val];
  return self;
}
- (void) drop{
  unsigned i;
  for (i=0; i<dim ; i++) 
    [v[i] drop];
  [super drop];  
}
@end
