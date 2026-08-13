// =============================================================
//  多看隐藏Tab插件 — 双模式支持（新版/旧版）
//  三指长按（基于 UIApplication sendEvent:，不会被拦截）
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ---------- 模式管理 ----------
static NSInteger DKGetMode() {
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"DuokanHideTabMode"];
}

static void DKSetMode(NSInteger mode) {
    [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:@"DuokanHideTabMode"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static BOOL DKShouldApply() {
    NSString *bid = [NSBundle mainBundle].bundleIdentifier.lowercaseString;
    return bid && [bid containsString:@"duokan"] && DKGetMode() != 0;
}

// ---------- 新版模式（5.8.7）逻辑 ----------
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

static void DKHideTabBarNew(UIView *rootView) {
    if (!rootView) return;
    if ([NSStringFromClass([rootView class]) isEqualToString:@"DKTabBarForPhone"] ||
        [NSStringFromClass([rootView class]) isEqualToString:@"DKTabBarForIPhone"]) {
        rootView.hidden = YES;
        rootView.alpha = 0.0;
        rootView.backgroundColor = [UIColor clearColor];
        return;
    }
    for (UIView *sub in rootView.subviews) {
        DKHideTabBarNew(sub);
    }
}

// ---------- 旧版模式（5.6.9）逻辑 ----------
static void DKHideTabBarOld(UIView *rootView) {
    if (!rootView) return;
    if ([NSStringFromClass([rootView class]) isEqualToString:@"DKTabBarForIPhone"]) {
        rootView.hidden = YES;
        rootView.alpha = 0.0;
        return;
    }
    for (UIView *sub in rootView.subviews) {
        DKHideTabBarOld(sub);
    }
}

// ---------- 统一执行函数 ----------
static void DKPerformHide(UIViewController *vc) {
    if (!vc) return;
    NSInteger mode = DKGetMode();
    if (mode == 0) return;
    if (mode == 1) {
        DKHideTabBarOld(vc.view);
    } else if (mode == 2) {
        DKHideTabBarNew(vc.view);
        DKRemoveEarnBeansFromView(vc.view);
        DKRemoveNavEarnBeans(vc);
    }
}

// =============================================================
// 手势检测（基于 UIApplication sendEvent:）
// =============================================================

static void showToast(NSString *msg, UIWindow *window) {
    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) {
        top = top.presentedViewController;
    }
    UIAlertController *toast = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
    [top presentViewController:toast animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [toast dismissViewControllerAnimated:YES completion:nil];
    });
}

static void showSettingsMenu(UIWindow *window) {
    UIViewController *topVC = window.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    
    NSInteger mode = DKGetMode();
    NSString *status;
    if (mode == 0) status = @"已关闭";
    else if (mode == 1) status = @"旧版模式（5.6.9）";
    else status = @"新版模式（5.8.7）";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"多看Tab隐藏控制"
                                                                   message:[NSString stringWithFormat:@"当前模式：%@\n切换后需重启 App 生效", status]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    NSArray *titles = @[@"关闭插件", @"开启旧版（5.6.9）", @"开启新版（5.8.7）"];
    NSArray *modes = @[@0, @1, @2];
    for (NSInteger i = 0; i < titles.count; i++) {
        NSString *title = titles[i];
        NSInteger targetMode = [modes[i] integerValue];
        [alert addAction:[UIAlertAction actionWithTitle:title
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction * _Nonnull action) {
                                                    if (targetMode == mode) {
                                                        showToast(@"已是当前模式", window);
                                                        return;
                                                    }
                                                    UIAlertController *confirmAlert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                                                                           message:@"切换模式后需要重启 App 才能生效，确定要继续吗？"
                                                                                                                    preferredStyle:UIAlertControllerStyleAlert];
                                                    [confirmAlert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                                        DKSetMode(targetMode);
                                                        showToast([NSString stringWithFormat:@"已切换至：%@，请重启 App", titles[targetMode]], window);
                                                    }]];
                                                    [confirmAlert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
                                                    UIViewController *top = window.rootViewController;
                                                    while (top.presentedViewController) {
                                                        top = top.presentedViewController;
                                                    }
                                                    [top presentViewController:confirmAlert animated:YES completion:nil];
                                                }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = window;
        alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(window.bounds), CGRectGetMidY(window.bounds), 0, 0);
    }
    
    [topVC presentViewController:alert animated:YES completion:nil];
}

// 检测三指长按的全局变量
static NSTimeInterval touchStartTime = 0;
static BOOL isTouching = NO;
static NSInteger touchCount = 0;

// =============================================================
// Hook UIApplication 的 sendEvent: 来检测触摸事件
// =============================================================
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

// =============================================================
// Hook UIViewController
// =============================================================
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!DKShouldApply()) return;
    if ([NSStringFromClass([self class]) isEqualToString:@"DKIPhoneMainTabBarViewController"]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                BOOL animationsEnabled = [UIView areAnimationsEnabled];
                [UIView setAnimationsEnabled:NO];
                DKPerformHide(self);
                [UIView setAnimationsEnabled:animationsEnabled];
            });
        });
    }
}
%end

// =============================================================
// 构造函数
// =============================================================
%ctor {
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DuokanHideTabMode"]) {
        DKSetMode(0);
    }
    NSLog(@"[DuokanHide] 插件加载完成，当前模式：%ld", (long)DKGetMode());
}
