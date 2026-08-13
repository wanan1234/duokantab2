#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL DKShouldApply(void) {
    NSString *bid = [NSBundle mainBundle].bundleIdentifier.lowercaseString;
    return bid && [bid containsString:@"duokan"];
}

// 清除赚书豆（递归）
static void DKRemoveEarnBeansFromView(UIView *view) {
    if (!view) return;
    if ([NSStringFromClass([view class]) isEqualToString:@"DuokanReader.HorizonalLayoutButton"]) {
        __block BOOL hasEarnBeans = NO;
        for (UIView *sub in view.subviews) {
            if ([sub isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)sub;
                if ([label.text isEqualToString:@"赚书豆"]) {
                    hasEarnBeans = YES;
                    break;
                }
            }
        }
        if (hasEarnBeans) {
            view.hidden = YES;
            view.alpha = 0.0;
            view.userInteractionEnabled = NO;
            return;
        }
    }
    for (UIView *sub in view.subviews) {
        DKRemoveEarnBeansFromView(sub);
    }
}

static void DKRemoveNavEarnBeans(UIViewController *vc) {
    if (!vc || !vc.navigationItem.rightBarButtonItems) return;
    NSMutableArray *newItems = [NSMutableArray array];
    for (UIBarButtonItem *item in vc.navigationItem.rightBarButtonItems) {
        if (![item.title isEqualToString:@"赚书豆"]) {
            [newItems addObject:item];
        }
    }
    vc.navigationItem.rightBarButtonItems = newItems;
}

static void DKHideTabBar(UIViewController *vc) {
    if (!vc) return;
    UIView *mainView = vc.view;
    if (!mainView) return;
    
    for (UIView *sub in mainView.subviews) {
        NSString *className = NSStringFromClass([sub class]);
        if ([className isEqualToString:@"DKTabBarForPhone"] || 
            [className isEqualToString:@"DKTabBarForIPhone"]) {
            sub.hidden = YES;
            sub.alpha = 0.0;
            sub.backgroundColor = [UIColor clearColor];
            NSLog(@"[DuokanTab587] TabBar 已隐藏");
            break;
        }
    }
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!DKShouldApply()) return;
    if ([NSStringFromClass([self class]) isEqualToString:@"DKIPhoneMainTabBarViewController"]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            // 延迟执行，确保视图完全加载
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                BOOL animationsEnabled = [UIView areAnimationsEnabled];
                [UIView setAnimationsEnabled:NO];
                DKHideTabBar(self);
                DKRemoveEarnBeansFromView(self.view);
                DKRemoveNavEarnBeans(self);
                [UIView setAnimationsEnabled:animationsEnabled];
            });
        });
    }
}
%end

%ctor {
    if (DKShouldApply()) {
        NSLog(@"[DuokanTab587] 最终稳定版加载成功");
    }
}
