/*
 * IPRL - Parameter Sweeper
 *
 * Copyright 2003-2007 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
#import <stdlib.h>
#import <string.h>
#import <modelUtils.h>
#import "ParameterSweeper.h"

@implementation ParameterSweeper

+ createBegin: aZone
{
  return [super createBegin: aZone];
}

- createEnd
{
  return [super createEnd];
}

- construct : (int) start to: (int) end
{
  // validity check !
  if(start >= end || start >= [sweepTbl getCount])
    {
      printf("Parameter Sweeping Error:");
      printf(" OutOfOffset : start(%d) >= end(%d)\n ...", start, end);
      exit(-1);
    }

  // move to the start location of the table
  int offset;
  id <MapIndex> indexer = [sweepTbl mapBegin: [self getZone]];
  for(offset = 0; offset < start; offset++) [indexer next];

  // parameter sweeping space construction !!
  sweepSpaceSize = [self getSweepingSpaceSize];
  tupleSize = end-start+1;
  sweepSpace = malloc(sizeof(id<String>)*sweepSpaceSize*tupleSize);

  unsigned length = sweepSpaceSize;
  for(offset = start; offset < end; offset++)
    {
      id <List> paramValues = [indexer next]; 
      unsigned partition = [paramValues getCount];
      unsigned size = length/partition;
      unsigned repeat =  sweepSpaceSize/length;
      unsigned r, p, s, e, l;
      id <String> v;

      // printf("total: %d length:%d partition:%d size:%d repeat:%d\n", total, length, partition, size, repeat); 
      for(r = 0; r < repeat; r++)
	{
	  for (p = 0; p < partition; p++)
	    {   
	      s = r * length + p * size;
	      e = r * length + (p+1) * size;
	      v = [paramValues atOffset: p]; 
	      for (l = s; l < e; l++) *(sweepSpace+l*tupleSize+offset) = v;
	    }
	}
      length = length/partition;
    }

  return self;
}

- buildParameterSweepingSpace: (id <String>) fn to: (id <String>) dir
{
  FILE *fp = fopen([fn getC], "r");
  if(fp != NULL)
    {
      // cretea a folder that will contain all parameter files genereated here
      baseDir = dir;
      [DMM checkAndCreateDir: baseDir];
      
      // construct a parameter sweeping table 
      [self buildParameterSweepingTable: fp];
      fclose(fp);

      // build a parameter sweeping space
      [self construct: 0 to: [sweepTbl getCount]];

      // create parameter files for the whole parameter sweeping space
      [self generateParameterFiles];
    }

  return self;
}

/*
 * isComment(char *str) -- Reads the string and if a ; precedes everything
 * except spaces and tabs, then it's a comment.
 */
BOOL isComment(char *str)
{
   BOOL retVal = YES;
   char * sPtr = str;
   char * semi = index(str, ';');
   // if there is no ";" then NO
   if (semi == (const char *)nil) retVal = NO;
   else {
     int size = semi - sPtr;
     int sNdx;
     // if one of size slots is not a space or tab, then NO
     for ( sNdx=0 ; sNdx<size ; sNdx++ )
       if ( !( (sPtr+sNdx)[0] == ' ' || (sPtr+sNdx)[0] == '\t' ) )
         retVal = NO;
   }
   return retVal;
}

- buildParameterSweepingTable:  (FILE *) fp
{
  char buf[2048]; // a line buffer
  char token[512]; // a token buffer
  char* line; // a parameter tuple
  char* ptr; // current position in the line buffer

  tabSize = -1;

  // read a base parameter file name first
  if(fgets(buf, 2048, fp) == '\0')
    {
      printf("Parameter Sweeping Table Format Error: ");
      printf("You should put a basic parameter file first (e.g., liver3.scm)...");
      exit(-1);
    }
  ptr = strstr(buf, "\n");
  token[ptr - buf] = '\0';
  id <String> pfname = [String create: [self getZone] setC: strncpy(token, buf, (ptr - buf))];
  FILE *pf = fopen([pfname getC], "r");
  if(pf == NULL)
  {
    printf("Cannot open the parameter file %s ...\n", [pfname getC]);
    exit(-1);
  }

  header = [String create: [self getZone]];
  tail = [String create: [self getZone]];
  sweepTbl = [Map create: [self getZone]];
  paramTbl = [Map create: [self getZone]]; 

  // construct parameter sweeping table 
  while(fgets(buf, 2048, fp) != '\0')
    {
      line = buf;
      // read parameter name first
      if((ptr = strstr(line, "\n")) != '\0') *ptr = '\0'; // remove an  EOL character
      ptr = strstr(line, " ");
      token[ptr - line] = '\0';
      id <String> param = [String create: [self getZone] setC: strncpy(token, line, (ptr - line))];
      line += (ptr - line + 1);
      // read all parameter values associated with the parameter name
      id <List> values = [List create: [self getZone]];
      while((ptr = strstr(line, " ")) != '\0')
	{
	   token[ptr - line] = '\0';
	  [values addLast: [String create: [self getZone] setC: strncpy(token, line, (ptr - line))]];
	  line += (ptr - line + 1);
	}
      [values addLast: [String create: [self getZone] setC: line]];
      // add the pair of the parameter name and associated values
      [sweepTbl at: param insert: values];
    }
  printf("*** Parameter Sweeping Table *** \n");
  [self printSweepMap];

  // construct invariant parameter table 
  while(fgets(buf, 2048, pf) != '\0')
    {
      [header catC: buf];
      if(strstr(buf, "'ParameterManager") != '\0') break;
    }
  while(fgets(buf, 2048, pf) != '\0')
    {
      line = buf;
      if(strstr(line, "'bolusContents") != '\0') break;
      else if(strstr(line, ")")) continue;
      else if(isComment(line)) continue;
      else 
	{
	  line = strstr(line, ":"); // move a file pointer to a key
	  if(tabSize == -1) tabSize = line - buf;
	  ptr = strstr(++line, " ");
	  strncpy(token, line, (ptr - line));
	  token[ptr-line] = '\0'; 
	  id <String> key = [String create: [self getZone] setC: token];
	  if([sweepTbl at: key] != nil) continue;
	  line += (ptr - line) + 1;
	  ptr = strstr(line, "\n");
	  strncpy(token, line, (ptr - line));
	  token[ptr-line] = '\0'; 
	  id <String> value = [String create: [self getZone] setC: token];
	  [paramTbl at: key insert: value];
	}
    }
  [tail catC: buf];
  while(fgets(buf, 2048, pf) != '\0') [tail catC: buf];
  fclose(pf);
  
  return self;
}

- generateParameterFiles
{
  FILE *fp;

  // print the whole Parameter Sweeping Space
  printf("*** Parameter Sweeping Space *** \n");
  [self printSweepSpace];

  printf("Generting parameter files for the entire parameter sweeping space (sweepSpaceSize = %d) ...\n", sweepSpaceSize);

  // create key array
  id <MapIndex> indexer = [sweepTbl mapBegin: [self getZone]];
  id <String> keySet[tupleSize];
  id <String> k;
  int cnt = 0;
  while(([indexer getLoc] != End) && ([indexer next: &k] != nil)) keySet[cnt++] = k;
  [indexer drop];

  int s, t, i;
  for(s = 0; s < sweepSpaceSize; s++)
    {
      char buf[1024];
      sprintf(buf, "%s/param-%d.scm", [baseDir getC], s);
      fp = fopen(buf, "w");

      // write the header
      fprintf(fp, "%s", [header getC]);

      // write invariant parameters first
      id <MapIndex> indexer = [paramTbl mapBegin: [self getZone]];
      id <String> pkey;
      id <String> pvalue;
      while(([indexer getLoc] != End) && ((pvalue = [indexer next: &pkey]) != nil)) 
	{
	  for(i = 0; i < tabSize-1; i++) fprintf(fp, " ");
	  fprintf(fp, "#:%s %s\n", [pkey getC], [pvalue getC]); 
	}
      [indexer drop];
      
      // write variant parameters  
      for(t = 0; t < tupleSize-1; t++)
	{
	  for(i = 0; i < tabSize-1; i++) fprintf(fp, " ");
	  fprintf(fp, "#:%s %s\n", [keySet[t] getC], [(id <String>) *(sweepSpace+s*tupleSize+t) getC]); 
	}
      for(i = 0; i < tabSize-1; i++) fprintf(fp, " ");
      fprintf(fp, "))\n");
      
      // write the tail
      fprintf(fp, "%s", [tail getC]);
      fclose(fp);
    }
 return self;
}

- (id <String>) getParameterSweepingSpaceDir
{
  return baseDir;
}

- printSweepSpace
{
  id<String> *space = sweepSpace;

  int i, j;
  for(i = 0; i < sweepSpaceSize; i++)
    {
      printf("%d: ", i); 
      for(j = 0; j < tupleSize-1; j++) 
	  printf("[%s]", [(id <String>) *(space + i * tupleSize + j) getC]); 
      printf("\n");
    }
  return self;
}

-printParamMap
{
  id <MapIndex> indexer = [paramTbl mapBegin: [self getZone]];
  id <String> key;
  id <String> value;
  while(([indexer getLoc] != End) && ((value = [indexer next: &key]) != nil))
    printf("Key: %s, Value: %s\n", [key getC], [value getC]); 
  [indexer drop];
  return self;
}

- printSweepMap
{
  id <MapIndex> indexer = [sweepTbl mapBegin: [self getZone]];
  id <String> key;
  id <List> tuple;
  while(([indexer getLoc] != End) && ((tuple = [indexer next: &key]) != nil))
    {
      printf("Key: %s ==> ", [key getC]); 
      id <ListIndex> idx = [tuple listBegin: [self getZone]];
      id <String> value;
      while(([idx getLoc] != End) && ((value = [idx next]) != nil)) printf("%s ", [value getC]);
      printf("\n");
      [idx drop];
    }
  [indexer drop];
  return self;
}

- (unsigned) getSweepingSpaceSize
{
  unsigned total = 1;
  id <MapIndex> indexer = [sweepTbl mapBegin: [self getZone]];
  id <List> tuple;
  while(([indexer getLoc] != End) && ((tuple = [indexer next]) != nil))
    total *= [tuple getCount];
  [indexer drop];
  return total;
}
  
@end
