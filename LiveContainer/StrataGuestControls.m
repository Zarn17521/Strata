#import <objc/runtime.h>
#import "StrataGuestControls.h"
#import "LCSharedUtils.h"
#import "utils.h"
#import <UIKit/UIKit.h>
#import <unistd.h>
#import <math.h>

// Optional NxNative appearance-only bezel. This is a transparent touch-through
// decoration that lives between the Metal picture and the original gamepad.
// It never resizes the picture, creates touch controls or changes guest input.

/* White plastic handheld artwork, modelled on the supplied portrait skin.
   These are cosmetic shapes only: DmGamepad remains responsible for ALL input. */
static void StrataNxDrawBevel(CGRect frame, CGFloat radius, NSString *label, CGFloat font) {
    UIBezierPath *shape = [UIBezierPath bezierPathWithRoundedRect:frame cornerRadius:radius];
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 2.3), 3, UIColor.blackColor.CGColor);
    [[UIColor colorWithWhite:0.95 alpha:1] setFill];
    [shape fill];
    CGContextRestoreGState(ctx);
    shape.lineWidth = 1.7;
    [[UIColor colorWithWhite:0.14 alpha:1] setStroke];
    [shape stroke];
    UIBezierPath *lip = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(frame, 2.5, 2.5)
                                                  cornerRadius:MAX(1, radius - 2.5)];
    lip.lineWidth = 1;
    [[UIColor colorWithWhite:1 alpha:0.9] setStroke]; [lip stroke];
    if (label.length) {
        NSDictionary *attrs = @{
            NSFontAttributeName: [UIFont systemFontOfSize:font weight:UIFontWeightMedium],
            NSForegroundColorAttributeName: [UIColor colorWithWhite:0.36 alpha:1]
        };
        CGSize text = [label sizeWithAttributes:attrs];
        CGRect pos = CGRectMake(CGRectGetMidX(frame) - text.width/2,
                                CGRectGetMidY(frame) - text.height/2,
                                text.width, text.height);
        [label drawInRect:pos withAttributes:attrs];
    }
}
static void StrataNxDrawAnalog(CGPoint c, CGFloat radius) {
    CGRect outside = CGRectMake(c.x-radius,c.y-radius,radius*2,radius*2);
    UIBezierPath *ring = [UIBezierPath bezierPathWithOvalInRect:outside];
    [[UIColor colorWithWhite:0.12 alpha:1] setFill]; [ring fill];
    UIBezierPath *inside = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(outside, 4, 4)];
    [[UIColor colorWithWhite:0.94 alpha:1] setFill]; [inside fill];
    inside.lineWidth = 2.0; [[UIColor colorWithWhite:0.58 alpha:1] setStroke]; [inside stroke];
    UIBezierPath *thumb = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(outside,radius*0.28,radius*0.28)];
    [[UIColor colorWithWhite:0.88 alpha:1] setFill]; [thumb fill];
    thumb.lineWidth = 1.0; [[UIColor colorWithWhite:0.67 alpha:1] setStroke]; [thumb stroke];
}
static void StrataNxDrawDPad(CGPoint c, CGFloat unit) {
    CGFloat a=unit*0.36, b=unit;
    UIBezierPath *p=[UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(c.x-a,c.y-b)];
    [p addLineToPoint:CGPointMake(c.x+a,c.y-b)];
    [p addLineToPoint:CGPointMake(c.x+a,c.y-a)];
    [p addLineToPoint:CGPointMake(c.x+b,c.y-a)];
    [p addLineToPoint:CGPointMake(c.x+b,c.y+a)];
    [p addLineToPoint:CGPointMake(c.x+a,c.y+a)];
    [p addLineToPoint:CGPointMake(c.x+a,c.y+b)];
    [p addLineToPoint:CGPointMake(c.x-a,c.y+b)];
    [p addLineToPoint:CGPointMake(c.x-a,c.y+a)];
    [p addLineToPoint:CGPointMake(c.x-b,c.y+a)];
    [p addLineToPoint:CGPointMake(c.x-b,c.y-a)];
    [p addLineToPoint:CGPointMake(c.x-a,c.y-a)];
    [p closePath];
    CGContextRef ctx=UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx,CGSizeMake(0,2),3,[UIColor colorWithWhite:0.1 alpha:0.5].CGColor);
    [[UIColor colorWithWhite:0.95 alpha:1] setFill]; [p fill];
    CGContextRestoreGState(ctx);
    p.lineWidth=2; [[UIColor colorWithWhite:0.13 alpha:1] setStroke]; [p stroke];
    [[UIColor colorWithWhite:0.52 alpha:1] setStroke];
    for (NSInteger i=0;i<4;i++) {
        CGFloat ang=M_PI_2*i;
        CGFloat dx=cos(ang),dy=sin(ang);
        UIBezierPath *notch=[UIBezierPath bezierPath];
        [notch moveToPoint:CGPointMake(c.x+dx*unit*0.65-dy*unit*0.11,c.y+dy*unit*0.65+dx*unit*0.11)];
        [notch addLineToPoint:CGPointMake(c.x+dx*unit*0.65+dy*unit*0.11,c.y+dy*unit*0.65-dx*unit*0.11)];
        notch.lineWidth=1.5; [notch stroke];
    }
}
static void StrataNxDrawPortraitHandheld(CGRect bounds, CGRect game) {
    // Bounds remain those of NxNative's native controller/screen layout.
    // The GameView is excluded by the caller's even/odd clipping path.
    CGFloat w=bounds.size.width, h=bounds.size.height;
    CGFloat bottom=CGRectGetMaxY(game);
    CGFloat remaining=MAX(180,h-bottom);
    CGFloat unit=w/923.0;
    // Display edge just outside the unmodified native picture viewport.
    CGRect bezel=CGRectInset(game, -MAX(2,8*unit), -MAX(2,8*unit));
    UIBezierPath *screen=[UIBezierPath bezierPathWithRoundedRect:bezel cornerRadius:13*unit];
    screen.lineWidth=MAX(2,8*unit);
    [[UIColor colorWithWhite:0.10 alpha:1] setStroke]; [screen stroke];
    UIBezierPath *rim=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(bezel,-3*unit,-3*unit)
                                                 cornerRadius:16*unit];
    rim.lineWidth=MAX(1,3*unit);
    [[UIColor colorWithWhite:1 alpha:1] setStroke]; [rim stroke];

    // Place the photographic controls in the unused portrait panel.
    // Decorative only: the real transparent DmGamepad remains ABOVE this view.
    CGFloat shouldersY=bottom+remaining*0.14;
    CGFloat shoulderH=MAX(19,42*unit);
    CGFloat gap=4*unit;
    StrataNxDrawBevel(CGRectMake(w*0.045,shouldersY,w*0.16,shoulderH),10*unit,@"L",MAX(13,18*unit));
    StrataNxDrawBevel(CGRectMake(w*0.045+w*0.16+gap,shouldersY,w*0.16,shoulderH),10*unit,@"ZL",MAX(12,15*unit));
    StrataNxDrawBevel(CGRectMake(w*0.63,shouldersY,w*0.16,shoulderH),10*unit,@"ZR",MAX(12,15*unit));
    StrataNxDrawBevel(CGRectMake(w*0.63+w*0.16+gap,shouldersY,w*0.16,shoulderH),10*unit,@"R",MAX(13,18*unit));

    // Centre speaker perforations echo the reference image.
    [[UIColor colorWithWhite:0.36 alpha:0.85] setFill];
    for (int row=0;row<3;row++) for (int col=0;col<6;col++) {
        CGFloat d=4*unit;
        CGFloat x=w*0.415+col*30*unit, y=shouldersY+shoulderH*0.29+row*12*unit;
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(x,y,d,d)] fill];
    }

    CGFloat controlsY=bottom+remaining*0.45;
    CGFloat dpadUnit=MIN(w*0.145,remaining*0.15);
    StrataNxDrawDPad(CGPointMake(w*0.25,controlsY),dpadUnit);
    CGFloat keyRadius=MIN(w*0.078,remaining*0.086);
    StrataNxDrawBevel(CGRectMake(w*0.75-keyRadius,controlsY-dpadUnit*0.94-keyRadius,
                               2*keyRadius,2*keyRadius),keyRadius,@"X",MAX(16,22*unit));
    StrataNxDrawBevel(CGRectMake(w*0.75-keyRadius*2.05-keyRadius,controlsY-keyRadius,
                               2*keyRadius,2*keyRadius),keyRadius,@"Y",MAX(16,22*unit));
    StrataNxDrawBevel(CGRectMake(w*0.75+keyRadius*2.05-keyRadius,controlsY-keyRadius,
                               2*keyRadius,2*keyRadius),keyRadius,@"A",MAX(16,22*unit));
    StrataNxDrawBevel(CGRectMake(w*0.75-keyRadius,controlsY+dpadUnit*0.94-keyRadius,
                               2*keyRadius,2*keyRadius),keyRadius,@"B",MAX(16,22*unit));
    CGFloat analogRadius=MIN(w*0.115,remaining*0.115);
    CGFloat analogY=bottom+remaining*0.79;
    StrataNxDrawAnalog(CGPointMake(w*0.25,analogY),analogRadius);
    StrataNxDrawAnalog(CGPointMake(w*0.75,analogY),analogRadius);
}

// Optional touch-coordinate bridge for the imported white-shell artwork.
// UIKit still routes the real UITouch to the game's DmGamepad (not a fake pad).
// Only the location reported TO THAT SPECIFIC pad is translated. This leaves
// the original engine's multi-touch, haptics, drag ownership and HID handling
// responsible for the actual input; no game binary or C input hooks required.
static char StrataNxPadArtTouchEnabledKey;
static char StrataNxTouchArtRoleKey;
static CGPoint (*StrataOriginalLocationInView)(id, SEL, UIView *) = NULL;

enum {
    StrataArtNoMapping = 0, StrataArtFace = 1, StrataArtDpad,
    StrataArtLeftStick, StrataArtRightStick, StrataArtL, StrataArtZL,
    StrataArtZR, StrataArtR, StrataArtMinus, StrataArtPlus
};

static BOOL StrataArtNear(CGPoint point, CGFloat x, CGFloat y, CGFloat rx, CGFloat ry) {
    CGFloat dx = (point.x - x) / rx, dy = (point.y - y) / ry;
    return dx * dx + dy * dy <= 1.0;
}

// These are the measured button centres in the user-supplied 923 x 2000 skin.
// Coordinates remain normalized so iPhone 15 resolution changes do not matter.
static NSInteger StrataNxArtRole(CGPoint p, BOOL landscape) {
    if (landscape) {
        // Normalized centres measured from the supplied 1792x1008 artwork.
        if (StrataArtNear(p, 0.121, 0.168, 0.030, 0.025)) return StrataArtL;
        if (StrataArtNear(p, 0.188, 0.168, 0.030, 0.025)) return StrataArtZL;
        if (StrataArtNear(p, 0.736, 0.168, 0.031, 0.025)) return StrataArtZR;
        if (StrataArtNear(p, 0.806, 0.168, 0.030, 0.025)) return StrataArtR;
        if (StrataArtNear(p, 0.380, 0.733, 0.024, 0.038)) return StrataArtMinus;
        if (StrataArtNear(p, 0.541, 0.733, 0.024, 0.038)) return StrataArtPlus;
        const CGFloat faceX[] = {0.815, 0.779, 0.779, 0.731};
        const CGFloat faceY[] = {0.340, 0.418, 0.255, 0.340};
        for (int i = 0; i < 4; i++)
            if (StrataArtNear(p, faceX[i], faceY[i], 0.028, 0.047)) return StrataArtFace;
        if (StrataArtNear(p, 0.148, 0.333, 0.060, 0.101)) return StrataArtDpad;
        if (StrataArtNear(p, 0.147, 0.570, 0.050, 0.079)) return StrataArtLeftStick;
        if (StrataArtNear(p, 0.776, 0.570, 0.050, 0.079)) return StrataArtRightStick;
        return StrataArtNoMapping;
    }
    if (StrataArtNear(p, 0.106, 0.451, 0.073, 0.029)) return StrataArtL;
    if (StrataArtNear(p, 0.254, 0.451, 0.078, 0.029)) return StrataArtZL;
    if (StrataArtNear(p, 0.748, 0.451, 0.078, 0.029)) return StrataArtZR;
    if (StrataArtNear(p, 0.901, 0.451, 0.073, 0.029)) return StrataArtR;
    if (StrataArtNear(p, 0.309, 0.842, 0.058, 0.033)) return StrataArtMinus;
    if (StrataArtNear(p, 0.599, 0.842, 0.058, 0.033)) return StrataArtPlus;
    if (StrataArtNear(p, 0.675, 0.524, 0.070, 0.036) ||
        StrataArtNear(p, 0.551, 0.575, 0.070, 0.036) ||
        StrataArtNear(p, 0.797, 0.575, 0.070, 0.036) ||
        StrataArtNear(p, 0.675, 0.632, 0.070, 0.036)) return StrataArtFace;
    if (StrataArtNear(p, 0.225, 0.577, 0.173, 0.096)) return StrataArtDpad;
    if (StrataArtNear(p, 0.224, 0.756, 0.147, 0.085)) return StrataArtLeftStick;
    if (StrataArtNear(p, 0.698, 0.756, 0.147, 0.085)) return StrataArtRightStick;
    return StrataArtNoMapping;
}

static CGPoint StrataArtNativePoint(id pad, SEL sel) {
    if (![pad respondsToSelector:sel]) return CGPointMake(NAN, NAN);
    CGPoint (*imp)(id, SEL) = (void *)[pad methodForSelector:sel];
    return imp(pad, sel);
}
static CGPoint StrataArtNativeButton(id pad, SEL sel, int b) {
    if (![pad respondsToSelector:sel]) return CGPointMake(NAN, NAN);
    CGPoint (*imp)(id, SEL, int) = (void *)[pad methodForSelector:sel];
    return imp(pad, sel, b);
}
static CGRect StrataArtNativePill(id pad, int b) {
    SEL sel = @selector(pillRect:);
    if (![pad respondsToSelector:sel]) return CGRectNull;
    CGRect (*imp)(id, SEL, int) = (void *)[pad methodForSelector:sel];
    return imp(pad, sel, b);
}
static CGFloat StrataArtNativeRadius(id pad, int index) {
    SEL sel = @selector(stickR:);
    if (![pad respondsToSelector:sel]) return 0;
    CGFloat (*imp)(id, SEL, int) = (void *)[pad methodForSelector:sel];
    return imp(pad, sel, index);
}

static CGRect StrataNxArtworkFrame(CGRect bounds, UIImage *image) {
    if (!image || image.size.width <= 0 || image.size.height <= 0 ||
        bounds.size.width <= 0 || bounds.size.height <= 0) return bounds;
    CGFloat scale = MIN(bounds.size.width / image.size.width,
                        bounds.size.height / image.size.height);
    CGSize fit = CGSizeMake(image.size.width*scale, image.size.height*scale);
    return CGRectMake(CGRectGetMidX(bounds)-fit.width/2,
                      CGRectGetMidY(bounds)-fit.height/2,fit.width,fit.height);
}

static CGPoint StrataNxRemappedTouchLocation(id touch, SEL command, UIView *view) {
    CGPoint original = StrataOriginalLocationInView(touch, command, view);
    // Absolutely no touch mapping outside an explicitly opted-in NxNative pad.
    if (!view || ![NSStringFromClass(view.class) isEqualToString:@"DmGamepad"] ||
        !objc_getAssociatedObject(view, &StrataNxPadArtTouchEnabledKey) ||
        view.bounds.size.width <= 0 || view.bounds.size.height <= 0)
        return original;
    BOOL landscape = view.bounds.size.width > view.bounds.size.height;
    UIView *art = [view.superview viewWithTag:877144];
    id activeImage = [art valueForKey:landscape ? @"landscapeArtwork" : @"portraitArtwork"];
    if (!activeImage) return original;
    CGRect artFrame = StrataNxArtworkFrame(view.bounds, (UIImage *)activeImage);
    CGPoint p = CGPointMake((original.x - artFrame.origin.x) / MAX(artFrame.size.width,1),
                            (original.y - artFrame.origin.y) / MAX(artFrame.size.height,1));
    NSNumber *selected = objc_getAssociatedObject(touch, &StrataNxTouchArtRoleKey);
    NSInteger role = selected ? selected.integerValue : StrataArtNoMapping;
    if (!selected) {
        if (((UITouch *)touch).phase != UITouchPhaseBegan) return original;
        role = StrataNxArtRole(p, landscape);
        objc_setAssociatedObject(touch, &StrataNxTouchArtRoleKey,
                                @(role), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (role == StrataArtNoMapping) return original;

    // Source NxNative DmGamepad.m button identifiers. These are only used
    // to ask DmGamepad for its OWN current interactive target centres.
    // A B X Y L3 R3 L R ZL ZR + -
    switch (role) {
        case StrataArtL:
        case StrataArtZL:
        case StrataArtZR:
        case StrataArtR: {
            int button = role == StrataArtL ? 6 : role == StrataArtZL ? 8 :
                         role == StrataArtZR ? 9 : 7;
            CGPoint c = StrataArtNativeButton(view, @selector(dropCenter:), button);
            return (isfinite(c.x) && isfinite(c.y)) ? c : original;
        }
        case StrataArtMinus: {
            CGRect r = StrataArtNativePill(view, 11);
            return CGRectIsNull(r) ? original : CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r));
        }
        case StrataArtPlus: {
            CGRect r = StrataArtNativePill(view, 10);
            return CGRectIsNull(r) ? original : CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r));
        }
        case StrataArtFace: {
            // Sliding between the four image buttons stays a native face drag.
            const CGFloat portraitX[] = {0.797, 0.675, 0.675, 0.551};
            const CGFloat portraitY[] = {0.575, 0.632, 0.524, 0.575};
            const CGFloat landscapeX[] = {0.815, 0.779, 0.779, 0.731};
            const CGFloat landscapeY[] = {0.340, 0.418, 0.255, 0.340};
            const CGFloat *px = landscape ? landscapeX : portraitX;
            const CGFloat *py = landscape ? landscapeY : portraitY;
            int closest = 0; CGFloat best = CGFLOAT_MAX;
            for (int i = 0; i < 4; i++) {
                CGFloat dx = (p.x - px[i]) / (landscape ? 0.029 : 0.072);
                CGFloat dy = (p.y - py[i]) / (landscape ? 0.048 : 0.038);
                CGFloat score = dx * dx + dy * dy;
                if (score < best) { best = score; closest = i; }
            }
            CGPoint pos = StrataArtNativeButton(view, @selector(facePos:), closest);
            return (isfinite(pos.x) && isfinite(pos.y)) ? pos : original;
        }
        case StrataArtDpad: {
            CGPoint c = StrataArtNativePoint(view, @selector(dpadCenter));
            // D-pad chooses direction continuously from the native touch point.
            CGFloat radius = 0;
            if ([view respondsToSelector:@selector(dpadR)]) {
                CGFloat (*imp)(id, SEL) = (void *)[view methodForSelector:@selector(dpadR)];
                radius = imp(view, @selector(dpadR));
            }
            if (!isfinite(c.x) || radius <= 0) return original;
            CGFloat dx = fmax(-1, fmin(1, (p.x - (landscape ? 0.148 : 0.225)) / (landscape ? 0.055 : 0.135)));
            CGFloat dy = fmax(-1, fmin(1, (p.y - (landscape ? 0.333 : 0.577)) / (landscape ? 0.093 : 0.071)));
            return CGPointMake(c.x + dx * radius * 0.90, c.y + dy * radius * 0.90);
        }
        case StrataArtRightStick: {
            // NxNative's 3D right stick has no permanent visual hitbox.
            // At touch-down it claims a point in the controls' rightmost third,
            // provided that point is far from the native ABXY diamond.
            CGRect safe = CGRectNull;
            SEL safeSel = NSSelectorFromString(@"safe");
            if ([view respondsToSelector:safeSel]) {
                CGRect (*get)(id, SEL) = (void *)[view methodForSelector:safeSel];
                safe = get(view, safeSel);
            }
            if (CGRectIsNull(safe) || CGRectIsEmpty(safe)) safe = view.bounds;
            CGPoint home = CGPointMake(CGRectGetMaxX(safe)-MAX(8, safe.size.width*0.055),
                                       CGRectGetMinY(safe)+safe.size.height*0.52);
            CGFloat radius = StrataArtNativeRadius(view, 1);
            if (!isfinite(radius) || radius <= 0) return original;
            CGFloat sx = landscape ? 0.776 : 0.698;
            CGFloat sy = landscape ? 0.570 : 0.756;
            CGFloat dx = fmax(-1, fmin(1, (p.x-sx)/(landscape ? 0.048 : 0.125)));
            CGFloat dy = fmax(-1, fmin(1, (p.y-sy)/(landscape ? 0.073 : 0.075)));
            return CGPointMake(home.x+dx*radius*0.82, home.y+dy*radius*0.82);
        }
        case StrataArtLeftStick: {
            CGPoint c = StrataArtNativePoint(view, @selector(stickHome));
            CGFloat radius = StrataArtNativeRadius(view, 0);
            if (!isfinite(c.x) || radius <= 0) return original;
            CGFloat dx = fmax(-1, fmin(1, (p.x - (landscape ? 0.147 : 0.224)) / (landscape ? 0.043 : 0.122)));
            CGFloat dy = fmax(-1, fmin(1, (p.y - (landscape ? 0.570 : 0.756)) / (landscape ? 0.067 : 0.070)));
            return CGPointMake(c.x + dx * radius * 0.85, c.y + dy * radius * 0.85);
        }
        default: return original;
    }
}

@interface StrataNxArtMenuBridge : NSObject <UIGestureRecognizerDelegate>
@property(nonatomic, weak) UIView *pad;
@end
@implementation StrataNxArtMenuBridge
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch {
    CGPoint p = StrataOriginalLocationInView
        ? StrataOriginalLocationInView(touch, @selector(locationInView:), self.pad)
        : [touch locationInView:self.pad];
    CGSize b = self.pad.bounds.size;
    if (b.width <= 0 || b.height <= 0) return NO;
    BOOL landscape = b.width > b.height;
    UIView *skin = [self.pad.superview viewWithTag:877144];
    UIImage *image = [skin valueForKey:landscape ? @"landscapeArtwork" : @"portraitArtwork"];
    CGRect artFrame = StrataNxArtworkFrame(self.pad.bounds, image);
    CGPoint normalized = CGPointMake((p.x-artFrame.origin.x)/MAX(artFrame.size.width,1),
                                      (p.y-artFrame.origin.y)/MAX(artFrame.size.height,1));
    return landscape
        ? StrataArtNear(normalized, 0.460, 0.734, 0.030, 0.042)
        : StrataArtNear(normalized, 0.453, 0.842, 0.052, 0.035);
}
- (void)openMenu:(UITapGestureRecognizer *)tap {
    if (tap.state != UIGestureRecognizerStateRecognized) return;
    for (UIView *v in self.pad.subviews) {
        if ([NSStringFromClass(v.class) isEqualToString:@"DmMenuButton"] &&
            [v isKindOfClass:UIControl.class]) {
            [(UIControl *)v sendActionsForControlEvents:UIControlEventTouchUpInside];
            return;
        }
    }
}
@end

// Visual feedback observes only touch events that NxNative already handles.
// Its input methods still execute unchanged, including cancellation and drag.
static void (*StrataOldNxTouchesBegan)(id, SEL, NSSet<UITouch *> *, UIEvent *);
static void (*StrataOldNxTouchesMoved)(id, SEL, NSSet<UITouch *> *, UIEvent *);
static void (*StrataOldNxTouchesEnded)(id, SEL, NSSet<UITouch *> *, UIEvent *);
static void (*StrataOldNxTouchesCancelled)(id, SEL, NSSet<UITouch *> *, UIEvent *);

// NxNative renders virtual keys into a dedicated CALayer, separate from the
// DmGamepad UIView that owns their real touches. Hide JUST that artwork layer,
// never UIView.hidden / UIView.alpha (both would disable UIKit hit testing).
// The printed skin is visible underneath and gameplay input stays live.
static void StrataNxKeepNativeInputButHideDrawing(UIView *pad) {
    if (!pad || ![NSStringFromClass(pad.class) isEqualToString:@"DmGamepad"]) return;
    UIView *art = [pad.superview viewWithTag:877144];
    if (!art) return;
    BOOL landscape = pad.bounds.size.width > pad.bounds.size.height;
    UIImage *image = [art valueForKey:landscape ? @"landscapeArtwork" : @"portraitArtwork"];
    CALayer *controls = nil;
    @try {
        id layer = [pad valueForKey:@"controls"]; // NxNative's private CALayer *_controls
        if ([layer isKindOfClass:CALayer.class]) controls = layer;
    } @catch (NSException *e) {
        NSLog(@"[Strata Skin] NxNative control-layer lookup failed: %@", e.reason);
    }
    if (!controls) return;  // safest fallback: use the original native controls.
    if (image) {
        // White skin needs D-pad + right stick. Enable the existing 3D handler
        // in memory only; do not change saved gamepad preferences or profiles.
        @try {
            BOOL full = [[pad valueForKey:@"full"] boolValue];
            BOOL tap = [[pad valueForKey:@"tap"] boolValue];
            if (!full || tap) {
                [pad setValue:@NO forKey:@"tap"];
                [pad setValue:@YES forKey:@"full"];
                SEL apply = NSSelectorFromString(@"applyLayout");
                if ([pad respondsToSelector:apply]) {
                    void (*call)(id, SEL) = (void *)[pad methodForSelector:apply];
                    call(pad, apply);
                }
                [pad setNeedsLayout];
                NSLog(@"[Strata Skin] enabled NxNative 3D touch layout in memory only");
            }
        } @catch (NSException *e) {
            NSLog(@"[Strata Skin] kept original input layout: %@", e.reason);
        }
    }
    controls.hidden = image != nil;
    // The gear is a separate UIButton (outside _controls): remove its native
    // drawing but leave the real UIButton and its menu actions intact.
    UIView *menu = nil;
    for (UIView *child in pad.subviews)
        if ([NSStringFromClass(child.class) isEqualToString:@"DmMenuButton"]) {
            menu = child; break;
        }
    if (menu) {
        if (image) {
            menu.backgroundColor = UIColor.clearColor;
            menu.layer.borderWidth = 0;
            menu.layer.shadowOpacity = 0;
            menu.tintColor = UIColor.clearColor;
            menu.layer.sublayers.firstObject.opacity = 0;
        } else {
            menu.layer.sublayers.firstObject.opacity = 1;
        }
    }
}

static void StrataNxSkinTouchVisual(id pad, NSSet<UITouch *> *touches, BOOL ending) {
    UIView *container = ((UIView *)pad).superview;
    UIView *skin = [container viewWithTag:877144];
    SEL selector = @selector(strataTrackTouches:ending:);
    if (!skin || ![skin respondsToSelector:selector]) return;
    void (*track)(id, SEL, NSSet<UITouch *> *, BOOL) = (void *)[skin methodForSelector:selector];
    track(skin, selector, touches, ending);
}
// Prime each touch's Skin role BEFORE NxNative's native touchesBegan gets
// its first locationInView:. UIKit can query a touch during hit testing,
// where UITouch.phase is not reliably "Began", so lazy selection was fragile.
static void StrataNxPrimeArtTouchRoles(UIView *pad, NSSet<UITouch *> *touches) {
    if (!pad || !objc_getAssociatedObject(pad, &StrataNxPadArtTouchEnabledKey)) return;
    UIView *art = [pad.superview viewWithTag:877144];
    BOOL landscape = pad.bounds.size.width > pad.bounds.size.height;
    UIImage *image = [art valueForKey:landscape ? @"landscapeArtwork" : @"portraitArtwork"];
    if (!image || !StrataOriginalLocationInView) return;
    CGRect frame = StrataNxArtworkFrame(pad.bounds, image);
    for (UITouch *touch in touches) {
        CGPoint native = StrataOriginalLocationInView(touch, @selector(locationInView:), pad);
        CGPoint p = CGPointMake((native.x-frame.origin.x)/MAX(frame.size.width,1),
                                (native.y-frame.origin.y)/MAX(frame.size.height,1));
        NSInteger role = StrataNxArtRole(p, landscape);
        objc_setAssociatedObject(touch, &StrataNxTouchArtRoleKey,
                                @(role), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
static void StrataNxTouchBegan(id pad, SEL selector, NSSet<UITouch *> *touches, UIEvent *event) {
    StrataNxKeepNativeInputButHideDrawing((UIView *)pad);
    StrataNxPrimeArtTouchRoles((UIView *)pad, touches);
    StrataNxSkinTouchVisual(pad, touches, NO);
    if (StrataOldNxTouchesBegan) StrataOldNxTouchesBegan(pad, selector, touches, event);
}
static void StrataNxTouchMoved(id pad, SEL selector, NSSet<UITouch *> *touches, UIEvent *event) {
    StrataNxSkinTouchVisual(pad, touches, NO);
    if (StrataOldNxTouchesMoved) StrataOldNxTouchesMoved(pad, selector, touches, event);
}
static void StrataNxClearArtTouchRoles(NSSet<UITouch *> *touches) {
    for (UITouch *touch in touches)
        objc_setAssociatedObject(touch, &StrataNxTouchArtRoleKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static void StrataNxTouchEnded(id pad, SEL selector, NSSet<UITouch *> *touches, UIEvent *event) {
    if (StrataOldNxTouchesEnded) StrataOldNxTouchesEnded(pad, selector, touches, event);
    StrataNxSkinTouchVisual(pad, touches, YES);
    StrataNxClearArtTouchRoles(touches);
}
static void StrataNxTouchCancelled(id pad, SEL selector, NSSet<UITouch *> *touches, UIEvent *event) {
    if (StrataOldNxTouchesCancelled) StrataOldNxTouchesCancelled(pad, selector, touches, event);
    StrataNxSkinTouchVisual(pad, touches, YES);
    StrataNxClearArtTouchRoles(touches);
}
static void StrataNxHookPadVisualEvents(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class padClass = NSClassFromString(@"DmGamepad");
        if (!padClass) return;
        const struct {
            SEL selector;
            IMP replacement;
            void (**original)(id, SEL, NSSet<UITouch *> *, UIEvent *);
        } swaps[] = {
            {@selector(touchesBegan:withEvent:), (IMP)StrataNxTouchBegan, &StrataOldNxTouchesBegan},
            {@selector(touchesMoved:withEvent:), (IMP)StrataNxTouchMoved, &StrataOldNxTouchesMoved},
            {@selector(touchesEnded:withEvent:), (IMP)StrataNxTouchEnded, &StrataOldNxTouchesEnded},
            {@selector(touchesCancelled:withEvent:), (IMP)StrataNxTouchCancelled, &StrataOldNxTouchesCancelled}
        };
        for (NSUInteger i = 0; i < sizeof(swaps)/sizeof(swaps[0]); i++) {
            Method method = class_getInstanceMethod(padClass, swaps[i].selector);
            if (!method) continue;
            *swaps[i].original = (void *)method_getImplementation(method);
            method_setImplementation(method, swaps[i].replacement);
        }
    });
}

static void StrataEnableNxSkinTouchMapping(UIView *pad) {
    if (!pad || objc_getAssociatedObject(pad, &StrataNxPadArtTouchEnabledKey)) return;
    SEL sel = @selector(locationInView:);
    if (!StrataOriginalLocationInView) {
        Method method = class_getInstanceMethod(UITouch.class, sel);
        if (!method) return;
        StrataOriginalLocationInView = (void *)method_getImplementation(method);
        method_setImplementation(method, (IMP)StrataNxRemappedTouchLocation);
    }
    objc_setAssociatedObject(pad, &StrataNxPadArtTouchEnabledKey,
                            @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    StrataNxHookPadVisualEvents();
    StrataNxArtMenuBridge *target = [StrataNxArtMenuBridge new];
    target.pad = pad;
    UITapGestureRecognizer *menuTap = [[UITapGestureRecognizer alloc]
                                      initWithTarget:target action:@selector(openMenu:)];
    menuTap.delegate = target;
    menuTap.cancelsTouchesInView = NO;
    [pad addGestureRecognizer:menuTap];
    objc_setAssociatedObject(pad, @selector(openMenu:), target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[Strata] NxNative white art touch targets mapped to native DmGamepad");
}

static NSString * const StrataNxSkinToggleKey = @"StrataNxSkinEnabled";
static const NSInteger StrataNxSkinViewTag = 877144;

@interface StrataNxSkinView : UIView
@property(nonatomic, strong) UIImage *portraitArtwork;
@property(nonatomic, strong) UIImage *landscapeArtwork;
@property(nonatomic, strong) NSMutableDictionary<NSValue *, NSValue *> *artTouches;
@property(nonatomic, strong) NSMutableDictionary<NSValue *, NSNumber *> *artRoles;
- (void)strataTrackTouches:(NSSet<UITouch *> *)touches ending:(BOOL)ending;
@end
@implementation StrataNxSkinView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO;
        self.opaque = NO;
        self.backgroundColor = UIColor.clearColor;
        self.contentMode = UIViewContentModeRedraw;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.tag = StrataNxSkinViewTag;
        self.artTouches = [NSMutableDictionary new];
        self.artRoles = [NSMutableDictionary new];
        self.accessibilityIdentifier = @"strata.nxnative.cosmetic-skin";
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    [self setNeedsDisplay];
}
- (void)strataTrackTouches:(NSSet<UITouch *> *)touches ending:(BOOL)ending {
    if (!self.superview) return;
    BOOL landscape = self.bounds.size.width > self.bounds.size.height;
    if (!(landscape ? self.landscapeArtwork : self.portraitArtwork)) return;
    for (UITouch *touch in touches) {
        NSValue *key = [NSValue valueWithNonretainedObject:touch];
        if (ending) {
            [self.artTouches removeObjectForKey:key];
            [self.artRoles removeObjectForKey:key];
        } else {
            if (!self.artRoles[key]) {
                NSNumber *role = objc_getAssociatedObject(touch, &StrataNxTouchArtRoleKey);
                if (role) self.artRoles[key] = role;
            }
            UIView *pad = nil;
            for (UIView *v in self.superview.subviews)
                if ([NSStringFromClass(v.class) isEqualToString:@"DmGamepad"]) { pad = v; break; }
            if (!pad) continue;
            CGPoint point = StrataOriginalLocationInView
                ? StrataOriginalLocationInView(touch, @selector(locationInView:), pad)
                : [touch locationInView:pad];
            if (isfinite(point.x) && isfinite(point.y))
                self.artTouches[key] = [NSValue valueWithCGPoint:point];
        }
    }
    // Redraw only when input changes, never on an idle 60 FPS timer.
    [self setNeedsDisplay];
}
static void StrataNxDrawArtFeedback(CGContextRef ctx, CGRect area, BOOL portrait,
                                    NSDictionary<NSValue *, NSValue *> *touches,
                                    NSDictionary<NSValue *, NSNumber *> *roles) {
    CGFloat w = area.size.width, h = area.size.height;
    for (NSValue *key in touches) {
        CGPoint raw = touches[key].CGPointValue;
        CGPoint norm = CGPointMake((raw.x-area.origin.x) / MAX(w,1),
                                   (raw.y-area.origin.y) / MAX(h,1));
        NSNumber *fixedRole = roles[key];
        NSInteger role = fixedRole ? fixedRole.integerValue : StrataNxArtRole(norm, !portrait);
        if (role == StrataArtNoMapping) continue;
        CGFloat x = raw.x, y = raw.y;
        if (role == StrataArtLeftStick || role == StrataArtRightStick) {
            BOOL right = role == StrataArtRightStick;
            CGPoint centre = portrait
                ? CGPointMake(area.origin.x+w*(right ? 0.698 : 0.224), area.origin.y+h*0.756)
                : CGPointMake(area.origin.x+w*(right ? 0.776 : 0.147), area.origin.y+h*0.570);
            CGFloat radius = MIN(w*(portrait ? 0.100 : 0.038), h*(portrait ? 0.047 : 0.067));
            CGFloat dx = MAX(-1.0, MIN(1.0, (x-centre.x)/MAX(radius,1)));
            CGFloat dy = MAX(-1.0, MIN(1.0, (y-centre.y)/MAX(radius,1)));
            // Cover the printed stationary knob, then draw its live position.
            // The outer black ring and surrounding white shell are left intact.
            CGRect original = CGRectMake(centre.x-radius*0.96,centre.y-radius*0.96,
                                         radius*1.92,radius*1.92);
            CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.94 alpha:1].CGColor);
            CGContextFillEllipseInRect(ctx,original);
            CGPoint shifted = CGPointMake(centre.x+dx*radius*0.30,centre.y+dy*radius*0.30);
            CGRect knob = CGRectMake(shifted.x-radius*0.87, shifted.y-radius*0.87,
                                     radius*1.74, radius*1.74);
            CGContextSaveGState(ctx);
            CGContextSetShadowWithColor(ctx,CGSizeMake(0,1.5),2.5,
                                        [UIColor colorWithWhite:0.05 alpha:0.55].CGColor);
            CGContextSetFillColorWithColor(ctx,[UIColor colorWithWhite:0.94 alpha:1].CGColor);
            CGContextFillEllipseInRect(ctx,knob);
            CGContextRestoreGState(ctx);
            CGContextSetStrokeColorWithColor(ctx,[UIColor colorWithWhite:0.3 alpha:0.85].CGColor);
            CGContextSetLineWidth(ctx,1.5);
            CGContextStrokeEllipseInRect(ctx,CGRectInset(knob,1,1));
        } else {
            CGFloat radius = MIN(w*(portrait ? 0.046 : 0.020),
                                 h*(portrait ? 0.025 : 0.041));
            // Darkened inset + highlight: the printed shell key appears pressed.
            CGRect hit = CGRectMake(x-radius,y-radius,radius*2,radius*2);
            CGContextSetFillColorWithColor(ctx,[UIColor colorWithWhite:0.08 alpha:0.21].CGColor);
            CGContextFillEllipseInRect(ctx,hit);
            CGContextSetStrokeColorWithColor(ctx,[UIColor colorWithWhite:1 alpha:0.42].CGColor);
            CGContextSetLineWidth(ctx,1.0);
            CGContextStrokeEllipseInRect(ctx,CGRectInset(hit,2,2));
        }
    }
}
- (void)drawRect:(CGRect)rect {
    UIView *parent = self.superview;
    if (!parent || CGRectIsEmpty(self.bounds)) return;
    UIView *picture = nil;
    for (UIView *child in parent.subviews) {
        if ([NSStringFromClass(child.class) isEqualToString:@"DmGameView"]) { picture = child; break; }
    }
    if (!picture || picture.hidden) return;

    CGRect bounds = self.bounds;
    CGRect game = CGRectIntersection(bounds, picture.frame);
    if (CGRectIsEmpty(game)) return;
    BOOL portrait = bounds.size.height > bounds.size.width;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    // Even-odd clip: color ONLY the unused letterbox / touch-panel area.
    // All existing game pixels and the native pad hit targets remain untouched.
    CGContextSaveGState(ctx);
    CGContextAddRect(ctx, bounds);
    CGContextAddRect(ctx, CGRectInset(game, -0.5, -0.5));
    CGContextEOClip(ctx);

    NSArray *colors = portrait
        ? @[
            (__bridge id)[UIColor colorWithWhite:0.98 alpha:1].CGColor,
            (__bridge id)[UIColor colorWithWhite:0.94 alpha:1].CGColor,
            (__bridge id)[UIColor colorWithWhite:0.85 alpha:1].CGColor
          ]
        : @[
            (__bridge id)[UIColor colorWithRed:0.20 green:0.72 blue:0.82 alpha:1].CGColor,
            (__bridge id)[UIColor colorWithRed:0.20 green:0.72 blue:0.82 alpha:1].CGColor,
            (__bridge id)[UIColor colorWithRed:0.95 green:0.13 blue:0.13 alpha:1].CGColor,
            (__bridge id)[UIColor colorWithRed:0.95 green:0.13 blue:0.13 alpha:1].CGColor
          ];
    CGFloat stopsPortrait[] = {0.0, 0.48, 1.0};
    CGFloat stopsLandscape[] = {0.0, 0.49, 0.51, 1.0};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGGradientRef grad = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, portrait ? stopsPortrait : stopsLandscape);
    if ((portrait && self.portraitArtwork) || (!portrait && self.landscapeArtwork)) {
        // Exact imported white-shell artwork. The imported PNG has a transparent
        // aperture, and the clip above also protects ALL live game pixels.
        // This is only visual: no game aspect ratio or DmGamepad input changes.
        UIImage *image = portrait ? self.portraitArtwork : self.landscapeArtwork;
        [image drawInRect:StrataNxArtworkFrame(bounds, image)];
    } else {
        if (grad) {
            CGContextDrawLinearGradient(ctx, grad,
                portrait ? CGPointMake(CGRectGetMidX(bounds), CGRectGetMinY(bounds)) : CGPointMake(CGRectGetMinX(bounds), CGRectGetMidY(bounds)),
                portrait ? CGPointMake(CGRectGetMidX(bounds), CGRectGetMaxY(bounds)) : CGPointMake(CGRectGetMaxX(bounds), CGRectGetMidY(bounds)), 0);
        }
        if (portrait) StrataNxDrawPortraitHandheld(bounds, game);
    }
    if (grad) CGGradientRelease(grad);
    CGColorSpaceRelease(space);
    // Draw the visual pressed states above the imported art but never over game pixels.
    if ((portrait ? self.portraitArtwork : self.landscapeArtwork) && self.artTouches.count)
        StrataNxDrawArtFeedback(ctx,
                                StrataNxArtworkFrame(bounds,portrait ? self.portraitArtwork : self.landscapeArtwork),
                                portrait,self.artTouches,self.artRoles);
    CGContextRestoreGState(ctx);

    // A subtle screen edge, without a big opaque cover over the game content.
    CGContextSaveGState(ctx);
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.06 alpha:0.88].CGColor);
    CGContextSetLineWidth(ctx, 3.0);
    CGContextStrokeRect(ctx, CGRectInset(game, -1.5, -1.5));
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1 alpha:0.38].CGColor);
    CGContextSetLineWidth(ctx, 1.0);
    CGContextStrokeRect(ctx, CGRectInset(game, -3.0, -3.0));
    CGContextRestoreGState(ctx);
}
@end

static UIView *StrataFindNxPadHost(UIView *view, NSUInteger depth) {
    if (!view || depth > 6) return nil;
    BOOL game = NO, pad = NO;
    for (UIView *child in view.subviews) {
        NSString *name = NSStringFromClass(child.class);
        game |= [name isEqualToString:@"DmGameView"];
        pad |= [name isEqualToString:@"DmGamepad"];
    }
    if (game && pad) return view;
    for (UIView *child in view.subviews) {
        UIView *found = StrataFindNxPadHost(child, depth + 1);
        if (found) return found;
    }
    return nil;
}

// The skin's black screen opening is not the default NxNative picture frame.
// Apply the original game aspect FIT inside the measured artwork opening AFTER
// DmRootVC lays out the scene; do not change render scale or Metal resources.
static char StrataNxSkinRootGroupKey;
static void (*StrataNxOriginalRootDidLayout)(id, SEL) = NULL;

static UIView *StrataNxChildOfClass(UIView *host, NSString *name) {
    for (UIView *v in host.subviews) if ([NSStringFromClass(v.class) isEqualToString:name]) return v;
    return nil;
}

static void StrataNxEnableNative3DPadForSkin(UIView *pad) {
    if (!pad || objc_getAssociatedObject(pad, @selector(StrataNxEnableNative3DPadForSkin))) return;
    // NxNative's 2D layout lacks both the D-pad and right stick. Turn on its
    // existing 3D touch parser for this session only; don't save DmPadLayout.
    @try {
        BOOL full = [[pad valueForKey:@"full"] boolValue];
        BOOL tap = [[pad valueForKey:@"tap"] boolValue];
        if (!full || tap) {
            if ([pad respondsToSelector:@selector(reset)])
                ((void (*)(id, SEL))[pad methodForSelector:@selector(reset)])(pad, @selector(reset));
            [pad setValue:@YES forKey:@"full"];
            [pad setValue:@NO forKey:@"tap"];
            if ([pad respondsToSelector:@selector(applyLayout)])
                ((void (*)(id, SEL))[pad methodForSelector:@selector(applyLayout)])(pad, @selector(applyLayout));
            [pad setNeedsLayout];
        }
        objc_setAssociatedObject(pad, @selector(StrataNxEnableNative3DPadForSkin),
                                @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @catch (NSException *e) {
        NSLog(@"[Strata][NxSkin] Native 3D pad unavailable; retaining game controls: %@", e.reason);
    }
}

static void StrataNxFitGameToImportedArt(UIViewController *root) {
    NSString *group = objc_getAssociatedObject(root, &StrataNxSkinRootGroupKey);
    if (!group || ![[[NSUserDefaults alloc] initWithSuiteName:group]
                    boolForKey:StrataNxSkinToggleKey]) return;
    UIView *host = root.view;
    UIView *skinView = [host viewWithTag:StrataNxSkinViewTag];
    if (![skinView isKindOfClass:StrataNxSkinView.class]) return;
    StrataNxSkinView *skin = (StrataNxSkinView *)skinView;
    BOOL portrait = host.bounds.size.height > host.bounds.size.width;
    UIImage *img = portrait ? skin.portraitArtwork : skin.landscapeArtwork;
    if (!img) return;  // leave native size if no artwork was imported
    UIView *game = StrataNxChildOfClass(host, @"DmGameView");
    UIView *pad = StrataNxChildOfClass(host, @"DmGamepad");
    if (!game || game.superview != host || !pad) return;

    CGRect frame = StrataNxArtworkFrame(host.bounds,img);
    CGRect hole = portrait
        ? CGRectMake(CGRectGetMinX(frame)+frame.size.width*0.039,
                     CGRectGetMinY(frame)+frame.size.height*0.064,
                     frame.size.width*0.923,frame.size.height*0.295)
        : CGRectMake(CGRectGetMinX(frame)+frame.size.width*0.238,
                     CGRectGetMinY(frame)+frame.size.height*0.155,
                     frame.size.width*0.442,frame.size.height*0.525);
    if (hole.size.width < 80 || hole.size.height < 50 ||
        game.frame.size.width < 1 || game.frame.size.height < 1) return;
    // DmRootVC's original layout was just calculated, including game aspect.
    CGFloat aspect = game.frame.size.width / game.frame.size.height;
    CGFloat width = MIN(hole.size.width,hole.size.height*aspect);
    CGFloat height = width/aspect;
    CGRect fitted = CGRectIntegral(CGRectMake(CGRectGetMidX(hole)-width/2,
                                               CGRectGetMidY(hole)-height/2,width,height));
    if (!CGRectEqualToRect(game.frame,fitted)) {
        game.frame = fitted;
        [skin setNeedsDisplay];
    }
    // Native CALayer visuals are hidden, not the UIKit gamepad hit targets.
    StrataNxKeepNativeInputButHideDrawing(pad);
    @try {
        UILabel *fps = [root valueForKey:@"fps"];
        if ([fps isKindOfClass:UILabel.class] && !fps.hidden)
            fps.frame = CGRectMake(CGRectGetMinX(fitted)+5,CGRectGetMinY(fitted)+5,64,22);
    } @catch (__unused NSException *e) {}
}
static void StrataNxRootDidLayout(id root, SEL sel) {
    if (StrataNxOriginalRootDidLayout) StrataNxOriginalRootDidLayout(root,sel);
    StrataNxFitGameToImportedArt((UIViewController *)root);
}
static void StrataNxHookRootLayout(UIViewController *root, NSString *group) {
    if (!root || ![NSStringFromClass(root.class) isEqualToString:@"DmRootVC"]) return;
    objc_setAssociatedObject(root, &StrataNxSkinRootGroupKey,group,OBJC_ASSOCIATION_COPY_NONATOMIC);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Method method = class_getInstanceMethod(root.class,@selector(viewDidLayoutSubviews));
        if (!method) return;
        StrataNxOriginalRootDidLayout = (void *)method_getImplementation(method);
        method_setImplementation(method,(IMP)StrataNxRootDidLayout);
    });
}

static void StrataInstallNxSkin(UIWindow *window, NSString *group) {
    if (!window || window.isHidden || ![NSUserDefaults.lcGuestAppId.lowercaseString hasPrefix:@"org.nxnative"]) return;
    if (![[[NSUserDefaults alloc] initWithSuiteName:group] boolForKey:StrataNxSkinToggleKey]) return;
    UIView *host = StrataFindNxPadHost(window.rootViewController.view, 0);
    if (!host || [host viewWithTag:StrataNxSkinViewTag]) return;
    UIView *pad = nil;
    for (UIView *child in host.subviews) {
        if ([NSStringFromClass(child.class) isEqualToString:@"DmGamepad"]) { pad = child; break; }
    }
    if (!pad) return;
    StrataNxSkinView *skin = [[StrataNxSkinView alloc] initWithFrame:host.bounds];
    // The library stores artwork in the host App Group, readable by the guest
    // even for existing BOTW / TOTK IPAs without an NxNative rebuild.
    NSURL *groupURL = [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:group];
    NSURL *portraitPNG = [groupURL URLByAppendingPathComponent:@"Strata3/Skins/NxNativePortrait.png"];
    if (portraitPNG) skin.portraitArtwork = [UIImage imageWithContentsOfFile:portraitPNG.path];
    NSURL *landscapePNG = [groupURL URLByAppendingPathComponent:@"Strata3/Skins/NxNativeLandscape.png"];
    if (landscapePNG) skin.landscapeArtwork = [UIImage imageWithContentsOfFile:landscapePNG.path];
    if (skin.portraitArtwork || skin.landscapeArtwork) StrataEnableNxSkinTouchMapping(pad);
    [host insertSubview:skin belowSubview:pad];
    if (skin.portraitArtwork || skin.landscapeArtwork) {
        StrataNxEnableNative3DPadForSkin(pad);
        StrataNxKeepNativeInputButHideDrawing(pad);
        StrataNxHookRootLayout(window.rootViewController, group);
        [host setNeedsLayout];
        [host layoutIfNeeded];
        StrataNxFitGameToImportedArt(window.rootViewController);
    }
    [skin setNeedsDisplay];
    NSLog(@"[Strata][NxSkin] imported portrait=%@ landscape=%@; viewport fit and input mapping",
          skin.portraitArtwork ? @"YES":@"NO", skin.landscapeArtwork ? @"YES":@"NO");
}

// Apply the Switchboard's portrait/landscape choice to the NxNative guest,
// never to Strata's launcher. The existing NxNative DmRootVC supports both
// orientations, so the native game will relayout its own picture and gamepad.
static NSString * const StrataNxGuestLandscapeKey = @"StrataNxGuestLandscape";
static char StrataNxOrientationRequestKey;

static void StrataApplyNxGameOrientation(UIWindow *window, NSString *group) {
    if (!window || !window.windowScene || !group.length) return;
    if (![NSUserDefaults.lcGuestAppId.lowercaseString hasPrefix:@"org.nxnative"]) return;
    UIViewController *root = window.rootViewController;
    if (!root || ![NSStringFromClass(root.class) isEqualToString:@"DmRootVC"]) return;

    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:group];
    id stored = [prefs objectForKey:StrataNxGuestLandscapeKey];
    if (![stored respondsToSelector:@selector(boolValue)]) return; // no override selected
    BOOL landscape = [stored boolValue];
    UIWindowScene *scene = window.windowScene;
    BOOL satisfied = landscape ? UIInterfaceOrientationIsLandscape(scene.interfaceOrientation)
                               : (scene.interfaceOrientation == UIInterfaceOrientationPortrait);
    if (satisfied) return;
    NSString *requested = landscape ? @"landscape" : @"portrait";
    if ([objc_getAssociatedObject(window, &StrataNxOrientationRequestKey) isEqual:requested]) return;

    objc_setAssociatedObject(window, &StrataNxOrientationRequestKey,
                            requested, OBJC_ASSOCIATION_COPY_NONATOMIC);
    if (@available(iOS 16.0, *)) {
        UIInterfaceOrientationMask mask = landscape ? UIInterfaceOrientationMaskLandscapeRight
                                                   : UIInterfaceOrientationMaskPortrait;
        [root setNeedsUpdateOfSupportedInterfaceOrientations];
        UIWindowSceneGeometryPreferencesIOS *geometry =
            [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:mask];
        __weak UIWindow *weakWindow = window;
        [scene requestGeometryUpdateWithPreferences:geometry errorHandler:^(NSError *error) {
            NSLog(@"[Strata] NxNative guest orientation %@ rejected: %@", requested, error.localizedDescription);
            UIWindow *liveWindow = weakWindow;
            if (liveWindow) objc_setAssociatedObject(liveWindow, &StrataNxOrientationRequestKey,
                                                    nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
        }];
    } else {
        [UIViewController attemptRotationToDeviceOrientation];
    }
}

@interface StrataControlsWindow : UIWindow
@end
@implementation StrataControlsWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self.rootViewController.view ? nil : hit;
}
@end
@interface StrataControlsController : UIViewController
@property(nonatomic) UIInterfaceOrientationMask orientationMask;
@end
@implementation StrataControlsController
- (BOOL)prefersStatusBarHidden { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return self.orientationMask ?: UIInterfaceOrientationMaskAllButUpsideDown; }
@end
@interface StrataGuestControls : NSObject<UIGestureRecognizerDelegate, UIScrollViewDelegate>
@property(nonatomic) NSString *group;
@property(nonatomic) NSString *appName;
@property(nonatomic) NSString *currentKey;
@property(nonatomic) BOOL separateProcess;
@property(nonatomic) BOOL hostMode;
@property(nonatomic) UIWindow *panel;
@property(nonatomic, weak) UIWindow *previousKeyWindow;
@property(nonatomic) NSHashTable<UIWindow *> *installedWindows;
@property(nonatomic) CGFloat cardStride;
@property(nonatomic) NSMutableArray<NSDictionary *> *deck;      // {view, body, header, entry}
@property(nonatomic) CGRect deckBounds;
@property(nonatomic) CGFloat deckPosition;
@property(nonatomic) NSInteger deckPage;
@property(nonatomic) NSInteger deckMode;                         // 0 none, 1 browse, 2 lift, 3 home
@property(nonatomic) NSInteger deckLiftIndex;
@property(nonatomic) CGFloat deckLiftOffset;
@property(nonatomic, weak) UIView *deckRoot;
@end
@implementation StrataGuestControls
- (void)installInWindow:(UIWindow *)window {
    if (!window || [self.installedWindows containsObject:window]) return;
    StrataApplyNxGameOrientation(window, self.group);
    StrataInstallNxSkin(window, self.group);
    // The guest's Metal view can be created after the window becomes visible.
    // One-off retries are bounded; no periodic cleanup or render-thread hooks.
    __weak UIWindow *weakWindow = window;
    NSString *group = [self.group copy];
    for (NSNumber *delay in @[@1, @4, @12]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            UIWindow *liveWindow = weakWindow;
            if (liveWindow) {
                StrataApplyNxGameOrientation(liveWindow, group);
                StrataInstallNxSkin(liveWindow, group);
            }
        });
    }
    [self.installedWindows addObject:window];
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggle:)];
    gesture.numberOfTouchesRequired = 3;
    gesture.cancelsTouchesInView = window == self.panel;
    gesture.delaysTouchesEnded = window == self.panel;
    gesture.delaysTouchesBegan = NO;
    gesture.delegate = self;
    [window addGestureRecognizer:gesture];
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    // Card swipe-up pans must not run alongside the horizontal card scroll.
    if ([gesture isKindOfClass:UIPanGestureRecognizer.class] && objc_getAssociatedObject(gesture.view, @selector(cardPanned:))) return NO;
    return YES;
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    if (![gesture isKindOfClass:UIPanGestureRecognizer.class] || !objc_getAssociatedObject(gesture.view, @selector(cardPanned:))) return YES;
    CGPoint velocity = [(UIPanGestureRecognizer *)gesture velocityInView:gesture.view];
    return velocity.y < 0 && fabs(velocity.y) > fabs(velocity.x) * 1.2;   // mostly-vertical, upward
}
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)target {
    if (self.cardStride <= 0) return;
    CGFloat page = round(target->x / self.cardStride);
    if (velocity.x > 0.3) page = floor(scrollView.contentOffset.x / self.cardStride) + 1;
    else if (velocity.x < -0.3) page = ceil(scrollView.contentOffset.x / self.cardStride) - 1;
    CGFloat maxX = MAX(0, scrollView.contentSize.width - scrollView.bounds.size.width);
    target->x = MIN(maxX, MAX(0, page * self.cardStride));
}
- (void)hide {
    self.panel.hidden = YES;
    self.panel = nil;
    if (!self.previousKeyWindow.hidden) [self.previousKeyWindow makeKeyWindow];
    self.previousKeyWindow = nil;
}
- (void)request:(NSString *)action {
    if (self.hostMode) {
        [self hide];
        if ([action isEqualToString:@"minimize"]) [NSNotificationCenter.defaultCenter postNotificationName:@"StrataMinimizeAllWindows" object:nil];
        return;
    }
    if (!self.separateProcess) {
        [self hide];
        // A normal guest owns the main process. Use the existing self-relaunch
        // path to return to the launcher, without requiring a manual force-quit.
        [NSUserDefaults.lcUserDefaults removeObjectForKey:@"selected"];
        [NSUserDefaults.lcUserDefaults removeObjectForKey:@"selectedContainer"];
        [NSUserDefaults.lcUserDefaults removeObjectForKey:@"launchAppUrlScheme"];
        [LCSharedUtils launchToGuestAppWithClassicMode:0];
        return;
    }
    NSURL *root = [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:self.group];
    if (!root) { [self showError:@"Strata's shared container is unavailable. Reinstall with all extensions kept, then reopen this app from Strata."]; return; }
    NSURL *directory = [root URLByAppendingPathComponent:@"Library/StrataControls"];
    NSError *error = nil;
    if (![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&error]) { [self showError:error.localizedDescription]; return; }
    NSDictionary *request = @{@"id":NSUUID.UUID.UUIDString, @"pid":@(getpid()), @"action":action, @"timestamp":@(NSDate.date.timeIntervalSince1970)};
    NSData *data = [NSJSONSerialization dataWithJSONObject:request options:0 error:nil];
    if ([data writeToURL:[directory URLByAppendingPathComponent:@"request.json"] options:NSDataWritingAtomic error:nil]) {
        [self hide];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.strata.controls.request"), NULL, NULL, true);
    } else { [self showError:@"The app controls request could not be saved. Return to Strata and reopen this app."]; }
}
- (void)selectEntry:(NSDictionary *)entry close:(BOOL)close {
    if (close && [entry[@"key"] isEqualToString:self.currentKey]) { [self request:@"close"]; return; }
    if (!close && [entry[@"key"] isEqualToString:self.currentKey]) { [self hide]; return; }
    NSURL *root = [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:self.group];
    NSURL *directory = [root URLByAppendingPathComponent:@"Library/StrataControls"];
    NSError *error = nil;
    if (!directory || ![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&error]) {
        [self showError:error.localizedDescription ?: @"Strata's shared container is unavailable."]; return;
    }
    NSDictionary *command = @{@"key":entry[@"key"], @"close":@(close), @"timestamp":@(NSDate.date.timeIntervalSince1970)};
    NSData *data = [NSJSONSerialization dataWithJSONObject:command options:0 error:nil];
    if (![data writeToURL:[directory URLByAppendingPathComponent:@"switch.json"] options:NSDataWritingAtomic error:&error]) { [self showError:error.localizedDescription]; return; }
    if (self.hostMode) {
        [self hide];
        [NSNotificationCenter.defaultCenter postNotificationName:@"StrataLaunchFromControls" object:nil];
    } else [self request:@"library"];
}
/// Closes another running app without leaving the switcher.
- (void)closeInBackground:(NSDictionary *)entry {
    NSURL *root = [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:self.group];
    NSURL *directory = [root URLByAppendingPathComponent:@"Library/StrataControls"];
    if (!directory || ![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil]) return;
    NSDictionary *command = @{@"key":entry[@"key"], @"close":@YES, @"timestamp":@(NSDate.date.timeIntervalSince1970)};
    [[NSJSONSerialization dataWithJSONObject:command options:0 error:nil] writeToURL:[directory URLByAppendingPathComponent:@"switch.json"] atomically:YES];
    if (self.hostMode) { [NSNotificationCenter.defaultCenter postNotificationName:@"StrataLaunchFromControls" object:nil]; return; }
    NSDictionary *request = @{@"id":NSUUID.UUID.UUIDString, @"pid":@(getpid()), @"action":@"closeOther", @"timestamp":@(NSDate.date.timeIntervalSince1970)};
    [[NSJSONSerialization dataWithJSONObject:request options:0 error:nil] writeToURL:[directory URLByAppendingPathComponent:@"request.json"] atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.strata.controls.request"), NULL, NULL, true);
}
- (void)showError:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"App controls unavailable" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self.panel.rootViewController presentViewController:alert animated:YES completion:nil];
}
- (UIButton *)button:(NSString *)title action:(void (^)(void))action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *config;
    config = UIButtonConfiguration.plainButtonConfiguration;
    NSString *symbol = [title isEqualToString:@"Library"] ? @"square.grid.2x2" : ([title isEqualToString:@"Minimize"] ? @"rectangle.stack.badge.minus" : ([title isEqualToString:@"⌄"] ? @"chevron.down" : nil));
    if (symbol) config.image = [UIImage systemImageNamed:symbol];
    else config.title = title;
    config.contentInsets = NSDirectionalEdgeInsetsMake(8, 4, 8, 4);
    button.accessibilityLabel = [title isEqualToString:@"⌄"] ? @"Hide app strip" : title;
    config.baseForegroundColor = UIColor.whiteColor;
    config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    button.configuration = config;
    [button addAction:[UIAction actionWithHandler:^(UIAction *item) { action(); }] forControlEvents:UIControlEventTouchUpInside];
    return button;
}

#pragma mark - Card switcher
// Full-screen card switcher: current app first (live snapshot), then running and pinned apps (icons).
// Tap a card to switch, swipe it up to close it (or unpin a pinned app), tap the background or Home to leave.
- (NSURL *)snapshotURLForKey:(NSString *)key {
    NSURL *root = [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:self.group];
    if (!root || key.length == 0) return nil;
    NSString *safe = [[key componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@"_"];
    NSURL *dir = [root URLByAppendingPathComponent:@"Library/StrataControls/Snapshots" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir URLByAppendingPathComponent:[safe stringByAppendingString:@".jpg"]];
}
/// Saves the current app's screen for its switcher card. Metal-only screens can come out black;
/// those are skipped so the card falls back to the app icon.
- (void)saveSnapshotOfWindow:(UIWindow *)window {
    NSURL *url = [self snapshotURLForKey:self.currentKey];
    if (!url || !window || window.bounds.size.width < 10) return;
    CGFloat scale = MIN(1.0, 640.0 / MAX(window.bounds.size.width, window.bounds.size.height)) * window.screen.scale;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat]; format.scale = scale; format.opaque = YES;
    UIImage *image = [[[UIGraphicsImageRenderer alloc] initWithSize:window.bounds.size format:format] imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
    }];
    unsigned char pixel[4] = {0};
    CGContextRef tiny = CGBitmapContextCreate(pixel, 1, 1, 8, 4, CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast);
    if (tiny && image.CGImage) { CGContextDrawImage(tiny, CGRectMake(0, 0, 1, 1), image.CGImage); }
    if (tiny) CGContextRelease(tiny);
    if (pixel[0] + pixel[1] + pixel[2] < 9) return;
    [UIImageJPEGRepresentation(image, 0.7) writeToURL:url atomically:YES];
}
- (UIImage *)snapshotForKey:(NSString *)key {
    NSURL *url = [self snapshotURLForKey:key];
    return url ? [UIImage imageWithContentsOfFile:url.path] : nil;
}
- (NSArray *)switcherEntries:(NSArray **)pinnedOut {
    NSURL *root = [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:self.group];
    NSData *data = root ? [NSData dataWithContentsOfURL:[root URLByAppendingPathComponent:@"Library/StrataControls/library.json"]] : nil;
    NSArray *all = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if (![all isKindOfClass:NSArray.class]) all = @[];
    NSUserDefaults *settings = [[NSUserDefaults alloc] initWithSuiteName:self.group];
    NSArray *pinned = [settings stringArrayForKey:@"StrataSwitcherPinnedApps"] ?: @[];
    NSArray *recents = [settings stringArrayForKey:@"StrataRecentApps"] ?: @[];
    if (pinnedOut) *pinnedOut = pinned;
    NSMutableDictionary *byKey = [NSMutableDictionary new];
    for (NSDictionary *entry in all) if ([entry isKindOfClass:NSDictionary.class] && [entry[@"key"] isKindOfClass:NSString.class]) byKey[entry[@"key"]] = entry;
    NSMutableArray *ordered = [NSMutableArray new]; NSMutableSet *seen = [NSMutableSet new];
    void (^add)(NSString *) = ^(NSString *key) { NSDictionary *entry = byKey[key]; if (entry && ![seen containsObject:key]) { [seen addObject:key]; [ordered addObject:entry]; } };
    if (self.currentKey) add(self.currentKey);
    for (NSDictionary *entry in all) if ([entry isKindOfClass:NSDictionary.class] && [entry[@"running"] isEqualToString:@"1"]) add(entry[@"key"]);
    for (NSString *key in recents) if ([key isKindOfClass:NSString.class]) add(key);
    for (NSString *key in pinned) if ([key isKindOfClass:NSString.class]) add(key);
    return ordered;
}
- (void)cardPanned:(UIPanGestureRecognizer *)pan {
    UIView *card = pan.view;
    CGFloat dy = MIN(0, [pan translationInView:card.superview].y);
    if (pan.state == UIGestureRecognizerStateChanged) {
        card.transform = CGAffineTransformMakeTranslation(0, dy);
        card.alpha = 1 - MIN(0.6, -dy / 600);
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        BOOL dismiss = dy < -120 || [pan velocityInView:card.superview].y < -900;
        NSDictionary *entry = objc_getAssociatedObject(card, @selector(cardPanned:));
        if (!dismiss || !entry) { [UIView animateWithDuration:0.25 animations:^{ card.transform = CGAffineTransformIdentity; card.alpha = 1; }]; return; }
        [UIView animateWithDuration:0.22 animations:^{ card.transform = CGAffineTransformMakeTranslation(0, -card.superview.bounds.size.height); card.alpha = 0; } completion:^(BOOL finished) {
            BOOL isRunning = [entry[@"key"] isEqualToString:self.currentKey] || [entry[@"running"] isEqualToString:@"1"];
            if (isRunning) { [self selectEntry:entry close:YES]; return; }
            NSUserDefaults *settings = [[NSUserDefaults alloc] initWithSuiteName:self.group];
            for (NSString *list in @[@"StrataSwitcherPinnedApps", @"StrataRecentApps"]) {
                NSMutableArray *values = [[settings stringArrayForKey:list] mutableCopy] ?: [NSMutableArray new];
                [values removeObject:entry[@"key"]]; [settings setObject:values forKey:list];
            }
            [UIView animateWithDuration:0.2 animations:^{ card.hidden = YES; [card.superview layoutIfNeeded]; }];
        }];
    }
}
/// iOS-style open: the tapped card grows to fill the screen, the rest of the switcher fades away.
- (void)zoomCard:(UIView *)card inRoot:(UIView *)root completion:(void (^)(void))completion {
    UIView *portal = [card viewWithTag:7701];
    if (portal) {
        // Live card: grow the card itself (the running app keeps drawing) to full screen.
        CGRect from = [card convertRect:card.bounds toView:root];
        [root addSubview:card]; card.frame = from;
        [UIView animateWithDuration:0.36 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0 options:0 animations:^{
            card.frame = root.bounds; card.layer.cornerRadius = 0;
            portal.transform = CGAffineTransformIdentity; portal.center = CGPointMake(CGRectGetMidX(root.bounds), CGRectGetMidY(root.bounds));
            for (UIView *view in root.subviews) if (view != card) view.alpha = 0;
        } completion:^(BOOL finished) { completion(); }];
        return;
    }
    UIView *shot = [card snapshotViewAfterScreenUpdates:NO];
    if (!shot || card.bounds.size.width < 1) { completion(); return; }
    CGRect from = [card convertRect:card.bounds toView:root];
    shot.frame = from; shot.layer.cornerRadius = 22; shot.layer.cornerCurve = kCACornerCurveContinuous; shot.clipsToBounds = YES;
    [root addSubview:shot];
    card.alpha = 0;
    CGFloat scale = root.bounds.size.width / from.size.width;
    [UIView animateWithDuration:0.34 delay:0 usingSpringWithDamping:0.92 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        shot.center = CGPointMake(CGRectGetMidX(root.bounds), CGRectGetMidY(root.bounds));
        shot.transform = CGAffineTransformMakeScale(scale, scale);
        shot.layer.cornerRadius = 22 / scale;
        for (UIView *view in root.subviews) if (view != shot) view.alpha = 0;
    } completion:^(BOOL finished) { completion(); }];
}
#pragma mark - Live cards (host)
// Strata registers these when it hosts apps in their own processes: a live view of the app shown full screen,
// and its key. The front card then mirrors the running app live (_UIPortalView) instead of a screenshot.
static UIView *(^strataLiveViewProvider)(NSString *key);
static NSString *(^strataFrontKeyProvider)(void);
void StrataSetSwitcherProviders(UIView *(^live)(NSString *key), NSString *(^front)(void)) {
    strataLiveViewProvider = [live copy]; strataFrontKeyProvider = [front copy];
}
static UIView *StrataPortalForView(UIView *source) {
    Class portalClass = NSClassFromString(@"_UIPortalView");
    if (!portalClass || !source) return nil;
    UIView *portal = [[portalClass alloc] initWithFrame:source.bounds];
    @try {
        [portal setValue:source forKey:@"sourceView"];
        [portal setValue:@NO forKey:@"matchesAlpha"];
        [portal setValue:@NO forKey:@"matchesTransform"];
        [portal setValue:@NO forKey:@"matchesPosition"];
    } @catch (NSException *exception) { return nil; }
    portal.userInteractionEnabled = NO;
    portal.tag = 7701;
    return portal;
}

#pragma mark - iOS-style deck
// Deck geometry and gesture model adapted from ryC0's AppSwitcherView (RYSwitcherLayout / RYSwitcherDeck),
// https://github.com/Sami-Wali/ryC0, AGPL-3.0. Ported to UIKit so it also runs inside guest processes.
static CGRect StrataDeckBaseFrame(CGRect b) {
    CGSize size = CGSizeMake(b.size.width * 0.685, b.size.height * 0.685);
    return CGRectMake(CGRectGetMidX(b) - size.width / 2, CGRectGetMinY(b) + b.size.height * 0.49 - size.height / 2, size.width, size.height);
}
static CGFloat StrataDeckStride(CGRect b) { return MAX(1, b.size.width * 0.53); }
static CGRect StrataDeckFrame(NSInteger index, CGFloat position, CGRect b) {
    CGFloat distance = index - position;
    CGFloat spread = MIN(MAX(position, 0), 1);
    CGFloat offset = b.size.width * (b.size.width > b.size.height ? 0.03 : 0.075) * spread;
    CGRect frame = CGRectOffset(StrataDeckBaseFrame(b), offset, 0);
    if (distance <= 0) return CGRectOffset(frame, -distance * StrataDeckStride(b), 0);
    CGFloat depth = MIN(distance, 4);
    CGFloat peek = 0.135 + spread * 0.045;
    CGFloat inset = (MIN(distance, 1) * peek + MAX(0, distance - 1) * 0.048) * b.size.width;
    return CGRectOffset(CGRectInset(frame, frame.size.width * depth * 0.004, frame.size.height * depth * 0.008), -inset, 0);
}
static const CGFloat StrataDeckHeader = 36;   // icon row + gap above each card

- (void)layoutDeck {
    CGRect b = self.deckBounds;
    for (NSInteger i = 0; i < (NSInteger)self.deck.count; i++) {
        NSDictionary *item = self.deck[i];
        UIView *view = item[@"view"], *body = item[@"body"], *header = item[@"header"], *shade = item[@"shade"];
        CGRect frame = StrataDeckFrame(i, self.deckPosition, b);
        CGFloat lift = (self.deckMode == 2 && self.deckLiftIndex == i) ? MIN(0, self.deckLiftOffset) : 0;
        view.frame = CGRectMake(frame.origin.x, frame.origin.y - StrataDeckHeader + lift, frame.size.width, frame.size.height + StrataDeckHeader);
        body.frame = CGRectMake(0, StrataDeckHeader, frame.size.width, frame.size.height);
        body.layer.cornerRadius = MIN(frame.size.width, frame.size.height) * 0.16;
        header.frame = CGRectMake(frame.size.width * 0.08, 0, frame.size.width * 0.84, 28);
        CGFloat depth = i - self.deckPosition;
        header.alpha = MAX(0, 1 - fabs(depth));
        shade.alpha = MIN(0.28, MAX(0, depth) * 0.24);
        view.layer.zPosition = -i;
    }
}
- (void)settleDeckOn:(NSInteger)page {
    self.deckPage = MIN(MAX(page, 0), MAX(0, (NSInteger)self.deck.count - 1));
    self.deckPosition = self.deckPage; self.deckMode = 0; self.deckLiftOffset = 0;
    [UIView animateWithDuration:0.34 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0 options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:^{ [self layoutDeck]; } completion:nil];
}
- (NSInteger)deckIndexAtPoint:(CGPoint)point {
    for (NSInteger i = MAX(0, self.deckPage - 2); i < MIN((NSInteger)self.deck.count, self.deckPage + 5); i++) {
        CGRect frame = StrataDeckFrame(i, self.deckPage, self.deckBounds);
        frame.origin.y -= StrataDeckHeader; frame.size.height += StrataDeckHeader;
        if (CGRectContainsPoint(frame, point)) return i;
    }
    return NSNotFound;
}
- (void)deckPanned:(UIPanGestureRecognizer *)pan {
    CGPoint t = [pan translationInView:pan.view], v = [pan velocityInView:pan.view];
    CGRect b = self.deckBounds;
    if (pan.state == UIGestureRecognizerStateBegan) {
        CGPoint start = CGPointMake([pan locationInView:pan.view].x - t.x, [pan locationInView:pan.view].y - t.y);
        if (fabs(t.x) >= fabs(t.y)) self.deckMode = 1;
        else if (start.y > b.size.height - 45) self.deckMode = 3;
        else { NSInteger index = [self deckIndexAtPoint:start]; self.deckMode = index == NSNotFound ? 0 : 2; self.deckLiftIndex = index; }
    }
    if (pan.state == UIGestureRecognizerStateChanged) {
        if (self.deckMode == 1) {
            CGFloat proposed = self.deckPage + t.x / StrataDeckStride(b);
            CGFloat clamped = MIN(MAX(proposed, 0), MAX(0, (CGFloat)self.deck.count - 1));
            self.deckPosition = clamped + (proposed - clamped) * 0.2;   // rubber band past the ends
            [self layoutDeck];
        } else if (self.deckMode == 2) { self.deckLiftOffset = t.y; [self layoutDeck]; }
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        if (self.deckMode == 1) {
            CGFloat stride = StrataDeckStride(b);
            CGFloat distance = t.x / stride, predicted = (t.x + v.x * 0.25) / stride;
            CGFloat projected = MIN(MAX(predicted, distance - 1), distance + 1);
            [self settleDeckOn:self.deckPage + (NSInteger)lround(projected)];
        } else if (self.deckMode == 2) {
            BOOL fling = t.y < -28 && (t.y < -b.size.height * 0.10 || v.y < -900);
            if (fling && self.deckLiftIndex != NSNotFound) [self flyAwayDeckCard:self.deckLiftIndex velocity:-v.y];
            else [self settleDeckOn:self.deckPage];
        } else if (self.deckMode == 3) {
            self.deckMode = 0;
            if (t.y < -30) [self hide];
        } else self.deckMode = 0;
    }
}
- (void)deckTapped:(UITapGestureRecognizer *)tap {
    NSInteger index = [self deckIndexAtPoint:[tap locationInView:tap.view]];
    if (index == NSNotFound) { [self hide]; return; }
    NSDictionary *item = self.deck[index];
    __weak typeof(self) weakSelf = self;
    [self zoomCard:item[@"body"] inRoot:self.deckRoot completion:^{ [weakSelf selectEntry:item[@"entry"] close:NO]; }];
}
- (void)flyAwayDeckCard:(NSInteger)index velocity:(CGFloat)velocity {
    NSDictionary *item = self.deck[index];
    UIView *view = item[@"view"];
    CGFloat remaining = MAX(0, self.deckBounds.size.height + view.frame.origin.y);
    NSTimeInterval duration = MAX(0.14, MIN(0.24, remaining / MAX(velocity, 1)));
    self.deckMode = 0;
    [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        view.frame = CGRectOffset(view.frame, 0, -self.deckBounds.size.height);
    } completion:^(BOOL finished) {
        NSDictionary *entry = item[@"entry"];
        BOOL running = [entry[@"key"] isEqualToString:self.currentKey] || [entry[@"running"] isEqualToString:@"1"];
        [view removeFromSuperview];
        [self.deck removeObjectAtIndex:index];
        if (running && [entry[@"key"] isEqualToString:self.currentKey] && !self.hostMode) {
            // Closing the app the switcher lives in: in its own process, ask Strata to close it and
            // reopen the switcher there, so the switcher stays up like iOS.
            if (self.separateProcess) [self request:@"closeReopen"]; else [self selectEntry:entry close:YES];
            return;
        }
        if (running) [self closeInBackground:entry];   // like iOS: the switcher stays open
        NSUserDefaults *settings = [[NSUserDefaults alloc] initWithSuiteName:self.group];
        for (NSString *list in @[@"StrataSwitcherPinnedApps", @"StrataRecentApps"]) {
            NSMutableArray *values = [[settings stringArrayForKey:list] mutableCopy] ?: [NSMutableArray new];
            [values removeObject:entry[@"key"]]; [settings setObject:values forKey:list];
        }
        [self settleDeckOn:MIN(self.deckPage, (NSInteger)self.deck.count - 1)];
    }];
}

- (void)presentCardsInController:(StrataControlsController *)controller window:(UIWindow *)window source:(UIWindow *)source {
    if (!self.hostMode) [self saveSnapshotOfWindow:source];
    NSArray *entries = [self switcherEntries:nil];
    UIView *root = controller.view;
    self.deckRoot = root;
    UIVisualEffectView *backdrop = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark]];
    backdrop.frame = root.bounds; backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    backdrop.accessibilityIdentifier = @"strata.switcher.cards";
    [root addSubview:backdrop];
    UIView *dim = [[UIView alloc] initWithFrame:root.bounds]; dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.14];
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; dim.userInteractionEnabled = NO;
    [backdrop.contentView addSubview:dim];
    UIView *stage = [[UIView alloc] initWithFrame:root.bounds];
    stage.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [backdrop.contentView addSubview:stage];
    self.deckBounds = root.bounds;
    self.deck = [NSMutableArray new];
    self.deckPage = 0; self.deckPosition = 0; self.deckMode = 0;
    UIView *intro = [source snapshotViewAfterScreenUpdates:NO];
    UIView *liveSnapshot = [source snapshotViewAfterScreenUpdates:NO];
    for (NSDictionary *entry in entries) {
        BOOL isCurrent = [entry[@"key"] isEqualToString:self.currentKey];
        UIImage *icon = [UIImage imageWithData:[[NSData alloc] initWithBase64EncodedString:entry[@"icon"] ?: @"" options:0]] ?: [UIImage systemImageNamed:@"app.fill"];
        UIView *view = [UIView new];
        CGRect base = StrataDeckBaseFrame(root.bounds);
        UIView *body = [[UIView alloc] initWithFrame:CGRectMake(0, 0, base.size.width, base.size.height)];
        body.backgroundColor = UIColor.secondarySystemBackgroundColor;
        body.layer.cornerCurve = kCACornerCurveContinuous; body.clipsToBounds = YES;
        body.accessibilityLabel = entry[@"name"] ?: @"App";
        body.accessibilityIdentifier = [@"strata.switcher.card." stringByAppendingString:entry[@"key"]];
        UIImage *shotImage = isCurrent ? nil : [self snapshotForKey:entry[@"key"]];
        UIView *liveSource = (self.hostMode && isCurrent && strataLiveViewProvider) ? strataLiveViewProvider(entry[@"key"]) : nil;
        UIView *portal = liveSource ? StrataPortalForView(liveSource) : nil;
        if (portal) {
            portal.bounds = liveSource.bounds;
            portal.transform = CGAffineTransformMakeScale(base.size.width / MAX(1, liveSource.bounds.size.width), base.size.height / MAX(1, liveSource.bounds.size.height));
            portal.center = CGPointMake(base.size.width / 2, base.size.height / 2);
            [body addSubview:portal];
        } else if (isCurrent && liveSnapshot) {
            liveSnapshot.userInteractionEnabled = NO;
            liveSnapshot.bounds = source.bounds;
            liveSnapshot.transform = CGAffineTransformMakeScale(base.size.width / MAX(1, source.bounds.size.width), base.size.height / MAX(1, source.bounds.size.height));
            liveSnapshot.center = CGPointMake(base.size.width / 2, base.size.height / 2);
            [body addSubview:liveSnapshot];
        } else if (shotImage) {
            UIImageView *shot = [[UIImageView alloc] initWithImage:shotImage];
            shot.frame = body.bounds; shot.clipsToBounds = YES;
            shot.contentMode = UIViewContentModeScaleAspectFill; shot.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [body addSubview:shot];
        } else {
            UIImageView *big = [[UIImageView alloc] initWithImage:icon];
            big.layer.cornerRadius = 14; big.clipsToBounds = YES;
            big.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            big.frame = CGRectMake(0, 0, 64, 64);
            big.center = CGPointMake(base.size.width / 2, base.size.height / 2);
            [body addSubview:big];
        }
        UIView *shade = [[UIView alloc] initWithFrame:body.bounds]; shade.backgroundColor = UIColor.blackColor; shade.alpha = 0; shade.userInteractionEnabled = NO;
        shade.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [body addSubview:shade];
        UIStackView *header = [UIStackView new]; header.axis = UILayoutConstraintAxisHorizontal; header.spacing = 8; header.alignment = UIStackViewAlignmentCenter;
        UIImageView *small = [[UIImageView alloc] initWithImage:icon]; small.layer.cornerRadius = 6.5; small.clipsToBounds = YES;
        [small.widthAnchor constraintEqualToConstant:28].active = YES; [small.heightAnchor constraintEqualToConstant:28].active = YES;
        UILabel *name = [UILabel new]; name.text = entry[@"name"] ?: @"App"; name.textColor = UIColor.whiteColor;
        name.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold]; name.lineBreakMode = NSLineBreakByTruncatingTail;
        [header addArrangedSubview:small]; [header addArrangedSubview:name];
        [view addSubview:header]; [view addSubview:body];
        [stage addSubview:view];
        [self.deck addObject:@{@"view": view, @"body": body, @"header": header, @"shade": shade, @"entry": entry}];
    }
    if (entries.count == 0) {
        UILabel *empty = [UILabel new]; empty.text = @"No open apps"; empty.textColor = [UIColor colorWithWhite:1 alpha:0.8];
        empty.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium]; [empty sizeToFit];
        empty.center = CGPointMake(CGRectGetMidX(root.bounds), CGRectGetMidY(root.bounds));
        [stage addSubview:empty];
    }
    [self layoutDeck];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(deckPanned:)];
    pan.maximumNumberOfTouches = 1;
    [stage addGestureRecognizer:pan];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(deckTapped:)];
    [tap requireGestureRecognizerToFail:pan];
    [stage addGestureRecognizer:tap];
    // iOS-style open: the current screen shrinks into the front card.
    NSDictionary *front = self.deck.firstObject;
    if (intro && front && [front[@"entry"][@"key"] isEqualToString:self.currentKey] && !UIAccessibilityIsReduceMotionEnabled()) {
        CGRect target = StrataDeckFrame(0, 0, root.bounds);
        UIView *frontView = front[@"view"];
        intro.frame = root.bounds; intro.clipsToBounds = YES; intro.layer.cornerCurve = kCACornerCurveContinuous;
        [root addSubview:intro];
        backdrop.alpha = 0; frontView.alpha = 0;
        CGFloat scale = target.size.width / MAX(1, root.bounds.size.width);
        [UIView animateWithDuration:0.36 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0 options:0 animations:^{
            intro.center = CGPointMake(CGRectGetMidX(target), CGRectGetMidY(target));
            intro.transform = CGAffineTransformMakeScale(scale, scale);
            intro.layer.cornerRadius = MIN(target.size.width, target.size.height) * 0.16 / MAX(0.01, scale);
            backdrop.alpha = 1;
        } completion:^(BOOL finished) { frontView.alpha = 1; [intro removeFromSuperview]; }];
    }
}
- (void)toggle:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateRecognized) return;
    [self toggleFromWindow:gesture.view.window ?: (UIWindow *)gesture.view];
}
- (void)toggleFromWindow:(UIWindow *)source {
    if (self.panel) { [self hide]; return; }
    UIWindowScene *scene = source.windowScene;
    UIWindow *window = scene ? [[StrataControlsWindow alloc] initWithWindowScene:scene] : [[StrataControlsWindow alloc] initWithFrame:source.bounds];
    if (scene) window.frame = scene.coordinateSpace.bounds;
    window.multipleTouchEnabled = YES;
    window.accessibilityIdentifier = @"strata.controls.window";
    window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    window.windowLevel = UIWindowLevelAlert + 1;
    window.backgroundColor = UIColor.clearColor;
    StrataControlsController *controller = [StrataControlsController new];
    UIInterfaceOrientation orientation = scene ? scene.interfaceOrientation : UIApplication.sharedApplication.statusBarOrientation;
    if (orientation != UIInterfaceOrientationUnknown) controller.orientationMask = 1 << orientation;
    window.rootViewController = controller;
    controller.view.multipleTouchEnabled = YES;
    controller.view.backgroundColor = UIColor.clearColor;
    NSString *style = [[[NSUserDefaults alloc] initWithSuiteName:self.group] stringForKey:@"StrataSwitcherStyle"] ?: @"cards";
    if ([style isEqualToString:@"cards"] && self.separateProcess && !self.hostMode) {
        // This app runs in its own process inside Strata: save its snapshot, then let Strata show the deck,
        // where every running app is available and the front card is live.
        [self saveSnapshotOfWindow:source];
        [self request:@"switcher"];
        return;
    }
    if ([style isEqualToString:@"cards"]) {
        [self presentCardsInController:controller window:window source:source];
        self.previousKeyWindow = source;
        self.panel = window;
        [self installInWindow:window];
        [window makeKeyAndVisible];
        return;
    }
    UIVisualEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];
    if (@available(iOS 26.0, *)) effect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:effect];
    glass.multipleTouchEnabled = YES;
    glass.contentView.multipleTouchEnabled = YES;
    glass.accessibilityIdentifier = @"strata.controls.panel";
    glass.layer.cornerRadius = 15;
    glass.clipsToBounds = YES;
    glass.translatesAutoresizingMaskIntoConstraints = NO;
    [controller.view addSubview:glass];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [glass.contentView addSubview:stack];
    __weak typeof(self) weakSelf = self;
    [stack addArrangedSubview:[self button:@"⌄" action:^{ [weakSelf hide]; }]];
    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.showsVerticalScrollIndicator = NO;
    [stack addArrangedSubview:scroll];
    UIStackView *icons = [UIStackView new];
    icons.axis = UILayoutConstraintAxisVertical; icons.spacing = 12;
    icons.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:icons];
    NSURL *root = [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:self.group];
    NSData *data = [NSData dataWithContentsOfURL:[root URLByAppendingPathComponent:@"Library/StrataControls/library.json"]];
    NSArray *entries = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if (![entries isKindOfClass:NSArray.class]) entries = @[];
    NSUserDefaults *settings = [[NSUserDefaults alloc] initWithSuiteName:self.group];
    NSArray *pinned = [settings stringArrayForKey:@"StrataSwitcherPinnedApps"] ?: @[];
    entries = [entries filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *entry, NSDictionary *bindings) {
        if (![entry isKindOfClass:NSDictionary.class]) return NO;
        return [entry[@"running"] isEqualToString:@"1"] || [entry[@"key"] isEqualToString:self.currentKey] || [pinned containsObject:entry[@"key"]];
    }]];
    for (NSDictionary *entry in entries) {
        if (![entry isKindOfClass:NSDictionary.class] || ![entry[@"key"] isKindOfClass:NSString.class]) continue;
        UIButton *icon = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *image = [UIImage imageWithData:[[NSData alloc] initWithBase64EncodedString:entry[@"icon"] ?: @"" options:0]];
        UIImageView *art = [[UIImageView alloc] initWithImage:image ?: [UIImage systemImageNamed:@"app"]];
        art.contentMode = UIViewContentModeScaleAspectFill;
        art.translatesAutoresizingMaskIntoConstraints = NO; art.userInteractionEnabled = NO;
        [icon addSubview:art];
        [NSLayoutConstraint activateConstraints:@[[art.leadingAnchor constraintEqualToAnchor:icon.leadingAnchor], [art.trailingAnchor constraintEqualToAnchor:icon.trailingAnchor], [art.topAnchor constraintEqualToAnchor:icon.topAnchor], [art.bottomAnchor constraintEqualToAnchor:icon.bottomAnchor]]];
        icon.layer.cornerRadius = 17; icon.clipsToBounds = YES;
        icon.accessibilityLabel = entry[@"name"] ?: @"App";
        [icon.heightAnchor constraintEqualToConstant:72].active = YES;
        [icon addAction:[UIAction actionWithHandler:^(UIAction *action) { [weakSelf selectEntry:entry close:NO]; }] forControlEvents:UIControlEventTouchUpInside];
        UIAction *open = [UIAction actionWithTitle:@"Open app" image:[UIImage systemImageNamed:@"play"] identifier:nil handler:^(UIAction *action) { [weakSelf selectEntry:entry close:NO]; }];
        UIAction *close = [UIAction actionWithTitle:@"Close app" image:[UIImage systemImageNamed:@"xmark.circle"] identifier:nil handler:^(UIAction *action) { [weakSelf selectEntry:entry close:YES]; }];
        close.attributes = UIMenuElementAttributesDestructive;
        BOOL running = [entry[@"key"] isEqualToString:self.currentKey] || [entry[@"running"] isEqualToString:@"1"];
        BOOL isPinned = [pinned containsObject:entry[@"key"]];
        UIAction *pin = [UIAction actionWithTitle:isPinned ? @"Unpin" : @"Pin app" image:[UIImage systemImageNamed:@"pin"] identifier:nil handler:^(UIAction *action) {
            NSMutableArray *values = [[settings stringArrayForKey:@"StrataSwitcherPinnedApps"] mutableCopy] ?: [NSMutableArray new];
            if ([values containsObject:entry[@"key"]]) [values removeObject:entry[@"key"]]; else [values addObject:entry[@"key"]];
            [settings setObject:values forKey:@"StrataSwitcherPinnedApps"];
        }];
        icon.menu = [UIMenu menuWithTitle:entry[@"name"] ?: @"App" children:running ? @[open, close, pin] : @[open, pin]];
        [icons addArrangedSubview:icon];
    }
    if (entries.count == 0) {
        UILabel *empty = [UILabel new]; empty.text = @"No open apps"; empty.numberOfLines = 2; empty.textAlignment = NSTextAlignmentCenter; empty.font = [UIFont systemFontOfSize:12]; empty.textColor = UIColor.secondaryLabelColor;
        [icons addArrangedSubview:empty];
    }
    [stack addArrangedSubview:[self button:@"Minimize" action:^{ [weakSelf request:@"minimize"]; }]];
    [NSLayoutConstraint activateConstraints:@[
        [glass.trailingAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.trailingAnchor constant:-8],
        [glass.centerYAnchor constraintEqualToAnchor:controller.view.centerYAnchor],
        [glass.widthAnchor constraintEqualToConstant:96],
        [glass.heightAnchor constraintEqualToConstant:MIN(window.bounds.size.height * 0.72, MAX(230, entries.count * 84 + 152))],
        [stack.leadingAnchor constraintEqualToAnchor:glass.contentView.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:glass.contentView.trailingAnchor constant:-12],
        [stack.topAnchor constraintEqualToAnchor:glass.contentView.topAnchor constant:10],
        [stack.bottomAnchor constraintEqualToAnchor:glass.contentView.bottomAnchor constant:-10],
        [icons.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [icons.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [icons.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [icons.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [icons.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
    ]];
    self.previousKeyWindow = source;
    self.panel = window;
    [self installInWindow:window];
    [window makeKeyAndVisible];
}
@end
void StrataStartGuestControls(NSString *group, NSString *appName, BOOL separateProcess) {
    StrataStartGuestControlsWithIdentity(group, appName, separateProcess, nil);
}
void StrataStartGuestControlsWithIdentity(NSString *group, NSString *appName, BOOL separateProcess, NSString *key) {
    static StrataGuestControls *controls;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (controls) return;
        controls = [StrataGuestControls new];
        controls.group = group;
        controls.appName = appName.lastPathComponent ?: @"Strata";
        controls.currentKey = key;
        controls.separateProcess = separateProcess;
        controls.installedWindows = [NSHashTable weakObjectsHashTable];
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            if (controls.panel) return;
            for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (![scene isKindOfClass:UIWindowScene.class]) continue;
                for (UIWindow *window in scene.windows) if (window.isKeyWindow) { [controls saveSnapshotOfWindow:window]; return; }
            }
        }];
        [NSNotificationCenter.defaultCenter addObserverForName:UIWindowDidBecomeVisibleNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            if ([note.object isKindOfClass:UIWindow.class]) [controls installInWindow:note.object];
        }];
        for (UIWindow *window in UIApplication.sharedApplication.windows) [controls installInWindow:window];
        for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *window in scene.windows) [controls installInWindow:window];
        }
    });
}

void StrataToggleHostControls(UIWindow *window) {
    static StrataGuestControls *host;
    if (!window) return;
    if (!host) {
        host = [StrataGuestControls new]; host.group = [LCSharedUtils appGroupID]; host.appName = @"Strata";
        host.hostMode = YES; host.installedWindows = [NSHashTable weakObjectsHashTable];
    }
    host.currentKey = strataFrontKeyProvider ? strataFrontKeyProvider() : nil;
    [host toggleFromWindow:window];
}
