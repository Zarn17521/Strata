// Included inside StrataNxSkinView's implementation. These small independent
// textures are built on layout, never from a Metal framebuffer or per touch.
- (CALayer *)znSpriteForKey:(NSString *)key centre:(CGPoint)centre pixels:(CGSize)pixels
                       art:(CGRect)art reference:(CGSize)ref kind:(NSInteger)kind label:(NSString *)label dark:(BOOL)dark {
    CGFloat scale=MIN(art.size.width/ref.width,art.size.height/ref.height);
    if (!isfinite(scale) || scale<=0) return nil;
    CGSize size=CGSizeMake(MAX(8,pixels.width*scale),MAX(8,pixels.height*scale));
    UIGraphicsImageRendererFormat *fmt=[UIGraphicsImageRendererFormat preferredFormat];
    fmt.opaque=NO; fmt.scale=MIN(2.0,UIScreen.mainScreen.scale);
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:size format:fmt];
    BOOL stick=ZNIsStickSprite(kind);
    UIImage *bitmap=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGContextScaleCTM(context.CGContext,size.width/pixels.width,size.height/pixels.height);
        ZNDrawControllerSpriteBody(pixels,kind,label,dark);
    }];
    CALayer *layer=[CALayer layer];
    layer.contents=(__bridge id)bitmap.CGImage; layer.contentsScale=fmt.scale;
    layer.bounds=(CGRect){CGPointZero,size};
    layer.position=CGPointMake(art.origin.x+centre.x*art.size.width,art.origin.y+centre.y*art.size.height);
    layer.zPosition=3;
    layer.shadowColor=UIColor.blackColor.CGColor; layer.shadowOpacity=.25;
    layer.shadowRadius=1.4; layer.shadowOffset=CGSizeMake(0,1.6);
    layer.actions=@{@"position":[NSNull null],@"bounds":[NSNull null],@"transform":[NSNull null],@"hidden":[NSNull null],@"shadowOpacity":[NSNull null],@"shadowOffset":[NSNull null]};
    if (stick) {
        CGSize ks=CGSizeMake(size.width*.67,size.height*.67);
        UIGraphicsImageRenderer *kr=[[UIGraphicsImageRenderer alloc] initWithSize:ks format:fmt];
        UIImage *ki=[kr imageWithActions:^(UIGraphicsImageRendererContext *context) {
            CGContextScaleCTM(context.CGContext,ks.width/100,ks.height/100);
            StrataNxBuiltKey(CGPointMake(50,50),CGSizeMake(94,94),@"",dark,YES);
        }];
        CALayer *knob=[CALayer layer]; knob.name=@"zn.stick.knob";
        knob.contents=(__bridge id)ki.CGImage; knob.contentsScale=fmt.scale;
        knob.bounds=(CGRect){CGPointZero,ks}; knob.position=CGPointMake(size.width*.5,size.height*.5);
        knob.shadowColor=UIColor.blackColor.CGColor; knob.shadowOpacity=.4; knob.shadowRadius=1.4; knob.shadowOffset=CGSizeMake(0,1.6);
        knob.actions=@{@"position":[NSNull null],@"transform":[NSNull null]};
        [layer addSublayer:knob];
    }
    layer.hidden=self.znControlsHidden && ![key isEqualToString:@"gear"];
    [self.layer addSublayer:layer]; self.znSprites[key]=layer;
    return layer;
}
- (void)znLayoutSprites {
    if (self.fullScreenMode || CGRectIsEmpty(self.bounds) || !self.superview) return;
    if (self.znSprites.count && CGRectEqualToRect(self.znSpriteBounds,self.bounds)) return;
    BOOL land=self.bounds.size.width>self.bounds.size.height;
    UIImage *image=[self artworkForPortrait:!land];
    if (!image) return;
    [self znResetSprites];
    for (CALayer *layer in self.znSprites.allValues) [layer removeFromSuperlayer];
    [self.znSprites removeAllObjects];
    self.znSpriteBounds=self.bounds;
    BOOL wide=StrataNxIsWideSkin(self);
    BOOL dark=ZNUsesAMOLEDButtons(self.themeIdentifier,self.darkTheme);
    CGSize ref=land?CGSizeMake(1792,1008):CGSizeMake(923,2000);
    ZNVisitControllerKeys(land,!dark||StrataNxIsPreparedPhoto(image),^(NSString *key, CGPoint centre, CGSize px, NSInteger role, NSString *label){
        [self znSpriteForKey:key centre:centre pixels:px art:StrataNxControlFrame(self.bounds,image,wide,centre.x) reference:ref kind:role label:label dark:dark];
    });
}
- (CALayer *)znMovingLayer:(CALayer *)root {
    CALayer *knob=root.sublayers.firstObject;
    return [knob.name isEqualToString:@"zn.stick.knob"] ? knob : root;
}
- (void)znMoveLayer:(CALayer *)layer transform:(CATransform3D)t animated:(BOOL)animated {
    if (!layer) return;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    CATransform3D previous=layer.presentationLayer ? ((CALayer *)layer.presentationLayer).transform : layer.transform;
    [layer removeAnimationForKey:@"zn.real.motion"];
    layer.transform=t;
    if (animated && self.znAnimate) {
        CABasicAnimation *move=[CABasicAnimation animationWithKeyPath:@"transform"];
        move.fromValue=[NSValue valueWithCATransform3D:previous];
        move.toValue=[NSValue valueWithCATransform3D:t];
        move.duration=CATransform3DIsIdentity(t)?.075:.045;
        move.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [layer addAnimation:move forKey:@"zn.real.motion"];
    }
    [CATransaction commit];
}
- (void)znResetSprites {
    [self.znTouchSprites removeAllObjects];
    for (CALayer *root in self.znSprites.allValues) {
        [self znMoveLayer:[self znMovingLayer:root] transform:CATransform3DIdentity animated:NO];
        root.shadowOpacity=.25; root.shadowOffset=CGSizeMake(0,1.6);
    }
    self.znGearPressed=NO;
    if (self.fullScreenMode && self.znGearControl) [self znMoveLayer:self.znGearControl.layer transform:CATransform3DIdentity animated:NO];
}
- (void)znReleaseSprite:(NSString *)key {
    if (!key || [self.znTouchSprites.allValues containsObject:key]) return;
    CALayer *root=self.znSprites[key];
    [self znMoveLayer:[self znMovingLayer:root] transform:CATransform3DIdentity animated:YES];
    root.shadowOpacity=.25; root.shadowOffset=CGSizeMake(0,1.6);
}
- (void)znTrackSpriteTouches:(NSSet<UITouch *> *)touches ending:(BOOL)ending pad:(UIView *)pad {
    BOOL land=self.bounds.size.width>self.bounds.size.height;
    UIImage *image=self.activeArtwork;
    if (!image) return;
    BOOL wide=StrataNxIsWideSkin(self);
    for (UITouch *touch in touches) {
        NSValue *owner=[NSValue valueWithNonretainedObject:touch];
        NSString *old=self.znTouchSprites[owner];
        if (ending) {
            if (!old) continue;
            [self.znTouchSprites removeObjectForKey:owner];
            [self znReleaseSprite:old];
            if (touch.phase==UITouchPhaseEnded && !self.znControlsHidden) [self znClick:YES role:StrataArtNoMapping];
            continue;
        }
        NSInteger role=[objc_getAssociatedObject(touch,&StrataNxTouchArtRoleKey) integerValue];
        if (role==StrataArtNoMapping) continue;
        CGPoint raw=StrataOriginalLocationInView?StrataOriginalLocationInView(touch,@selector(locationInView:),pad):[touch locationInView:pad];
        CGPoint norm=StrataNxNormalizeControlPoint(self.bounds,image,[self convertPoint:raw fromView:pad],wide,role);
        if (!isfinite(norm.x)||!isfinite(norm.y)) continue;
        NSString *key=[NSString stringWithFormat:@"role%ld",(long)role];
        if (role==StrataArtFace) {
            CGPoint nearest=StrataNxPressCentre(norm,role,land);
            for (int i=0;i<4;i++) if (CGPointEqualToPoint(nearest,StrataArtFaceCentre(land,i))) {key=[NSString stringWithFormat:@"face%d",i];break;}
        }
        CALayer *root=self.znSprites[key];
        if (!root || root.hidden) continue;
        BOOL changed=![old isEqualToString:key];
        if (changed) {
            self.znTouchSprites[owner]=key; [self znReleaseSprite:old];
            if (touch.phase==UITouchPhaseBegan) [self znClick:NO role:role];
        }
        if (!self.znAnimate) continue;
        CATransform3D t=CATransform3DIdentity;
        BOOL stick=role==StrataArtLeftStick||role==StrataArtRightStick;
        if (stick) {
            CGPoint c=StrataArtStickCentre(land,role==StrataArtRightStick);
            CGFloat dx=(norm.x-c.x)/(land?.040:.110),dy=(norm.y-c.y)/(land?.073:.055);
            CGFloat length=MAX(1,hypot(dx,dy)), travel=MIN(root.bounds.size.width,root.bounds.size.height)*.19;
            t=CATransform3DMakeTranslation(dx/length*travel,dy/length*travel,0);
        } else if (role==StrataArtDpad) {
            CGPoint c=StrataArtDpadCentre(land);
            CGFloat dx=MAX(-1,MIN(1,(norm.x-c.x)/(land?.052:.145)));
            CGFloat dy=MAX(-1,MIN(1,(norm.y-c.y)/(land?.086:.078)));
            t.m34=-1.0/220; t=CATransform3DRotate(t,-dy*.22,1,0,0); t=CATransform3DRotate(t,dx*.22,0,1,0);
            t=CATransform3DTranslate(t,0,1,0);
        } else {
            if (!changed) continue;
            t=CATransform3DConcat(CATransform3DMakeScale(.94,.94,1),CATransform3DMakeTranslation(0,1.4,0));
        }
        [self znMoveLayer:[self znMovingLayer:root] transform:t animated:changed && !stick];
        if (!stick) {root.shadowOpacity=.10;root.shadowOffset=CGSizeMake(0,.5);}
    }
}
- (void)znGearDown:(UIControl *)sender {
    if (self.znGearPressed) return;
    self.znGearPressed=YES; self.znLastGearDown=CACurrentMediaTime();
    [self znClick:NO role:StrataArtNoMapping];
    if (self.znAnimate) {
        [self znMoveLayer:self.znSprites[@"gear"] ?: sender.layer transform:CATransform3DConcat(CATransform3DMakeScale(.94,.94,1),CATransform3DMakeTranslation(0,1.2,0)) animated:YES];
    }
}
- (void)znGearFinish:(UIControl *)sender sound:(BOOL)sound {
    if (!self.znGearPressed) return;
    self.znGearPressed=NO;
    if (sound) [self znClick:YES role:StrataArtNoMapping];
    [self znMoveLayer:self.znSprites[@"gear"] ?: sender.layer transform:CATransform3DIdentity animated:YES];
}
- (void)znGearUp:(UIControl *)sender { [self znGearFinish:sender sound:YES]; }
- (void)znGearCancel:(UIControl *)sender { [self znGearFinish:sender sound:NO]; }
- (void)znGearTriggered:(UIControl *)sender {
    if (!self.znGearPressed && CACurrentMediaTime()-self.znLastGearDown>.18) [self znGearDown:sender];
    [self znGearUp:sender];
}
- (void)znBindGear:(UIControl *)gear {
    if (!gear || self.znGearControl==gear) return;
    UIControl *old=self.znGearControl;
    [old removeTarget:self action:@selector(znGearDown:) forControlEvents:UIControlEventTouchDown];
    [old removeTarget:self action:@selector(znGearUp:) forControlEvents:UIControlEventTouchUpInside];
    [old removeTarget:self action:@selector(znGearCancel:) forControlEvents:UIControlEventTouchUpOutside|UIControlEventTouchCancel];
    [old removeTarget:self action:@selector(znGearTriggered:) forControlEvents:UIControlEventMenuActionTriggered];
    self.znGearControl=gear;
    [gear addTarget:self action:@selector(znGearDown:) forControlEvents:UIControlEventTouchDown];
    [gear addTarget:self action:@selector(znGearUp:) forControlEvents:UIControlEventTouchUpInside];
    [gear addTarget:self action:@selector(znGearCancel:) forControlEvents:UIControlEventTouchUpOutside|UIControlEventTouchCancel];
    [gear addTarget:self action:@selector(znGearTriggered:) forControlEvents:UIControlEventMenuActionTriggered];
}
