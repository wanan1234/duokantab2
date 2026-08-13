# 多看纯净书架 · DuokanHideTabs

一个给 **多看阅读** 写的 TrollFools 注入插件（Theos tweak）。
把底部 Tab 栏的 **书城 / 分类 / 我的** 全部隐藏，只留 **书架**，
让多看回归「纯阅读器」。

适配版本：
5.8.7最后一个可插件的版本
5.83第一个新版
5.82最后一个旧版
5.69最优的版本 建议此版本
---

## 它做了什么

多看阅读的主界面是一个标准的 `UITabBarController`，四个标签分别是
`书架 / 书城 / 分类 / 我的`。
本插件在 App 启动时 Hook 了「设置子控制器」的流程，把标题命中
`书城 / 分类 / 我的` 的页面直接过滤掉，于是底部只剩 `书架`。

> 只是**视觉与交互层面移除入口**，不会删你已下载的书，也不会动多看的任何数据。

---

## 目录结构

```
duokan-hide-tabs/
├── Tweak.xm              # 核心 Hook 逻辑（想改隐藏哪些标签改这里）
├── Makefile              # Theos 编译配置
├── control               # Debian 包描述信息
├── README.md             # 本文件
└── .github/workflows/    # 云端编译（无 Mac 也能出包）
```

---

## 编译方式（二选一）

### 方式 A：本地 macOS 编译（推荐，有 Mac 就用这个）

```bash
# 1. 安装 Theos（按官方文档 https://theos.dev ）
# 2. 进入工程目录
cd duokan-hide-tabs

# 3. 编译并打包
make package FINALPACKAGE=1

# 产物在 packages/ 下：DuokanHideTabs_1.0.0_iphoneos-arm.deb
```

依赖：`theos`、`dpkg`、`ldid`（均可用 Homebrew 安装）。

### 方式 B：GitHub Actions 云端编译（没有 Mac 也能用）

1. 把整个 `duokan-hide-tabs` 目录推到你自己的 GitHub 仓库；
2. 打开仓库的 **Actions** 标签页，找到 `Build DuokanHideTabs`；
3. 点 **Run workflow** 手动触发；
4. 跑完后下载名为 `DuokanHideTabs-deb` 的 Artifact，里面就是 `.deb`。

> 用的是 `macos-latest` Runner，自带 Xcode 和 iPhoneOS SDK，
> 不需要你准备任何证书或签名。

---

## 注入到多看阅读（TrollFools）

> 前提：已装好 TrollStore + TrollFools，多看阅读本身通过
> App Store 或 TrollStore 正常安装。

1. 打开 **TrollFools**，在应用列表里找到 **多看**；
2. 进入后点 **注入（Inject）**，在文件选择器里选中编译好的
   `DuokanHideTabs_1.0.0_iphoneos-arm.deb`
   （如果你手里是 `.dylib` 文件，直接选 `.dylib` 也行）；
3. 等待注入完成，回到桌面**彻底杀掉多看阅读**（上划清后台）；
4. 重新打开多看阅读 —— 底部应该只剩 **书架** 一个标签了。

---

## 想自己微调

打开 `Tweak.xm`，改 `DKHiddenTitles()` 这个数组即可：

```objc
static NSArray<NSString *> *DKHiddenTitles(void) {
    static NSArray *titles = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        titles = @[@"书城", @"分类", @"我的"];   // ← 想隐藏谁就写谁
    });
    return titles;
}
```

- 想连「书架」都不要、换成别的入口？把数组换成你想要的标题即可。
- 标题必须和多看底部**实际显示的文字完全一致**（区分中英文、全半角）。

---

## 排错

**Q：注入后底部标签没变 / 还是四个？**

插件在运行时会往系统日志打印一行调试信息，方便定位：

```
[DuokanHideTabs] 容器类=xxx 当前标签: "书架" "书城" "分类" "我的"
```

用 Mac 上的**控制台（Console.app）**连上手机，过滤进程 `多看` 或
关键词 `DuokanHideTabs` 查看：

1. **完全看不到 `[DuokanHideTabs]` 日志**
   → 插件没被加载。确认 TrollFools 注入成功、多看已彻底杀后台重开。
2. **日志里标签标题是 `(空)`**
   → 多看把标题延后设置了，但兜底逻辑（`viewDidLayoutSubviews`）会再次过滤，
     正常一两帧后就只剩书架。等半秒再看。
3. **日志里标题是英文/别的字（如 `Store` / `Mine`）**
   → 多看用的不是中文标题。把 `DKHiddenTitles()` 里的字改成日志里出现的实际文字。
4. **日志里「容器类」不是 `UITabBarController` 或其子类**
   → 多看用了自定义底部栏（非标准 UITabBarController）。这种情况需要换 Hook 点，
     可以把日志里打印的容器类名发我，我帮你改成对应的类。

**Q：注入后多看闪退？**
先把插件从 TrollFools 里移除（取消注入）确认是插件导致的。多半是标题匹配
把某个被其他逻辑强引用的控制器干掉了；把 `DKHiddenTitles()` 里的项减到只留
`书城` 一个测试，逐步定位。

---

## 兼容性说明

- 适配 **iOS 14 ~ iOS 16（TrollStore 支持范围）**；
- 多看阅读只要仍用标准 `UITabBarController` 做底部栏就长期有效；
- 多看大版本更新若重做了底部栏结构，可能需按上面「排错」微调类名/标题。
