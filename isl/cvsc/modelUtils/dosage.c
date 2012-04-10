#include <math.h>
#include "dosage.h"

unsigned dosageParamA, dosageParamB, dosageParamC;

unsigned dosage (unsigned t) {
  // from ../lp/framework/readme:
  //
  //  dosage function:
  //
  //             b^c * t^(c-1) * exp(-b*t)
  //     d = a * -------------------------
  //                   (c-1)! 
  //
  // the factorial in the denominator can be converted to a libc gamma
  // function call, eliminating the need for a factorial function.
  // Also note that most of that expression is invariant with respect
  // to t.  The invariant parts ought to be computed once when the
  // dosageParam[ABC]'s are set.  Maybe something like:
  //
  //         a * b^c
  //     d = -------- * t^(c-1) * exp(-b*t)
  //         gamma(c)

  unsigned a = dosageParamA;
  unsigned b = dosageParamB;
  unsigned c = dosageParamC;

  double dosageInvariant = exp(log(a) + c * log(b) - lgamma(c));

  double result = dosageInvariant * pow(t,c-1) * exp(-1*(double)b*t);

#ifdef TESTING
  printf("%12.5g, ",result);
#endif

  return nearbyint(result);
}

#ifdef TESTING
#include <unistd.h>
int main(int argc, char **argv) {
  int c, digit_optind=0;
  unsigned ndx;
  unsigned sum;

  while (1) {
    int this_option_optind = optind ? optind : 1;
    int option_index = 0;
    c = getopt (argc, argv, "a:b:c:");
    if (c == -1)
      break;

    switch (c) {

    case 'a':
      printf ("a = %d\n",atoi(optarg));
      dosageParamA=atoi(optarg);
      break;
    case 'b':
      printf ("b = %d\n",atoi(optarg));
      dosageParamB=atoi(optarg);
      break;
    case 'c':
      printf ("c = %d\n", atoi(optarg));
      dosageParamC=atoi(optarg);
      break;
    case '?':
    default:
      printf("Usage: dosage -a <val> -b <val> -c <val>");
    }
  }

  printf("Dosage function\n");
  printf("%5s,%12s,%10s,%9s\n", "Time", "as float", "as uns", "sum");
  sum = 0U;
  for ( ndx=0 ; ndx<=15 ; ndx++ ) {
    unsigned d;
    printf("%5d,",ndx);
    d = dosage(ndx);
    printf("%9d,", d);
    sum += d;
    printf("%9d\n", sum);
    fflush(0);
  }
  return (0);
}
#endif
