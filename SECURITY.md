# 安全策略 / Security Policy

## 支持的版本 / Supported Versions

| 版本    | 支持状态           |
| ------- | ------------------ |
| v0.1.x  | :white_check_mark: 活跃维护 |
| < v0.1  | :x: 不再维护        |

## 报告漏洞 / Reporting a Vulnerability

**请不要在公开 Issue 中报告安全漏洞。**

我们重视 Aftermap 及其用户的隐私与安全。请通过以下私有渠道之一报告漏洞：

1. **GitHub 私密联系**：在 GitHub 上 @ 项目维护者 `@zymalpha`（直接私信，不要在 Issue 区域公开）。
2. **邮件**：发送给项目所有者邮箱 `security@aftermap.local`（占位地址，请在第一次公开 Release 时替换为真实邮箱）。
3. **Discord / 微信**（如有）：联系维护者私下沟通。

我们会在 **72 小时内**确认收到你的报告，并在 **14 天内**给出评估与修复时间表。

## 漏洞披露流程 / Disclosure Process

1. **提交报告**：通过上述任一渠道发送漏洞细节（包括复现步骤、影响范围、可选的 PoC）。
2. **确认**：维护者确认漏洞并开始调查。
3. **修复**：在私密分支修复，添加回归测试，准备 release。
4. **披露**：漏洞修复后 90 天内公布；如果你希望更长的预披露期，请在报告时声明。
5. **致谢**：如果你愿意，我们会在公开 advisory 中注明你的名字（或匿名）。

## 我们关注的安全范围 / In Scope

- 存档完整性绕过：`save_v1.gd` 的 SHA-256 校验失效、`.bak` 回退路径被绕过（SAVE-2 相关）
- 事件解释器注入：绕过白名单执行任意 GDScript（ADR-0005）
- 内容校验绕过：让无效 JSON 进入 `ContentDB`（`validate.py` 漏检）
- RNG 流污染：让 `cosmetic_only` 流混入战斗判定（ADR-0003）
- 任意文件读写：通过 `GameSession` 命令路径读取仓库外文件
- 依赖供应链：`tools/content_validator/` 的 `jsonschema` 升级问题

## 范围外 / Out of Scope

- 与 Godot 4.6.2 引擎本身相关的安全问题（请向 godotengine/godot 上游报告）
- 与 `tools/map_pipeline/` 中抓取 OSM 的 PoC 相关的网络嗅探（OSM 抓取不在本期路线图内）
- 自带存档 `.bak` 加密强度问题（暂未启用加密，仅 SHA-256 完整性校验）

## 安全最佳实践 / Best Practices for Contributors

- 任何新增命令必须走 `GameSession.command_queue`，不得直接 mutate `state`
- 任何新增 JSON 必须通过 `python tools/content_validator/validate.py content`
- 任何新增事件关键字必须加入白名单（ADR-0005）
- 不要在 PR 中引入真实用户数据 / 邮件 / 凭证

---

感谢你帮助 Aftermap 更安全！