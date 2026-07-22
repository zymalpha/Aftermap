# 贡献指南 / Contributing to Aftermap

感谢你对 Aftermap 的兴趣！这是一份关于代码、提交、PR、Issue 全流程的开发约定。请在动手前通读一遍。

---

## 1. 开发环境

| 工具        | 版本要求                       | 说明                                       |
| ----------- | ------------------------------ | ------------------------------------------ |
| Godot       | **4.6.2-stable**（Compatibility renderer / GL） | 不要用 4.5 / 4.7 / 4.8；CI 锁死版本。 |
| Python      | **3.9+**                       | 用于 `tools/content_validator/validate.py`。 |
| Git         | 2.30+                          | 中文 commit message；签名可选。            |
| OS          | Windows 11 / Ubuntu 22.04 / macOS 14 | CI 使用 Ubuntu runner。              |

> Godot 工程使用 **GL Compatibility** 渲染后端，不要切换到 Forward+ / Mobile。

---

## 2. 仓库布局速记

```
game/             # 全部 GDScript
  core/           # GameSession / RNG / Clock / ContentDB
  domain/         # tactical / events / infection / inventory / survivors / world
  adapters/       # saves / localization / maps
  presentation/   # pixel scaling / scenes / UI
  tests/          # test_*.gd，CI 一键跑
content/          # JSON 数据 + schemas
docs/
  adr/            # ADR-0001..0006
  api/            # API 契约
  production/     # PROJECT_STATE / BACKLOG / DECISIONS / CHANGELOG_DEV
tools/
  content_validator/  # Python jsonschema 校验器
  map_pipeline/       # OSM 管线（P3）
```

完整结构与含义见 `README.md` 和 `docs/production/PROJECT_STATE.md`。

---

## 3. GDScript 静态类型约定（强约束）

- 函数参数和返回值必须显式标注类型，例：
  ```gdscript
  func roll(rng: RandomNumberGenerator, stream: StringName) -> int:
      ...
  ```
- 变量使用 `:=` 推断；只在必要时显式标注。
- `class_name` 必须出现在 `extends` 之后、方法之前。
- 避免 `_process` / `_physics_process` 中做重活；命令应进 `GameSession` 队列。
- 任何与 `cosmetic_only` 之外的随机性都走 **8 个命名 RNG 流** 之一（见 `ADR-0003`）。

---

## 4. 内容数据约定

- 所有 ID 形如 `^[a-z]+_[a-z0-9_]+$`，例：`item_medkit_basic`、`event_first_night_calm`。
- 每次新增 / 修改 JSON 都需要重跑 `python tools/content_validator/validate.py content`。
- 不要绕过 `tools/content_validator/`。即使本地缺 jsonschema，也至少跑通 CI。
- 任何新事件关键字必须加入 `tools/content_validator/.../event_whitelist.json`（白名单解释器，ADR-0005）。

---

## 5. Commit Message 约定（中文）

格式：

```
<类型>(<范围>): <中文简短描述>

[可选正文]
[可选脚注]
```

类型（与 ADR/路线图语义对齐）：

| 类型      | 用途                                     |
| --------- | ---------------------------------------- |
| `feat`    | 新功能 / 新阶段                          |
| `fix`     | Bug 修复                                 |
| `chore`   | 工程杂项（脚本、CICD、目录整理）         |
| `docs`    | 文档 / ADR / README                      |
| `test`    | 新增 / 调整测试                          |
| `refactor`| 重构（不改变行为）                       |
| `deps`    | 依赖升级                                 |
| `ci`      | CI / GitHub Actions                      |

示例：

```
feat(tactical): 加入 infected_three.svg 三目标渲染
fix(save): SAVE-1 修复 race，导致 .bak 被覆盖
docs(adr): 0007 新增 SAVE 迁移 ADR
chore(tools): 把 .tools/godot 改成缓存目录
ci(workflows): dependabot 周更
```

> 我们不在 commit message 里写 WIP / "update" / "fix again"。

---

## 6. PR 流程

1. **Fork → 分支**：从 `main` 拉分支，命名 `feat/xxx`、`fix/xxx`、`docs/xxx`。
2. **本地跑通**：
   ```bash
   python tools/content_validator/validate.py content
   bash run.sh
   ```
   都必须退出码 0。
3. **小步提交**：每个 commit 独立可回滚；避免 squash 把不相关的改动粘在一起（除非是 chore / docs）。
4. **PR 模板**：使用 `.github/PULL_REQUEST_TEMPLATE.md`，填写：
   - 关联 Issue / ADR
   - 阶段（P0~P6）
   - 测试结果截图 / 终端输出
   - 是否破坏存档（需要 `SAVE-2` 迁移？）
5. **Review 期望**：
   - 至少 1 位 maintainer 同意才能合
   - CI 全绿（content-validate / godot-headless / readme-checks）
   - 重大架构改动需要在 `docs/adr/` 加新 ADR
6. **合入后**：把对应 `docs/production/CHANGELOG_DEV.md` 追加一行。

---

## 7. Issue 流程

- Bug：用 `.github/ISSUE_TEMPLATE/bug_report.md`
- 功能：用 `.github/ISSUE_TEMPLATE/feature_request.md`
- 标签由 maintainer 首次 triage 时打。

---

## 8. 严禁事项（来自策划 14 §八 §九）

- ❌ 不引入云 API / SaaS 后端
- ❌ 不真实抓取 OpenStreetMap 数据（OSM 抓取推迟到 P3+；当前只能用 `tools/map_pipeline/` 的本地样本）
- ❌ 不修改事件白名单解释器为 `eval` / 表达式注入
- ❌ 不绕过 `GameSession` 直接改状态
- ❌ 不把游戏字符串硬编码英文在玩法逻辑里（必须走 localization）

违反任何一条，PR 直接关。

---

## 9. 沟通

- 提交 Issue / PR 前先看 `docs/production/PROJECT_STATE.md` 与 `docs/adr/0001..0006`。
- 长讨论放 Issue，不在 PR 里吵架。

欢迎贡献，祝玩得开心 🎮