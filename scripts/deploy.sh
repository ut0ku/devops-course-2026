#!/usr/bin/env bash

# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]

set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
LOCAL_DIR="$(git rev-parse --show-toplevel)/site/"

# 1. Разбор аргумента --dry-run
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# 2. Проверки по требованиям 4 и 5
# Требование 5: незафиксированные изменения
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незафиксированные изменения." >&2
    exit 1
fi

# Требование 4: наличие index.html
if [[ ! -f "${LOCAL_DIR}/index.html" ]]; then
    echo "Ошибка: файл site/index.html отсутствует." >&2
    exit 1
fi

# 3. Синхронизация каталога ${LOCAL_DIR} на ${REMOTE}:${REMOTE_DIR}
RSYNC_CMD="rsync -avz --delete --chmod=D755,F644"
if [[ "$DRY_RUN" == "true" ]]; then
    RSYNC_CMD="${RSYNC_CMD} --dry-run"
fi
$RSYNC_CMD "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"

# 4. При --dry-run — завершение с кодом 0 без проверки доступности
if [[ "$DRY_RUN" == "true" ]]; then
    echo "Пробный запуск завершен."
    exit 0
fi

# 5. Проверка доступности ${SITE_URL} и завершение с корректным кодом возврата
if ! curl -fsS --cacert "${CA_CERT}" "${SITE_URL}" > /dev/null; then
    echo "Ошибка: ресурс недоступен по адресу ${SITE_URL}." >&2
    exit 1
fi

# Успешное завершение (Требование 7)
echo "Деплой успешно завершен. Коммит: $(git rev-parse --short HEAD)"
exit 0
