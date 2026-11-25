#import <Foundation/Foundation.h>
void StrataStartGuestControls(NSString *group, NSString *appName, BOOL separateProcess);
void StrataStartGuestControlsWithIdentity(NSString *group, NSString *appName, BOOL separateProcess, NSString *key);

@class UIWindow;
void StrataToggleHostControls(UIWindow *window);
@class UIView;
void StrataSetSwitcherProviders(UIView *(^live)(NSString *key), NSString *(^front)(void));

// Bounded Settings preview using the same artwork and controls as gameplay.
@class UIImage;
UIImage *StrataNxSkinPreviewImageForTheme(BOOL portrait, BOOL dark, NSString *mode, NSString *identifier);
void StrataNxTrimSkinPreviewCache(void);
BOOL StrataNxPhotoSkinsBundled(void);
