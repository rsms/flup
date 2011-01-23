@interface HImageView : NSImageView {
  NSURL *url_;
  BOOL isDragging_;
}

@property(retain) NSURL *url;

@end
