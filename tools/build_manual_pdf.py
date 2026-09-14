from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak,
    KeepTogether
)

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output" / "pdf" / "校园网自动认证工具-使用与排错手册.pdf"
OUT.parent.mkdir(parents=True, exist_ok=True)

font_regular = Path(r"C:\Windows\Fonts\simhei.ttf")
font_bold = Path(r"C:\Windows\Fonts\simhei.ttf")
if not font_regular.exists():
    raise FileNotFoundError(f"中文字体不存在: {font_regular}")
pdfmetrics.registerFont(TTFont("CampusSans", str(font_regular)))
pdfmetrics.registerFont(TTFont("CampusSansBold", str(font_bold)))

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(
    name="CoverTitle", fontName="CampusSansBold", fontSize=25,
    leading=34, alignment=TA_CENTER, textColor=colors.HexColor("#17324D"),
    spaceAfter=8*mm
))
styles.add(ParagraphStyle(
    name="CoverSub", fontName="CampusSans", fontSize=12, leading=20,
    alignment=TA_CENTER, textColor=colors.HexColor("#52606D")
))
styles.add(ParagraphStyle(
    name="H1Campus", fontName="CampusSansBold", fontSize=17, leading=24,
    textColor=colors.HexColor("#17324D"), spaceBefore=3*mm, spaceAfter=4*mm
))
styles.add(ParagraphStyle(
    name="H2Campus", fontName="CampusSansBold", fontSize=12, leading=18,
    textColor=colors.HexColor("#0B7285"), spaceBefore=3*mm, spaceAfter=2*mm
))
styles.add(ParagraphStyle(
    name="BodyCampus", fontName="CampusSans", fontSize=9.5, leading=16,
    textColor=colors.HexColor("#263238"), spaceAfter=2.2*mm
))
styles.add(ParagraphStyle(
    name="SmallCampus", fontName="CampusSans", fontSize=8, leading=12,
    textColor=colors.HexColor("#52606D")
))
styles.add(ParagraphStyle(
    name="TableCampus", fontName="CampusSans", fontSize=8.3, leading=12,
    textColor=colors.HexColor("#263238")
))
styles.add(ParagraphStyle(
    name="TableHeadCampus", fontName="CampusSansBold", fontSize=8.5,
    leading=12, textColor=colors.white, alignment=TA_CENTER
))

def P(text, style="BodyCampus"):
    return Paragraph(text, styles[style])

def bullet(text):
    return P("• " + text)

def page_decor(canvas, doc):
    canvas.saveState()
    width, height = A4
    canvas.setStrokeColor(colors.HexColor("#D9E2EC"))
    canvas.line(18*mm, height-16*mm, width-18*mm, height-16*mm)
    canvas.setFont("CampusSans", 8)
    canvas.setFillColor(colors.HexColor("#7B8794"))
    canvas.drawString(18*mm, 10*mm, "校园网自动认证工具 | 使用与疑难排错")
    canvas.drawRightString(width-18*mm, 10*mm, f"第 {doc.page} 页")
    canvas.restoreState()

def make_table(rows, widths, header=True):
    converted = []
    for row_index, row in enumerate(rows):
        converted.append([
            Paragraph(str(cell), styles["TableHeadCampus" if header and row_index == 0 else "TableCampus"])
            for cell in row
        ])
    table = Table(converted, colWidths=widths, repeatRows=1 if header else 0)
    commands = [
        ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#BCCCDC")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]
    if header:
        commands += [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#0B7285")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ]
        for idx in range(1, len(rows)):
            commands.append(("BACKGROUND", (0, idx), (-1, idx), colors.HexColor("#F5F7FA" if idx % 2 else "#FFFFFF")))
    table.setStyle(TableStyle(commands))
    return table

story = []
story.append(Spacer(1, 30*mm))
story.append(P("校园网自动认证工具", "CoverTitle"))
story.append(P("使用过程与疑难排错手册", "CoverSub"))
story.append(Spacer(1, 12*mm))
story.append(make_table([
    ["适用版本", "当前工具包"],
    ["默认学校", "江西师范大学 | jxnu_stu"],
    ["浏览器", "Microsoft Edge（复用已保存密码）"],
    ["联网方式", "一键半自动 / 开机全自动"],
], [42*mm, 112*mm]))
story.append(Spacer(1, 12*mm))
story.append(P("本手册对应同目录下的 PowerShell 脚本、Edge 用户脚本和学校配置文件。工具不会把校园网密码写入脚本，也不会主动修改 Clash、VPN 或网卡设置。", "BodyCampus"))
story.append(PageBreak())

story.append(P("1. 两种联网模式", "H1Campus"))
story.append(P("安装时只选择一种模式即可。两种模式使用同一个认证引擎，区别只是启动时机。", "BodyCampus"))
story.append(make_table([
    ["模式", "怎样触发", "适合谁", "注意事项"],
    ["一键联网（半自动）", "双击桌面快捷方式后运行", "希望开机后自行决定何时联网的人", "不会创建开机任务；需要用户点一次"],
    ["自动联网（全自动）", "用户登录 Windows 后由任务计划程序运行", "希望进入桌面后自动认证的人", "需要先安装任务；若 Wi-Fi 尚未就绪会等待"],
], [31*mm, 42*mm, 46*mm, 43*mm]))
story.append(Spacer(1, 4*mm))
story.append(P("推荐先用一键模式验证校园网、Edge 保存密码和运营商选择都正常，再切换到全自动模式。", "BodyCampus"))

story.append(P("2. 安装与切换", "H1Campus"))
story.append(P("最简单的入口是双击 <b>Setup-JXNUAutoLogin.cmd</b>，然后按提示选择：1 为一键联网，2 为全自动联网。", "BodyCampus"))
story.append(P("也可以在 PowerShell 中执行：", "BodyCampus"))
story.append(P("一键模式：<font name='Courier'>.\\Setup-JXNUAutoLogin.ps1 -Mode one-click</font><br/>全自动模式：<font name='Courier'>.\\Setup-JXNUAutoLogin.ps1 -Mode automatic</font>", "BodyCampus"))
story.append(bullet("一键模式会在桌面创建“江西师范大学校园网一键连接.lnk”，并移除本工具自己创建的同名自动任务。"))
story.append(bullet("全自动模式会注册“JXNU Wi-Fi Auto Login”任务，触发后等待 jxnu_stu 连接，再打开 Edge 认证。"))
story.append(bullet("两种模式都不会立即替你断开当前网络，也不会在本次制作过程中触发登录。"))

story.append(P("3. 日常使用流程", "H1Campus"))
story.append(P("一键模式", "H2Campus"))
story.append(P("1）确认电脑已打开 Wi-Fi；2）确认连接到 <b>jxnu_stu</b>；3）双击桌面快捷方式；4）等待 Edge 打开校园网页面；5）脚本把运营商切换到电信并点击登录；6）看到网页显示认证成功后即可上网。", "BodyCampus"))
story.append(P("全自动模式", "H2Campus"))
story.append(P("Windows 登录后任务会在后台等待目标 Wi-Fi。Wi-Fi 就绪后，脚本打开 Edge 并执行同样的认证流程。若校园网尚未发放地址或门户暂时不可达，脚本会等待并记录状态，不会填写空密码。", "BodyCampus"))
story.append(PageBreak())

story.append(P("4. 常见问题与排错", "H1Campus"))
story.append(make_table([
    ["现象", "优先检查", "处理方式"],
    ["桌面快捷方式点了没反应", "Wi-Fi 是否连接到 jxnu_stu；PowerShell 执行策略", "在工具目录执行 <font name='Courier'>powershell -ExecutionPolicy Bypass -File .\\Start-JXNUAutoLogin.ps1 -ForceOpen</font> 查看提示"],
    ["Edge 打开但没有自动登录", "Edge 是否已保存密码；用户脚本是否启用", "确认对应门户页已安装并启用 <b>engine/campus-autologin.user.js</b>；不要在无密码时强制提交"],
    ["运营商没有切到电信", "门户页面结构是否变化", "检查页面是否仍有 <font name='Courier'>@ctcc</font> 或“电信”选项；若学校改版，需要更新用户脚本选择器"],
    ["全自动模式没有启动", "任务是否存在、Wi-Fi 是否晚于任务启动", "运行 <font name='Courier'>Get-ScheduledTask -TaskName 'JXNU Wi-Fi Auto Login'</font>；任务会等待目标 SSID，不要重复安装多个同名任务"],
    ["Clash TUN/VPN 开启后认证失败", "门户是否被代理拦截；本地门户是否可达", "工具只对校园门户和连通性探测使用直连检查，不会删除 VPN；必要时暂时关闭规则代理后再测试"],
    ["提示 651 或没有网络", "网卡链路、交换机/校园网设备、驱动", "先确认 Windows 能看到 Wi-Fi 已连接；651 通常不是密码问题，按物理链路和校园网设备顺序排查"],
], [39*mm, 48*mm, 75*mm]))
story.append(Spacer(1, 4*mm))
story.append(P("日志位置：<font name='Courier'>%LOCALAPPDATA%\\CampusAutoLogin\\jxnu-stu.log</font>。日志只记录 SSID、门户可达性、浏览器启动和认证阶段，不记录密码。", "BodyCampus"))

story.append(P("5. 安全与隐私", "H1Campus"))
story.append(bullet("密码继续由 Edge 的密码管理器保存；脚本只等待浏览器自动填充，不读取或导出密码。"))
story.append(bullet("脚本不会上传账号、密码、浏览记录或日志。"))
story.append(bullet("用户脚本默认不勾选新的协议确认框；如果页面要求首次人工同意，请先手动完成一次。"))
story.append(bullet("如需停止全自动联网，运行 <font name='Courier'>.\\Uninstall-JXNUAutoLoginTask.ps1</font>；这只移除本工具创建的任务，不会卸载 Edge、Clash 或 VPN。"))
story.append(PageBreak())

story.append(P("6. 适配其他学校", "H1Campus"))
story.append(P("引擎与学校信息分离。复制 <b>schools/example.json</b>，填写目标学校的 SSID、门户地址、需要直连的门户主机和连通性探测地址，再把配置路径传给 Setup-CampusAutoLogin.ps1。", "BodyCampus"))
story.append(P("还需要在 <b>engine/campus-autologin.user.js</b> 中增加该学校门户的 <font name='Courier'>@match</font> 和选择器 profile。不同学校的门户页面字段可能完全不同，不能只改 SSID 就保证自动登录。", "BodyCampus"))
story.append(P("适配完成后的最小验收：一键模式能打开门户、Edge 能自动填充、运营商选择正确、点击登录后能访问公网；确认无误后再安装全自动任务。", "BodyCampus"))

story.append(P("7. 卸载", "H1Campus"))
story.append(P("运行 <font name='Courier'>.\\Uninstall-JXNUAutoLoginTask.ps1</font> 移除自动任务；然后可手动删除桌面快捷方式和工具目录。卸载不会删除 Edge 保存的校园网密码，也不会修改 VPN 或 Clash。", "BodyCampus"))
story.append(Spacer(1, 6*mm))
story.append(P("当前包未执行真实登录测试；请先用一键模式在你方便时验证。", "SmallCampus"))

doc = SimpleDocTemplate(
    str(OUT), pagesize=A4, leftMargin=18*mm, rightMargin=18*mm,
    topMargin=22*mm, bottomMargin=18*mm, title="校园网自动认证工具-使用与排错手册",
    author="Codex"
)
doc.build(story, onFirstPage=page_decor, onLaterPages=page_decor)
print(OUT)
