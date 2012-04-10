#import "LogPlotter.h"
@implementation LogPlotter
-(void) setYAxisLogscale
{
  [globalTkInterp
    eval: "%s yaxis configure -logscale yes", widgetName];
}
@end
