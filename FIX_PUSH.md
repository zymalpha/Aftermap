# 推送：修复后命令

## 根因
你机器上：
- ✅ Windows Credential Manager **已缓存** GitHub Personal Access Token（之前 HTTPS 推送都是这么成功的）
- ❌ SSH 通道上**没有可用 key**（`id_rsa.pub` / `id_ed25519_autodl.pub` 都没绑到 GitHub）
- ❌ 你刚才输的 `git@github.com:...` 走的是 SSH 通道，所以 Permission denied

## 已为你修好的改动
远程 URL 已从 `git@github.com:zymalpha/Aftermap.git`（SSH）改为 `https://github.com/zymalpha/Aftermap.git`（HTTPS，PAT 自动用）。

**大小写注意**：我用 `Aftermap.git`（大写 A），跟你仓库实际名一致；GitHub URL 大小写不敏感，但用你建的写法保持一致。

## 你只需执行
在 PowerShell / Git Bash：

```bash
cd E:/0_BestSelf/0_末世游戏制作
git push -u origin main
```

应该看到：
```
Username for 'https://github.com': <已自动填充/无需输入>
Password for 'https://zymalpha@github.com': <PAT 自动从 Credential Manager 读取>
```

→ 然后 8 个 commit 全部推上去。

## 如果仍然失败（PAT 失效/过期）
Credential Manager 里的 PAT 可能已过期或被 GitHub 撤销。重新生成一个：

1. 打开 https://github.com/settings/tokens?type=beta
2. **Generate new token** → Fine-grained
3. Token name：`aftermap-push-2026`
4. Expiration：随便（7 天即可）
5. Repository access：**Only select repositories** → 选 `Aftermap`
6. Permissions：**Contents: Read and write**
7. 生成后**只显示一次**，复制
8. 在 PowerShell 跑：
   ```bash
   git credential reject
   protocol=https
   host=github.com
   ```
   （按两次回车结束；清除旧 token）
9. 重新 push，会提示输入用户名 + 粘贴新 PAT 作为密码
10. Credential Manager 会缓存新 PAT，下次免输入

## Bundle 替代方案（无 PAT / 无 SSH key）

如果你只是想拿到 v0.2 代码但不想走 Git 推送，工作区根目录已经有：

```
aftermap-v0.2.bundle    # v0.2 release：P0–P4 全部完成 + 352 PASS
aftermap-p1.bundle      # v0.1 spike：P0 + P1 + 166 PASS（保留作历史）
```

直接 clone bundle 就能拿到完整仓库：

```bash
cd /d/workspace
git clone /e/0_BestSelf/0_末世游戏制作/aftermap-v0.2.bundle aftermap
cd aftermap
git log --oneline   # 看到 28 个 commit（含本次 v0.2 release）
bash run.sh          # 跑全量回归
```

## 推完验证
打开 https://github.com/zymalpha/Aftermap 应看到 9 个 commit（HEAD a07c73a 在最上）：
```
a07c73a docs: add PUSH_COMMANDS.md
0389bcc chore: push instructions + bundle
3f77c3d docs: stage 6 ...
c6c2320 feat(p1): tactical ...
6b3b85f test(p0): remaining P0 spike tests
bc18aaf feat(p0): GameSession/RNG/Clock + Save + EventInterpreter core + 53-pass smoke
de4216c feat(p0): ADR + JSON schema + content validator + sample data
e79e503 chore: add .gitignore, run scripts, docs skeleton
97f64fc chore: init repo with planning docs and skeleton dirs
```

## 为什么不推荐你 SSH
SSH 需要 key + GitHub 端公钥注册 + ssh-agent 服务（你这台机器 ssh-agent 没启动）。HTTPS + PAT 是 GitHub 官方推荐方式，对 Windows 用户更友好；Credential Manager 自动缓存，下次免密。
