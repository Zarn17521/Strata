#import <objc/runtime.h>
#import "StrataGuestControls.h"
#import "LCSharedUtils.h"
#import "utils.h"
#import <UIKit/UIKit.h>
#import <unistd.h>
#import <math.h>
#import "StrataNxBuiltinSkin.h"

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
// Artwork pixel centres (not the guest's native button positions).
// Portrait 923x2000: measured from IMG_7621; landscape 1792x1008:
// measured from IMG_7623. Keep ALL remapping and artwork hit-tests tied
// to these exact centres so changes cannot drift between methods.
// The imported image still has its original A/B/X/Y diamond above the
// right look stick. Swap their artwork, THEN move input hit centres by the
// identical offset. The visual and actual controls must never diverge.
static CGPoint StrataArtOriginalFaceCentre(BOOL landscape, int b) {
    static const CGFloat portraitX[4] = {0.8743, 0.7469, 0.7482, 0.6169}; // A B X Y
    static const CGFloat portraitY[4] = {0.6459, 0.7041, 0.5817, 0.6459};
    static const CGFloat landscapeX[4] = {0.8856, 0.8401, 0.8401, 0.7945};
    static const CGFloat landscapeY[4] = {0.3613, 0.4411, 0.2804, 0.3613};
    b = MAX(0, MIN(b, 3));
    return CGPointMake(landscape ? landscapeX[b] : portraitX[b],
                       landscape ? landscapeY[b] : portraitY[b]);
}
static CGPoint StrataArtOriginalFaceGroupCentre(BOOL landscape) {
    return landscape ? CGPointMake(0.8401, 0.3613)
                     : CGPointMake(0.7466, 0.6449);
}
static CGPoint StrataArtOriginalRightStickCentre(BOOL landscape) {
    return landscape ? CGPointMake(0.8381, 0.6185)
                     : CGPointMake(0.7469, 0.8361);
}
static CGPoint StrataArtFaceCentre(BOOL landscape, int b) {
    CGPoint c = StrataArtOriginalFaceCentre(landscape, b);
    CGPoint from = StrataArtOriginalFaceGroupCentre(landscape);
    CGPoint to = StrataArtOriginalRightStickCentre(landscape);
    return CGPointMake(c.x + to.x - from.x, c.y + to.y - from.y);
}
static CGPoint StrataArtDpadCentre(BOOL landscape) {
    return landscape ? CGPointMake(0.1590, 0.3620) : CGPointMake(0.2490, 0.6460);
}
static CGPoint StrataArtStickCentre(BOOL landscape, BOOL right) {
    if (right) return StrataArtOriginalFaceGroupCentre(landscape);
    return landscape ? CGPointMake(0.1590, 0.6161)
                     : CGPointMake(0.2438, 0.8379);
}
static CGPoint StrataArtGearCentre(BOOL landscape) {
    return landscape ? CGPointMake(0.4999, 0.7982) : CGPointMake(0.4999, 0.9363);
}
static NSInteger StrataNxArtRole(CGPoint p, BOOL landscape) {
    if (!isfinite(p.x) || !isfinite(p.y)) return StrataArtNoMapping;
    if (landscape) {
        if (StrataArtNear(p, 0.1430, 0.1804, 0.026, 0.025)) return StrataArtL;
        if (StrataArtNear(p, 0.2146, 0.1804, 0.026, 0.025)) return StrataArtZL;
        if (StrataArtNear(p, 0.8126, 0.1827, 0.026, 0.025)) return StrataArtR;
        if (StrataArtNear(p, 0.8628, 0.1827, 0.026, 0.025)) return StrataArtZR;
        if (StrataArtNear(p, 0.4122, 0.7982, 0.025, 0.038)) return StrataArtMinus;
        if (StrataArtNear(p, 0.5869, 0.7994, 0.025, 0.038)) return StrataArtPlus;
    } else {
        if (StrataArtNear(p, 0.119, 0.504, 0.081, 0.024)) return StrataArtL;
        if (StrataArtNear(p, 0.283, 0.504, 0.081, 0.024)) return StrataArtZL;
        if (StrataArtNear(p, 0.719, 0.504, 0.081, 0.024)) return StrataArtR;
        if (StrataArtNear(p, 0.879, 0.504, 0.081, 0.024)) return StrataArtZR;
        if (StrataArtNear(p, 0.3452, 0.9357, 0.058, 0.035)) return StrataArtMinus;
        if (StrataArtNear(p, 0.6559, 0.9339, 0.058, 0.035)) return StrataArtPlus;
    }
    for (int b = 0; b < 4; b++) {
        CGPoint f = StrataArtFaceCentre(landscape, b);
        if (StrataArtNear(p, f.x, f.y, landscape ? 0.029 : 0.074,
                        landscape ? 0.048 : 0.038)) return StrataArtFace;
    }
    CGPoint d = StrataArtDpadCentre(landscape);
    if (StrataArtNear(p, d.x, d.y, landscape ? 0.061 : 0.180,
                      landscape ? 0.106 : 0.097)) return StrataArtDpad;
    for (int i = 0; i < 2; i++) {
        CGPoint s = StrataArtStickCentre(landscape, i == 1);
        if (StrataArtNear(p, s.x, s.y, landscape ? 0.049 : 0.143,
                          landscape ? 0.090 : 0.069))
            return i ? StrataArtRightStick : StrataArtLeftStick;
    }
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
    // Portrait: fit the whole handheld; landscape: cover every screen pixel.
    // On wide iPhones, the 1792x1008 art is cropped centrally at the top
    // and bottom (never stretched). The same frame is used by rendering,
    // the game aperture, input hit-testing and skin touch remapping.
    BOOL landscapeArtwork = image.size.width > image.size.height;
    CGFloat sx = bounds.size.width / image.size.width;
    CGFloat sy = bounds.size.height / image.size.height;
    // Crop only the source image's outer black gutter in landscape. All
    // screen-aperture and touch positions use this SAME transformed frame.
    // Legacy JPEG artwork needs gutter crop. Built-in vectors have no
    // baked black gutters, so aspect-fill alone reaches every display edge
    // without cropping the shoulder buttons.
    CGFloat scale = landscapeArtwork
        ? MAX(sx, sy) * (StrataNxIsBuiltinImage(image) ? 1.0 : 1.12)
        : MIN(sx, sy);
    CGSize fit = CGSizeMake(image.size.width*scale, image.size.height*scale);
    return CGRectMake(CGRectGetMidX(bounds)-fit.width/2,
                      CGRectGetMidY(bounds)-fit.height/2,fit.width,fit.height);
}
// Exact visible game opening cut out of the imported artwork. Shared by
// Metal-view layout and skin drawing: they MUST use the same rectangle.
static CGRect StrataNxArtworkAperture(CGRect bounds, UIImage *image) {
    if (!image || CGRectIsEmpty(bounds)) return CGRectNull;
    CGRect art = StrataNxArtworkFrame(bounds, image);
    BOOL portrait = bounds.size.height > bounds.size.width;
    CGRect hole = portrait
        ? CGRectMake(CGRectGetMinX(art) + art.size.width * (37.0/923.0),
                     CGRectGetMinY(art) + art.size.height * (138.0/2000.0),
                     art.size.width * (847.0/923.0),
                     art.size.height * (661.0/2000.0))
        : CGRectMake(CGRectGetMinX(art) + art.size.width * (463.0/1792.0),
                     CGRectGetMinY(art) + art.size.height * (169.0/1008.0),
                     art.size.width * (863.0/1792.0),
                     art.size.height * (574.0/1008.0));
    return CGRectIntersection(hole, bounds);
}
static CGRect StrataNxArtworkFrameInPad(UIView *pad, UIImage *image) {
    UIView *skin = [pad.superview viewWithTag:877144];
    if (!skin) return StrataNxArtworkFrame(pad.bounds, image);
    // The artwork belongs to the sibling skin overlay, NOT DmGamepad.
    // Convert its displayed rect to pad coordinates (handles safe areas,
    // asymmetric game layouts and any future root-view offsets).
    return [pad convertRect:StrataNxArtworkFrame(skin.bounds, image) fromView:skin];
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
    CGRect artFrame = StrataNxArtworkFrameInPad(view, (UIImage *)activeImage);
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
            int closest = 0; CGFloat best = CGFLOAT_MAX;
            for (int i = 0; i < 4; i++) {
                CGPoint f = StrataArtFaceCentre(landscape, i);
                CGFloat dx = (p.x - f.x) / (landscape ? 0.029 : 0.074);
                CGFloat dy = (p.y - f.y) / (landscape ? 0.048 : 0.038);
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
            CGPoint d = StrataArtDpadCentre(landscape);
            CGFloat dx = fmax(-1, fmin(1, (p.x - d.x) / (landscape ? 0.052 : 0.145)));
            CGFloat dy = fmax(-1, fmin(1, (p.y - d.y) / (landscape ? 0.086 : 0.078)));
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
            CGPoint s = StrataArtStickCentre(landscape, YES);
            CGFloat dx = fmax(-1, fmin(1, (p.x-s.x)/(landscape ? 0.040 : 0.110)));
            CGFloat dy = fmax(-1, fmin(1, (p.y-s.y)/(landscape ? 0.073 : 0.055)));
            return CGPointMake(home.x+dx*radius*0.82, home.y+dy*radius*0.82);
        }
        case StrataArtLeftStick: {
            CGPoint c = StrataArtNativePoint(view, @selector(stickHome));
            CGFloat radius = StrataArtNativeRadius(view, 0);
            if (!isfinite(c.x) || radius <= 0) return original;
            CGPoint s = StrataArtStickCentre(landscape, NO);
            CGFloat dx = fmax(-1, fmin(1, (p.x - s.x) / (landscape ? 0.040 : 0.110)));
            CGFloat dy = fmax(-1, fmin(1, (p.y - s.y) / (landscape ? 0.073 : 0.055)));
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
    CGRect artFrame = StrataNxArtworkFrameInPad(self.pad, image);
    CGPoint normalized = CGPointMake((p.x-artFrame.origin.x)/MAX(artFrame.size.width,1),
                                      (p.y-artFrame.origin.y)/MAX(artFrame.size.height,1));
    CGPoint gear = StrataArtGearCentre(landscape);
    return StrataArtNear(normalized, gear.x, gear.y,
                         landscape ? 0.030 : 0.052,
                         landscape ? 0.042 : 0.035);
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
// NxNative paints its buttons in _controls, but its full-screen DmGamepad UIView
// STILL hit-tests the invisible native controls. Only accept touches inside
// imported artwork buttons; keep the engine to own those touches and publish HID.
static UIView *(*StrataOldNxPadHitTest)(id, SEL, CGPoint, UIEvent *) = NULL;
static UIView *StrataNxPadHitTest(id pad, SEL selector, CGPoint point, UIEvent *event) {
    UIView *hit = StrataOldNxPadHitTest
        ? StrataOldNxPadHitTest(pad, selector, point, event) : nil;
    UIView *view = (UIView *)pad;
    if (hit != view || !objc_getAssociatedObject(pad, &StrataNxPadArtTouchEnabledKey))
        return hit; // preserve the real artwork menu button and non-skin games
    BOOL landscape = view.bounds.size.width > view.bounds.size.height;
    UIView *skin = [view.superview viewWithTag:877144];
    UIImage *image = [skin valueForKey:landscape ? @"landscapeArtwork" : @"portraitArtwork"];
    if (!image) return hit; // no artwork for this orientation: native fallback
    CGRect artFrame = StrataNxArtworkFrameInPad(view, image);
    if (CGRectIsEmpty(artFrame)) return hit;
    CGPoint artPoint = CGPointMake((point.x - artFrame.origin.x)/artFrame.size.width,
                                  (point.y - artFrame.origin.y)/artFrame.size.height);
    // No mapping = NO input. In particular, no invisible native buttons
    // underneath the skin's game viewport or in the unused margins.
    if (StrataNxArtRole(artPoint, landscape) == StrataArtNoMapping) return nil;
    return hit;
}
static void (*StrataOldNxTouchesBegan)(id, SEL, NSSet<UITouch *> *, UIEvent *);
static void (*StrataOldNxTouchesMoved)(id, SEL, NSSet<UITouch *> *, UIEvent *);
static void (*StrataOldNxTouchesEnded)(id, SEL, NSSet<UITouch *> *, UIEvent *);
static void (*StrataOldNxTouchesCancelled)(id, SEL, NSSet<UITouch *> *, UIEvent *);

// NxNative renders virtual keys into a dedicated CALayer, separate from the
// DmGamepad UIView that dispatches touch HID. Hide that artwork layer (not the
// UIView: the engine still owns skin button touches). StrataNxPadHitTest
// separately blocks the invisible native touch regions when artwork is active.
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
    BOOL physicalPad = NO;
    @try { physicalPad = [[pad valueForKey:@"padOff"] boolValue]; }
    @catch (__unused NSException *e) {}
    controls.hidden = image != nil || physicalPad;
    // The gear is a separate UIButton (outside _controls): remove its native
    // drawing but leave the real UIButton and its menu actions intact.
    UIView *menu = nil;
    for (UIView *child in pad.subviews)
        if ([NSStringFromClass(child.class) isEqualToString:@"DmMenuButton"]) {
            menu = child; break;
        }
    if (menu) {
        if (image) {
            // A UIButton's imageView can use more than one layer; hide all
            // native gear artwork, not its UIKit touch system.
            menu.layer.opacity = 0;
            menu.backgroundColor = UIColor.clearColor;
            menu.layer.borderWidth = 0;
            menu.layer.shadowOpacity = 0;
            menu.tintColor = UIColor.clearColor;
            menu.layer.sublayers.firstObject.opacity = 0;
        } else {
            menu.layer.opacity = 1;
            // Moving from an imported skin to an orientation without artwork
            // must restore the original native gear appearance and hit target.
            menu.backgroundColor = [UIColor colorWithWhite:1 alpha:0.14];
            menu.layer.borderWidth = 1.5;
            menu.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.38].CGColor;
            menu.layer.shadowOpacity = 0.2;
            menu.tintColor = [UIColor colorWithWhite:1 alpha:0.6];
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
    CGRect frame = StrataNxArtworkFrameInPad(pad, image);
    for (UITouch *touch in touches) {
        CGPoint native = StrataOriginalLocationInView(touch, @selector(locationInView:), pad);
        CGPoint p = CGPointMake((native.x-frame.origin.x)/MAX(frame.size.width,1),
                                (native.y-frame.origin.y)/MAX(frame.size.height,1));
        NSInteger role = StrataNxArtRole(p, landscape);
        objc_setAssociatedObject(touch, &StrataNxTouchArtRoleKey,
                                @(role), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        // No synchronous NSLog in the touch hot path: first-frame input
        // must not stall for console I/O on memory-constrained iPhones.
    }
}
static void StrataNxTouchBegan(id pad, SEL selector, NSSet<UITouch *> *touches, UIEvent *event) {
    // Prime touch mapping before the guest reads UITouch, then dispatch to
    // the original HID handler IMMEDIATELY. Artwork feedback comes after.
    // Do not repeat expensive KVC / applyLayout on every single tap.
    StrataNxPrimeArtTouchRoles((UIView *)pad, touches);
    if (StrataOldNxTouchesBegan) StrataOldNxTouchesBegan(pad, selector, touches, event);
    StrataNxSkinTouchVisual(pad, touches, NO);
}
static void StrataNxTouchMoved(id pad, SEL selector, NSSet<UITouch *> *touches, UIEvent *event) {
    // Motion input takes priority over visual tracking.
    if (StrataOldNxTouchesMoved) StrataOldNxTouchesMoved(pad, selector, touches, event);
    StrataNxSkinTouchVisual(pad, touches, NO);
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
        Method hit = class_getInstanceMethod(padClass, @selector(hitTest:withEvent:));
        if (hit) {
            StrataOldNxPadHitTest = (void *)method_getImplementation(hit);
            method_setImplementation(hit, (IMP)StrataNxPadHitTest);
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
    // The actual native UIMenu is attached to a transparent UIButton at
    // the artwork's gear position by StrataNxUpdateGameMenuButton below.
    // A separate tap gesture calling TouchUpInside did not present the UIMenu.
    NSLog(@"[Strata] NxNative white art touch targets mapped to native DmGamepad");
}

static NSString * const StrataNxSkinToggleKey = @"StrataNxSkinEnabled";
static NSString * const StrataNxSkinStyleKey = @"StrataNxSkinStyle";
static BOOL StrataNxSkinIsEnabled(NSString *group) {
    if (!group.length) return NO;
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:group];
    // Built-in Pearl Light is the default; preserve explicit Skin OFF choices.
    return [defaults objectForKey:StrataNxSkinToggleKey]
        ? [defaults boolForKey:StrataNxSkinToggleKey] : YES;
}
static const NSInteger StrataNxSkinViewTag = 877144;

// Press feedback uses the EXACT control geometry of the touch remapper,
// with no extra view hitboxes or replacement input handler.
static CGPoint StrataNxPressCentre(CGPoint p, NSInteger role, BOOL land) {
    switch (role) {
        case StrataArtFace: {
            CGFloat best=CGFLOAT_MAX; CGPoint point=CGPointZero;
            for (int i=0;i<4;i++) {
                CGPoint f=StrataArtFaceCentre(land,i);
                CGFloat dx=(p.x-f.x)/(land?0.029:0.074);
                CGFloat dy=(p.y-f.y)/(land?0.048:0.038);
                CGFloat score=dx*dx+dy*dy;
                if (score<best) { best=score;point=f; }
            }
            return point;
        }
        case StrataArtDpad: {
            CGPoint d=StrataArtDpadCentre(land);
            CGFloat dx=(p.x-d.x)/(land?0.052:0.145);
            CGFloat dy=(p.y-d.y)/(land?0.086:0.078);
            if (fabs(dx)>fabs(dy))
                d.x+=(dx>=0?1:-1)*(land?0.030:0.065);
            else
                d.y+=(dy>=0?1:-1)*(land?0.050:0.046);
            return d;
        }
        case StrataArtLeftStick: case StrataArtRightStick: {
            CGPoint s=StrataArtStickCentre(land,role==StrataArtRightStick);
            CGFloat dx=MAX(-1,MIN(1,(p.x-s.x)/(land?0.040:0.110)));
            CGFloat dy=MAX(-1,MIN(1,(p.y-s.y)/(land?0.073:0.055)));
            s.x+=dx*(land?0.012:0.026);
            s.y+=dy*(land?0.020:0.018);
            return s;
        }
        case StrataArtL: return land?CGPointMake(0.1430,0.1804):CGPointMake(0.119,0.504);
        case StrataArtZL: return land?CGPointMake(0.2146,0.1804):CGPointMake(0.283,0.504);
        case StrataArtR: return land?CGPointMake(0.8126,0.1827):CGPointMake(0.719,0.504);
        case StrataArtZR: return land?CGPointMake(0.8628,0.1827):CGPointMake(0.879,0.504);
        case StrataArtMinus: return land?CGPointMake(0.4122,0.7982):CGPointMake(0.3452,0.9357);
        case StrataArtPlus: return land?CGPointMake(0.5869,0.7994):CGPointMake(0.6559,0.9339);
        default: return CGPointMake(NAN,NAN);
    }
}
static CGRect StrataNxPressFrame(CGRect art, CGPoint p, NSInteger role, BOOL land) {
    CGPoint centre=StrataNxPressCentre(p,role,land);
    if (!isfinite(centre.x)||!isfinite(centre.y)) return CGRectNull;
    CGFloat w=art.size.width,h=art.size.height,width=0,height=0;
    switch (role) {
        case StrataArtL: case StrataArtZL: case StrataArtR: case StrataArtZR:
            width=w*(land?0.046:0.135);height=h*(land?0.035:0.016);break;
        case StrataArtMinus: case StrataArtPlus:
            width=w*(land?0.036:0.075);height=h*(land?0.059:0.027);break;
        case StrataArtDpad:
            width=w*(land?0.035:0.077);height=h*(land?0.066:0.035);break;
        case StrataArtLeftStick: case StrataArtRightStick: {
            CGFloat side=MIN(w*(land?0.069:0.118),h*(land?0.116:0.054));
            width=side;height=side;break;
        }
        case StrataArtFace:
            width=w*(land?0.050:0.119);height=h*(land?0.088:0.055);break;
        default: return CGRectNull;
    }
    width=MAX(9,width);height=MAX(9,height);
    return CGRectMake(CGRectGetMinX(art)+centre.x*w-width*0.5,
                      CGRectGetMinY(art)+centre.y*h-height*0.5,width,height);
}

@interface StrataNxSkinView : UIView
@property(nonatomic, strong) UIImage *portraitArtwork;
@property(nonatomic, strong) UIImage *landscapeArtwork;
@property(nonatomic) BOOL darkTheme;
@property(nonatomic, weak) UIView *mappedPad;
@property(nonatomic, strong) NSMutableDictionary<NSValue *, CAGradientLayer *> *pressLayers;
@property(nonatomic, strong) NSMutableArray<CAGradientLayer *> *sparePressLayers;
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
        self.pressLayers=[NSMutableDictionary new];
        self.sparePressLayers=[NSMutableArray arrayWithCapacity:10];
        // Pool GPU-composited pearl/champagne texture layers BEFORE gameplay.
        // No allocations, glow shadow or skin bitmap redraw on every press.
        for (NSUInteger i=0;i<10;i++) {
            CAGradientLayer *shine=[CAGradientLayer layer];
            shine.colors=@[
                (__bridge id)[UIColor colorWithWhite:1 alpha:0.62].CGColor,
                (__bridge id)[UIColor colorWithWhite:1 alpha:0.24].CGColor,
                (__bridge id)[UIColor colorWithRed:0.88 green:0.80 blue:0.64 alpha:0.14].CGColor
            ];
            shine.locations=@[@0.0,@0.46,@1.0];
            shine.startPoint=CGPointMake(0.25,0);
            shine.endPoint=CGPointMake(0.70,1);
            shine.borderColor=[UIColor colorWithRed:0.77 green:0.65 blue:0.44 alpha:0.55].CGColor;
            shine.borderWidth=0.85;
            shine.masksToBounds=YES;
            shine.opacity=0;
            shine.zPosition=2;
            shine.actions=@{@"position":[NSNull null],@"bounds":[NSNull null],
                            @"opacity":[NSNull null],@"transform":[NSNull null],
                            @"cornerRadius":[NSNull null]};
            [self.layer addSublayer:shine];
            [self.sparePressLayers addObject:shine];
        }
        self.accessibilityIdentifier = @"strata.nxnative.cosmetic-skin";
    }
    return self;
}
- (void)setDarkTheme:(BOOL)darkTheme {
    _darkTheme = darkTheme;
    // Recolor the pooled, zero-hit-test premium press texture to match the
    // selected built-in Pearl Light / graphite glass controls.
    NSArray *colors = darkTheme ? @[
        (__bridge id)[UIColor colorWithRed:0.75 green:0.81 blue:0.88 alpha:0.39].CGColor,
        (__bridge id)[UIColor colorWithRed:0.59 green:0.65 blue:0.73 alpha:0.28].CGColor,
        (__bridge id)[UIColor colorWithRed:0.33 green:0.40 blue:0.48 alpha:0.16].CGColor
    ] : @[
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.62].CGColor,
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.24].CGColor,
        (__bridge id)[UIColor colorWithRed:0.88 green:0.80 blue:0.64 alpha:0.14].CGColor
    ];
    UIColor *edge = darkTheme
        ? [UIColor colorWithRed:0.57 green:0.64 blue:0.72 alpha:0.53]
        : [UIColor colorWithRed:0.77 green:0.65 blue:0.44 alpha:0.55];
    for (CAGradientLayer *layer in self.sparePressLayers) {
        layer.colors = colors;
        layer.borderColor = edge.CGColor;
    }
}
- (void)layoutSubviews {
    [super layoutSubviews];
    [self setNeedsDisplay];
}
- (void)strataTrackTouches:(NSSet<UITouch *> *)touches ending:(BOOL)ending {
    UIView *pad=self.mappedPad;
    if (!pad||!self.superview||touches.count==0) return;
    BOOL land=self.bounds.size.width>self.bounds.size.height;
    UIImage *image=land?self.landscapeArtwork:self.portraitArtwork;
    if (!image) return;
    CGRect art=StrataNxArtworkFrame(self.bounds,image);
    if (CGRectIsEmpty(art)) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (UITouch *touch in touches) {
        NSValue *key=[NSValue valueWithNonretainedObject:touch];
        CAGradientLayer *shine=self.pressLayers[key];
        if (ending) {
            if (!shine) continue;
            // Native touch-up already completed; release sheen never delays HID.
            [shine removeAllAnimations];
            CABasicAnimation *fade=[CABasicAnimation animationWithKeyPath:@"opacity"];
            fade.fromValue=@(shine.opacity);fade.toValue=@0;
            fade.duration=0.075;
            fade.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            shine.opacity=0;
            [shine addAnimation:fade forKey:@"zn.press.release"];
            [self.pressLayers removeObjectForKey:key];
            [self.sparePressLayers addObject:shine];
            continue;
        }
        NSNumber *number=objc_getAssociatedObject(touch,&StrataNxTouchArtRoleKey);
        NSInteger role=number?number.integerValue:StrataArtNoMapping;
        if (role==StrataArtNoMapping) continue;
        BOOL moving=role==StrataArtLeftStick||role==StrataArtRightStick||
                    role==StrataArtFace||role==StrataArtDpad;
        if (shine&&!moving) continue; // no work each frame for digital keys
        CGPoint raw=StrataOriginalLocationInView
            ? StrataOriginalLocationInView(touch,@selector(locationInView:),pad)
            : [touch locationInView:pad];
        CGPoint local=[self convertPoint:raw fromView:pad];
        CGPoint norm=CGPointMake((local.x-art.origin.x)/art.size.width,
                                 (local.y-art.origin.y)/art.size.height);
        if (!isfinite(norm.x)||!isfinite(norm.y)) continue;
        CGRect frame=StrataNxPressFrame(art,norm,role,land);
        if (CGRectIsNull(frame)||CGRectIsEmpty(frame)) continue;
        if (!shine) {
            shine=self.sparePressLayers.lastObject;
            if (!shine) continue; // gameplay still accepts every extra touch
            [self.sparePressLayers removeLastObject];
            self.pressLayers[key]=shine;
            [shine removeAllAnimations];
        }
        shine.frame=frame;
        shine.cornerRadius=MIN(frame.size.width,frame.size.height)*
                           ((role==StrataArtL||role==StrataArtZL||
                             role==StrataArtR||role==StrataArtZR)?0.42:0.50);
        shine.transform=CATransform3DMakeScale(0.94,0.94,1);
        shine.opacity=0.92;
    }
    [CATransaction commit];
}
// All rectangles below use the SAME normalized artwork coordinates as the
// actual DmGamepad touch map, not physical iPhone point coordinates.
static CGRect StrataNxArtRect(CGRect art, CGRect n) {
    return CGRectMake(art.origin.x + n.origin.x * art.size.width,
                      art.origin.y + n.origin.y * art.size.height,
                      n.size.width * art.size.width,
                      n.size.height * art.size.height);
}
static CGRect StrataNxArtOffset(CGRect n, CGPoint shift) {
    return CGRectOffset(n, shift.x, shift.y);
}

// Draw a small crop of the ORIGINAL imported image at its new location.
// Do not overwrite or mutate the user's imported JPG/PNG on disk.
static void StrataNxDrawArtCrop(UIImage *image, CGRect sourceNorm,
                                 CGRect destinationNorm, CGRect art) {
    CGImageRef original = image.CGImage;
    if (!original) return;
    size_t pxW = CGImageGetWidth(original), pxH = CGImageGetHeight(original);
    CGRect sourcePx = CGRectIntegral(CGRectMake(sourceNorm.origin.x * pxW,
                                               sourceNorm.origin.y * pxH,
                                               sourceNorm.size.width * pxW,
                                               sourceNorm.size.height * pxH));
    CGRect imageBounds = CGRectMake(0, 0, pxW, pxH);
    sourcePx = CGRectIntersection(sourcePx,imageBounds);
    if (CGRectIsNull(sourcePx) || CGRectIsEmpty(sourcePx)) return;
    CGImageRef crop = CGImageCreateWithImageInRect(original,sourcePx);
    if (!crop) return;
    UIImage *patch = [UIImage imageWithCGImage:crop scale:image.scale
                                  orientation:UIImageOrientationUp];
    CGRect dest = StrataNxArtRect(art,destinationNorm);
    CGContextSaveGState(UIGraphicsGetCurrentContext());
    [[UIBezierPath bezierPathWithRoundedRect:dest
                              cornerRadius:MIN(dest.size.width,dest.size.height)*0.18] addClip];
    [patch drawInRect:dest];
    CGContextRestoreGState(UIGraphicsGetCurrentContext());
    CGImageRelease(crop);
}

static void StrataNxDrawRearrangedArtwork(UIImage *image, CGRect art,
                                           BOOL landscape, BOOL darkTheme) {
    if (!image || !image.CGImage) return;
    // Face diamond and right thumbstick from the supplied white-shell art.
    // Portrait and landscape both move actual art, not just invisible hitboxes.
    CGRect face = landscape ? CGRectMake(0.751,0.215,0.178,0.280)
                            : CGRectMake(0.532,0.540,0.416,0.209);
    CGRect look = landscape ? CGRectMake(0.768,0.510,0.145,0.228)
                            : CGRectMake(0.591,0.764,0.308,0.153);
    CGPoint from = StrataArtOriginalFaceGroupCentre(landscape);
    CGPoint to = StrataArtOriginalRightStickCentre(landscape);
    CGPoint delta = CGPointMake(to.x-from.x,to.y-from.y);
    CGRect destFace = StrataNxArtOffset(face,delta);
    CGRect destLook = StrataNxArtOffset(look,CGPointMake(-delta.x,-delta.y));

    // Clear the two original positions first, otherwise both controls remain
    // visible under the newly repositioned artwork.
    // Photo-derived AMOLED art needs a black/graphite erasure surface;
    // previously the white-only patch created glaring squares on dark.
    UIColor *shell = darkTheme ? StrataNxBuiltShell(YES)
                               : [UIColor colorWithWhite:0.970 alpha:1];
    [shell setFill];
    for (NSValue *v in @[[NSValue valueWithCGRect:StrataNxArtRect(art,face)],
                        [NSValue valueWithCGRect:StrataNxArtRect(art,look)]]) {
        CGRect r = v.CGRectValue;
        [[UIBezierPath bezierPathWithRoundedRect:CGRectInset(r,-1,-1)
                                   cornerRadius:MIN(r.size.width,r.size.height)*0.18] fill];
    }
    // Draw from the unmodified file, so the patches never recursively copy
    // an earlier swap. The original artwork remains available in Settings.
    StrataNxDrawArtCrop(image,look,destLook,art);
    StrataNxDrawArtCrop(image,face,destFace,art);

    // R and ZR are the RIGHT-hand shoulder pair visible in the example;
    // swap the printed glyphs to match their swapped native touch roles.
    const CGFloat leftX = landscape ? 0.8126 : 0.7190;
    const CGFloat rightX = landscape ? 0.8628 : 0.8790;
    const CGFloat y = landscape ? 0.1827 : 0.5040;
    CGFloat size = MIN(art.size.width*(landscape ? 0.013 : 0.038),
                       art.size.height*(landscape ? 0.036 : 0.019));
    UIFont *font = [UIFont systemFontOfSize:MAX(8,size) weight:UIFontWeightMedium];
    NSArray<NSString *> *labels = @[@"R",@"ZR"];
    for (int i=0; i<2; i++) {
        CGPoint centre = CGPointMake(art.origin.x+(i ? rightX:leftX)*art.size.width,
                                    art.origin.y+y*art.size.height);
        CGRect erase = CGRectMake(centre.x - size*1.02,centre.y-size*0.66,
                                  size*2.04,size*1.32);
        UIColor *labelGround = darkTheme
            ? [UIColor colorWithRed:0.25 green:0.28 blue:0.32 alpha:1]
            : [UIColor colorWithWhite:0.965 alpha:1];
        [labelGround setFill];
        [[UIBezierPath bezierPathWithRoundedRect:erase cornerRadius:size*0.2] fill];
        NSString *label = labels[i];
        CGSize textSize = [label sizeWithAttributes:@{NSFontAttributeName:font}];
        [label drawAtPoint:CGPointMake(centre.x-textSize.width*0.5,
                                      centre.y-textSize.height*0.5)
           withAttributes:@{NSFontAttributeName:font,
                            NSForegroundColorAttributeName:darkTheme
                                ? [UIColor whiteColor]
                                : [UIColor colorWithWhite:0.43 alpha:1]}];
    }
}

// Small ZN's LIBRARY motif on the LOWER LEFT of the shell, matching the
// launcher's gold Z, jade N and green tilted Link cap. Kept away from D-pad,
// sticks and menu hitboxes. It is purely artwork, never an input target.
// Pixel-for-pixel shape coordinates from the SwiftUI ZN's LIBRARY header,
// rendered at a compact size on the LOWER LEFT of the imported controller.
static void StrataNxPaintLogoPath(UIBezierPath *path, CGRect target,
                                  UIColor *color) {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx || CGRectIsEmpty(target)) return;
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx,target.origin.x,target.origin.y);
    CGContextScaleCTM(ctx,target.size.width/100.0,target.size.height/100.0);
    [color setFill];
    [path fill];
    CGContextRestoreGState(ctx);
}
static void StrataNxDrawZNBrand(CGRect art, BOOL portrait) {
    CGFloat width = art.size.width * (portrait ? 0.160 : 0.075);
    CGFloat height = width * (43.0/74.0);
    CGFloat x = CGRectGetMinX(art) + art.size.width * (portrait ? 0.066 : 0.090);
    CGFloat y = CGRectGetMinY(art) + art.size.height * (portrait ? 0.923 : 0.758);
    CGRect frame = CGRectMake(x,y,width,height);

    UIBezierPath *z = [UIBezierPath bezierPath];
    [z moveToPoint:CGPointMake(5,36)];
    [z addQuadCurveToPoint:CGPointMake(20,6) controlPoint:CGPointMake(14,25)];
    for (NSValue *v in @[
      [NSValue valueWithCGPoint:CGPointMake(91,6)],
      [NSValue valueWithCGPoint:CGPointMake(100,0)],
      [NSValue valueWithCGPoint:CGPointMake(91,29)],
      [NSValue valueWithCGPoint:CGPointMake(85,29)],
      [NSValue valueWithCGPoint:CGPointMake(87,18)],
      [NSValue valueWithCGPoint:CGPointMake(77,18)],
      [NSValue valueWithCGPoint:CGPointMake(28,87)],
      [NSValue valueWithCGPoint:CGPointMake(91,87)],
      [NSValue valueWithCGPoint:CGPointMake(99,74)],
      [NSValue valueWithCGPoint:CGPointMake(97,100)],
      [NSValue valueWithCGPoint:CGPointMake(4,100)],
      [NSValue valueWithCGPoint:CGPointMake(11,86)],
      [NSValue valueWithCGPoint:CGPointMake(66,18)],
      [NSValue valueWithCGPoint:CGPointMake(29,18)]
    ]) [z addLineToPoint:v.CGPointValue];
    [z closePath];
    // Cut the same ornamental notches used on the library header.
    [z moveToPoint:CGPointMake(63,51)];
    [z addLineToPoint:CGPointMake(70,45)];
    [z addLineToPoint:CGPointMake(66,59)];
    [z closePath];
    [z moveToPoint:CGPointMake(50,71)];
    [z addLineToPoint:CGPointMake(56,63)];
    [z addLineToPoint:CGPointMake(55,76)];
    [z closePath];
    z.usesEvenOddFillRule = YES;

    UIBezierPath *n = [UIBezierPath bezierPath];
    [n appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(10,10,14,80)]];
    [n appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(76,10,14,80)]];
    [n moveToPoint:CGPointMake(19,10)];
    [n addLineToPoint:CGPointMake(35,10)];
    [n addLineToPoint:CGPointMake(83,89)];
    [n addLineToPoint:CGPointMake(66,89)];
    [n closePath];
    for (NSValue *v in @[
      [NSValue valueWithCGRect:CGRectMake(2,5,31,8)],
      [NSValue valueWithCGRect:CGRectMake(3,88,31,9)],
      [NSValue valueWithCGRect:CGRectMake(67,5,31,8)],
      [NSValue valueWithCGRect:CGRectMake(67,88,31,9)]
    ]) [n appendPath:[UIBezierPath bezierPathWithRect:v.CGRectValue]];

    UIBezierPath *hat = [UIBezierPath bezierPath];
    [hat moveToPoint:CGPointMake(14,69)];
    [hat addCurveToPoint:CGPointMake(57,18)
           controlPoint1:CGPointMake(23,38)
           controlPoint2:CGPointMake(43,14)];
    [hat addCurveToPoint:CGPointMake(92,63)
           controlPoint1:CGPointMake(73,19)
           controlPoint2:CGPointMake(89,46)];
    [hat addQuadCurveToPoint:CGPointMake(73,77) controlPoint:CGPointMake(90,78)];
    [hat addQuadCurveToPoint:CGPointMake(21,78) controlPoint:CGPointMake(44,68)];
    [hat addQuadCurveToPoint:CGPointMake(4,34) controlPoint:CGPointMake(5,65)];
    [hat addQuadCurveToPoint:CGPointMake(28,52) controlPoint:CGPointMake(18,41)];
    [hat addLineToPoint:CGPointMake(14,69)];
    [hat closePath];

    UIColor *gold = [UIColor colorWithRed:0.70 green:0.43 blue:0.10 alpha:1];
    UIColor *jade = [UIColor colorWithRed:0.10 green:0.51 blue:0.35 alpha:1];
    UIColor *green = [UIColor colorWithRed:0.10 green:0.56 blue:0.23 alpha:1];
    StrataNxPaintLogoPath(z,CGRectMake(x+width*(3.0/74.0),y+height*(12.0/43.0),
                                       width*(32.0/74.0),height*(30.0/43.0)),gold);
    StrataNxPaintLogoPath(n,CGRectMake(x+width*(39.0/74.0),y+height*(12.0/43.0),
                                       width*(32.0/74.0),height*(30.0/43.0)),jade);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx,x-width/74.0,y);
    CGContextRotateCTM(ctx,(CGFloat)(-M_PI/18.0));
    StrataNxPaintLogoPath(hat,CGRectMake(0,0,width*(30.0/74.0),
                                            height*(19.0/43.0)),green);
    CGContextRestoreGState(ctx);
}

// Settings uses the exact same cached photograph and the very same
// Look/ABXY, R/ZR and ZN transforms as the running NxNative game. A vector
// mockup would give the user a misleading preview of the shipped skin.
UIImage *StrataNxSkinPreviewImage(BOOL portrait, BOOL dark) {
    static NSCache<NSString *, UIImage *> *previewCache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        previewCache = [NSCache new];
        previewCache.countLimit = 4;
        previewCache.totalCostLimit = 32 * 1024 * 1024;
    });
    NSString *key = [NSString stringWithFormat:@"photo-preview-%@-%@",
                     portrait ? @"portrait" : @"landscape",
                     dark ? @"amoled" : @"pearl"];
    UIImage *cached = [previewCache objectForKey:key];
    if (cached) return cached;

    UIImage *source = StrataNxBuiltinArtwork(portrait,dark);
    if (!source) return nil;
    CGSize size = source.size;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = YES;
    format.scale = 1;
    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    UIImage *result = [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *r) {
        CGRect art = CGRectMake(0,0,size.width,size.height);
        [StrataNxBuiltShell(dark) setFill];
        UIRectFill(art);
        CGContextRef ctx=UIGraphicsGetCurrentContext();
        if (!ctx) return;
        CGContextSaveGState(ctx);
        if (!StrataNxIsBuiltinImage(source)) {
            CGRect body=StrataNxArtRect(art,
                 portrait ? CGRectMake(0.025,0.015,0.950,0.970)
                          : CGRectMake(0.052,0.100,0.896,0.790));
            [[UIBezierPath bezierPathWithRoundedRect:body
                    cornerRadius:MIN(body.size.width,body.size.height)*
                                       (portrait?0.055:0.135)] addClip];
        }
        [source drawInRect:art];
        if (!StrataNxIsBuiltinImage(source))
            StrataNxDrawRearrangedArtwork(source,art,!portrait,dark);
        StrataNxDrawZNBrand(art,portrait);
        CGContextRestoreGState(ctx);
    }];
    if (result) [previewCache setObject:result forKey:key
        cost:(NSUInteger)(result.size.width*result.size.height*4)];
    return result;
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

    // The artwork overlay now sits ABOVE DmGameView. Cut out exactly the
    // skin's black opening, not the oversized game frame. The opaque shell
    // covers every pixel of aspect-FILL overscan outside the opening.
    UIImage *artwork = portrait ? self.portraitArtwork : self.landscapeArtwork;
    CGRect opening = artwork ? StrataNxArtworkAperture(bounds, artwork) : game;
    if (CGRectIsNull(opening) || CGRectIsEmpty(opening)) return;
    CGContextSaveGState(ctx);
    CGContextAddRect(ctx, bounds);
    // A tiny inward overlap prevents the Metal drawable from peeking past
    // the printed screen border because of fractional backing-pixel rounding.
    CGContextAddRect(ctx, CGRectInset(opening, 0.35, 0.35));
    CGContextEOClip(ctx);
    if (artwork) {
        // Cover even transparent parts of imported PNGs so the extra-wide
        // Metal drawable cannot leak around the handheld artwork.
        CGContextSetFillColorWithColor(ctx, StrataNxBuiltShell(self.darkTheme).CGColor);
        CGContextFillRect(ctx, bounds);
    }

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
        CGRect art = StrataNxArtworkFrame(bounds, image);
        // JPG skins have opaque BLACK gutters around the rounded white shell
        // that survive aspect-fill. Clip those gutters away; the white opaque
        // backing painted above remains, so landscape has no black exterior.
        CGRect body = StrataNxArtRect(
            art, portrait ? CGRectMake(0.025,0.015,0.950,0.970)
                          : CGRectMake(0.052,0.100,0.896,0.790));
        CGFloat radius = MIN(body.size.width,body.size.height) *
                         (portrait ? 0.055 : 0.135);
        CGContextSaveGState(ctx);
        BOOL builtIn = StrataNxIsBuiltinImage(image);
        if (!builtIn) {
            // Legacy imported JPG geometry retained for backward compatibility.
            [[UIBezierPath bezierPathWithRoundedRect:body cornerRadius:radius] addClip];
        }
        [image drawInRect:art];
        if (!builtIn) {
            // Custom imported art uses the original unmodified button positions.
            StrataNxDrawRearrangedArtwork(image,art,!portrait,self.darkTheme);
        }
        // Built-ins are already laid out with Look above ABXY. Do not
        // repaint white crop patches over the dark shell.
        StrataNxDrawZNBrand(art,portrait);
        CGContextRestoreGState(ctx);
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
    // Cached GPU layers now provide premium button/analog feedback; the
    // large imported skin bitmap is NEVER redrawn because of touch motion.
    CGContextRestoreGState(ctx);

    // A subtle screen edge follows the fixed opening, not the oversized game.
    CGRect displayEdge = artwork ? opening : game;
    CGContextSaveGState(ctx);
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.06 alpha:0.88].CGColor);
    CGContextSetLineWidth(ctx, 3.0);
    CGContextStrokeRect(ctx, CGRectInset(displayEdge, -0.5, -0.5));
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:1 alpha:0.38].CGColor);
    CGContextSetLineWidth(ctx, 1.0);
    CGContextStrokeRect(ctx, CGRectInset(displayEdge, -2.0, -2.0));
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

static const NSInteger StrataNxSkinMenuButtonTag = 877145;
static void StrataNxUpdateGameMenuButton(UIView *pad) {
    UIView *skin = [pad.superview viewWithTag:StrataNxSkinViewTag];
    if (![skin isKindOfClass:StrataNxSkinView.class]) return;
    BOOL portrait = pad.bounds.size.height > pad.bounds.size.width;
    UIImage *image = portrait ? ((StrataNxSkinView *)skin).portraitArtwork
                              : ((StrataNxSkinView *)skin).landscapeArtwork;
    UIButton *nativeMenu = nil;
    for (UIView *candidate in pad.subviews)
        if ([NSStringFromClass(candidate.class) isEqualToString:@"DmMenuButton"]) {
            nativeMenu = (UIButton *)candidate; break;
        }
    if (!nativeMenu) return;
    UIButton *artMenu = (UIButton *)[pad viewWithTag:StrataNxSkinMenuButtonTag];
    if (!image) {
        artMenu.hidden = YES;
        nativeMenu.userInteractionEnabled = YES;
        return;
    }
    if (!artMenu) {
        artMenu = [UIButton buttonWithType:UIButtonTypeCustom];
        artMenu.tag = StrataNxSkinMenuButtonTag;
        artMenu.accessibilityLabel = @"NxNative game menu";
        artMenu.backgroundColor = UIColor.clearColor;
        artMenu.showsMenuAsPrimaryAction = YES;
        // Preserve NxNative's actual menu actions and reset on open.
        __weak UIView *weakPad = pad;
        [artMenu addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
            UIView *livePad = weakPad;
            if (livePad && [livePad respondsToSelector:@selector(reset)])
                ((void (*)(id, SEL))[livePad methodForSelector:@selector(reset)])(livePad,@selector(reset));
        }] forControlEvents:UIControlEventMenuActionTriggered];
        [pad addSubview:artMenu];
    }
    artMenu.menu = nativeMenu.menu;
    artMenu.hidden = NO;
    nativeMenu.userInteractionEnabled = NO;
    CGRect r = StrataNxArtworkFrameInPad(pad,image);
    CGPoint icon = StrataArtGearCentre(!portrait);
    CGPoint centre = CGPointMake(CGRectGetMinX(r)+r.size.width*icon.x,
                                  CGRectGetMinY(r)+r.size.height*icon.y);
    CGFloat radius = MAX(20,MIN(r.size.width*(portrait?0.055:0.032),
                                r.size.height*(portrait?0.035:0.052)));
    artMenu.frame = CGRectMake(centre.x-radius,centre.y-radius,radius*2,radius*2);
}

static void StrataNxFitGameToImportedArt(UIViewController *root) {
    NSString *group = objc_getAssociatedObject(root, &StrataNxSkinRootGroupKey);
    if (!StrataNxSkinIsEnabled(group)) return;
    UIView *host = root.view;
    UIView *skinView = [host viewWithTag:StrataNxSkinViewTag];
    if (![skinView isKindOfClass:StrataNxSkinView.class]) return;
    StrataNxSkinView *skin = (StrataNxSkinView *)skinView;
    BOOL portrait = host.bounds.size.height > host.bounds.size.width;
    UIImage *img = portrait ? skin.portraitArtwork : skin.landscapeArtwork;
    if (!img) {
        // The opposite orientation may have artwork while this one does not.
        // Restore the standard controls and menu; preserve the default picture.
        UIView *pad = StrataNxChildOfClass(host, @"DmGamepad");
        if (pad) {
            StrataNxKeepNativeInputButHideDrawing(pad);
            StrataNxUpdateGameMenuButton(pad);
        }
        return;
    }
    UIView *game = StrataNxChildOfClass(host, @"DmGameView");
    UIView *pad = StrataNxChildOfClass(host, @"DmGamepad");
    if (!game || game.superview != host || !pad) return;

    CGRect hole = StrataNxArtworkAperture(host.bounds, img);
    // The opening is taller than the usual 16:9 guest picture. Aspect-FIT
    // created the black top/bottom bands shown in the user's screenshots.
    // Aspect-FILL preserves the picture's aspect and covers the ENTIRE hole:
    // the shell above the Metal view occludes the small left/right overscan.
    // Never change DmGameView's superview (NxNative treats that as TV output).
    if (CGRectIsNull(hole) || CGRectIsEmpty(hole) ||
        hole.size.width < 80 || hole.size.height < 50 ||
        game.frame.size.width <= 0 || game.frame.size.height <= 0) return;
    CGFloat aspect = game.frame.size.width / game.frame.size.height;
    if (!isfinite(aspect) || aspect <= 0) return;
    CGFloat width = MAX(hole.size.width, hole.size.height * aspect);
    CGFloat height = width / aspect;
    CGRect filled = CGRectMake(CGRectGetMidX(hole) - width * 0.5,
                               CGRectGetMidY(hole) - height * 0.5,
                               width, height);
    // No layer masks or offscreen extra surfaces: the imported white shell is
    // rendered ABOVE the guest Metal view but BELOW the touch input layer.
    // It draws only outside StrataNxArtworkAperture and covers the overscan.
    game.clipsToBounds = YES;
    if (!CGRectEqualToRect(game.frame, filled)) {
        game.frame = filled;
        [skin setNeedsDisplay];
        NSLog(@"[Strata][NxSkin] %@ aspect-FILL %@ over aperture %@",
              portrait ? @"portrait" : @"landscape",
              NSStringFromCGRect(filled), NSStringFromCGRect(hole));
    }
    // Native CALayer visuals are hidden, not the UIKit gamepad hit targets.
    StrataNxKeepNativeInputButHideDrawing(pad);
    StrataNxUpdateGameMenuButton(pad);
    @try {
        UILabel *fps = [root valueForKey:@"fps"];
        if ([fps isKindOfClass:UILabel.class] && !fps.hidden)
            fps.frame = CGRectMake(CGRectGetMinX(hole)+5,CGRectGetMinY(hole)+5,64,22);
    } @catch (__unused NSException *e) {}
}
static void StrataNxRootDidLayout(id root, SEL sel) {
    if (StrataNxOriginalRootDidLayout) StrataNxOriginalRootDidLayout(root,sel);
    StrataNxFitGameToImportedArt((UIViewController *)root);
}
static UIViewController *StrataNxFindGameController(UIViewController *controller, NSUInteger depth) {
    if (!controller || depth > 6) return nil;
    if ([NSStringFromClass(controller.class) isEqualToString:@"DmRootVC"]) return controller;
    for (UIViewController *child in controller.childViewControllers) {
        UIViewController *game = StrataNxFindGameController(child,depth+1);
        if (game) return game;
    }
    return nil;
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
    if (!StrataNxSkinIsEnabled(group)) return;
    UIView *host = StrataFindNxPadHost(window.rootViewController.view, 0);
    if (!host || [host viewWithTag:StrataNxSkinViewTag]) return;
    UIView *pad = nil;
    for (UIView *child in host.subviews) {
        if ([NSStringFromClass(child.class) isEqualToString:@"DmGamepad"]) { pad = child; break; }
    }
    if (!pad) return;
    StrataNxSkinView *skin = [[StrataNxSkinView alloc] initWithFrame:host.bounds];
    skin.mappedPad = pad;
    // Built-in vector skin: every NxNative guest has BOTH orientations
    // without importing or downloading any PNG. The user's old custom
    // artwork files remain untouched on disk for potential future restore.
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:group];
    skin.darkTheme = [[prefs stringForKey:StrataNxSkinStyleKey] isEqualToString:@"amoled"];
    skin.portraitArtwork = StrataNxBuiltinArtwork(YES, skin.darkTheme);
    skin.landscapeArtwork = StrataNxBuiltinArtwork(NO, skin.darkTheme);
    if (skin.portraitArtwork || skin.landscapeArtwork) StrataEnableNxSkinTouchMapping(pad);
    // The shell must cover aspect-FILL side overscan while staying under
    // the active DmGamepad touch view. Never reparent DmGameView.
    UIView *gameView = StrataNxChildOfClass(host, @"DmGameView");
    if (gameView) [host insertSubview:skin aboveSubview:gameView];
    else [host insertSubview:skin belowSubview:pad];
    if (skin.portraitArtwork || skin.landscapeArtwork) {
        StrataNxKeepNativeInputButHideDrawing(pad);
        UIViewController *gameRoot = StrataNxFindGameController(window.rootViewController,0);
        if (gameRoot) {
            StrataNxHookRootLayout(gameRoot, group);
            [gameRoot.view setNeedsLayout];
            [gameRoot.view layoutIfNeeded];
            StrataNxFitGameToImportedArt(gameRoot);
        } else {
            NSLog(@"[Strata][NxSkin] DmRootVC not found; leaving native picture size unchanged");
        }
    }
    [skin setNeedsDisplay];
    NSLog(@"[Strata][NxSkin] built-in %@ portrait=%@ landscape=%@; mapped native input",
          skin.darkTheme ? @"AMOLED Dark" : @"Pearl Light",
          skin.portraitArtwork ? @"YES" : @"NO",
          skin.landscapeArtwork ? @"YES" : @"NO");
}

// Apply the PER-APP Orientation Lock selected in App Settings or the
// Switchboard Rotation shortcut. This is read directly from the guest's
// LCAppInfo.plist (NSUserDefaults.guestAppInfo), not from a global preference.
// Values: 0 = Disabled / system default, 1 = Landscape, 2 = Portrait.
// Do not rotate the launcher or interfere with another game's preference.
static char StrataNxOrientationRequestKey;

static void StrataApplyNxGameOrientation(UIWindow *window, NSString *group) {
    if (!window || !window.windowScene || !group.length) return;
    if (![NSUserDefaults.lcGuestAppId.lowercaseString hasPrefix:@"org.nxnative"]) return;
    // The guest can be nested in a LiveContainer hosting controller.
    // Looking only at the window's immediate root missed those launches.
    UIViewController *root = StrataNxFindGameController(window.rootViewController, 0);
    if (!root) return;

    // LCAppModel.uiOrientationLock writes LCOrientationLock into the app's
    // LCAppInfo.plist. LCBootstrap loads that exact plist for the current guest.
    // Therefore Settings Picker and Rotation shortcut always agree, even
    // when multiple NxNative games have different orientation preferences.
    id orientationSetting = NSUserDefaults.guestAppInfo[@"LCOrientationLock"];
    NSInteger orientation = [orientationSetting respondsToSelector:@selector(integerValue)]
        ? [orientationSetting integerValue] : 0;
    if (orientation != 1 && orientation != 2) {
        // Disabled/Auto: do not force rotation, but CLEAR the launcher's
        // portrait-only supported-orientation mask. Otherwise Auto stays
        // portrait-locked in the same process even with device rotation on.
        Class bridge = NSClassFromString(@"StrataNxGameOrientationBridge");
        SEL restoreAuto = NSSelectorFromString(@"applyAuto");
        if (bridge && [bridge respondsToSelector:restoreAuto]) {
            void (*call)(id, SEL) = (void *)[bridge methodForSelector:restoreAuto];
            call(bridge, restoreAuto);
            if (@available(iOS 16.0, *)) {
                [window.rootViewController setNeedsUpdateOfSupportedInterfaceOrientations];
                if (window.rootViewController != root)
                    [root setNeedsUpdateOfSupportedInterfaceOrientations];
            } else {
                [UIViewController attemptRotationToDeviceOrientation];
            }
        }
        return;
    }
    BOOL landscape = orientation == 1;

    // AppDelegate supportedInterfaceOrientationsForWindow reads the shared
    // LiveBoardOrientation mask. Clear the launcher's portrait lock only for
    // this actual NxNative guest before requesting UIWindowScene geometry.
    Class bridge = NSClassFromString(@"StrataNxGameOrientationBridge");
    SEL apply = NSSelectorFromString(@"apply:");
    if (bridge && [bridge respondsToSelector:apply]) {
        void (*call)(id, SEL, NSNumber *) = (void *)[bridge methodForSelector:apply];
        call(bridge, apply, @(landscape));
    }
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
        if (window.rootViewController != root) {
            [window.rootViewController setNeedsUpdateOfSupportedInterfaceOrientations];
        }
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
