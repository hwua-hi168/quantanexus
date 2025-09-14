#!/bin/bash

ABC_EXP_SERVICE="${ABC_EXP_SERVICE}"
if [ -z "${ABC_EXP_SERVICE}" ]; then
    ABC_EXP_SERVICE="/usr/local/hw_experiment_service"
fi
echo "ABC_EXP_SERVICE[${ABC_EXP_SERVICE}]"
cd "${ABC_EXP_SERVICE}" || exit 1

# 启动前的钩子脚本
PreStartShell="${ABCExpPreStartShell}"
# 检查变量是否为空
if [ -n "${PreStartShell}" ]; then
  echo "start PreStartShell[${PreStartShell}]"
  bash "${PreStartShell}"
  echo "finish PreStartShell[${PreStartShell}]"
fi

cd "${ABC_EXP_SERVICE}" || exit 1
bash ./start.sh
