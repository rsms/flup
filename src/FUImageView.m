#import "FUImageView.h"

@implementation FUImageView


- (void)drawRect:(NSRect)dirtyRect {
  [super drawRect:dirtyRect];

  if (self.image) return;

  static NSAttributedString *mastr = nil;
  if (!mastr) {
    NSMutableParagraphStyle *paragraphStyle =
        [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [paragraphStyle setAlignment:NSCenterTextAlignment];
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
      [NSColor colorWithCalibratedWhite:0.0 alpha:0.4],
      NSForegroundColorAttributeName,
      paragraphStyle, NSParagraphStyleAttributeName,
      [NSFont fontWithName:@"Helvetica-Bold" size:16.0], NSFontAttributeName,
      nil];
    NSString *s = @"Drop an image here to upload";
    mastr = [[NSAttributedString alloc] initWithString:s attributes:attrs];
  }
  NSRect r = [self bounds];
  r.origin.y -= 30.0;
  r.origin.x += 15.0;
  r.size.width -= 30.0;
  [mastr drawInRect:r];
}


@end
