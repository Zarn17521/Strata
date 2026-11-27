// Included by StrataGuestControls.m after the skin/menu geometry helpers.
// A separate UIKit view using an optional presented-frame observer.
#include "ZNPresentedFrameMeter.h"
@interface ZNCompactHUDButton : UIButton
@property(nonatomic, weak) UIViewController *gameRoot;
@property(nonatomic, weak) UILabel *nativeFPS;
@property(nonatomic, strong) NSTimer *sampleTimer;
@property(nonatomic, copy) NSString *detailText;
@property(nonatomic, copy) NSString *compactText;
@property(nonatomic) BOOL reducedWidth;
@property(nonatomic) BOOL gaugeOnly;
@property(nonatomic) BOOL hasNativeFPS;
@property(nonatomic, weak) CAMetalLayer *measuredLayer;
@property(nonatomic, strong) ZNPresentedFrameMeter *frameMeter;
@property(nonatomic, strong) NSNumber *measuredFPS;
@property(nonatomic) BOOL standalone;
- (void)znStopMeasuring;
@property(nonatomic, strong) NSNumber *savedNativeFPSAlpha;
- (void)znSample;
- (void)znRestoreNativeFPS;
- (void)znSyncNativeFPSVisibility;
- (void)znBindNativeFPS:(UILabel *)label;
@end

@implementation ZNCompactHUDButton
- (void)znStopMeasuring {
    [self.frameMeter stop];
    CAMetalLayer *layer=self.measuredLayer;
    if (layer && objc_getAssociatedObject(layer,&ZNMetalFrameMeterKey)==self.frameMeter)
        objc_setAssociatedObject(layer,&ZNMetalFrameMeterKey,nil,OBJC_ASSOCIATION_RETAIN);
    self.measuredLayer=nil; self.frameMeter=nil; self.measuredFPS=nil;
}
- (void)znMeasure {
    CAMetalLayer *layer=ZNMetalSurfaceForRoot(self.gameRoot);
    if (layer!=self.measuredLayer || (layer && !self.frameMeter)) {
        [self znStopMeasuring];
        if (layer) {
            ZNInstallPresentedFrameObserver();
            self.measuredLayer=layer; self.frameMeter=[ZNPresentedFrameMeter new];
            objc_setAssociatedObject(layer,&ZNMetalFrameMeterKey,self.frameMeter,OBJC_ASSOCIATION_RETAIN);
        }
    }
    NSNumber *value=[self.frameMeter sample];
    if (value) self.measuredFPS=value;
    else self.measuredFPS=nil;
}
// Do not set hidden or disable the native counter: NxNative may use that
// state to decide whether to update its FPS reading. Only hide its visuals
// while a valid reading is actually shown by the inline ZN HUD.
- (void)znRestoreNativeFPS {
    if (self.savedNativeFPSAlpha) {
        self.nativeFPS.alpha=self.savedNativeFPSAlpha.doubleValue;
        self.savedNativeFPSAlpha=nil;
    }
}
- (void)znSyncNativeFPSVisibility {
    UILabel *label=self.nativeFPS;
    if (!label || !self.window || self.hidden || self.gaugeOnly || !self.hasNativeFPS || label.hidden) {
        [self znRestoreNativeFPS];
        return;
    }
    if (!self.savedNativeFPSAlpha) self.savedNativeFPSAlpha=@(label.alpha);
    if (label.alpha!=0) label.alpha=0;
}
- (void)znBindNativeFPS:(UILabel *)label {
    if (self.nativeFPS==label) return;
    [self znRestoreNativeFPS];
    self.nativeFPS=label;
    self.hasNativeFPS=NO;
}
- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self.sampleTimer invalidate]; self.sampleTimer=nil;
    if (!self.window) { [self znRestoreNativeFPS]; [self znStopMeasuring]; return; }
    __weak ZNCompactHUDButton *weakSelf=self;
    NSTimer *timer=[NSTimer timerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
        ZNCompactHUDButton *button=weakSelf;
        if (!button) { [t invalidate]; return; }
        if (!button.hidden && button.window && UIApplication.sharedApplication.applicationState==UIApplicationStateActive) [button znSample];
        else { [button znStopMeasuring]; [button znRestoreNativeFPS]; }
    }];
    self.sampleTimer=timer;
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    [self znSample];
}
- (void)dealloc { [_sampleTimer invalidate]; [_frameMeter stop]; if (_savedNativeFPSAlpha) _nativeFPS.alpha=_savedNativeFPSAlpha.doubleValue; }
- (void)znSample {
    task_vm_info_data_t vm={0};
    mach_msg_type_number_t count=TASK_VM_INFO_COUNT;
    BOOL ok=task_info(mach_task_self(),TASK_VM_INFO,(task_info_t)&vm,&count)==KERN_SUCCESS;
    uint64_t headroom=os_proc_available_memory();
    NSString *ram=ok?[NSString stringWithFormat:@"%.1f GiB",vm.phys_footprint/1073741824.0]:@"—";
    NSString *available=[NSString stringWithFormat:@"%.0f MiB",headroom/1048576.0];
    NSString *fps=@"—";
    UILabel *native=self.nativeFPS;
    NSString *raw=native.hidden?nil:native.text;
    self.hasNativeFPS=NO;
    if (raw.length) {
        // Reuse only the game's actual reading; never infer FPS from refresh rate.
        NSScanner *scanner=[NSScanner scannerWithString:raw];
        [scanner scanUpToCharactersFromSet:NSCharacterSet.decimalDigitCharacterSet intoString:NULL];
        double number=0;
        if ([scanner scanDouble:&number] && isfinite(number) && number>=0 && number<=1000) {
            fps=[NSString stringWithFormat:@"%.0f",number];
            self.hasNativeFPS=YES;
        }
    }
    if (self.window) [self znMeasure];
    NSString *source=self.hasNativeFPS?@"Native counter":@"Unavailable";
    if (self.measuredFPS) {
        fps=[NSString stringWithFormat:@"%.0f",self.measuredFPS.doubleValue];
        source=@"Metal presented frames";
    }
    NSString *thermal=@"Unknown";
    switch (NSProcessInfo.processInfo.thermalState) {
        case NSProcessInfoThermalStateNominal: thermal=@"Nominal"; break;
        case NSProcessInfoThermalStateFair: thermal=@"Fair"; break;
        case NSProcessInfoThermalStateSerious: thermal=@"Serious"; break;
        case NSProcessInfoThermalStateCritical: thermal=@"Critical"; break;
        default: break;
    }
    self.detailText=[NSString stringWithFormat:@"FPS: %@\nFPS source: %@\nProcess RAM: %@\nAvailable process memory: %@\nThermal state: %@\n\nMetal FPS counts presented frames, not necessarily internal emulation frames. Unsupported surfaces show —. Memory is process allocation headroom, not total device free RAM.",fps,source,ram,available,thermal];
    NSString *availableCompact=[NSString stringWithFormat:@"%.2f GiB",headroom/1073741824.0];
    self.compactText=[NSString stringWithFormat:@"%@ FPS · %@ Avail",fps,availableCompact];
    NSString *label=self.gaugeOnly?nil:self.compactText;
    if (!self.gaugeOnly && ![self.currentTitle isEqualToString:label]) [self setTitle:label forState:UIControlStateNormal];
    self.accessibilityValue=self.compactText;
    [self znSyncNativeFPSVisibility];
}
- (void)znShowDetails {
    UIViewController *root=self.gameRoot;
    if (!root || !root.view.window || root.presentedViewController) return;
    [self znSample];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"ZN Performance HUD" message:self.detailText preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
    [root presentViewController:alert animated:YES completion:nil];
}
@end

// A menu fallback is also available when there is no safe touch target.
static void ZNSetHUDMenuFallback(StrataNxSkinView *skin, ZNCompactHUDButton *hud, BOOL enabled) {
    UIButton *gear=[skin.znGearControl isKindOfClass:UIButton.class]?(UIButton *)skin.znGearControl:nil;
    UIMenu *menu=gear.menu;
    if (!menu) return;
    NSString *identifier=@"zn.compact.performance.details";
    NSMutableArray<UIMenuElement *> *items=[NSMutableArray array];
    BOOL found=NO;
    for (UIMenuElement *item in menu.children) {
        if ([item isKindOfClass:UIAction.class] && [((UIAction *)item).identifier isEqualToString:identifier]) { found=YES; continue; }
        [items addObject:item];
    }
    if (!enabled && !found) return;
    if (enabled) {
        UIAction *action=[UIAction actionWithTitle:@"ZN Performance HUD" image:[UIImage systemImageNamed:@"gauge.with.dots.needle.67percent"] identifier:identifier handler:^(__unused UIAction *a) {
            [hud znShowDetails];
        }];
        [items addObject:action];
    }
    gear.menu=[menu menuByReplacingChildren:items];
}
static BOOL ZNHUDFrameFits(CGRect candidate, CGRect safe, CGRect picture, StrataNxSkinView *skin, CGRect gearFrame) {
    if (candidate.size.width<28 || candidate.size.height<12 || !CGRectContainsRect(safe,candidate) ||
        CGRectIntersectsRect(candidate,picture) || (!CGRectIsNull(gearFrame) && CGRectIntersectsRect(candidate,gearFrame))) return NO;
    for (CALayer *sprite in skin.znSprites.allValues) {
        if (!sprite.hidden && CGRectIntersectsRect(CGRectInset(sprite.frame,-3,-3),candidate)) return NO;
    }
    return YES;
}
static void ZNLayoutCompactPerformanceHUD(UIViewController *root, StrataNxSkinView *skin, UIImage *image, CGRect picture) {
    UIView *host=root.view;
    if (!skin || ![skin isKindOfClass:StrataNxSkinView.class]) { [[host viewWithTag:877146] removeFromSuperview]; return; }
    const NSInteger tag=877146;
    ZNCompactHUDButton *hud=(ZNCompactHUDButton *)[host viewWithTag:tag];
    NSUserDefaults *prefs=[[NSUserDefaults alloc] initWithSuiteName:skin.sharedGroup];
    BOOL enabled=[prefs objectForKey:@"ZNCompactPerformanceHUD"]?[prefs boolForKey:@"ZNCompactPerformanceHUD"]:YES;
    if (!enabled || CGRectIsEmpty(picture)) { ZNSetHUDMenuFallback(skin,nil,NO); [hud removeFromSuperview]; return; }
    [[host viewWithTag:877147] removeFromSuperview];
    if (!hud) {
        hud=[ZNCompactHUDButton buttonWithType:UIButtonTypeCustom];
        hud.tag=tag; hud.gameRoot=root;
        hud.backgroundColor=[UIColor colorWithWhite:.055 alpha:.92];
        hud.layer.cornerRadius=5; hud.layer.borderWidth=.5;
        hud.layer.borderColor=[UIColor colorWithWhite:.55 alpha:.8].CGColor;
        hud.layer.zPosition=skin.mappedPad.layer.zPosition+3;
        hud.tintColor=UIColor.whiteColor;
        [hud setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        hud.titleLabel.font=[UIFont monospacedDigitSystemFontOfSize:9 weight:UIFontWeightSemibold];
        hud.titleLabel.adjustsFontSizeToFitWidth=YES; hud.titleLabel.minimumScaleFactor=.7;
        hud.accessibilityLabel=@"ZN performance HUD";
        hud.accessibilityHint=@"Shows current game FPS, memory and thermal state";
        [hud addTarget:hud action:@selector(znShowDetails) forControlEvents:UIControlEventTouchUpInside];
    }
    @try {
        id native=[root valueForKey:@"fps"];
        [hud znBindNativeFPS:[native isKindOfClass:UILabel.class]?native:nil];
    } @catch (__unused NSException *e) { [hud znBindNativeFPS:nil]; }
    // Full screen keeps a small live readout inside the upper safe corner.
    if (!image || skin.fullScreenMode) {
        CGRect safe=UIEdgeInsetsInsetRect(host.bounds,host.safeAreaInsets);
        hud.gaugeOnly=NO;
        hud.frame=CGRectMake(CGRectGetMinX(safe)+5,CGRectGetMinY(safe)+5,MIN(155,safe.size.width-10),22);
        [hud setImage:nil forState:UIControlStateNormal];
        [hud setTitle:hud.compactText ?: @"— FPS · — Avail" forState:UIControlStateNormal];
        if (!hud.superview) [host addSubview:hud];
        ZNSetHUDMenuFallback(skin,hud,YES); [hud znSyncNativeFPSVisibility]; return;
    }
    BOOL land=host.bounds.size.width>host.bounds.size.height;
    CGRect footer=StrataNxControlFrame(skin.bounds,image,StrataNxIsWideSkin(skin),.5);
    CGPoint minus=StrataNxPressCentre(CGPointZero,StrataArtMinus,land);
    CGPoint gear=StrataArtGearCentre(land);
    CGFloat left=CGRectGetMinX(picture)+3;
    CGFloat right=CGRectGetMinX(footer)+minus.x*footer.size.width;
    CALayer *minusSprite=skin.znSprites[[NSString stringWithFormat:@"role%ld",(long)StrataArtMinus]];
    if (minusSprite && !minusSprite.hidden) right=MIN(right,CGRectGetMinX(minusSprite.frame));
    CGRect gearFrame=CGRectNull;
    if (skin.znGearControl.superview) gearFrame=CGRectInset([host convertRect:skin.znGearControl.bounds fromView:skin.znGearControl],-2,-2);
    if (skin.znControlsHidden && !CGRectIsNull(gearFrame)) right=CGRectGetMinX(gearFrame);
    right-=4;
    CGFloat y=footer.origin.y+gear.y*footer.size.height;
    CGRect safe=CGRectInset(UIEdgeInsetsInsetRect(host.bounds,host.safeAreaInsets),2,2);
    CGFloat height=MIN(24,CGRectGetMaxY(safe)-CGRectGetMaxY(picture)-2);
    // Prefer a left-aligned readout on the actual unused black screen band.
    // The transparent background makes this look like part of the display.
    BOOL inBar=NO;
    CGRect band=ZNPerformanceBlackBar(skin.bounds,image,StrataNxIsWideSkin(skin));
    CGRect candidate=CGRectNull;
    BOOL fits=NO;
    if (!CGRectIsNull(band)&&!CGRectIsEmpty(band)) {
        CGRect hostBand=[host convertRect:band fromView:skin];
        CGRect usable=CGRectIntersection(CGRectInset(hostBand,3,1),safe);
        if (!CGRectIsNull(usable)&&usable.size.width>=116&&usable.size.height>=12) {
            CGFloat hh=MIN(22,usable.size.height);
            candidate=CGRectMake(CGRectGetMinX(usable),CGRectGetMidY(usable)-hh*.5,MIN(155,usable.size.width),hh);
            fits=ZNHUDFrameFits(candidate,safe,picture,skin,gearFrame);
            inBar=fits;
        }
    }
    if (!fits) {
        candidate=CGRectMake(left,MAX(CGRectGetMaxY(picture)+2,y-height*.5),MIN(155,right-left),height);
        fits=candidate.size.height>=20&&ZNHUDFrameFits(candidate,safe,picture,skin,gearFrame);
    }
    BOOL gauge=!fits || candidate.size.width<100;
    if (gauge) {
        inBar=NO;
        // Try compact gauge next to minus/gear, then scan the footer only.
        CGFloat gy=MAX(CGRectGetMaxY(picture)+2,y-14);
        CGRect options[]={CGRectMake(right-30,gy,30,28),CGRectMake(left,gy,30,28),CGRectMake(CGRectGetMaxX(picture)-33,gy,30,28)};
        fits=NO;
        for (NSUInteger i=0;i<sizeof(options)/sizeof(options[0]);i++) {
            if (ZNHUDFrameFits(options[i],safe,picture,skin,gearFrame)) {candidate=options[i];fits=YES;break;}
        }
        if (!fits) for (CGFloat x=left;x+30<=CGRectGetMaxX(picture);x+=8) {
            CGRect trial=CGRectMake(x,gy,30,28);
            if (ZNHUDFrameFits(trial,safe,picture,skin,gearFrame)) {candidate=trial;fits=YES;break;}
        }
    }
    if (gauge || !fits) {
        // If the shell has no room for text, use a small safe-corner readout
        // rather than replacing FPS with an icon that shows no live numbers.
        candidate=CGRectMake(CGRectGetMinX(safe)+3,CGRectGetMinY(safe)+3,MIN(155,safe.size.width-6),22);
        gauge=NO; inBar=NO;
    }
    ZNSetHUDMenuFallback(skin,nil,NO);
    hud.gaugeOnly=gauge;
    hud.backgroundColor=inBar?UIColor.clearColor:[UIColor colorWithWhite:.055 alpha:.92];
    hud.layer.borderWidth=inBar?0:.5;
    hud.titleLabel.font=[UIFont monospacedDigitSystemFontOfSize:inBar?10:9 weight:UIFontWeightSemibold];
    hud.contentHorizontalAlignment=inBar?UIControlContentHorizontalAlignmentLeft:UIControlContentHorizontalAlignmentCenter;
    [hud setImage:gauge?[UIImage systemImageNamed:@"gauge.with.dots.needle.67percent"]:nil forState:UIControlStateNormal];
    [hud setTitle:gauge?nil:(hud.compactText ?: @"— FPS · — Avail") forState:UIControlStateNormal];
    hud.frame=candidate;
    if (!hud.superview) [host addSubview:hud];
    [hud znSyncNativeFPSVisibility];
}

// Non-NxNative Metal guests (and NxNative with skins disabled) share the same
// meter. No universal guess for OpenGL/software-rendered emulators.
static void ZNInstallStandaloneHUD(UIWindow *window, NSString *group) {
    UIViewController *root=window.rootViewController;
    if (!root.isViewLoaded || window.hidden) return;
    UIView *host=root.view;
    NSUserDefaults *prefs=[[NSUserDefaults alloc] initWithSuiteName:group];
    BOOL enabled=[prefs objectForKey:@"ZNCompactPerformanceHUD"]?[prefs boolForKey:@"ZNCompactPerformanceHUD"]:YES;
    ZNCompactHUDButton *hud=(ZNCompactHUDButton *)[host viewWithTag:877147];
    if (!enabled) { [hud removeFromSuperview]; return; }
    BOOL nx=[NSUserDefaults.lcGuestAppId.lowercaseString hasPrefix:@"org.nxnative"];
    if (nx && StrataNxSkinIsEnabled(group)) { [hud removeFromSuperview]; return; }
    if (hud || CGRectIsEmpty(host.bounds)) return;
    hud=[ZNCompactHUDButton buttonWithType:UIButtonTypeCustom];
    hud.tag=877147; hud.gameRoot=root; hud.standalone=YES;
    hud.backgroundColor=[UIColor colorWithWhite:0 alpha:.8]; hud.layer.cornerRadius=5;
    hud.layer.zPosition=10000;
    hud.titleLabel.font=[UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightSemibold];
    hud.titleLabel.adjustsFontSizeToFitWidth=YES; hud.titleLabel.minimumScaleFactor=.7;
    [hud setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [hud setTitle:@"— FPS · — Avail" forState:UIControlStateNormal];
    hud.accessibilityLabel=@"ZN HUD";
    [hud addTarget:hud action:@selector(znShowDetails) forControlEvents:UIControlEventTouchUpInside];
    hud.translatesAutoresizingMaskIntoConstraints=NO;
    [host addSubview:hud];
    [NSLayoutConstraint activateConstraints:@[
        [hud.leadingAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.leadingAnchor constant:5],
        [hud.topAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.topAnchor constant:5],
        [hud.widthAnchor constraintEqualToConstant:155],
        [hud.heightAnchor constraintEqualToConstant:23]
    ]];
}
