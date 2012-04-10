#include "ParameterGenerator.h"

@implementation ParameterGenerator

+ createBegin: aZone
{
  ParameterGenerator *genr;

  genr = [super createBegin: aZone];
  return genr;
}

- createEnd
{
  return [super createEnd];
}

//
// generate a parameter file containing the given parameter information
//  parameters:
//   fn : parameter file name
//   header : a priori constant part of the parameter file 
//   tail   : a posteriori constant part of the parameter file
//   params : a set of parameter tuples that exists between the header and the tail 
//
- generate: (id <String>) fn 
            withHeader: (id <String>) header 
            withTail: (id <String>) tail 
            withParams: (id <List>) params
{
  target = fopen([fn getC], "w");
  if (target == NULL) {
    printf("ParameterGenerator::generate - can't create a file: %s \n", [fn getC]);
    exit(-1);
  }
  [self buildHeader: header];
  [self addParameters: params];
  [self buildTail: tail];
  [self closeFile];

  return self;
}

//
// write header information to the parameter file, fn
//
- (void) buildHeader: (id <String>) header 
{
  fprintf(target, "%s\n", [header getC]);
}

//
// write tail infomration to the parameter file, fn
//
- (void) buildTail: (id <String>) tail
{
  fprintf(target, "%s\n", [tail getC]);
}

//
// write all parameter tuples to the parameter file, fn
//   parameters:
//     params: a list of parameter tuples. Each tuple consists of a prefix
//             string and a parameter pair.
//
// Note: This method should be invoked between buildHeader and buildTail
// 
- (void) addParameters: (id <List>) params
{
  id <Pair> pair = nil;
  id <Index> indexer = [params begin: globalZone];
  while ((pair = [indexer next]) != nil)
    [self addParameter: (id <String>)[pair getFirst] withParameter: (id <Pair>)[pair getSecond]];
  [indexer drop];
}

//
// write a parameter pair to the parameter file, fn, with its preceeding string information
//   parameters:
//     prefix: a preceeding string 
//     param: a pair of a parameter name and a parameter value
//
- (void) addParameter: (id <String>) prefix withParameter: (id <Pair>) param
{
  id <String> pn = [param getFirst];
  id <String> pv = [param getSecond];
  fprintf(target, "%s %s %s\n", [prefix getC], [pn getC], [pv getC]);
} 

- closeFile
{
  fclose(target);
  return self;
}

@end
