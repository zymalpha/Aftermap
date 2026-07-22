## 摘要 / Summary

一句话说明这个 PR 做了什么。

例：实现 ADR-0006 地图管线第一段（OSM 解析为 .osm.pbf 索引）。

## 关联 / Related

- Issue: #xxx
- ADR: `docs/adr/0001..0006-*.md` 中受影响条目
- 阶段: P0 / P1 / P2 / P3 / P4 / P5 / P6
- 路线图条目: `docs/production/BACKLOG.md` 中对应的卡片 ID

## 变更类型 / Type of Change

- [ ] Bug 修复（不破坏既有行为的修复）
- [ ] 新功能（不破坏既有行为）
- [ ] 破坏性变更（需要 `SAVE-2` 迁移或 ADR 更新）
- [ ] 文档 / 注释
- [ ] 测试 / 性能 / 重构

## 测试 / Testing

- [ ] `python tools/content_validator/validate.py content` 退出码 0
- [ ] `bash run.sh` 退出码 0（Godot 4.6.2 headless 全部通过）
- [ ] 在 Windows 上额外运行 `run.bat`
- [ ] 新增 `game/tests/test_*.gd` 用例（如适用）
- [ ] 既有 `test_*.gd` 用例无需修改即可通过

## 检查清单 / Checklist

- [ ] 已遵守 `CONTRIBUTING.md` 的 GDScript 静态类型约定
- [ ] commit message 用中文（或中英混合）
- [ ] 修改了 README / ADR / 文档（如适用）
- [ ] 新增 JSON 已通过 `validate.py` 校验
- [ ] 没有引入云 API / 真实 OSM 抓取 / 加密密钥
- [ ] 没有修改 CI 的 `godot-headless` 版本（4.6.2-stable）

## 备注 / Notes

给 reviewer 看的一段话：实现思路、坑、风险、未来工作。