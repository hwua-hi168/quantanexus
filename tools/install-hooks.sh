#!/bin/bash
# 用法：仓库根目录下 ./tools/install-hooks.sh
set -e
[[ -d .git ]] || { echo "错误：请在仓库根目录运行"; exit 1; }

HOOKS_DIR=".git/hooks"
HOOK_SCRIPT='# Git 自动版本号钩子
QNI_VER=$(git describe --tags --always --dirty)
sed "s/{{ QNI_VER }}/$QNI_VER/" install/kubeasz/ezdown.in > install/kubeasz/ezdown
chmod +x ezdown
'

for hook in post-checkout post-commit; do
  # 覆盖写入，避免重复追加
  cat > "$HOOKS_DIR/$hook" <<<"$HOOK_SCRIPT"
  chmod +x "$HOOKS_DIR/$hook"
done

echo "Git hooks installed."