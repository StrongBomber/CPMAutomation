#ifndef _CPMSTUB_PHOTOSUI_H
#define _CPMSTUB_PHOTOSUI_H
#import <UIKit/UIKit.h>

@interface PHPickerFilter : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)imagesFilter;
+ (instancetype)videosFilter;
+ (instancetype)anyFilter;
@end

@interface PHPickerConfiguration : NSObject
@property (nonatomic) NSInteger selectionLimit;
@property (nonatomic, strong, nullable) PHPickerFilter *filter;
@end

@interface PHPickerResult : NSObject
@property (nonatomic, readonly) NSItemProvider *itemProvider;
@end

@protocol PHPickerViewControllerDelegate <NSObject>
- (void)picker:(id)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14.0));
@end

@interface PHPickerViewController : UIViewController
- (instancetype)initWithConfiguration:(PHPickerConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil;
@property (nonatomic, readonly) PHPickerConfiguration *configuration;
@property (nonatomic, weak, nullable) id<PHPickerViewControllerDelegate> delegate;
@end
#endif
