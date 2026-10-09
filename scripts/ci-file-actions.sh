#!/usr/bin/env bash
set -euo pipefail
# 未知版本必须先核对公开 API，不能静默关闭新 API 的消费者探针。
case "${1:?Provide an immutable release version}" in
  0.1.3|0.2.0-rc.1|0.2.0-rc.2|0.2.0-rc.3|0.2.0-rc.4) echo false ;;
  0.2.0-rc.5|0.2.0-rc.6|0.2.0-rc.7) echo true ;;
  *) echo "Unmapped file-actions contract: $1" >&2; exit 1 ;;
esac
