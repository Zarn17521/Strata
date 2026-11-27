// Included by StrataGuestControls.m after the skin/menu geometry helpers.
// A separate UIKit view; no Metal interception, frame capture or render timer.
@interface ZNCompactHUDButton : UIButton
@property(nonatomic, weak) UIViewController *gameRoot;
@property(nonatomic, weak) UILabel *nativeFPS;
@property(nonatomic, strong) NSTimer *sampleTimer;
@property(nonatomic, copy) NSString *detailText;
@property(nonatomic, copy) NSString *compactText;
@property(nonatomic) BOOL reducedWidth;
@property(nonatomic) BOOL gaugeOnly;
@property(nonatomic) BOOL hasNativeFPS;
@property(nonatomic, strong) NSNumber *savedNativeFPSAlpha;
- (void)znSample;
- (void)znRestoreNativeFPS;
- (void)znSyncNativeFPSVisibility;
- (void)znBindNativeFPS:(UILabel *)label;
@end

@implementation ZNCompactHUDButton
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
    if (!self.window) { [self znRestoreNativeFPS]; return; }
    __weak ZNCompactHUDButton *weakSelf=self;
    NSTimer *timer=[NSTimer timerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
        ZNCompactHUDButton *button=weakSelf;
        if (!button) { [t invalidate]; return; }
        if (!button.hidden && button.window && UIApplication.sharedApplication.applicationState==UIApplicationStateActive) [button znSample];
    }];
    self.sampleTimer=timer;
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    [self znSample];
}
- (void)dealloc { [_sampleTimer invalidate]; if (_savedNativeFPSAlpha) _nativeFPS.alpha=_savedNativeFPSAlpha.doubleValue; }
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
    NSString *thermal=@"Unknown";
    switch (NSProcessInfo.processInfo.thermalState) {
        case NSProcessInfoThermalStateNominal: thermal=@"Nominal"; break;
        case NSProcessInfoThermalStateFair: thermal=@"Fair"; break;
        case NSProcessInfoThermalStateSerious: thermal=@"Serious"; break;
        case NSProcessInfoThermalStateCritical: thermal=@"Critical"; break;
        default: break;
    }
    self.detailText=[NSString stringWithFormat:@"Game FPS: %@\nProcess RAM: %@\nAvailable process memory: %@\nThermal state: %@\n\nFPS requires the native FPS counter. Memory is the current process footprint and headroom, not total device free RAM.",fps,ram,available,thermal];
    self.compactText=[NSString stringWithFormat:@"%@ FPS · %@",fps,ram];
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
    if (candidate.size.width<28 || candidate.size.height<20 || !CGRectContainsRect(safe,candidate) ||
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
    // Full Screen has native controls with unknown safe areas; use its real gear menu.
    if (!image || skin.fullScreenMode) {
        [hud removeFromSuperview]; ZNSetHUDMenuFallback(skin,hud,YES); return;
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
    CGRect candidate=CGRectMake(left,MAX(CGRectGetMaxY(picture)+2,y-height*.5),MIN(108,right-left),height);
    BOOL fits=ZNHUDFrameFits(candidate,safe,picture,skin,gearFrame);
    BOOL gauge=!fits || candidate.size.width<75;
    if (gauge) {
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
    if (!fits) { [hud removeFromSuperview]; ZNSetHUDMenuFallback(skin,hud,YES); return; }
    ZNSetHUDMenuFallback(skin,nil,NO);
    hud.gaugeOnly=gauge;
    [hud setImage:gauge?[UIImage systemImageNamed:@"gauge.with.dots.needle.67percent"]:nil forState:UIControlStateNormal];
    [hud setTitle:gauge?nil:(hud.compactText ?: @"— FPS · —") forState:UIControlStateNormal];
    hud.frame=candidate;
    if (!hud.superview) [host addSubview:hud];
    [hud znSyncNativeFPSVisibility];
}
