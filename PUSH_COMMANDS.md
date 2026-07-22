# 推送命令（1 分钟完成）

## 前置：创建 GitHub 仓库

打开 https://github.com/new ，填：
- **Repository name**：`aftermap`
- **Owner**：`zymalpha`（你的用户名）
- **Visibility**：**Private**（私有，按策划 14 §七 推荐）
- **不要**勾 Add a README / .gitignore / license（我们已有完整内容）

点 **Create repository**，你会看到一个空仓库的快速指引页。

## 推送（PowerShell 或 Git Bash 任选）

### 方法 A：直推（推荐，最快）

```bash
cd /e/0_BestSelf/0_末世游戏制作
git remote add origin git@github.com:zymalpha/aftermap.git
# 如果你用 HTTPS 而不是 SSH，把上面那行换成：
# git remote add origin https://github.com/zymalpha/aftermap.git
git push -u origin main
```

首次推送会要求认证：
- **SSH**：确保 `~/.ssh/id_ed25519` 已加到 GitHub Settings → SSH keys
- **HTTPS**：用 GitHub 用户名 + PAT（不是密码；PAT 在 Settings → Developer settings → Personal access tokens → Fine-grained tokens 创建，勾选 `Contents: Read and write`，Repository access 选 `Only select repositories → aftermap`）

完成后你会看到：
```
* [new branch]      main -> main
Branch 'main' set up to track remote 'main' from 'origin'.
```

### 方法 B：从 bundle 克隆推送（如果方法 A 凭证麻烦）

```bash
# 1. 在工作区外（如 D:\workspace）从 bundle 克隆
cd /d/workspace
git clone /e/0_BestSelf/0_末世游戏制作/aftermap-p1.bundle aftermap
cd aftermap

# 2. 接远程 + 推送
git remote add origin git@github.com:zymalpha/aftermap.git
git push -u origin main
```

完成后删除临时克隆：`rm -rf /d/workspace/aftermap`

## 验证推送成功

打开 https://github.com/zymalpha/aftermap 应该看到 8 个 commit：
```
0389bcc chore: push instructions + bundle
3f77c3d docs: stage 6 production + api docs, README, CHANGELOG, test runners
c6c2320 feat(p1): tactical grid + pathfind + movement + FOV + sound + alertness + combat + search + infection
6b3b85f test(p0): remaining P0 spike tests (command_queue, grid_pathfind, pixel_scaling)
bc18aaf feat(p0): GameSession/RNG/Clock + Save + EventInterpreter core + 53-pass smoke
de4216c feat(p0): ADR + JSON schema + content validator + sample data
e79e503 chore: add .gitignore, run scripts, docs skeleton
97f64fc chore: init repo with planning docs and skeleton dirs
```

## 推送完告诉我

如果你希望我继续推进 P2（七日纵向切片）或者再开一个新工作流（比如 P3 真实 OSM 地图流水线），告诉我即可。

---

# 查看当前效果

当前会话已经可以**自动验证**一切（166 PASS / 0 FAIL），但你可能想看 **可视化** 跑起来是什么样子。当前阶段 P0+P1 只交付**逻辑层**（无美术素材），所以"看效果"有几条路径：

## 路径 1：跑 P1 战术场景（占位美术）

打开 Godot 编辑器（你机器上的 Godot 4.x 任意版本）：

```bash
cd /e/0_BestSelf/0_末世游戏制作
.tools/godot/Godot_v4.6.2-stable_win64.exe  # 双击即可
```

在编辑器里：
1. **File → Open Project** → 选 `E:\0_BestSelf\0_末世游戏制作\project.godot`
2. 等扫描结束（首次会 import 资源）
3. 顶部菜单 **Project → Project Settings → Rendering → Renderer** 确认是 `gl_compatibility`
4. 在文件系统面板打开 `game/presentation/scenes/tactical.tscn`
5. 按 **F6** 或顶部播放按钮 ▶

**你会看到**：24×24 灰盒诊所、占位精灵（无图时��示方块）、控制台输出场景加载日志
**输入**：WASD/方向键移动，Space 暂停，1/2 切速度，鼠标点击下达命令
**预期**：3 类感染者占位在格子上跑警觉 AI；你能跑完整战术回合（虽然看不到漂亮图）

⚠️ 当前 `tactical.tscn` 是最小可加载占位（策划 §10 美术素材待 P5），所以**视觉上很朴素**，但逻辑全跑通。

## 路径 2：纯 headless 看日志（最快）

```bash
cd /e/0_BestSelf/0_末世游戏制作
.tools/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path . --script game/tests/test_p1_tactical.gd
.tools/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path . --script game/tests/test_stage3_smoke.gd
.tools/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path . --script game/tests/test_grid_pathfind.gd
```

会看到 52 + 53 + 23 = **128 条 PASS**，含性能数字（"elapsed_ms < 33ms"）。

## 路径 3：全部跑一次（一键）

```bash
bash run.sh
```

会跑 Python 校验器 + 全部 5 个 Godot 测试，输出 `<tests/166 PASS 0 FAIL>`。

## 路径 4：翻文档了解"游戏到底设计成什么样"

打开这些文件就能掌握游戏全貌（按阅读顺序）：
1. `README.md` — 一句话定位 + 验收清单
2. `策划案/00_文档导航与决策总表.md` — 14 份策划导航
3. `策划案/01_产品定位与游戏设计总纲.md` — 游戏是什么
4. `策划案/03_核心循环与战役流程.md` — 30 天怎么玩
5. `docs/production/PROJECT_STATE.md` — 当前做到哪、还差什么
6. `docs/production/BACKLOG.md` — P2-P6 待办

## 路径 5：可视化战术模块（适合快速理解）

如果编辑器里能看到战术场景但太朴素，你可以临时**自己改一格**看反馈：

1. 打开 `game/domain/tactical/grid.gd` 看 PIXELS_PER_TILE=32
2. 打开 `game/domain/tactical/alertness.gd` 把 ALERT_HP_THRESHOLD 改一下
3. F5 重新跑——看到 AI 警觉行为改变

这就是"程序员式"查看效果——直接改代码看行为变化。P5 之前美术空白，但**逻辑可调可玩**。