#import "Handler.h"

//
// operators
//
void MAX_SIMILARITY(struct payload *a, struct payload *b, int *len, MPI_Datatype *type)
{
  int i;
  for(i = 0; i < *len; i++)
    {
      if(a->similarity > b->similarity) *b = *a;
      a++;
      b++;
    }
}

void MIN_SIMILARITY(struct payload *a, struct payload *b, int *len, MPI_Datatype *type)
{
  int i;
  for(i = 0; i < *len; i++)
    {
      if(a->similarity < b->similarity) *b = *a;
      a++;
      b++;
    }
}

void MAX_EXEC_TIME(struct payload *a, struct payload *b, int *len, MPI_Datatype *type)
{
  int i;
  for(i = 0; i < *len; i++)
    {
      if(a->exetime > b->exetime) *b = *a;
      a++;
      b++;
    }
}
