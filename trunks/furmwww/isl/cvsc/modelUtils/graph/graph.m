// Copyright ? 1995-2000 Swarm Development Group.
// No warranty implied, see LICENSE for terms.
//
// This is a derived work.
// Modified from the original by glen e. p. ropella <gepr@tempusdictum.com>
//
#import <defobj.h>
#import "graph.sym"

void initGraphLibrary() {
  static BOOL  already_initialized = 0;

  if ( already_initialized ) return;
  already_initialized = 1;

  defsymbol( RectangleNode );
  defsymbol( OvalNode );
}

