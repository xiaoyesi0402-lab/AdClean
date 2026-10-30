# AdClean — 动漫共和国 去广告模块

一个极小的 LSPosed 模块，只做一件事：**让「动漫共和国」（`com.shizi.tool.p3`）不再加载任何广告**。

```
体积   ~8 KB
权限   无
组件   无
联网   无
作用域 仅 com.shizi.tool.p3
```

> 本模块**不修改**目标 App 的任何文件，也不重签名，使用模块后务必清除数据去除缓存广告

---

## 原理

目标 App 的广告由 **Windmill 聚合 SDK**（Sigmob 换皮）统一调度：

```
App
 └─ com.windmill.sdk.WindMillAd.initSDK(...)     ← 拉取广告配置
      └─ 按配置调 Sigmob / 穿山甲 / 优量汇 / 倍孜 / 快手 / 百度
```

模块 hook 掉 `initSDK`：

- 直接返回 `true`（假装初始化成功），**跳过真正的初始化**，因此永远不会拉取广告配置；
- 反射回调 `listener.onInitSuccess()`，让上层（Flutter）正常继续。

配置为空 → 所有广告平台都「无填充」→ 一条广告都不显示，而 App 走的是**正常的「没广告」分支**，不会闪退、不会卡开屏。

### 为什么用这种方式

| 尝试 | 结果 |
|---|---|
| 改 APK（改广告地址后重签名） | App 校验签名，报 `300101 请求服务器超时`，内容全废 |
| hook `java.net.InetAddress` 做 DNS 拦截 | 无效：Sigmob 在原生层（`libsgcore.so`）直接调 `getaddrinfo`，不经过 Java |
| hosts 屏蔽广告域名 | 有效，但需要全局改 hosts，会影响其它 App |
| **hook 聚合 SDK 初始化**（本方案） | 只影响目标 App，且不依赖域名，App 换广告域名也照样拦 |

---

## 环境要求

- Android 8.0+（实测 Android 13 / MIUI 14 正常）
- 手机已 root（KernelSU / SukiSU / Magisk）
- 已安装并启用 **LSPosed**（Zygisk 版）

---

## 安装

1. 下载 APK 并安装（装完没有桌面图标，正常）
   - 方式一：[**Releases 页面**](../../releases/latest)（推荐）
   - 方式二：仓库内 [`release/AdClean-1.1.apk`](release/AdClean-1.1.apk)
2. 打开 **LSPosed 管理器** → 「模块」
3. 找到 **AdClean (动漫共和国)** → 打开「启用模块」
4. 应用列表里搜索 `shizi`，勾选 **`com.shizi.tool.p3`**
   > 作用域只勾这一个，不要勾系统或其它应用
5. 强制停止目标 App（或重启手机），重新打开

详细图文步骤见 [使用说明.md](使用说明.md)。

## 验证生效

LSPosed 日志里应出现：

```
(com.shizi.tool.p3)[to.kosaki.adclean] AdClean: installing hooks
(com.shizi.tool.p3)[to.kosaki.adclean] AdClean: hooked initSDK
(com.shizi.tool.p3)[to.kosaki.adclean] AdClean: onInitSuccess -> ...
```

出现 `hooked initSDK` 即成功。

---

## 构建

不需要 Android Studio / Gradle，只需要三个命令行工具：

| 工具 | 用途 |
|---|---|
| `aapt`（Android SDK build-tools） | 编译 AndroidManifest |
| `smali.jar`（[smali/baksmali](https://github.com/JesusFreke/smali)） | 把 smali 汇编成 classes.dex |
| `apksigner`（Android SDK build-tools） | 签名 |

```bash
./build.sh
# 产物：dist/AdClean.apk
```

> 注意：APK 签名包含时间戳，**自行构建的产物 SHA-256 与仓库内 `release/` 下的文件不同属正常现象**，行为一致即可。

脚本会校验最小可行流程，需要 `JAVA_HOME` 可用。首次构建请先准备一个 framework 资源文件：

```bash
# 从任意 root 设备取，或使用 Android SDK 的 android.jar
adb shell su -c 'cat /system/framework/framework-res.apk' > framework-res.apk
export FRAMEWORK=framework-res.apk
```

---



## 安全与隐私

- 申请权限：**无**
- 声明组件：**无**
- 联网 / 写文件 / 读取用户数据：**无**
- 日志内容：仅固定字符串与目标包名，不含任何账号、设备、位置信息

模块只做一件事：在目标 App 进程内给一个方法加 hook。

> 注意：本模块只解决「广告」，不改变目标 App 自身的隐私行为。

## 免责声明

- 仅供**个人学习与技术研究**，请勿用于商业用途。

## License

[MIT](LICENSE)
