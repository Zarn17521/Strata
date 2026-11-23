#import <Foundation/Foundation.h>
void StrataStartGuestControls(NSString *group, NSString *appName, BOOL separateProcess);
void StrataStartGuestControlsWithIdentity(NSString *group, NSString *appName, BOOL separateProcess, NSString *key);

@class UIWindow;
void StrataToggleHostControls(UIWindow *window);
@class UIView;
void StrataSetSwitcherProviders(UIView *(^live)(NSString *key), NSString *(^front)(void));

// Cached photo-faithful preview shared by Settings and the NxNative skin.
@class UIImage;
UIImage *StrataNxSkinPreviewImage(BOOL portrait, BOOL dark);
BOOL StrataNxPhotoSkinsBundled(void);
