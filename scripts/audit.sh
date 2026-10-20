#!/usr/bin/env bash
set -uo pipefail

PASS=0; FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo " [OK]  $desc"
        ((PASS++))
    else
        echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"
        ((FAIL++))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

# TODO 1
PORT=$(sudo sshd -T | awk '/^port/{print $2}')
if [[ "$PORT" != "22" ]]; then
    echo " [OK]  Порт SSH нестандартный (port=$PORT)"
    ((PASS++))
else
    echo " [FAIL] Порт SSH стандартный (port=22)"
    ((FAIL++))
fi

# TODO 2
check "MaxAuthTries равен 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"

# TODO 3
check "Политика incoming = deny" "deny" "$(sudo ufw status verbose | awk '/^Default:/{print $2}')"

echo "[3] Учётные записи"
awk -F: ' $3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd

# --- Новый раздел 4 ---
echo "[4] Веб-сервер"

# Проверка конфигурации nginx
check "Конфигурация Nginx корректна" "0" "$(sudo nginx -t >/dev/null 2>&1; echo $?)"

# Проверка срока действия сертификата (более 30 дней)
check "Сертификат действителен более 30 дней" "0" "$(sudo openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/devops.crt >/dev/null 2>&1; echo $?)"

# Проверка отсутствия файлов с правом записи для всех
check "Нет файлов с правом записи для всех" "" "$(sudo find /var/www/devops-site -perm -o+w)"

# Проверка прав на ключ (должно быть 600)
check "Права на ключ TLS (600)" "600" "$(sudo stat -c '%a' /etc/ssl/private/devops.key)"

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
