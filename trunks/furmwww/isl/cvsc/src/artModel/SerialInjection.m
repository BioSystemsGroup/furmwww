/*
 * SerialInjection -- Handles multiple bolus injections
 * 
 * Copyright 2003-2008 - Regents of the University of California, San
 * Francisco.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

/**
 * if the second two parameters are negative, use an impulse
 * function that just creates the exact number of Solute 
 * objects and injects them all at time 0.
 *
 * from ../lp/framework/readme:
 *
 * dosage function:
 *
 *            b^c * t^(c-1) * exp(-b*t)
 *    d = a * -------------------------
 *                  (c-1)! 
 *
 * the factorial in the denominator can be converted to a libc gamma
 * function call, eliminating the need for a factorial function.
 * Also note that most of that expression is invariant with respect
 * to t.  The invariant parts ought to be computed once when the
 * dosageParam[ABC]'s are set.  Maybe something like:
 *
 *        a * b^c
 *    d = -------- * t^(c-1) * exp(-b*t)
 *        gamma(c)
 */

#import "SerialInjection.h"
@implementation SerialInjection

#include <math.h>

- (unsigned) _internalDosage: (unsigned) t
{
  if ([params getCount] < 3)
    raiseEvent(InternalError, "Not enough dosage parameters.\n");
  unsigned a = [[params atOffset: 0] getInt];
  int b = [[params atOffset: 1] getInt];
  int c = [[params atOffset: 2] getInt];
  unsigned retVal = 0U;

  if ( b < 0 && c < 0 ) {
    // if b and c are negative, use impulse

    if (t == 0) retVal = a;

  } else {

    double dosageInvariant = exp(log(a) + c * log(b) - lgamma(c));

    // note: t=0 results in a zero result, leading to a 1 cycle delay in
    // when the dose actually starts.  So, we add 1 to t here.
    t += 1;
    double result = dosageInvariant * pow(t,c-1) * exp(-1*(double)b*t);

    retVal = floor(result+0.5F);

  }

  [Telem debugOut: 3 printf: "[%s(%p) -_internalDosage: %d] -- "
         "a = %d, b = %d, c = %d, retVal = %d\n",
         [[self getClass] getName], self, t, a, b, c, retVal];

  return retVal;
}

- (unsigned) dosage: (unsigned) t
{
  // find which bin it's in
  unsigned bin = 1U;  // defaults to bin 1
  int i=0;
  for ( i=0 ; i<[times getCount] ; i++ ) {
    if ([[times atOffset: i] getInt] <= t) {
      // then t is in bin i
      bin = i+1;
    }
  }

  // sum all the bins up to and including the one t is in
  unsigned sum = 0U;
  for ( i=0 ; i<bin ; i++ ) {
    unsigned booga = t - [[times atOffset: i] getInt];

    [Telem debugOut: 3 printf: "[%s(%p) -dosage: %d] [[times atOffset: %d] getInt] = %d, booga = %d\n", [[self getClass] getName], self, t, i, [[times atOffset: i] getInt], booga];

    sum += [self _internalDosage: t-[[times atOffset: i] getInt]];
  }


  [Telem debugOut: 3 printf: "[%s(%p) -dosage: %d] => %d\n",
         [[self getClass] getName], self, t, sum];

  return sum;
}

#ifdef TESTING
#import <simtools.h>
#include <unistd.h>
void usage(const char *s) {
  printf(s);
  printf("Usage: dosage -a <val> -b <val> -c <val>\n");
  exit(-1);
}

int main(int argc, char **argv) {
  int c, digit_optind=0;
  unsigned ndx;
  unsigned sum;

  initSwarm(1, argv);

  SerialInjection *dosage = [SerialInjection create: scratchZone];
  
  id <Array> tempParams = [Array createBegin: scratchZone];
  [tempParams setDefaultMember: [Integer create: scratchZone setInt: INVALID_INT]];
  [tempParams setCount: 3];
  tempParams = [tempParams createEnd];
  id <Array> tempTimes = [Array createBegin: scratchZone];
  [tempTimes setDefaultMember: [Integer create: scratchZone setInt: INVALID_INT]];
  [tempTimes setCount: 2];
  [tempTimes createEnd];

  while (1) {
    int this_option_optind = optind ? optind : 1;
    int option_index = 0;
    c = getopt (argc, argv, "a:b:c:");
    if (c == -1) {
      if ([[tempParams atOffset: 0] getInt] == INVALID_INT ||
          [[tempParams atOffset: 1] getInt] == INVALID_INT ||
          [[tempParams atOffset: 2] getInt] == INVALID_INT) {
        usage("Didn't get any parameters.\n");
      }
      break;
    }
    switch (c) {

    case 'a':
      printf ("a = %d\n",atoi(optarg));
      [tempParams atOffset: 0 put: [Integer create: scratchZone setInt: atoi(optarg)]];
      break;
    case 'b':
      printf ("b = %d\n",atoi(optarg));
      [tempParams atOffset: 1 put: [Integer create: scratchZone setInt: atoi(optarg)]];
      break;
    case 'c':
      printf ("c = %d\n", atoi(optarg));
      [tempParams atOffset: 2 put: [Integer create: scratchZone setInt: atoi(optarg)]];
      break;
    case '?':
    default:
      usage("Couldn't parse arguments.\n");
    }
  }

  [tempTimes atOffset: 0 put: [Integer create: scratchZone setInt: 0]];
  [tempTimes atOffset: 1 put: [Integer create: scratchZone setInt: 50]];

  [dosage setParams: tempParams];
  [dosage setTimes: tempTimes];

  printf("Dosage function\n");
  printf("%5s,%24s,%24s\n", "Time", "as uns", "sum");
  sum = 0U;
  for ( ndx=0 ; ndx<=[[tempTimes atOffset: [tempTimes getCount]-1] getInt] + 15 ; ndx++ ) {
    unsigned d;
    d = [dosage dosage: ndx];
    sum += d;
    printf("%5d, %24u, %24u\n",ndx, d, sum);
    fflush(0);
  }
  return (0);
}
#endif
@end
