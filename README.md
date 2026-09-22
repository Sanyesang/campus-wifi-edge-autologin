# Campus Wi-Fi Edge Auto Login

> 一个面向 Windows + Microsoft Edge 的校园 Wi-Fi 自动认证工具。

## 作者与协作

- 作者：小克（GitHub: [Sanyesang](https://github.com/Sanyesang)）
- Coworker：Codex（AI 协作助手）

这是一个“通用引擎 + 学校配置”的校园网自动认证工具。目前已经内置江西师范大学 `jxnu_stu` 配置，仍然保留原来的 JXNU 快捷脚本。

配套手册：[校园网自动认证工具-使用与排错手册.pdf](docs/校园网自动认证工具-使用与排错手册.pdf)

## 旧版自动连接方案失效说明

截至 2026-09-20，仓库早期的“等待 Wi-Fi、检测互联网、启动 Edge、等待页面、再执行认证”的自动连接闭环没有在当前电脑上稳定工作。旧版流程可能在网络检测、代理环境、浏览器启动或认证页加载阶段提前结束，导致坐标序列没有真正执行。因此，旧版通用引擎、开机自动任务、用户脚本和认证结果检测都不再宣称可用，也不应作为当前校园网连接方案。

当前只保留一个固定坐标点击工具：`CoordinateClicker.ps1`。它不通过程序接口检查 Wi-Fi、互联网、Edge 或认证结果，也不读取账号密码；这些动作由坐标序列完成。坐标序列从桌面右下角的网络入口开始，会依次打开网络面板、发起校园网连接、启动浏览器并操作认证页面。用户只需双击工具并点击开始，工具等待 8 秒后按固定坐标依次点击，普通间隔 2 秒；第三次点击后会额外停留 8 秒，期间显示 80% 不透明度的“等待页面响应”大字倒计时，给浏览器打开认证页面留出更充足的时间。

倒计时显示层只用于提示，不承担点击操作，也不会把浏览器认证步骤改成手动确认；倒计时结束后会自动关闭并继续第 4 个坐标。

坐标点击器的运行前提是硬性的：认证页面打开后必须处于全屏状态，Edge 浏览器缩放必须为 100%；主屏幕分辨率、系统显示缩放、任务栏位置、浏览器窗口布局和认证页面布局也必须与采集坐标时一致。任一条件变化，都可能导致点击偏移，需要重新采集坐标。

仓库中的旧版脚本和配置保留用于历史排查，不代表已经通过当前环境验收。若需要通用化、自动判断认证状态或适配其他学校，应重新设计和实测，不能从旧版代码直接推断可用性。

历史版本工具曾尝试负责：

1. Windows 登录后等待目标 Wi-Fi 连接；
2. 检测当前是否已经可以访问互联网；
3. 如果尚未认证，用 Edge 打开学校认证页；
4. 由 Edge 已保存的账号密码自动填充；
5. 用户脚本按学校配置选择运营商并点击“登录”。

密码不写入 `.ps1`、`.js`、JSON、日志或任务计划程序。工具也不会关闭 Clash、修改 TUN 或删除 VPN 配置。

## 当前内置配置

- 配置文件：[schools/jxnu.json](schools/jxnu.json)
- Wi-Fi：`jxnu_stu`
- 认证入口：`172.17.1.2/srun_portal_pc?ac_id=1&theme=pro`
- 当前运营商：电信 `@ctcc`

当前配置使用实测可响应的认证入口 `172.17.1.2/srun_portal_pc?ac_id=1&theme=pro`；旧门户域名和历史 IP 仍保留在绕过代理列表中，便于排错。

## Edge 一次性设置

在保存校园网密码的同一个 Edge 配置中安装 Violentmonkey 或 Tampermonkey，然后把
`engine/campus-autologin.user.js` 的全部内容粘贴为新脚本并启用。

如果 Edge 能在认证页自动填入账号和密码，脚本就能自动提交。脚本只匹配配置中的门户域名，不会在普通网站运行。

旧版 `engine/Start-CampusAutoLogin.ps1` 中的坐标集成仅作为历史实现保留，不要把它与当前的 `CoordinateClicker.ps1` 混用。

## 当前使用方式

1. 关闭可能遮挡桌面右下角网络区域的窗口，确认显示分辨率和系统缩放没有改变。
2. 双击桌面快捷方式“江西师范大学校园网一键连接”。
3. 点击“开始按坐标点击”；工具会从右下角网络入口开始，自动联网并打开浏览器认证页面。
4. 认证页面必须最终处于全屏、Edge 缩放 100% 的状态；工具按 8 个坐标依次点击，普通间隔 2 秒，第三次点击后等待 8 秒并显示倒计时。

工具完成后不会报告“认证成功”；请自行打开网页确认校园网是否已经可用。

## 历史版本说明（已失效）

下面的“选择联网模式”、任务注册和手动测试章节属于旧版实现，保留仅用于追溯；在当前环境中不要按这些章节判断自动连接已经可用。

旧版工具曾提供两种模式：

### 一键联网（半自动）

用户点击桌面上的“江西师范大学校园网一键连接”快捷方式后，会打开校园网助手窗口。点击窗口中央的“一键连接校园网”按钮，脚本随后自动等待 `jxnu_stu`、打开 Edge 认证页并提交登录。

窗口旁有“开机自启”复选框。勾选后，下次登录 Windows 会自动打开这个助手窗口；为避免开机时突然抢占网络或浏览器焦点，开机自启只打开窗口，不会替用户自动点击连接按钮。需要自动提交认证时，请使用下面的“全自动联网”模式。

### 全自动联网

Windows 登录后自动等待 `jxnu_stu` 并完成认证，不需要用户点击。

可以直接双击 `Setup-JXNUAutoLogin.cmd` 选择模式，也可以在 PowerShell 中执行：

```powershell
# 创建桌面一键联网快捷方式，不注册开机任务
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Setup-JXNUAutoLogin.ps1 -Mode one-click

# 注册 Windows 登录后自动联网任务
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Setup-JXNUAutoLogin.ps1 -Mode automatic
```

### 手动注册全自动任务

在本目录执行（不会修改系统执行策略）：

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-JXNUAutoLoginTask.ps1
```

也可以直接双击 `Install-JXNUAutoLoginTask.cmd`。它只注册全自动任务，适合已经确定使用全自动模式的情况。

任务名为 `JXNU Wi-Fi Auto Login`，以当前 Windows 用户运行，不需要管理员权限。

## 手动测试

先不要重启，可以手动执行：

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Start-JXNUAutoLogin.ps1 -ForceOpen
```

`-ForceOpen` 只会打开认证页；不会写入或输出密码。测试成功后再决定使用一键模式还是全自动模式。

## 采集门户按钮的屏幕坐标

如果需要记录认证页面上按钮的屏幕位置，可以双击 `Record-MousePosition.cmd`。

该启动器会优先调用已安装的 PowerShell 7（`pwsh.exe`）；只有找不到 PowerShell 7 时才回退到 Windows PowerShell 5.1（`powershell.exe`）。

- 按 `F1`：把当前鼠标位置复制到剪贴板，格式为 `X=1234, Y=567`；
- 每次记录同时追加到本目录的 `mouse-positions.txt`，避免剪贴板被下一次记录覆盖；
- 按 `Esc`：退出采集器。

该工具只读取鼠标位置和写入本地剪贴板/记录文件，不会点击页面、不提交账号密码，也不会修改网络、VPN 或浏览器设置。

坐标是相对于当前主屏幕左上角的屏幕坐标；采集和后续自动点击时应尽量保持相同的显示缩放、分辨率、浏览器窗口位置和页面布局。它适合作为采集/校准工具，不能单独保证页面改版后仍能准确点击。

## 卸载全自动任务

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-JXNUAutoLoginTask.ps1
```

## 为其他学校添加配置

1. 复制 `schools/example.json`，填写学校 Wi-Fi 名称、认证地址和绕过代理的主机名。
2. 在 `engine/campus-autologin.user.js` 顶部增加对应的 `@match`，并在 `PROFILES` 中添加认证域名、表单选择器和运营商值。
3. 在 Edge 中保存该学校认证页的账号密码。
4. 使用通用安装器注册对应配置：

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-CampusAutoLoginTask.ps1 -ConfigPath .\schools\example.json
```

## 兼容性边界

- 同样使用深澜 SRun 网关的学校，通常只需改配置和选择器。
- 页面结构不同但仍是网页认证的学校，需要调整选择器。
- Dr.COM、锐捷、NetKeeper、验证码、短信验证或统一身份认证等系统，需要单独适配器；本工具不会绕过验证码或二次确认。
- 如果出现新的校园网使用协议且复选框没有被门户记住，脚本不会替用户同意新协议。
- 如果 Edge 没有自动填充账号或密码，脚本不会提交空表单。
