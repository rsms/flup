#import "AppDelegate.h"
#import "flickr_api_key.h"
#import "HImageView.h"

NSString *const kGetAuthTokenStep = @"kGetAuthTokenStep";
NSString *const kCheckTokenStep = @"kCheckTokenStep";
NSString *const kUploadImageStep = @"kUploadImageStep";
NSString *const kGetImageSizesStep = @"kGetImageSizesStep";

static NSUserDefaults *g_defaults = nil;


@implementation AppDelegate

@synthesize window = window_,
            flickrUserName = flickrUserName_;


- (OFFlickrAPIRequest*)newFlickrRequest {
  OFFlickrAPIRequest *req =
      [[OFFlickrAPIRequest alloc] initWithAPIContext:flickrContext_];
  req.delegate = self;
  return req;
}


- (void)setAndStoreFlickrAuthToken:(NSString*)inAuthToken {
	if (!inAuthToken || ![inAuthToken length]) {
		flickrContext_.authToken = nil;
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:
     @"flickr_auth_token"];
	} else {
		flickrContext_.authToken = inAuthToken;
		[[NSUserDefaults standardUserDefaults] setObject:inAuthToken
                                              forKey:@"flickr_auth_token"];
	}
}


- (void)presentErrorMessage:(NSString*)message {
  NSDictionary *info = [NSDictionary dictionaryWithObject:message forKey:
                        NSLocalizedDescriptionKey];
  [NSApp presentError:[NSError errorWithDomain:@"se.hunch.flup"
                                          code:0
                                      userInfo:info]];
}


- (void)handleAppleEvent:(NSAppleEventDescriptor*)event
          withReplyEvent:(NSAppleEventDescriptor*)replyEvent {
  NSURL *url = [NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
  if (url && url.query && url.query.length > 6) {
    // query has the form of "&frob=", the rest is the frob
    NSString *frob = [url.query substringFromIndex:6];

    // make a request
		OFFlickrAPIRequest *req = [self newFlickrRequest];
    req.sessionInfo = kGetAuthTokenStep;
    [req callAPIMethodWithGET:@"flickr.auth.getToken"
                    arguments:
     [NSDictionary dictionaryWithObject:frob forKey:@"frob"]];

    // throb-throb-throb...
    [progressIndicator_ startAnimation:self];
    [imageDropView_ setEditable:NO];
    [imageDropView_ setEnabled:NO];
  }
}


- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  g_defaults = [[NSUserDefaults standardUserDefaults] retain];
  NSAppleEventManager *aem = [NSAppleEventManager sharedAppleEventManager];
  [aem setEventHandler:self
           andSelector:@selector(handleAppleEvent:withReplyEvent:)
         forEventClass:kInternetEventClass
            andEventID:kAEGetURL];
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Setup flickr api context
  flickrContext_ = [[OFFlickrAPIContext alloc] initWithAPIKey:
                    @FLICKR_API_KEY sharedSecret:@FLICKR_API_SHARED_SECRET];
  NSString *authToken = [g_defaults objectForKey:@"flickr_auth_token"];
  if (authToken) {
    flickrContext_.authToken = authToken;
  }
  applicationDidFinishLaunching_ = YES;
}


- (IBAction)authorizeFlickr:(id)sender {
  NSURL *loginURL =
      [flickrContext_ loginURLFromFrobDictionary:nil
                             requestedPermission:OFFlickrWritePermission];
  [[NSWorkspace sharedWorkspace] openURL:loginURL];
}


- (IBAction)uploadImage:(id)sender {
  // todo: check if authorized
  //NSImage *image = imageDropView_.image;
  NSURL *imageURL = imageDropView_.url;
  //NSLog(@"%@ %@ -- %@", NSStringFromSelector(_cmd), image, imageURL);

  // filename
  NSString *filename = [imageURL lastPathComponent];

  // flickr api params
  NSMutableDictionary *params = [NSMutableDictionary dictionary];
  NSString *tags = [g_defaults stringForKey:@"tags"];
  if (tags) [params setObject:tags forKey:@"tags"];
  BOOL public = [g_defaults boolForKey:@"is_public"];
  [params setObject:(public ? @"1" : @"0") forKey:@"is_public"];
  [params setObject:(public ? @"0" : @"1") forKey:@"hidden"];
  NSString *title = [[[[filename stringByDeletingPathExtension]
    stringByReplacingOccurrencesOfString:@"-" withString:@" "]
    stringByReplacingOccurrencesOfString:@"_" withString:@" "]
    stringByReplacingOccurrencesOfString:@"." withString:@" "];
  [params setObject:title forKey:@"title"];
  lastUploadedTitle_ = title;

  // MIME type
  NSString *mimeType = @"image/jpeg", *uti = nil;
  if ([imageURL getResourceValue:&uti
                          forKey:NSURLTypeIdentifierKey
                           error:nil]) {
    NSString *s = (NSString*)
        UTTypeCopyPreferredTagWithClass((CFStringRef)uti, kUTTagClassMIMEType);
    if (s) mimeType = s;
  }

  // image input stream
  NSInputStream *istream = nil;
  if ([imageURL isFileURL]) {
    istream = [NSInputStream inputStreamWithURL:imageURL];
  } else {
    [self presentErrorMessage:@"Only file URLs are (currently) supported"];
    return;
  }

  // throb.b.b.b.b...
  [progressIndicator_ startAnimation:self];
  [imageDropView_ setEditable:NO];
  [imageDropView_ setEnabled:NO];

  // make and send request
  OFFlickrAPIRequest *req = [self newFlickrRequest];
  req.sessionInfo = kUploadImageStep;
  [req uploadImageStream:istream
       suggestedFilename:filename
                MIMEType:mimeType
               arguments:params];
  NSLog(@"uploading %@...", imageURL);
}


- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames {
  NSLog(@"openFiles:%@", filenames);
  if (filenames.count > 1) {
    [self presentErrorMessage:@"Flup can only handle one image at the time. "
                               "Please drop single images on me. I like that."];
    return;
  }
  shouldTerminateWhenDone_ = !applicationDidFinishLaunching_;
  if (filenames.count != 0) {
    imageDropView_.url = [NSURL fileURLWithPath:[filenames objectAtIndex:0]];
    [self uploadImage:self];
  }
}


#pragma mark OFFlickrAPIRequest delegate methods


- (void)flickrAPIRequest:(OFFlickrAPIRequest *)req
 didCompleteWithResponse:(NSDictionary *)params {
	if (req.sessionInfo == kGetAuthTokenStep) {
    NSString *authToken = [[params valueForKeyPath:@"auth.token"] textContent];
		[self setAndStoreFlickrAuthToken:authToken];
		self.flickrUserName = [params valueForKeyPath:@"auth.user.username"];
	} else if (req.sessionInfo == kCheckTokenStep) {
		self.flickrUserName = [params valueForKeyPath:@"auth.user.username"];
	} else if (req.sessionInfo == kUploadImageStep) {
    NSString *photoId = [params valueForKeyPath:@"photoid._text"];
    lastUploadedId_ = photoId;
    OFFlickrAPIRequest *req = [self newFlickrRequest];
    req.sessionInfo = kGetImageSizesStep;
    [req callAPIMethodWithGET:@"flickr.photos.getSizes"
                    arguments:[NSDictionary dictionaryWithObjectsAndKeys:
                    photoId, @"photo_id", nil]];
    NSLog(@"fetching URLs for [%@] %@...", photoId, imageDropView_.url);
    return;
  } else if (req.sessionInfo == kGetImageSizesStep) {
    NSArray *imageSizes = [params valueForKeyPath:@"sizes.size"];
    NSInteger imageSize = [g_defaults integerForKey:@"image_size"];
    NSDictionary *info;
    if (imageSize > 0 && imageSize-1 <= imageSizes.count-1) {
      info = [imageSizes objectAtIndex:imageSize-1];
    } else {
      // default to original image
      info = [imageSizes lastObject];
    }
    NSString *sourceURLString = [info objectForKey:@"source"];
    NSURL *sourceURL = [NSURL URLWithString:sourceURLString];

    // log info
    NSAttributedString *astr = [[NSAttributedString alloc] initWithString:@"\n"
      attributes:nil];
    [textView_.textStorage insertAttributedString:astr atIndex:0];
    astr = [[NSAttributedString alloc] initWithString:
      [NSString stringWithFormat:@"(Edit)", sourceURLString] attributes:
      [NSDictionary dictionaryWithObjectsAndKeys:[NSURL URLWithString:
        [NSString stringWithFormat:
        @"http://www.flickr.com/photos/upload/edit/?ids=%@", lastUploadedId_]],
        NSLinkAttributeName, nil]];
    [textView_.textStorage insertAttributedString:astr atIndex:0];
    [textView_.textStorage insertAttributedString:[[NSAttributedString alloc]
      initWithString:@"  " attributes:nil] atIndex:0];
    astr = [[NSAttributedString alloc] initWithString:
      [NSString stringWithFormat:@"%@", sourceURLString] attributes:
      [NSDictionary dictionaryWithObjectsAndKeys:
        sourceURL, NSLinkAttributeName,
        nil]];
    [textView_.textStorage insertAttributedString:astr atIndex:0];
    astr = [[NSAttributedString alloc] initWithString:
      [NSString stringWithFormat:@"%@ ➜ ",
        [imageDropView_.url lastPathComponent]]
      attributes:nil];
    [textView_.textStorage insertAttributedString:astr atIndex:0];

    // pasteboard objects
    NSString *stringRep = nil;
    if ([g_defaults boolForKey:@"html_in_pasteboard"]) {
      // html
      stringRep = [NSString stringWithFormat:
        @"<img src=\"%@\" width=\"%@\" height=\"%@\" alt=\"%@\">",
        sourceURLString, [info objectForKey:@"width"],
        [info objectForKey:@"height"], lastUploadedTitle_];
    } else {
      // markdown
      stringRep = [NSString stringWithFormat:
        @"![%@](%@)", lastUploadedTitle_, sourceURLString];
    }

    // populate pasteboard
		NSPasteboard *pb = [NSPasteboard generalPasteboard];
		[pb clearContents];
    [pb setString:sourceURLString forType:NSURLPboardType];
    [pb setString:stringRep forType:NSStringPboardType];

    // terminate?
    if (shouldTerminateWhenDone_)
      [NSApp terminate:self];
  }
	[progressIndicator_ stopAnimation:self];
  [imageDropView_ setEditable:YES];
  [imageDropView_ setEnabled:YES];
  [imageDropView_ setImage:nil];
}


- (void)flickrAPIRequest:(OFFlickrAPIRequest *)req
        didFailWithError:(NSError *)error {
  NSLog(@"Flickr API request failed: (%@) %@", req, error);
  NSString *msg = @"Unspecified Flickr API error";
	if (req.sessionInfo == kGetAuthTokenStep) {
    msg = @"Failed to receive authentication token from Flickr";
	} else if (req.sessionInfo == kCheckTokenStep) {
    msg = @"Failed to authenticate with Flickr";
		[self setAndStoreFlickrAuthToken:nil];
	} else if (req.sessionInfo == kUploadImageStep) {
    msg = @"Failed to upload image";
  }
  if (error) {
    msg = [msg stringByAppendingFormat:@" -- %@", error];
  }
	[progressIndicator_ stopAnimation:self];
  [imageDropView_ setEditable:YES];
  [imageDropView_ setEnabled:YES];
  [imageDropView_ setImage:nil];
  [self presentErrorMessage:msg];
}



@end
