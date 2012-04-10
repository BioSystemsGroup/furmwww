/*
 * IPRL - Partitioner -- slices up runs for distribution over nodes
 *
 * Copyright 2003-2007 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */
//#import <objectbase/SwarmObject.h>	// for SwarmObject
#import "../RootObject.h"
#import <dirent.h>			// for DIR	
#import <mpi.h>

@interface Partitioner: RootObject
{
  struct payload
  {
    char name[256]; // file name of a parameter set
    double similarity; // similarity value
    double exetime; // execution time
  } payload_def;
}

+ createBegin: aZone;
- createEnd;

- (id <List>) partition: (char [][256]) parray length: (int) len for: (int) np;
- (id <List>) partition: (char [][256]) parray length: (int) len for: (int) np myid: (int) rank;
//- (struct payload) getPayload;
// - (MPI_Datatype) getPayloadType: (int) np;

- (MPI_Datatype) getPayloadType: (struct payload) result;

// file and directory handling methods
- (DIR *) openDir: (const char *) name;
- (id <List>) getFileListInfo: (const char *) name;
- (id <List>) getFileListInfo: (const char *) name with: (const char *) suffix;

// data type conversion
- (id <Array>) toArrayFromList: (const id <List>) list;
- (id <List>) toListFromArray: (const id <Array>) array;

// print
- print: (const id <List>) list;
- printArray: (const id <Array>) array;
- printList: (const id <List>) list;
@end
