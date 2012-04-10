#import <stdlib.h> // for exit()
#import <errno.h>  // for errno
#import <fnmatch.h> // for fnmatch()
#import <string.h> // for strerror()
#import <sys/stat.h> // for flags of mkdir()   
#import "Partitioner.h"
#import "OperationBuilder.h"

#import <modelUtils.h>

@implementation Partitioner

+ createBegin: aZone
{
  Partitioner *p = [super createBegin: aZone];
  return p;
}

- createEnd
{
  return [super createEnd];
}

/*
 * sequential partitioner
 *
 * tryutn a list of partition blocks.
 * each block consits of at least one input parameter set.
 * An input parameter set is reprensted by the file name associated with it.
 *
 */
- (id <List>) partition: (char [][256]) parray length: (int) len for: (int) np
{
  id <List> pblist = [[List createBegin: [self getZone]] createEnd];
  int idx;
  for(idx = 0; idx < np; idx++)
    [pblist addLast: [self partition: parray length: len for: np myid: idx]];
  return pblist;
}


/*
 * parallel partitioner
 *
 * return a partition block having at least one input parameter set.
 * An input parameter set is reprensted by the file name associated with it.
 *
 */
- (id <List>) partition: (char [][256]) parray length: (int) len for: (int) np myid: (int) rank
{
  int minsize =  len < np ? -1 : len/np; // the low bound of PB size
  

  if(minsize < 1)
    {
      fprintf(stderr, "Error: a  processor should have at least one parameter file ...\n");
      exit(-1);
    }

  int idx;
  id <List> pblist = [[List createBegin: [self getZone]] createEnd];
  int offset = minsize*rank; // low bound of parray for the given rank value
  for(idx = offset; idx < offset + minsize; idx++) 
        [pblist addLast: [String create: [self getZone] setC: parray[idx]]];
  
  if(len > minsize*np)
    {
      offset = len - rank;
      if(offset > minsize*np) 
	[pblist addLast: [String create: [self getZone] setC: parray[offset - 1]]];
    }

  return pblist;
}

//
// data type conversion
//

- (MPI_Datatype) getPayloadType: (struct payload) result
{
   int blockcount[3] = { 256, 1, 1};
   MPI_Aint displs[3];
   MPI_Datatype types[3];
   MPI_Datatype mpitype;

   MPI_Address(&result.name, &displs[0]);
   MPI_Address(&result.similarity, &displs[1]);
   MPI_Address(&result.exetime, &displs[2]);

   int idx;
   for(idx = 2; idx >= 0; idx--) displs[idx] -= displs[0];
   types[0] = MPI_CHAR;
   types[1] = MPI_DOUBLE;
   types[2] = MPI_DOUBLE;

   MPI_Type_struct(3, blockcount, displs, types, &mpitype);
   MPI_Type_commit(&mpitype);

   return mpitype;
}

//
// file and directory handling methods
//

/*
 * set directory name
 * 
 */
- (DIR *) openDir: (const char *) name
{
  DIR *dirp; // a pointer of a directory

  if((dirp = opendir(name)) == NULL)
    {
      fprintf(stderr, "Could not open %s directory: %s\n", name, strerror(errno));
      exit(1);
    }
  return dirp;
}

/*
 * get a list of file names of a directory
 *
 */
- (id <List>) getFileListInfo: (const char  *) name
{
  id <List> fnlist; // a list containing files of a dierctory
  DIR *dirp; // a pointer of a directory
  struct dirent *direntp; // a pointer of each directory entry data structure

  dirp = [self openDir: name];
  fnlist = [[List createBegin: [self getZone]] createEnd];   
  while((direntp = readdir(dirp)) != NULL)
    [fnlist addLast: [String create: [self getZone] setC: direntp->d_name]];
  closedir(dirp);
  return fnlist;
}

/*
 * get a lisst of file names of a directory having the given suffix
 *
 */

- (id <List>) getFileListInfo: (const char *) name with: (const char *) suffix
{
  char pattern[512]; // suffix pattern (e.g., *suffix)
  id <List> fnlist; // a list containing files of a directory after suffix filtering
  DIR *dirp; // a pointer of a directory
  struct dirent *direntp; // a pointer of each directory entry data structure

  dirp = [self openDir: name];
  sprintf(pattern, "*%s",  suffix);
  fnlist = [[List createBegin: [self getZone]] createEnd];
  while((direntp = readdir(dirp)) != NULL)
      if(fnmatch(pattern, direntp->d_name, FNM_NOESCAPE) == 0)
	[fnlist addLast: [String create: [self getZone] setC: direntp->d_name]];
  closedir(dirp);
  return fnlist;
}


- (id <Array>) toArrayFromList: (const id <List>) list
{
  int idx;
  int length = [list getCount];
  id <Array> array = [Array create: [self getZone] setCount: length];
  id <Index> indexer = [list begin: [self getZone]];
  for(idx = 0; idx < length; idx++) [array atOffset: idx put: [indexer next]];
  [indexer drop];
  return array;
}

- (id <List>) toListFromArray: (const id <Array>) array
{
  int idx;
  id <List> list = [[List createBegin: [self getZone]] createEnd];
  for(idx = 0; idx < [list getCount]; idx++) [list addLast: [array atOffset: idx]];
  return list;
}

//
// printing helper methods
//

/*
 * print a list
 *
 */
- print: (const id <List>) list
{
  id <Index> indexer = [list begin: [self getZone]];
  id element = nil; 
  while((element = [indexer next]) != nil) printf("%s ", [element getC]); 
  printf("\n");
  [indexer drop];
  return self;
}

/*
 * print an array
 *
 */
- printArray: (const id <Array>) array
{
  int idx;
  for(idx = 0; idx < [array getCount]; idx++) printf("%s ", [[array atOffset: idx] getC]);
  printf("\n");
  return self;
}


/*
 * print a List
 *
 */
- printList: (const id <List>) list
{
  id <Index> indexer = [list begin: [self getZone]];
  id <List> element = nil; 
  while((element = [indexer next]) != nil)  [self print: element];
  [indexer drop];
  return self;
}

@end

