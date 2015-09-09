//
//  OOInlineIOS7ViewController.m
//  OoyalaSDK
//
// Copyright (c) 2015 Ooyala, Inc. All rights reserved.
//

#import "OOInlineIOS7ViewController.h"
#import "OOOoyalaPlayer.h"
//#import "OOOoyalaPlayerViewController.h"
#import "OOInlineIOS7ControlsView.h"
#import "OOUIProgressSliderIOS7.h"
#import "OOVideo.h"
#import "OOUIUtils.h"
#import "OODebugMode.h"
#import "OOOptions.h"

@interface OOInlineIOS7ViewController() {
  BOOL wasPlaying;
  BOOL seeking;
  CGFloat bottomBarHeight;
}

@property (nonatomic) OOInlineIOS7ControlsView *controls;
@end

@implementation OOInlineIOS7ViewController

@dynamic controls;


- (void)viewDidLoad {
  if (self.player == nil) {
    LOG(@"viewDidLoad while player is nil");
    return;
  }
  
  self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
  
  //add controls
  self.controls = [[OOInlineIOS7ControlsView alloc] initWithFrame:self.view.bounds];

  [self initializeCoreControls];

  [self initializeFullscreenControls];

  [self initializeInlineControls];

  [super viewDidLoad];
}

- (void) initializeCoreControls {
  self.controls.playButton.target = self.player;

  self.controls.closedCaptionsButton.target = self.delegate;
  self.controls.closedCaptionsButton.action = @selector(closedCaptionsSelector);
  
  self.controls.fullscreenButton.target = self.delegate;
  self.controls.fullscreenButton.action = @selector(showFullscreen);

  [self.controls.scrubberSlider.scrubber addTarget:self action:@selector(onScrubbingStarted) forControlEvents:UIControlEventTouchDown];
  [self.controls.scrubberSlider.scrubber addTarget:self action:@selector(onScrubbingChanged) forControlEvents:UIControlEventValueChanged];
  [self.controls.scrubberSlider.scrubber addTarget:self action:@selector(onScrubbingEnded) forControlEvents:UIControlEventTouchUpInside];
  [self.controls.scrubberSlider.scrubber addTarget:self action:@selector(onScrubbingEnded) forControlEvents:UIControlEventTouchUpOutside];

  [super viewDidLoad];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAdsLoaded:) name:OOOoyalaPlayerAdsLoadedNotification object:self.player];
}

-(void)onAdsLoaded:(NSNotification*)notification {
  // delay to avoid crashing in the stack of handling the first notification.
  dispatch_async( dispatch_get_main_queue(), ^{
    [self syncUI];
  });
}

- (void) initializeFullscreenControls {
  self.controls.doneButton.target = self.delegate;
  self.controls.doneButton.action = @selector(onFullscreenDoneButtonClick);

  self.controls.videoGravityFillButton.target = self.delegate;
  self.controls.videoGravityFillButton.action = @selector(switchVideoGravity);

  self.controls.videoGravityFitButton.target = self.delegate;
  self.controls.videoGravityFitButton.action = @selector(switchVideoGravity);
}

- (void)initializeInlineControls {
  self.controls.fullscreenButton.target = self.delegate;
  self.controls.fullscreenButton.action = @selector(showFullscreen);
}

- (void)onScrubbingStarted {
  if (self.player == nil) {
    LOG(@"onScrubbingStarted while player is nil");
    return;
  }
  seeking = YES;
}

- (void)onScrubbingChanged {
  if (self.player == nil) {
    LOG(@"onScrubbingChanged while player is nil");
    return;
  }
  if (self.player.seekStyle == OOSeekStyleEnhanced) {
    [self.player seek:self.controls.scrubberSlider.scrubberAbsoluteValue];
  }
}

- (void)onScrubbingEnded {
  if (self.player == nil) {
    LOG(@"onScrubbingEnded while player is nil");
    return;
  }
  if (self.player.seekStyle != OOSeekStyleEnhanced) {
    [self.player seek:self.controls.scrubberSlider.scrubberAbsoluteValue];
  }
  
  seeking = NO;

  [self syncUI];
}

- (void)syncUI {
  [super syncUI];

  if (self.player == nil) {
    LOG(@"syncUI while player is nil");
    return;
  }

  if (!self.controls)
    return;
  
  //Hiding until we have UX to support it
  //Closed Captions button
  [self updateClosedCaptionsButton];

  // Handle LIVE streams
  self.controls.scrubberSlider.mode = [super sliderMode];
  
  //Handle time
  if (seeking == NO) {
    self.controls.scrubberSlider.duration = self.player.duration;
    self.controls.scrubberSlider.currentTime = self.player.playheadTime;
    self.controls.scrubberSlider.currentAvailableTime = self.player.bufferedTime;
    self.controls.scrubberSlider.seekableTimeRange = [self.player seekableTimeRange];
    [self.controls.scrubberSlider updateTimeDisplay];
  }
  
  //Handle state
  [self.controls setIsPlayShowing:!self.player.isPlaying];

  if (self.player.isPlaying) {

    if ([self showingAdsWithHiddenControls]) {
      [self hideControls];
    } else if (self.controls.playButton.isPlayShowing) {
      [self.controls.playButton setIsPlayShowing:NO];
      if (self.controls.hidden == NO) {
        [self invalidateHideControlsTimer];
        [self showControls];
      }
    }
  } else if (!self.controls.playButton.isPlayShowing) {
      [self.controls.playButton setIsPlayShowing:YES];
      if (self.controls.hidden == NO) {
        [self invalidateHideControlsTimer];
        [self showControls];
    }
  }

  self.controls.scrubberSlider.scrubber.userInteractionEnabled = self.player.seekable;

  if ((self.player.state == OOOoyalaPlayerStateLoading) && seeking == NO)
    [self.activityView startAnimating];
  else
    [self.activityView stopAnimating];

  self.controls.scrubberSlider.cuePointsAtSeconds = [self.player getCuePointsAtSecondsForCurrentPlayer];
}

- (void) setFullScreenButtonShowing: (BOOL) isShowing {
  [self.controls setFullscreenButtonShowing:isShowing];
}

- (void)hideControls {
  if (self.player == nil) {
    LOG(@"hideControls while player is nil");
    return;
  }

  [self invalidateHideControlsTimer];
  if (self.controls == nil) return;

  [UIView animateWithDuration:0.37
                   animations: ^ {
                     [self.controls hide];
                     if (self.overlay) [self.overlay setAlpha:0];
                     [self setNeedsStatusBarAppearanceUpdate];
                   }
                   completion: ^ (BOOL finished) {
                     if (self.overlay) self.overlay.hidden = YES;
                   }];
  self.controls.hidden = YES;
  [self updateClosedCaptionsPosition];
}

-(void) invalidateHideControlsTimer {
  if (self.hideControlsTimer != nil) {
    [self.hideControlsTimer invalidate];
    self.hideControlsTimer = nil;
  }
}

- (void)showControls {
  if (self.player == nil || [self showingAdsWithHiddenControls]) {
    LOG(@"showControls while player is nil");
    return;
  }
  if (!self.isVisible) return;
  [self invalidateHideControlsTimer];
  if (self.controls == nil) return;

  self.controls.hidden = NO;
  if (self.overlay) self.overlay.hidden = NO;
  self.hideControlsTimer = [NSTimer scheduledTimerWithTimeInterval:CONTROLS_HIDE_TIMEOUT target:self selector:@selector(hideControls) userInfo:nil repeats:NO];

  [UIView animateWithDuration:0.37
                   animations: ^ {
                     [self.controls show];
                     if (self.overlay) [self.overlay setAlpha:1];
                     [self setNeedsStatusBarAppearanceUpdate];
                   }
                   completion: NULL];
	[self updateClosedCaptionsPosition];
}

- (void)changeButtonLanguage:(NSString*)language {
  // Implement this method when inline button's language need to be changed with closed caption
}

- (void)viewDidAppear:(BOOL)animated {
  [self updateClosedCaptionsPosition];
  [[NSNotificationCenter defaultCenter] postNotificationName:OOOoyalaPlayerViewControllerInlineViewVisible object:self];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
  [self updateClosedCaptionsPosition];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
  [self.delegate didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

- (void)updateBottomHeight {
  if (self.player == nil) {
    LOG(@"updateBottomHeight while player is nil");
    return;
  }
  if (!self.controls.hidden) {
		// Check if the bottom bar will overlap with closed captions
  	CGRect videoRect = [self.player videoRect];
    if (self.controls.navigationBar.frame.origin.y < videoRect.origin.y + videoRect.size.height) {
      bottomBarHeight = self.controls.navigationBar.frame.size.height;
    } else {
			bottomBarHeight = 0;
    }
  } else {
  	bottomBarHeight = 0;
  }
}

- (BOOL)showingAdsWithHiddenControls {
  return (self.player.isShowingAd && !self.player.options.showAdsControls);
}

- (void)updateClosedCaptionsPosition {
  if (self.player == nil) {
    LOG(@"updateClosedCaptionsPosition while player is nil");
    return;
  }
  if ([self.delegate isKindOfClass:[OOOoyalaPlayerViewController class]]) {
    OOOoyalaPlayerViewController *controller = self.delegate;
    [controller updateClosedCaptionsViewPosition:self.controls.navigationBar.frame withControlsHide:self.controls.hidden];
  }
}

- (void)dealloc {
  LOG(@"OOInlineIOS7ViewController  dealloc");
  [self invalidateHideControlsTimer];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end