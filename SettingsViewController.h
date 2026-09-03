#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SettingsViewController : UIViewController

/// Shared photo picker. Uses PHPicker (iOS 14+) so no library permission string is
/// needed; the completion runs on the main thread with nil when the user cancels.
+ (void)presentImagePickerWithCompletion:(void (^)(UIImage *_Nullable image))completion;

@end

NS_ASSUME_NONNULL_END
