#import "HImageView.h"

@implementation HImageView


- (void)dealloc {
	[url_ release];
	[super dealloc];
}


- (void)setImage:(NSImage*)image {
	if(isDragging_ == NO) {
    [url_ autorelease];
    url_ = nil;
  }
	[super setImage:image];
}


- (void)concludeDragOperation:(id<NSDraggingInfo>)sender {
	[url_ autorelease];
  url_ = nil;

	NSPasteboard *pboard = [sender draggingPasteboard];
	NSArray *types = [pboard types];
  if ([types containsObject:NSURLPboardType]) {
    NSArray *objects = [pboard propertyListForType:NSURLPboardType];
    //NSLog(@"urls -> %@", objects);
    if (objects.count > 0) {
      url_ = [[NSURL alloc] initWithString:[objects objectAtIndex:0]];
    }
  } else if ([types containsObject:NSFilenamesPboardType]) {
		NSArray *objects = [pboard propertyListForType:NSFilenamesPboardType];
		//NSLog(@"filenames -> %@", objects);
    if (objects.count > 0) {
      url_ = [NSURL fileURLWithPath:[objects objectAtIndex:0]];
    }
	}

	isDragging_ = YES;
	[super concludeDragOperation:sender];
	isDragging_ = NO;
}


- (NSURL*)url {
  return url_;
}

- (void)setUrl:(NSURL*)url {
  [self setImage:nil];
	if (url) {
		NSImage *image = [[[NSImage alloc] initWithContentsOfURL:url] autorelease];
		if (image) {
			[self setImage:image];
      [url_ autorelease];
      url_ = [url retain];
		}
	}
}


@end
