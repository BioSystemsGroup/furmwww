// Copyright © 1995-2000 Swarm Development Group.
// No warranty implied, see LICENSE for terms.
//
// This is a derived work.
// Modified from the original by glen e. p. ropella <gepr@tempusdictum.com>
//

#import <objectbase.h>
#import <objectbase/SwarmObject.h>
@interface DiGraphLink: SwarmObject
{
  id from;
  id to;
  id canvas;
  id linkItem;
}

- setCanvas: aCanvas;
- setFrom: from To: to;
- createEnd;
- getFrom;
- getTo;
- getLinkItem;
- (void)update;
- hideLink;
- (void)drop;
@end
