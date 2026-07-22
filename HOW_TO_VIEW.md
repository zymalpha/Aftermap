# 如何查看当前效果（2026-07-23 实测）

诚实结论：**当前会话阶段你能看到的"效果"主要是测试日志和 JSON/代码可视化，因为 P0+P1 没做美术。**
真实可玩的可视化要等 P5 Beta 阶段。但你仍然能用下面 5 条路径看到 **逻辑/数据/性能** 全部按策划运行。

---

## 路径 1：跑全部测试（30 秒，最快看到全貌）

```bash
cd E:/0_BestSelf/0_末世游戏制作
bash run.sh
```

**期望输出末尾**：
```
=== Godot headless P0 spike ===
-- test_rng_determinism --
  PASS  identical seed produces identical 1000 draws
  PASS  post-draw state hashes equal
... (省略)
=== test_stage3_smoke result: pass=53 fail=0 ===
-- test_grid_pathfind --
=== test_grid_pathfind result: pass=23 fail=0 ===
... (省略)
=== 完成 ===
```

总计 **166 PASS / 0 FAIL**，证明：
- RNG 同种子同哈希（策划 11 §2.4）
- 存档原子写入 + 中断恢复（策划 11 §6）
- 事件解释器白名单拒绝恶意 op（策划 11 §4）
- A* 8 方向路径搜索（30 单位 < 33ms 预算）
- 对称 FOV、声音脉冲材质衰减、五阶段警觉 AI、感染 5 阶段（25/50/75/100 阈值）
- 半自动战斗（命中率 clamp 0.05–0.95，8 种武器）

## 路径 2：单独跑某个测试看具体数字

```bash
.tools/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path . --script game/tests/test_grid_pathfind.gd
```

**你会看到**：
```
[1] Grid chebyshev distance
  PASS  (0,0) -> (3,4) = 4
[2] Pathfinder A* 8-dir correctness
  PASS  path found, length=21
[3] Pathfinder 30-unit performance
  PASS  elapsed_ms < 33ms (got 29.035)
...
=== test_grid_pathfind result: pass=23 fail=0 ===
```

这个能让你**亲眼看到** A* 路径搜索在 32×32 网格上跑 30 次只花 29 毫秒（预算 33ms）。

## 路径 3：Python 内容校验器

```bash
python tools/content_validator/validate.py content/
```

**输出**：
```
OK: 7 files validated
```

这证明 7 份策划数据（1 个物品 / 1 个设施 / 1 个配方 / 1 个性格 / 1 个事件 / 1 个事件链 / 1 个 POI 房间）都通过 JSON Schema 严格校验。可以尝试故意改坏一个 JSON 看它失败：

```bash
# 改坏 sample_water_bottle.json 的 kind 字段
python -c "import json; d=json.load(open('content/items/sample_water_bottle.json')); d['kind']='bad_kind'; json.dump(d, open('content/items/sample_water_bottle.json','w'), ensure_ascii=False, indent=2)"
python tools/content_validator/validate.py content/
# 期望：FAIL: content/items/sample_water_bottle.json -> kind: 'bad_kind' is not one of [...]
# 退出码 1

# 还原
git checkout content/items/sample_water_bottle.json
```

## 路径 4：Godot 编辑器（仅看 HUD 占位）

⚠️ **重要提示**：当前 `tactical.tscn` 只包含 HUD 标签 + Camera，**没有任何可见的网格/角色/感染者渲染**（美术素材待 P5）。所以编辑器里"看效果"主要是看 HUD 文字变化。

```bash
# 启动 Godot 编辑器
cd E:/0_BestSelf/0_末世游戏制作
.tools/godot/Godot_v4.6.2-stable_win64.exe
```

编辑器里：
1. **File → Open Project** → 选 `project.godot`
2. 等 5-10 秒首次 import
3. 左侧 FileSystem 面板展开 `game/presentation/scenes/`
4. 双击 `tactical.tscn` 打开
5. 中央 viewport 会显示 `[Tactical] PAUSE` 文字 + 空白背景 + Camera
6. 顶部按 **▶** (F6) 运行游戏

**你会看到**：
- 1280×720 窗口
- 左上角 HUD 标签：`[Tactical] PAUSE`
- 其他全黑（无美术）

**这不能让你体验玩法**——只是验证场景能加载、Godot 引擎能跑。

## 路径 5：阅读设计文档（理解"为什么这么设计"）

按这个顺序读，大约 30 分钟掌握全部游戏设计：

| 文件 | 你会知道什么 |
|---|---|
| `README.md` | 项目一句话、当前进度、验收清单、已知限制 |
| `策划案/01_产品定位与游戏设计总纲.md` | 游戏是什么 / 受众 / 难度 / MVP 优先级 |
| `策划案/03_核心循环与战役流程.md` | 30 天战役怎么玩，三种时间尺度，一天状态机 |
| `策划案/06_探索潜行战斗与感染.md` | 战术探索怎么打，感染者怎么动 |
| `策划案/08_事件导演任务与内容规范.md` | 事件怎么生成，怎么影响剧情 |
| `策划案/12_MVP制作路线图与验收标准.md` | P0-P6 阶段，每个阶段交付什么 |
| `docs/production/PROJECT_STATE.md` | 当前做到哪，7 项已知风险，下一步 |
| `docs/api/game-session.md` | 状态机/RNG/存档的代码契约 |
| `docs/api/tactical-session.md` | 战术模块的代码契约 |
| `docs/adr/0001-0006` | 6 个架构决策的 WHY |

## 路径 6：代码层可视化（最推荐给程序员）

读代码、改阈值、跑测试看行为变化：

```bash
# 在 VS Code / Cursor 打开项目
code E:/0_BestSelf/0_末世游戏制作
```

**看 Grid + Pathfind**：
- `game/domain/tactical/grid.gd` — 32×32 像素/格、坐标系转换
- `game/domain/tactical/pathfinder.gd` — A* 8 方向实现（166 行）

**看警觉 AI**：
- `game/domain/tactical/alertness.gd` — 5 阶段状态机
- 改 `DECAY_SECONDS = 10.0` 为 `3.0`，再跑 `test_p1_tactical.gd` 看警觉衰减加速

**看战斗**：
- `game/domain/tactical/combat.gd` — 命中公式 `clamp(skill + 0.6 - dist - cover, 0.05, 0.95)`
- 改 `weapon_table` 里手枪伤害从 25 到 80，行为立刻变化

## 路径 7：用 Python 直接探索 JSON 内容

```bash
cd E:/0_BestSelf/0_末世游戏制作
python -c "
import json
for f in ['content/items/sample_water_bottle.json',
          'content/events/sample_first_night.json',
          'content/event-chains/sample_intro_welcome.json']:
    d = json.load(open(f, encoding='utf-8'))
    print(f'--- {f} ---')
    print(json.dumps(d, ensure_ascii=False, indent=2))
"
```

直接看到策划数据的形状——水瓶长什么样、第一个夜晚事件有什么选项、欢迎链 3 个节点怎么排序。

---

## 推荐组合（按你的角色）

| 如果你是... | 推荐路径 |
|---|---|
| **产品/策划** | 路径 5（读文档）+ 路径 7（看 JSON 数据） |
| **程序员** | 路径 1+2（看测试通过）+ 路径 6（改代码看效果）+ 路径 5 |
| **运维/打包** | 路径 1+2 + `README.md` 里的 30 分钟快速启动 |
| **投资人/评审** | 路径 5（理解设计意图）+ `PROJECT_STATE.md` 看进度 |

## 升级到"真正可玩"需要什么

| 缺口 | 阶段 | 估时 |
|---|---|---|
| 像素角色/感染者精灵 | P5 | 2-4 周（CC0 资源 + 占位组装） |
| 像素地块/墙壁 | P5 | 1-2 周 |
| UI 图标 | P5 | 1 周 |
| 主菜单 + 教程 | P5 | 2 周 |
| 音频（环境音 + 音乐） | P5 | 2-3 周 |

**如果你想立刻看到"截图能看的版本"**，我可以推进 **P5 占位美术批次**：从 Kenney.nl CC0 资源拉一组灰盒像素 + 我用程序生成 3 类感染者占位，1-2 个会话内出灰盒诊所截图版。这之前你看的都是逻辑层。
