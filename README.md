# Campus Wi-Fi Edge Auto Login

> 一个面向 Windows + Microsoft Edge 的校园 Wi-Fi 自动认证工具。

## 作者与协作

- 作者：小克（GitHub: [Sanyesang](https://github.com/Sanyesang)）
- Coworker：Codex（AI 协作助手）

这是一个“通用引擎 + 学校配置”的校园网自动认证工具。目前已经内置江西师范大学 `jxnu_stu` 配置，仍然保留原来的 JXNU 快捷脚本。

配套手册：[校园网自动认证工具-使用与排错手册.pdf](docs/校园网自动认证工具-使用与排错手册.pdf)

工具只负责：

1. Windows 登录后等待目标 Wi-Fi 连接；
2. 检测当前是否已经可以访问互联网；
3. 如果尚未认证，用 Edge 打开学校认证页；
4. 由 Edge 已保存的账号密码自动填充；
5. 用户脚本按学校配置选择运营商并点击“登录”。

密码不写入 `.ps1`、`.js`、JSON、日志或任务计划程序。工具也不会关闭 Clash、修改 TUN 或删除 VPN 配置。

## 当前内置配置

- 配置文件：[schools/jxnu.json](schools/jxnu.json)
- Wi-Fi：`jxnu_stu`
- 认证域名：`portal.jxnu.edu.cn`
- 当前运营商：电信 `@ctcc`

江西师大官方说明的校园无线认证入口为 `172.16.8.8`；当前配置同时兼容门户域名和旧 IP 入口。

## Edge 一次性设置

在保存校园网密码的同一个 Edge 配置中安装 Violentmonkey 或 Tampermonkey，然后把
`engine/campus-autologin.user.js` 的全部内容粘贴为新脚本并启用。

如果 Edge 能在认证页自动填入账号和密码，脚本就能自动提交。脚本只匹配配置中的门户域名，不会在普通网站运行。

## 选择联网模式

工具提供两种模式：

### 一键联网（半自动）

用户点击桌面上的“江西师范大学校园网一键连接”快捷方式后，会打开校园网助手窗口。点击窗口中央的“一键连接校园网”按钮，脚本随后自动等待 `jxnu_stu`、打开 Edge 认证页并提交登录。

窗口旁有“开机自启”复选框。勾选后，下次登录 Windows 会自动打开这个助手窗口；为避免开机时突然抢占网络或浏览器焦点，开机自启只打开窗口，不会替用户自动点击连接按钮。需要自动提交认证时，请使用下面的“全自动联网”模式。

### 全自动联网

Windows 登录后自动等待 `jxnu_stu` 并完成认证，不需要用户点击。

可以直接双击 `Setup-JXNUAutoLogin.cmd` 选择模式，也可以在 PowerShell 中执行：

```powershell
# 创建桌面一键联网快捷方式，不注册开机任务
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Setup-JXNUAutoLogin.ps1 -Mode one-click

# 注册 Windows 登录后自动联网任务
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Setup-JXNUAutoLogin.ps1 -Mode automatic
```

### 手动注册全自动任务

在本目录执行（不会修改系统执行策略）：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-JXNUAutoLoginTask.ps1
```

也可以直接双击 `Install-JXNUAutoLoginTask.cmd`。它只注册全自动任务，适合已经确定使用全自动模式的情况。

任务名为 `JXNU Wi-Fi Auto Login`，以当前 Windows 用户运行，不需要管理员权限。

## 手动测试

先不要重启，可以手动执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-JXNUAutoLogin.ps1 -ForceOpen
```

`-ForceOpen` 只会打开认证页；不会写入或输出密码。测试成功后再决定使用一键模式还是全自动模式。

## 卸载全自动任务

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-JXNUAutoLoginTask.ps1
```

## 为其他学校添加配置

1. 复制 `schools/example.json`，填写学校 Wi-Fi 名称、认证地址和绕过代理的主机名。
2. 在 `engine/campus-autologin.user.js` 顶部增加对应的 `@match`，并在 `PROFILES` 中添加认证域名、表单选择器和运营商值。
3. 在 Edge 中保存该学校认证页的账号密码。
4. 使用通用安装器注册对应配置：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-CampusAutoLoginTask.ps1 -ConfigPath .\schools\example.json
```

## 兼容性边界

- 同样使用深澜 SRun 网关的学校，通常只需改配置和选择器。
- 页面结构不同但仍是网页认证的学校，需要调整选择器。
- Dr.COM、锐捷、NetKeeper、验证码、短信验证或统一身份认证等系统，需要单独适配器；本工具不会绕过验证码或二次确认。
- 如果出现新的校园网使用协议且复选框没有被门户记住，脚本不会替用户同意新协议。
- 如果 Edge 没有自动填充账号或密码，脚本不会提交空表单。
