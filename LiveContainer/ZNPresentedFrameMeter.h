// Counts completed on-screen Metal drawable presentations, not display refresh ticks.
// Only the selected guest surface is observed; no GPU waits, readbacks or frame copies.
#pragma once
@import Metal;
@import QuartzCore;
@interface ZNPresentedFrameMeter : NSObject
@property(nonatomic) uint64_t frames;
@property(nonatomic) uint64_t previousFrames;
@property(nonatomic) CFTimeInterval previousSample;
@property(nonatomic) BOOL active;
- (void)recordPresentation;
- (NSNumber *)sample;
- (void)stop;
@end
@implementation ZNPresentedFrameMeter
- (void)recordPresentation {
    @synchronized(self) { if (_active) _frames++; }
}
- (NSNumber *)sample {
    @synchronized(self) {
        CFTimeInterval now=CACurrentMediaTime();
        if (!_active || _previousSample<=0 || now-_previousSample>3.5) {
            _active=YES; _previousSample=now; _previousFrames=_frames; return nil;
        }
        CFTimeInterval elapsed=now-_previousSample;
        if (elapsed<.35) return nil;
        uint64_t delta=_frames-_previousFrames;
        _previousFrames=_frames; _previousSample=now;
        if (_frames==0) return nil;
        return @(delta/elapsed);
    }
}
- (void)stop { @synchronized(self) { _active=NO; _frames=0; _previousFrames=0; _previousSample=0; } }
@end
static char ZNMetalFrameMeterKey;
static id<CAMetalDrawable> (*ZNOriginalNextDrawable)(CAMetalLayer *, SEL);
static id<CAMetalDrawable> ZNObservedNextDrawable(CAMetalLayer *layer, SEL selector) {
    id<CAMetalDrawable> drawable=ZNOriginalNextDrawable(layer,selector);
    ZNPresentedFrameMeter *meter=objc_getAssociatedObject(layer,&ZNMetalFrameMeterKey);
    if (meter && drawable && [drawable respondsToSelector:@selector(addPresentedHandler:)]) {
        __weak ZNPresentedFrameMeter *weakMeter=meter;
        [drawable addPresentedHandler:^(id<MTLDrawable> presented) {
            if (presented.presentedTime>0) [weakMeter recordPresentation];
        }];
    }
    return drawable;
}
static void ZNInstallPresentedFrameObserver(void) {
    if (@available(iOS 10.3,*)) {
        static dispatch_once_t once;
        dispatch_once(&once,^{
            Method method=class_getInstanceMethod(CAMetalLayer.class,@selector(nextDrawable));
            if (!method) return;
            ZNOriginalNextDrawable=(void *)method_getImplementation(method);
            method_setImplementation(method,(IMP)ZNObservedNextDrawable);
        });
    }
}
// Prefer the largest visible Metal surface inside the game view. Never count
// unrelated UI refreshes or sum multiple render surfaces as game FPS.
static void ZNFindMetalSurface(CALayer *layer, NSUInteger depth, CAMetalLayer **best, CGFloat *bestArea) {
    if (!layer || depth>16 || layer.hidden || layer.opacity<=.01) return;
    if ([layer isKindOfClass:CAMetalLayer.class]) {
        CGFloat area=layer.bounds.size.width*layer.bounds.size.height;
        if (area>*bestArea) { *best=(CAMetalLayer *)layer; *bestArea=area; }
    }
    for (CALayer *child in layer.sublayers) ZNFindMetalSurface(child,depth+1,best,bestArea);
}
static CAMetalLayer *ZNMetalSurfaceForRoot(UIViewController *root) {
    if (!root.isViewLoaded) return nil;
    UIView *game=StrataNxChildOfClass(root.view,@"DmGameView");
    CAMetalLayer *best=nil; CGFloat area=0;
    ZNFindMetalSurface((game ?: root.view).layer,0,&best,&area);
    return best;
}
