// =============================================================
//  多看隐藏Tab插件 — 修复切换无效 + 无闪烁
//  三指长按弹出菜单，模式切换需重启
// =============================================================
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL DKShouldApply() {
    NSString *bid = [NSBundle mainBundle].bundleIdentifier.lowercaseString;
    return bid && [bid containsString:@"duokan"];
}

// ---------- 旧版（5.6.9）：彻底移除 TabBar ----------
static void DKRemoveTabBarOld(UIView *rootView) {
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
        NSLog(@"[DuokanHide] 旧版：未找到 DKTabBarForIPhone");
        return;
    }
    
    // 无动画移除并调整布局
    [UIView performWithoutAnimation:^{
        [tabBar removeFromSuperview];
        if (parent) {
            // 调整所有子视图填满父视图
            for (UIView *sub in parent.subviews) {
                sub.frame = parent.bounds;
                sub.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            }
            [parent setNeedsLayout];
            [parent layoutIfNeeded];
        }
    }];
    NSLog(@"[DuokanHide] 旧版：已移除 TabBar");
}

// ---------- 新版（5.8.7）：隐藏 TabBar + 移除赚书豆 ----------
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
    NSMutableArray *queue = [NSMutableArray arrayWithObject:rootView];
    while (queue.count > 0) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if ([NSStringFromClass([view class]) isEqualToString:@"DKTabBarForPhone"] ||
            [NSStringFromClass([view class]) isEqualToString:@"DKTabBarForIPhone"]) {
            [UIView performWithoutAnimation:^{
                view.hidden = YES;
                view.alpha = 0.0;
                view.backgroundColor = [UIColor clearColor];
            }];
        }
        for (UIView *sub in view.subviews) {
            [queue addObject:sub];
        }
    }
}

// ---------- 统一执行（根据模式） ----------
static void DKPerformHide(UIViewController *vc) {
    if (!vc || !vc.view) return;
    NSInteger mode = [[NSUserDefaults standardUserDefaults] integerForKey:@"DuokanHideTabMode"];
    if (mode == 0) return;
    
    [UIView performWithoutAnimation:^{
        if (mode == 1) {
            DKRemoveTabBarOld(vc.view);
        } else if (mode == 2) {
            DKHideTabBarNew(vc.view);
            DKRemoveEarnBeansFromView(vc.view);
            DKRemoveNavEarnBeans(vc);
        }
    }];
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

// 三指长按检测（基于 sendEvent:）
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

// =============================================================
// Hook 主控制器 — 在 viewDidLoad 和 viewWillAppear 中执行，但只执行一次（除非模式变化）
// =============================================================
%hook UIViewController

- (void)viewDidLoad {
    %orig;
    if (!DKShouldApply()) return;
    if ([NSStringFromClass([self class]) isEqualToString:@"DKIPhoneMainTabBarViewController"]) {
        // 尽早执行一次
        NSInteger mode = [[NSUserDefaults standardUserDefaults] integerForKey:@"DuokanHideTabMode"];
        if (mode != 0) {
            DKPerformHide(self);
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (!DKShouldApply()) return;
    if ([NSStringFromClass([self class]) isEqualToString:@"DKIPhoneMainTabBarViewController"]) {
        // 每次出现都检查模式并执行，但只执行一次（通过静态变量记录已执行的模式）
        static NSInteger lastMode = -1;
        NSInteger currentMode = [[NSUserDefaults standardUserDefaults] integerForKey:@"DuokanHideTabMode"];
        if (currentMode != lastMode) {
            lastMode = currentMode;
            if (currentMode != 0) {
                DKPerformHide(self);
            }
        }
    }
}

%end

// =============================================================
// 构造函数
// =============================================================
%ctor {
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DuokanHideTabMode"]) {
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"DuokanHideTabMode"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    NSLog(@"[DuokanHide] 插件加载完成，当前模式：%ld", (long)[[NSUserDefaults standardUserDefaults] integerForKey:@"DuokanHideTabMode"]);
}
