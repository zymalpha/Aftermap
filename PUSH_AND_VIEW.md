# 推送与查看（v1.0 合并版）

> 本文档合并了早期的 `PUSH_COMMANDS.md` / `PUSH_INSTRUCTIONS.md` / `FIX_PUSH.md` / `HOW_TO_VIEW.md`。
> 如果你看到旧文件名引用，以本文为准。

---

## 一、推送到 GitHub

### 1. 创建仓库（一次性）

打开 https://github.com/new ：
- **Repository name**：`Aftermap`（或 `aftermap`，大小写不敏感）
- **Owner**：`zymalpha`
- **Visibility**：**Private**（按策划 14 §七 推荐）
- **不要**勾 Add README / .gitignore / license（仓库已有完整内容）

### 2. 配置远程（HTTPS，推荐）

本机 Windows Credential Manager 已缓存 GitHub PAT，HTTPS 推送会自动复用，无需每次输密码。

```bash
cd E:/0_BestSelf/0_末世游戏制作
git remote add origin https://github.com/zymalpha/Aftermap.git
# 若已存在错误 remote：git remote set-url origin https://github.com/zymalpha/Aftermap.git
```

> ⚠️ **不要用 `git@github.com:...`（SSH）**：本机 SSH key 未绑到 GitHub，会报 `Permission denied (publickey)`。
> 之前能推是因为走 HTTPS + Credential Manager 缓存的 PAT。

### 3. 推送

```bash
git push -u origin main
git push origin v1.0.0   # 推 tag
```

首次推送若 PAT 过期（报 401），到 https://github.com/settings/tokens?type=beta 生成 fine-grained PAT（勾 `Contents: Read and write` + 选 `Aftermap` 仓库），推送时用户名填 GitHub 用户名、密码粘 PAT。Credential Manager 会缓存。

### 4. 备选：从 bundle 克隆推送

如果直推凭证麻烦，用 v1.0 bundle：

```bash
cd /d/workspace
git clone /e/0_BestSelf/0_末世游戏制作/aftermap-v1.0.bundle aftermap
cd aftermap
git remote add origin https://github.com/zymalpha/Aftermap.git
git push -u origin main
git push origin v1.0.0
rm -rf /d/workspace/aftermap   # 清理临时克隆
```

### 5. 验证

打开 https://github.com/zymalpha/Aftermap 应看到：
- 55 个 commit
- `v1.0.0` release tag
- emoji README + 5 张像素 SVG + 56 美术
- 完整 MVP 内容（60 事件 / 10 链 / 25 POI / 47 物品）

---

## 二、查看当前效果

### 路径 1：一键跑全部测试（30 秒，最快看到全貌）

```bash
cd E:/0_BestSelf/0_末世游戏制作
bash run.sh
```

期望末尾：**759 PASS / 0 FAIL**（497 GDScript + 40 pytest + 222 内容 schema）。

### 路径 2：单跑某个测试看具体数字

```bash
# 1000 种子 × 30 天压测（~60-140 秒）
.tools/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path . --script game/tests/test_p6_thousand_seeds.gd

# 30 单位性能基准
.tools/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path . --script game/tests/test_p6_perf_benchmark.gd

# 战术模块（网格/FOV/警觉/战斗/感染）
.tools/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path . --script game/tests/test_p1_tactical.gd
```

### 路径 3：Godot 编辑器看可视化

```bash
.tools/godot/Godot_v4.6.2-stable_win64.exe   # 双击启动
```

编辑器里：
1. **File → Open Project** → 选 `project.godot`
2. 等 5-10 秒首次 import
3. FileSystem 打开 `game/presentation/scenes/` 下任一 `.tscn`（main_menu / base_hud / tactical 等）
4. 按 **F6** 或 ▶ 运行

**当前能看到**：主菜单（AFTERMAP 标题 + 4 按钮）、基地 HUD（压力表盘 + 角色卡 + 资源条）、晨间报告、事件决策面板、设施升级、库存、教程、无障碍设置——全部用像素占位美术渲染。

### 路径 4：阅读设计文档

按顺序读，30 分钟掌握全部设计：

| 文件 | 知道什么 |
|---|---|
| `README.md` | 一句话定位 + 路线图 + 验收清单 |
| `策划案/01_产品定位与游戏设计总纲.md` | 游戏是什么 |
| `策划案/03_核心循环与战役流程.md` | 30 天怎么玩 |
| `docs/production/PROJECT_STATE.md` | 当前做到哪、已知风险 |
| `docs/adr/0001-0006` | 6 个架构决策的 WHY |

### 路径 5：Python 直接看内容数据

```bash
python -c "
import json, glob
for f in sorted(glob.glob('content/events/*.json'))[:3]:
    d = json.load(open(f, encoding='utf-8'))
    print(f'--- {f} ---')
    print(json.dumps(d, ensure_ascii=False, indent=2)[:500])
"
```

---

## 三、已知限制（v1.0）

- **Windows EXE 导出**需本机装 Godot 导出模板（GUI Godot 一次性操作），配置已就绪（`export_presets.cfg`）
- `test_p5_localization` 有 2/38 FAIL（.po 边界 bug，游戏运行不受影响，回退到 key）
- 真实 OSM 抓取仍是 `NotImplementedError` 占位（合规，P3+ 启用）
- 美术是程序生成的像素占位，非正式美术（策划 §10 正式美术待外包/CC0 整理）
