#import <ObjectiveFlickr/ObjectiveFlickr.h>
@class HImageView;

@interface AppDelegate : NSObject <NSApplicationDelegate,
                                   OFFlickrAPIRequestDelegate> {
  NSWindow *window_;
  OFFlickrAPIContext *flickrContext_;
  OFFlickrAPIRequest *flickrRequest_;
  NSString *flickrUserName_;
  NSString *lastUploadedTitle_;
  NSString *lastUploadedId_;
  IBOutlet NSProgressIndicator *progressIndicator_;
  IBOutlet HImageView *imageDropView_;
  IBOutlet NSTextView *textView_;
}

@property (assign) IBOutlet NSWindow *window;
@property (retain) NSString *flickrUserName;

- (IBAction)authorizeFlickr:(id)sender;
- (IBAction)uploadImage:(id)sender;

@end
