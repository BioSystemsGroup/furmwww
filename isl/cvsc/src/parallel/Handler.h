#import "Partitioner.h"

// operations
extern void MAX_SIMILARITY(struct payload *a, struct payload *b, int *len, MPI_Datatype *type);
extern void MIN_SIMILARITY(struct payload *a, struct payload *b, int *len, MPI_Datatype *type);
extern void MAX_EXEC_TIME(struct payload *a, struct payload *b, int *len, MPI_Datatype *type);
