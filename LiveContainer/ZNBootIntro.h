// One intro per cold guest process. No shader recompilation, no frame blocking.
// Native progress is read from the guest's existing UIKit progress panel.
#pragma once
@interface ZNBootIntroView : UIView
@property(nonatomic,strong) AVPlayer *player;
@property(nonatomic,strong) AVPlayerLayer *movie;
@property(nonatomic,strong) UIImageView *poster;
@property(nonatomic,strong) UILabel *fallbackLogo;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UILabel *count;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic) CFTimeInterval began;
@property(nonatomic) CFTimeInterval lastLoading;
@property(nonatomic) BOOL frozen;
@end

// NxNative's front_progress() creates a UIProgressView alongside the title
// and count, and removes the whole panel on its null-title completion event.
// Read only a real, visible progress control; never infer from GPU activity.
static BOOL ZNBootLoadingText(UIView *node, NSString **title, NSString **detail, NSUInteger depth) {
    if (!node || depth>16 || node.hidden || node.alpha<.01 ||
        [node isKindOfClass:ZNBootIntroView.class]) return NO;
    UIProgressView *bar=nil;
    NSMutableArray<UILabel *> *labels=[NSMutableArray new];
    for (UIView *child in node.subviews) {
        if (child.hidden || child.alpha<.01) continue;
        if ([child isKindOfClass:UIProgressView.class]) bar=(UIProgressView *)child;
        if ([child isKindOfClass:UILabel.class]) [labels addObject:(UILabel *)child];
    }
    if (bar) {
        for (UILabel *label in labels) {
            NSString *raw=label.text ?: @"";
            NSString *lower=raw.lowercaseString;
            if ([lower containsString:@"shader"] || [lower containsString:@"pipeline"] ||
                [lower containsString:@"pso"]) {
                *title=([lower containsString:@"pipeline"]||[lower containsString:@"pso"])?
                    @"Loading Pipelines…":@"Loading Shaders…";
                for (UILabel *other in labels) {
                    if (other!=label && other.text.length && [other.text rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet].location!=NSNotFound) {
                        *detail=other.text;
                        break;
                    }
                }
                return YES;
            }
        }
    }
    for (UIView *child in node.subviews)
        if (ZNBootLoadingText(child,title,detail,depth+1)) return YES;
    return NO;
}

static NSURL *ZNBootAsset(NSString *name, NSString *ext) {
    NSBundle *host=NSUserDefaults.lcMainBundle;
    NSURL *url=[host URLForResource:name withExtension:ext];
    if (url) return url;
    // LiveProcess may use its .appex as lcMainBundle; resources live in
    // the containing host app, not the loaded guest's overwritten main bundle.
    NSURL *root=host.bundleURL;
    for (NSUInteger i=0;root && i<4;i++,root=[root URLByDeletingLastPathComponent]) {
        if (![root.pathExtension isEqualToString:@"app"]) continue;
        NSURL *candidate=[root URLByAppendingPathComponent:[name stringByAppendingPathExtension:ext]];
        if ([NSFileManager.defaultManager fileExistsAtPath:candidate.path]) return candidate;
    }
    return nil;
}
@implementation ZNBootIntroView
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self=[super initWithFrame:frame])) return nil;
    self.backgroundColor=UIColor.blackColor;
    self.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    self.layer.zPosition=20000;
    self.accessibilityViewIsModal=YES;
    self.began=CACurrentMediaTime();
    NSURL *url=ZNBootAsset(@"ZN_Library_Boot_Intro_Elegant",@"mp4");
    NSString *posterPath=ZNBootAsset(@"ZN_Boot_Intro_Elegant_Preview",@"png").path;
    UIImage *still=posterPath.length?[UIImage imageWithContentsOfFile:posterPath]:nil;
    self.poster=[[UIImageView alloc] initWithImage:still];
    self.poster.contentMode=UIViewContentModeScaleAspectFit;
    [self addSubview:self.poster];
    self.fallbackLogo=[UILabel new]; self.fallbackLogo.numberOfLines=2;
    self.fallbackLogo.textAlignment=NSTextAlignmentCenter;
    self.fallbackLogo.textColor=[UIColor colorWithRed:1 green:.047 blue:.098 alpha:1];
    self.fallbackLogo.text=@"Zn’s\nL I B R A R Y";
    self.fallbackLogo.font=[UIFont systemFontOfSize:34 weight:UIFontWeightHeavy];
    self.fallbackLogo.hidden=still!=nil;
    [self addSubview:self.fallbackLogo];
    if (url) {
        self.player=[AVPlayer playerWithURL:url];
        self.player.actionAtItemEnd=AVPlayerActionAtItemEndPause;
        self.player.volume=.8;
        self.movie=[AVPlayerLayer playerLayerWithPlayer:self.player];
        self.movie.videoGravity=AVLayerVideoGravityResizeAspect;
        self.movie.backgroundColor=UIColor.blackColor.CGColor;
        self.poster.hidden=YES; self.fallbackLogo.hidden=YES;
        [self.layer addSublayer:self.movie];
        [self.player play];
    } else {
        UIView *logo=still?self.poster:self.fallbackLogo;
        logo.alpha=0;
        [UIView animateWithDuration:2.3 animations:^{logo.alpha=1;}];
    }
    self.status=[UILabel new]; self.status.textAlignment=NSTextAlignmentCenter;
    self.status.textColor=UIColor.whiteColor;
    self.status.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.status.adjustsFontSizeToFitWidth=YES; self.status.minimumScaleFactor=.75;
    [self addSubview:self.status];
    self.count=[UILabel new]; self.count.textAlignment=NSTextAlignmentCenter;
    self.count.textColor=[UIColor colorWithWhite:.65 alpha:1];
    self.count.font=[UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular];
    [self addSubview:self.count];
    __weak typeof(self) weakSelf=self;
    self.timer=[NSTimer scheduledTimerWithTimeInterval:.15 repeats:YES block:^(NSTimer *timer){
        ZNBootIntroView *strong=weakSelf;
        if (!strong) { [timer invalidate]; return; }
        [strong sampleLoading];
    }];
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect safe=UIEdgeInsetsInsetRect(self.bounds,self.safeAreaInsets);
    CGFloat width=MIN(safe.size.width*.96,safe.size.height*.76*16.0/9.0);
    CGFloat height=width*9.0/16.0;
    CGRect image=CGRectMake(CGRectGetMidX(safe)-width*.5,CGRectGetMidY(safe)-height*.5-20,width,height);
    self.poster.frame=image; self.fallbackLogo.frame=image;
    [CATransaction begin]; [CATransaction setDisableActions:YES]; self.movie.frame=image; [CATransaction commit];
    self.status.frame=CGRectMake(CGRectGetMinX(safe)+8,CGRectGetMaxY(image)-5,safe.size.width-16,24);
    self.count.frame=CGRectMake(CGRectGetMinX(safe)+8,CGRectGetMaxY(image)+19,safe.size.width-16,20);
}
- (void)freezeLogo {
    if (self.frozen) return;
    self.frozen=YES;
    [self.player pause]; [self.movie removeFromSuperlayer];
    self.movie=nil; self.player=nil;
    self.poster.hidden=self.poster.image==nil; self.fallbackLogo.hidden=self.poster.image!=nil;
    self.poster.alpha=1; self.fallbackLogo.alpha=1;
}
- (void)finish {
    [self.timer invalidate]; self.timer=nil;
    [self freezeLogo];
    self.userInteractionEnabled=NO;
    [UIView animateWithDuration:.2 animations:^{ self.alpha=0; } completion:^(__unused BOOL done){
        [self removeFromSuperview];
    }];
}
- (void)sampleLoading {
    if (!self.window || UIApplication.sharedApplication.applicationState==UIApplicationStateBackground) {
        [self finish]; return;
    }
    UIViewController *root=self.window.rootViewController;
    if ([root.presentedViewController isKindOfClass:UIAlertController.class]) {
        [self finish]; return; // do not cover game errors or permission alerts
    }
    NSString *title=nil,*detail=nil;
    BOOL loading=ZNBootLoadingText(root.view,&title,&detail,0);
    CFTimeInterval now=CACurrentMediaTime();
    if (loading) self.lastLoading=now;
    self.status.text=loading?title:nil; self.count.text=loading?detail:nil;
    if (now-self.began<5.0) return;
    // A slow AVPlayer start can lag behind the wall clock. Let the short
    // clip finish naturally, but never block forever on a broken resource.
    if (self.player && now-self.began<8.0 &&
        self.player.currentItem.status!=AVPlayerItemStatusFailed &&
        CMTimeGetSeconds(self.player.currentTime)<4.95) return;
    [self freezeLogo]; // never loop or replay sound while loading
    if (loading || (self.lastLoading>0 && now-self.lastLoading<.65)) return;
    [self finish];
}
- (void)dealloc { [_timer invalidate]; [_player pause]; }
@end

static BOOL ZNBootIntroShown;
static __weak UIWindow *ZNBootCandidate;
static NSTimer *ZNBootWaitTimer;
static BOOL ZNBootGuestEligible(NSString *group, NSString *key) {
    NSString *identifier=NSUserDefaults.lcGuestAppId.lowercaseString ?: @"";
    if ([identifier hasPrefix:@"org.nxnative"]) return YES;
    if (!key.length || [key hasPrefix:@"builtin:"]) return NO;
    NSUserDefaults *prefs=[[NSUserDefaults alloc] initWithSuiteName:group];
    return [[prefs stringArrayForKey:@"ZNBootIntroEligibleKeys"] containsObject:key];
}
static void ZNBootTryStart(UIWindow *window, NSString *group, NSString *key) {
    if (ZNBootIntroShown || !window || window.hidden || !ZNBootGuestEligible(group,key)) return;
    UIViewController *root=window.rootViewController;
    BOOL nx=[NSUserDefaults.lcGuestAppId.lowercaseString hasPrefix:@"org.nxnative"];
    // NxNative's optional launcher can appear before Play. Leave it usable;
    // show the intro once the actual DmGameView has been created.
    if (!root.isViewLoaded || CGRectIsEmpty(root.view.bounds) ||
        (nx && !StrataNxChildOfClass(root.view,@"DmGameView"))) return;
    if ([root.presentedViewController isKindOfClass:UIAlertController.class]) return;
    ZNBootIntroShown=YES;
    [ZNBootWaitTimer invalidate]; ZNBootWaitTimer=nil;
    ZNBootIntroView *intro=[[ZNBootIntroView alloc] initWithFrame:root.view.bounds];
    [root.view addSubview:intro];
}
static void ZNBootInstall(UIWindow *window, NSString *group, NSString *key) {
    if (ZNBootIntroShown || !ZNBootGuestEligible(group,key)) return;
    ZNBootTryStart(window,group,key);
    if (ZNBootIntroShown || ZNBootCandidate==window) return;
    [ZNBootWaitTimer invalidate]; ZNBootCandidate=window;
    __weak UIWindow *weakWindow=window;
    ZNBootWaitTimer=[NSTimer scheduledTimerWithTimeInterval:.2 repeats:YES block:^(NSTimer *timer){
        UIWindow *candidate=weakWindow;
        if (!candidate || candidate.hidden || ZNBootIntroShown) {
            [timer invalidate]; if (ZNBootWaitTimer==timer) ZNBootWaitTimer=nil; return;
        }
        if (UIApplication.sharedApplication.applicationState!=UIApplicationStateBackground)
            ZNBootTryStart(candidate,group,key);
    }];
}
