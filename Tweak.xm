// =============================================================
//  多看隐藏Tab插件 — 无痕版（解决闪烁和封面加载慢）
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL DKShouldApply() {
    NSString *bid = [NSBundle mainBundle].bundleIdentifier.lowercaseString;
    return bid && [bid containsString:@"duokan"];
}

// 移除 TabBar 并调整布局（仅针对控制器视图层级）
static void DKRemoveTabBarAndResize(UIView *rootView) {
    if (!rootView) return;
    // 递归查找 DKTabBarForIPhone
    NSMutableArray *queue = [NSMutableArray arrayWithObject:rootView];
    UIView *tabBar = nil;
    UIView *parent = nil;
    while (queue.count > 0) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if ([NSStringFromClass([view class]) isEqualToString:@"DKTabBarForIPhone"]) {
            tabBar = view;
            parent = view.superview;
            break;
        }
        for (UIView *sub in view.subviews) {
            [queue addObject:sub];
        }
    }
    if (!tabBar) {
        NSLog(@"[DuokanHide] 未找到 DKTabBarForIPhone");
        return;
    }
    
    // 移除 TabBar
    [UIView performWithoutAnimation:^{
        [tabBar removeFromSuperview];
        // 调整父视图剩余子视图填满
        if (parent) {
            for (UIView *sub in parent.subviews) {
                sub.frame = parent.bounds;
                sub.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            }
            [parent setNeedsLayout];
            [parent layoutIfNeeded];
        }
    }];
    NSLog(@"[DuokanHide] 已移除 TabBar 并调整布局");
}

// 统一执行（确保只执行一次）
static void DKPerformRemoval(UIViewController *vc) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!vc || !vc.view) return;
        // 确保在主线程，且无动画
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIView performWithoutAnimation:^{
                DKRemoveTabBarAndResize(vc.view);
            }];
        });
    });
}

// =============================================================
// 手势检测（三指长按）
// =============================================================
static void showToast(NSString *msg, UIWindow *window) {
    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    UIAlertController *toast = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
    [top presentViewController:toast animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [toast dismissViewControllerAnimated:YES completion:nil];
    });
}

static void showSettingsMenu(UIWindow *window) {
    UIViewController *topVC = window.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;
    
    NSInteger mode = [[NSUserDefaults standardUserDefaults] integerForKey:@"DuokanHideTabMode"];
    NSString *status = mode == 0 ? @"已关闭" : (mode == 1 ? @"旧版模式（5.6.9）" : @"新版模式（5.8.7）");
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"多看Tab隐藏控制"
                                                                   message:[NSString stringWithFormat:@"当前模式：%@\n切换后需重启 App 生效", status]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray *titles = @[@"关闭插件", @"开启旧版（5.6.9）", @"开启新版（5.8.7）"];
    NSArray *modes = @[@0, @1, @2];
    for (NSInteger i = 0; i < titles.count; i++) {
        NSInteger targetMode = [modes[i] integerValue];
        [alert addAction:[UIAlertAction actionWithTitle:titles[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (targetMode == mode) {
                showToast(@"已是当前模式", window);
                return;
            }
            UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"提示"
                                                                             message:@"切换模式后需要重启 App 才能生效，确定要继续吗？"
                                                                      preferredStyle:UIAlertControllerStyleAlert];
            [confirm addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [[NSUserDefaults standardUserDefaults] setInteger:targetMode forKey:@"DuokanHideTabMode"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                showToast([NSString stringWithFormat:@"已切换至：%@，请重启 App", titles[targetMode]], window);
            }]];
            [confirm addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
            UIViewController *top = window.rootViewController;
            while (top.presentedViewController) top = top.presentedViewController;
            [top presentViewController:confirm animated:YES completion:nil];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = window;
        alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(window.bounds), CGRectGetMidY(window.bounds), 0, 0);
    }
    [topVC presentViewController:alert animated:YES completion:nil];
}

// 三指长按检测
static NSTimeInterval touchStartTime = 0;
static BOOL isTouching = NO;
static NSInteger touchCount = 0;

%hook UIApplication
- (void)sendEvent:(UIEvent *)event {
    %orig;
    if (event.type != UIEventTypeTouches) return;
    NSSet *touches = [event allTouches];
    if (touches.count == 0) return;
    UITouch *touch = [touches anyObject];
    if (touch.phase == UITouchPhaseBegan) {
        touchCount = touches.count;
        if (touchCount == 3) {
            isTouching = YES;
            touchStartTime = [NSDate timeIntervalSinceReferenceDate];
        }
    } else if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) {
        isTouching = NO;
        touchCount = 0;
    } else if (touch.phase == UITouchPhaseStationary) {
        if (isTouching && touchCount == 3) {
            NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
            if (now - touchStartTime > 1.2) {
                UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
                if (keyWindow) {
                    if (@available(iOS 10.0, *)) {
                        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
                        [generator prepare];
                        [generator impactOccurred];
                    }
                    showSettingsMenu(keyWindow);
                }
                isTouching = NO;
                touchCount = 0;
            }
        }
    }
}
%end

// Hook 主控制器
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!DKShouldApply()) return;
    if ([NSStringFromClass([self class]) isEqualToString:@"DKIPhoneMainTabBarViewController"]) {
        // 只执行一次移除
        DKPerformRemoval(self);
    }
}
%end

%ctor {
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DuokanHideTabMode"]) {
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"DuokanHideTabMode"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    NSLog(@"[DuokanHide] 插件加载完成，当前模式：%ld", (long)[[NSUserDefaults standardUserDefaults] integerForKey:@"DuokanHideTabMode"]);
}
