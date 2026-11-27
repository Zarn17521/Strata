// Built-in, self-contained NxNative controller art for Strata.
// Included by StrataGuestControls.m only.
// These shapes are rendered once on installation and cached.  All positions
// use the ORIGINAL 923x2000 / 1792x1008 reference coordinate system,
// with the requested FINAL mapping (look stick above, ABXY below).
#pragma once

// When the supplied portrait PNG / landscape JPG (and their graphite dark
// variants) are checked into LiveContainer/StrataNxSkins, GitHub Actions
// embeds their *exact bytes* into LiveContainerShared at build time.
// No network, file import, or PNG asset catalog lookup during game launch.
#if __has_include("StrataNxPhotoData.h")
#include "StrataNxPhotoData.h"
#else
static NSData *StrataNxPackedPhotoData(BOOL portrait, BOOL dark) {
    (void)portrait; (void)dark;
    return nil; // Compatibility fallback until the four image files are uploaded.
}
#endif

static char StrataNxBuiltinImageKey;
static char StrataNxPreparedPhotoKey;
static char StrataNxThemeImageKey;

static BOOL StrataNxIsThemeImage(UIImage *image) {
    return image && [objc_getAssociatedObject(image, &StrataNxThemeImageKey) boolValue];
}

static BOOL StrataNxIsPreparedPhoto(UIImage *image) {
    return image && [objc_getAssociatedObject(image, &StrataNxPreparedPhotoKey) boolValue];
}

static BOOL StrataNxIsBuiltinImage(UIImage *image) {
    return image && [objc_getAssociatedObject(image, &StrataNxBuiltinImageKey) boolValue];
}

static UIColor *StrataNxBuiltShell(BOOL dark) {
    return dark ? [UIColor colorWithRed:0.008 green:0.010 blue:0.014 alpha:1]
                : [UIColor colorWithRed:0.973 green:0.973 blue:0.956 alpha:1];
}
static UIColor *StrataNxBuiltEdge(BOOL dark) {
    return dark ? [UIColor colorWithRed:0.27 green:0.30 blue:0.34 alpha:1]
                : [UIColor colorWithRed:0.75 green:0.76 blue:0.74 alpha:1];
}

static void StrataNxBuiltGradient(UIBezierPath *path, UIColor *a, UIColor *b) {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;
    CGContextSaveGState(ctx);
    [path addClip];
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = @[(__bridge id)a.CGColor,(__bridge id)b.CGColor];
    CGGradientRef grad = CGGradientCreateWithColors(cs,(__bridge CFArrayRef)colors,NULL);
    CGRect bounds = path.bounds;
    if (grad) {
        CGContextDrawLinearGradient(ctx,grad,
            CGPointMake(CGRectGetMidX(bounds),CGRectGetMinY(bounds)),
            CGPointMake(CGRectGetMidX(bounds),CGRectGetMaxY(bounds)),0);
        CGGradientRelease(grad);
    }
    CGColorSpaceRelease(cs);
    CGContextRestoreGState(ctx);
}

static void StrataNxBuiltKey(CGPoint p, CGSize s, NSString *label, BOOL dark, BOOL round) {
    CGRect box = CGRectMake(p.x-s.width*0.5,p.y-s.height*0.5,s.width,s.height);
    CGFloat radius = round ? MIN(s.width,s.height)*0.5 : MIN(s.width,s.height)*0.24;
    UIBezierPath *outline = [UIBezierPath bezierPathWithRoundedRect:box cornerRadius:radius];
    UIColor *upper = dark ? [UIColor colorWithRed:0.42 green:0.46 blue:0.52 alpha:0.85]
                          : [UIColor colorWithRed:1 green:1 blue:1 alpha:1];
    UIColor *lower = dark ? [UIColor colorWithRed:0.17 green:0.20 blue:0.26 alpha:0.78]
                          : [UIColor colorWithRed:0.82 green:0.84 blue:0.82 alpha:1];
    StrataNxBuiltGradient(outline,upper,lower);
    outline.lineWidth = dark ? 2.1 : 2.0;
    [StrataNxBuiltEdge(dark) setStroke];[outline stroke];
    // Subtle vitreous specular ridge (Wii U graphite / Pearl Light).
    UIBezierPath *inset = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(box,3,3)
                                                  cornerRadius:MAX(1,radius-3)];
    inset.lineWidth = 1.5;
    [[UIColor colorWithWhite:1 alpha:dark ? 0.29 : 0.79] setStroke];
    [inset stroke];
    if (label.length) {
        CGFloat fontSize = MIN(s.height*0.40,s.width*0.52);
        UIFont *font=[UIFont systemFontOfSize:MAX(11,fontSize) weight:UIFontWeightSemibold];
        NSDictionary *attrs=@{
            NSFontAttributeName:font,
            NSForegroundColorAttributeName:dark
                ? [UIColor whiteColor]
                : [UIColor colorWithWhite:0.36 alpha:1]
        };
        CGSize sz=[label sizeWithAttributes:attrs];
        [label drawAtPoint:CGPointMake(p.x-sz.width*0.5,p.y-sz.height*0.5)
            withAttributes:attrs];
    }
}

static void StrataNxBuiltAnalog(CGPoint p, CGFloat radius, BOOL dark) {
    CGRect ring=CGRectMake(p.x-radius,p.y-radius,radius*2,radius*2);
    UIBezierPath *outer=[UIBezierPath bezierPathWithOvalInRect:ring];
    UIColor *outerFill = dark ? [UIColor colorWithWhite:0.04 alpha:1]
                               : [UIColor colorWithWhite:0.67 alpha:1];
    [outerFill setFill];
    [outer fill];
    outer.lineWidth = 3;
    [StrataNxBuiltEdge(dark) setStroke];[outer stroke];
    UIBezierPath *inner=[UIBezierPath bezierPathWithOvalInRect:CGRectInset(ring,radius*0.16,radius*0.16)];
    StrataNxBuiltGradient(inner,
        dark ? [UIColor colorWithRed:0.43 green:0.47 blue:0.53 alpha:0.88] : [UIColor whiteColor],
        dark ? [UIColor colorWithRed:0.16 green:0.19 blue:0.23 alpha:0.84] : [UIColor colorWithWhite:0.79 alpha:1]);
    inner.lineWidth = 1.8;
    [StrataNxBuiltEdge(dark) setStroke];[inner stroke];
    UIBezierPath *knob=[UIBezierPath bezierPathWithOvalInRect:CGRectInset(ring,radius*0.31,radius*0.31)];
    [[UIColor colorWithWhite:1 alpha:dark?0.09:0.45] setFill];[knob fill];
    knob.lineWidth=1;
    [[UIColor colorWithWhite:1 alpha:dark?0.19:0.62] setStroke];[knob stroke];
}

static void StrataNxBuiltDPad(CGPoint p, CGFloat unit, BOOL dark) {
    CGFloat a=unit*0.34,b=unit;
    UIBezierPath *cross=[UIBezierPath bezierPath];
    [cross moveToPoint:CGPointMake(p.x-a,p.y-b)];
    [cross addLineToPoint:CGPointMake(p.x+a,p.y-b)];
    [cross addLineToPoint:CGPointMake(p.x+a,p.y-a)];
    [cross addLineToPoint:CGPointMake(p.x+b,p.y-a)];
    [cross addLineToPoint:CGPointMake(p.x+b,p.y+a)];
    [cross addLineToPoint:CGPointMake(p.x+a,p.y+a)];
    [cross addLineToPoint:CGPointMake(p.x+a,p.y+b)];
    [cross addLineToPoint:CGPointMake(p.x-a,p.y+b)];
    [cross addLineToPoint:CGPointMake(p.x-a,p.y+a)];
    [cross addLineToPoint:CGPointMake(p.x-b,p.y+a)];
    [cross addLineToPoint:CGPointMake(p.x-b,p.y-a)];
    [cross addLineToPoint:CGPointMake(p.x-a,p.y-a)];
    [cross closePath];
    StrataNxBuiltGradient(cross,
        dark ? [UIColor colorWithRed:0.39 green:0.42 blue:0.47 alpha:0.88] : [UIColor whiteColor],
        dark ? [UIColor colorWithRed:0.16 green:0.18 blue:0.21 alpha:0.82] : [UIColor colorWithWhite:0.82 alpha:1]);
    cross.lineWidth=2.5;
    [StrataNxBuiltEdge(dark) setStroke];[cross stroke];
    UIBezierPath *dot=[UIBezierPath bezierPathWithOvalInRect:CGRectMake(p.x-7,p.y-7,14,14)];
    [[UIColor colorWithWhite:dark?0.11:0.85 alpha:1] setFill];[dot fill];
}

static void StrataNxBuiltScreen(CGRect hole, BOOL dark) {
    CGRect bezel=CGRectInset(hole,-12,-12);
    UIBezierPath *rim=[UIBezierPath bezierPathWithRoundedRect:bezel cornerRadius:15];
    [[UIColor colorWithWhite:dark?0.075:0.20 alpha:1] setFill];[rim fill];
    rim.lineWidth=6;
    [[UIColor colorWithWhite:dark?0.36:0.60 alpha:1] setStroke];[rim stroke];
    UIBezierPath *edge=[UIBezierPath bezierPathWithRoundedRect:CGRectInset(bezel,5,5) cornerRadius:10];
    edge.lineWidth=2;
    [[UIColor colorWithWhite:dark?0.62:0.93 alpha:0.70] setStroke];[edge stroke];
}

static UIImage *StrataNxBuildArtworkWithDrawing(BOOL portrait, BOOL dark, UIImage *plate, CGFloat scale, BOOL controls, void (^drawPlate)(CGRect)) {
    CGSize size = portrait ? CGSizeMake(923,2000) : CGSizeMake(1792,1008);
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque=YES;
    format.scale=scale;
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    UIImage *result=[renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull render) {
        CGRect all=CGRectMake(0,0,size.width,size.height);
        if (drawPlate) {
            drawPlate(all);
        } else if (plate) {
            [plate drawInRect:all];
        } else {
            [StrataNxBuiltShell(dark) setFill];
            UIRectFill(all);
            CGRect game = portrait ? CGRectMake(37,138,847,661) : CGRectMake(463,169,863,574);
            StrataNxBuiltScreen(game,dark);
        }
        if (controls) {
        // Shoulder pairs remain LEFT L/ZL and RIGHT R/ZR in both modes.
        NSArray<NSString *> *labels=@[@"L",@"ZL",@"R",@"ZR"];
        CGFloat lx[4],sy,shoulderW,shoulderH;
        if (portrait) {
            CGFloat points[]={0.119,0.283,0.719,0.879};
            for (int i=0;i<4;i++) lx[i]=size.width*points[i];
            sy=size.height*0.504;shoulderW=115;shoulderH=34;
        } else {
            CGFloat points[]={0.1318,0.2038,0.8006,0.8757};
            for (int i=0;i<4;i++) lx[i]=size.width*points[i];
            sy=size.height*0.1827;shoulderW=78;shoulderH=36;
        }
        for (int i=0;i<4;i++)
            StrataNxBuiltKey(CGPointMake(lx[i],sy),
                            CGSizeMake(shoulderW,shoulderH),labels[i],dark,NO);

        CGPoint dpad=CGPointMake(size.width*(portrait?0.2490:0.1590),
                                  size.height*(portrait?0.6460:0.3620));
        StrataNxBuiltDPad(dpad,portrait?91:65,dark);
        CGPoint leftStick=CGPointMake(size.width*(portrait?0.2438:0.1590),
                                      size.height*(portrait?0.8379:0.6161));
        CGPoint look=CGPointMake(size.width*(portrait?0.7466:0.8401),
                                 size.height*(portrait?0.6449:0.3613));
        StrataNxBuiltAnalog(leftStick,portrait?70:57,dark);
        StrataNxBuiltAnalog(look,portrait?70:57,dark);

        // FINAL layout: ABXY below right look stick, exactly matching
        // StrataArtFaceCentre()'s moved hit targets.
        CGFloat bx[4],by[4];
        if (portrait) {
            CGFloat xs[]={0.857,0.747,0.748,0.638};
            CGFloat ys[]={0.817,0.868,0.766,0.817};
            for (int i=0;i<4;i++) { bx[i]=xs[i];by[i]=ys[i]; }
        } else {
            CGFloat xs[]={0.8836,0.8381,0.8381,0.7925};
            CGFloat ys[]={0.6185,0.6983,0.5376,0.6185};
            for (int i=0;i<4;i++) { bx[i]=xs[i];by[i]=ys[i]; }
        }
        NSArray<NSString *> *face=@[@"A",@"B",@"X",@"Y"];
        for (int i=0;i<4;i++)
            StrataNxBuiltKey(CGPointMake(bx[i]*size.width,by[i]*size.height),
                            CGSizeMake(portrait?88:72,portrait?88:72),face[i],dark,YES);
        CGFloat gearY=size.height*(portrait?0.9363:0.7982);
        StrataNxBuiltKey(CGPointMake(size.width*(portrait?0.3452:0.4122),gearY),
                        CGSizeMake(portrait?57:45,portrait?53:45),@"−",dark,YES);
        StrataNxBuiltKey(CGPointMake(size.width*(portrait?0.6559:0.5869),gearY),
                        CGSizeMake(portrait?57:45,portrait?53:45),@"+",dark,YES);
        StrataNxBuiltKey(CGPointMake(size.width*0.4999,gearY),
                        CGSizeMake(portrait?67:48,portrait?67:48),@"⚙",dark,YES);
        }
        // Small perforations echo a physical handheld, away from hot zones.
        [[UIColor colorWithWhite:dark?0.36:0.57 alpha:0.65] setFill];
        for (int i=0;i<7;i++) {
            CGFloat x=size.width*(portrait?0.41:0.458)+i*(portrait?25:24);
            CGFloat y=size.height*(portrait?0.531:0.835);
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(x,y,portrait?5:4,portrait?5:4)] fill];
        }
        // Lower-left ZN logo is added by StrataNxDrawZNBrand() in the skin
        // overlay using the SAME gold Z / jade N / green tilted cap vector.
    }];
    if (result) objc_setAssociatedObject(result,&StrataNxBuiltinImageKey,
                                         @YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return result;
}

static UIImage *StrataNxBuildArtwork(BOOL portrait, BOOL dark, UIImage *plate, CGFloat scale, BOOL controls) {
    return StrataNxBuildArtworkWithDrawing(portrait,dark,plate,scale,controls,nil);
}

static UIImage *StrataNxBuiltinArtwork(BOOL portrait, BOOL dark, BOOL controls) {
    static NSCache<NSString *,UIImage *> *cache;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        cache=[NSCache new];
        cache.countLimit=1;
        cache.totalCostLimit=9*1024*1024;
    });
    NSString *key=[NSString stringWithFormat:@"%@-%@-%d",
        portrait?@"portrait":@"landscape",dark?@"amoled":@"pearl",controls];
    UIImage *image=[cache objectForKey:key];
    if (!image) {
        // Prefer the exact submitted photo skin, not the out-of-date vector
        // recreation. Photos are deliberately NOT tagged as builtin-vector:
        // the existing crop/swap path then exchanges Look and ABXY and
        // corrects the R/ZR glyphs at precisely the same touch coordinates.
        NSData *photo=controls ? StrataNxPackedPhotoData(portrait,dark) : nil;
#if defined(STRATA_NX_BLANK_PHOTOS)
        if (!controls) photo=StrataNxPackedBlankPhotoData(portrait,dark);
#endif
        if (photo.length) image=[UIImage imageWithData:photo];
#if defined(STRATA_NX_PREPARED_PHOTOS)
        // Preserve photo-specific frame/clip behavior, but never swap controls again.
        if (image) objc_setAssociatedObject(image,&StrataNxPreparedPhotoKey,
                                             @YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
#endif
        if (!image) image=StrataNxBuildArtwork(portrait,dark,nil,1,controls);
        if (image) [cache setObject:image forKey:key
                 cost:(NSUInteger)(image.size.width*image.size.height*4)];
    }
    return image;
}
