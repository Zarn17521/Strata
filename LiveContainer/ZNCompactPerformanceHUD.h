// Included by StrataGuestControls.m after the skin/menu geometry helpers.
// A separate UIKit view; no Metal interception, frame capture or render timer.
@interface ZNCompactHUDButton : UIButton
@property(nonatomic, weak) UIViewController *gameRoot;
@property(nonatomic, weak) UILabel *nativeFPS;
@property(nonatomic, strong) NSTimer *sampleTimer;
@property(nonatomic, copy) NSString *detailText;
@property(nonatomic, copy) NSString *compactText;
@property(nonatomic) BOOL reducedWidth;
- (void)znSample;
@end

@implementation ZNCompactHUDButton
- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self.sampleTimer invalidate]; self.sampleTimer=nil;
    if (!self.window) return;
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
- (void)dealloc { [_sampleTimer invalidate]; }
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
    if (raw.length) {
        // Reuse only the game's actual reading; never infer FPS from refresh rate.
        NSScanner *scanner=[NSScanner scannerWithString:raw];
        [scanner scanUpToCharactersFromSet:NSCharacterSet.decimalDigitCharacterSet intoString:NULL];
        double number=0;
        if ([scanner scanDouble:&number] && isfinite(number) && number>=0 && number<=1000)
            fps=[NSString stringWithFormat:@"%.0f",number];
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
    NSString *label=self.reducedWidth?@"HUD":self.compactText;
    if (![self.currentTitle isEqualToString:label]) [self setTitle:label forState:UIControlStateNormal];
    self.accessibilityValue=self.compactText;
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

static void ZNLayoutCompactPerformanceHUD(UIViewController *root, StrataNxSkinView *skin, UIImage *image, CGRect picture) {
    UIView *host=root.view;
    const NSInteger tag=877146;
    ZNCompactHUDButton *hud=(ZNCompactHUDButton *)[host viewWithTag:tag];
    NSUserDefaults *prefs=[[NSUserDefaults alloc] initWithSuiteName:skin.sharedGroup];
    BOOL enabled=[prefs objectForKey:@"ZNCompactPerformanceHUD"]?[prefs boolForKey:@"ZNCompactPerformanceHUD"]:YES;
    if (!enabled || CGRectIsEmpty(picture)) { [hud removeFromSuperview]; return; }
    BOOL land=host.bounds.size.width>host.bounds.size.height;
    BOOL wide=StrataNxIsWideSkin(skin);
    CGRect footer=StrataNxControlFrame(skin.bounds,image,wide,.5);
    CGPoint minus=StrataNxPressCentre(CGPointZero,StrataArtMinus,land);
    CGPoint gear=StrataArtGearCentre(land);
    CGFloat left=CGRectGetMinX(picture)+3;
    CGFloat right=CGRectGetMinX(footer)+minus.x*footer.size.width;
    CALayer *minusSprite=skin.znSprites[[NSString stringWithFormat:@"role%ld",(long)StrataArtMinus]];
    if (minusSprite) right=MIN(right,CGRectGetMinX(minusSprite.frame));
    right-=4;
    CGFloat y=footer.origin.y+gear.y*footer.size.height;
    CGFloat height=MIN(24,CGRectGetHeight(host.bounds)-CGRectGetMaxY(picture)-4);
    // In portrait the full-width display is followed by the controls.
    // Prefer its lower-left margin before shoulders if the footer is too narrow.
    CGRect candidate=CGRectMake(left,MAX(CGRectGetMaxY(picture)+2,y-height*.5),MIN(108,right-left),height);
    if (!land && (candidate.size.width<44 || CGRectGetMaxY(candidate)>CGRectGetMaxY(host.bounds)-2)) {
        CGFloat shoulderY=StrataNxArtworkFrame(skin.bounds,image).origin.y+.504*StrataNxArtworkFrame(skin.bounds,image).size.height;
        candidate=CGRectMake(left,CGRectGetMaxY(picture)+3,MIN(108,CGRectGetWidth(picture)-6),MIN(24,shoulderY-CGRectGetMaxY(picture)-24));
    }
    // Never cover the game, buttons, or gear to force a footer onto a tight layout.
    CGRect safe=CGRectInset(host.bounds,2,2);
    if (candidate.size.width<44 || candidate.size.height<16 || !CGRectContainsRect(safe,candidate) || CGRectIntersectsRect(candidate,picture)) {
        [hud removeFromSuperview]; return;
    }
    for (CALayer *sprite in skin.znSprites.allValues) {
        if (CGRectIntersectsRect(CGRectInset(sprite.frame,-3,-3),candidate)) { [hud removeFromSuperview]; return; }
    }
    if (!hud) {
        hud=[ZNCompactHUDButton buttonWithType:UIButtonTypeCustom];
        hud.tag=tag; hud.gameRoot=root;
        hud.backgroundColor=[UIColor colorWithWhite:.055 alpha:.92];
        hud.layer.cornerRadius=5; hud.layer.borderWidth=.5;
        hud.layer.borderColor=[UIColor colorWithWhite:.55 alpha:.8].CGColor;
        hud.layer.zPosition=skin.mappedPad.layer.zPosition+3;
        [hud setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        hud.titleLabel.font=[UIFont monospacedDigitSystemFontOfSize:9 weight:UIFontWeightSemibold];
        hud.titleLabel.adjustsFontSizeToFitWidth=YES; hud.titleLabel.minimumScaleFactor=.7;
        hud.accessibilityLabel=@"ZN performance HUD";
        hud.accessibilityHint=@"Shows current game FPS, memory and thermal state";
        [hud addTarget:hud action:@selector(znShowDetails) forControlEvents:UIControlEventTouchUpInside];
    }
    @try {
        id native=[root valueForKey:@"fps"];
        hud.nativeFPS=[native isKindOfClass:UILabel.class]?native:nil;
    } @catch (__unused NSException *e) { hud.nativeFPS=nil; }
    hud.reducedWidth=candidate.size.width<75;
    hud.frame=candidate;
    if (!hud.superview) [host addSubview:hud];
    if (hud.compactText) {
        NSString *label=hud.reducedWidth?@"HUD":hud.compactText;
        if (![hud.currentTitle isEqualToString:label]) [hud setTitle:label forState:UIControlStateNormal];
    }
}
