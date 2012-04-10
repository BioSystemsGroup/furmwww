#import "OperationBuilder.h"

@implementation OperationBuilder

+ (MPI_Op) buildOperation: (void *) handler
{
  MPI_Op op;
  MPI_Op_create((MPI_User_function *) handler, 1, &op);
  return op;
}

@end
