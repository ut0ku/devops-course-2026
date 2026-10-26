# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины

- **Наименование VM:** `devops-vm`
- **ОЗУ:** 2048 МБ
- **Ядер процессора:** 2
- **Объём диска:** 25 ГБ (динамически расширяемый)
- **Тип и версия гостевой ОС:** Ubuntu Server 24.04 LTS (Noble Numbat), 64-bit
- **Средство виртуализации:** VirtualBox 7.x

## 2. Сетевые интерфейсы

| Интерфейс | Тип адаптера | IP-адрес | Назначение |
|---|---|---|---|
| `enp0s3` | NAT | `10.0.2.15/24` | Доступ в интернет (репозитории пакетов) |
| `enp0s8` | Host-only Adapter | `192.168.56.107/24` | Прямой доступ с хостовой системы, `devops.local` |

- **NAT** — гостевая система в сегменте `10.0.2.0/24`. Доступ в интернет осуществляется через гипервизор, входящие соединения доступны только через проброс портов.
- **Host-only** — изолированный сегмент `192.168.56.0/24`. Гостевая система доступна с хостовой напрямую.

## 3. Правило проброса портов

| Адаптер | Имя правила | Протокол | IP хоста | Порт хоста | IP гостя | Порт гостя |
|---|---|---|---|---|---|---|
| Adapter 1 (NAT) | SSH | TCP | `127.0.0.1` | `2222` | (пусто) | `2222` |

**Порт гостя** — `2222` (не `22`!), поскольку SSH перенастроен на нестандартный порт в шаге 2.3.

## 4. Учётные записи

| Имя | Группы | Способ аутентификации |
|---|---|---|
| `student` | `student`, `sudo`, `users` | Пароль (для консоли и sudo) |
| `devops` | `devops`, `sudo`, `users` | SSH-ключ `devops_vm` (ed25519), пароль для sudo |

- **Пользователь `devops`** создан в задании 1 и добавлен в группу `sudo`.
- **Пользователь `root`** — вход по SSH **запрещён** (`PermitRootLogin no`).

## 5. Служба SSH

- **Порт:** `2222` (нестандартный)
- **Файл конфигурации:** `/etc/ssh/sshd_config.d/99-hardening.conf`
- **Бэкап основного конфига:** `/etc/ssh/sshd_config.backup`
- **Метод активации:** `ssh.service` (не `ssh.socket`)

### Изменённые директивы

| Директива | Значение | Назначение |
|---|---|---|
| `Port` | `2222` | Нестандартный порт |
| `PermitRootLogin` | `no` | Запрет входа под root |
| `PasswordAuthentication` | `no` | Только ключи |
| `PubkeyAuthentication` | `yes` | Ключевая аутентификация |
| `PermitEmptyPasswords` | `no` | Запрет пустых паролей |
| `MaxAuthTries` | `3` | 3 попытки на подключение |
| `LoginGraceTime` | `30` | 30 секунд на вход |
| `AllowUsers` | `devops` | Только пользователь devops |
| `X11Forwarding` | `no` | X11 запрещён |
| `ClientAliveInterval` | `300` | Пинг клиента каждые 300 сек |
| `ClientAliveCountMax` | `2` | Разрыв через 2 пропущенных пинга |

**Важно:** в `/etc/ssh/sshd_config.d/50-cloud-init.conf` строка `PasswordAuthentication yes` закомментирована, иначе она могла бы переопределить значение из `99-hardening.conf`.

## 6. Правила межсетевого экрана

- **Утилита:** UFW (Uncomplicated Firewall)
- **Статус:** `active`
- **Политики по умолчанию:** `deny incoming`, `allow outgoing`, `disabled routed`
- **Логирование:** `medium`

| Порт | Протокол | Действие | Комментарий |
|---|---|---|---|
| `2222` | TCP | `LIMIT` | SSH rate-limited |
| `80` | TCP | `ALLOW` | HTTP |
| `443` | TCP | `ALLOW` | HTTPS |

**`LIMIT`** — ограничение частоты подключений для защиты от брутфорса.

## 7. Снимки состояния

| Наименование | Момент создания | Что зафиксировано |
|---|---|---|
| `01-clean-install` | После установки Ubuntu, до всех изменений | Чистая система |
| `02-keys-configured` | После задания 1 | Пользователь devops, ключи, `~/.ssh/config` |
| `03-ssh-hardened` | После задания 2 | Hardening SSH (порт 2222, запрет root/паролей) |

## 8. Инструкция по восстановлению

### 8.1. Восстановление пользователей и SSH

**1. Запуск SSH:**

```bash
sudo systemctl enable --now ssh.service
```

**2. Создание пользователя `devops`:**

```bash
sudo adduser devops
```

**3. Выдача прав sudo:**

```bash
sudo usermod -aG sudo devops
```

### 8.2. Настройка ключей

**4. Копирование открытого ключа на сервер:**

```bash
ssh-copy-id -i ~/.ssh/devops_vm.pub -p 2222 devops@127.0.0.1
```

### 8.3. Hardening SSH

**5. Бэкап конфига:**

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
```

**6. Создание дополняющего файла:**

```bash
sudo nano /etc/ssh/sshd_config.d/99-hardening.conf
```

Содержимое файла:

```text
Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
LoginGraceTime 30
AllowUsers devops
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
```

**7. Комментирование конфликтной строки:**

```bash
sudo sed -i 's/^PasswordAuthentication yes/#PasswordAuthentication yes/' /etc/ssh/sshd_config.d/50-cloud-init.conf
```

**8. Отключение socket-активации:**

```bash
sudo systemctl disable --now ssh.socket
```

**9. Включение обычной службы:**

```bash
sudo systemctl enable --now ssh.service
```

**10. Перезапуск SSH:**

```bash
sudo systemctl restart ssh
```

### 8.4. Проброс портов в VirtualBox

**11. Изменение правила проброса портов:**

1. Выключить виртуальную машину.
2. Открыть настройки сети: `Adapter 1 → Advanced → Port Forwarding`.
3. Изменить `Guest Port` с `22` на `2222`.

### 8.5. Межсетевой экран

**12. Задание политик и создание правил:**

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 2222/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
```

**13. Активация:**

```bash
sudo ufw enable
```

**14. Замена правила SSH на LIMIT:**

```bash
sudo ufw delete allow 2222/tcp
sudo ufw limit 2222/tcp comment 'SSH rate-limited'
```

**15. Включение логирования:**

```bash
sudo ufw logging medium
```

### 8.6. Доменное имя

**16. Установка hostname:**

```bash
sudo hostnamectl set-hostname devops-vm
```

**17. Настройка FQDN в `/etc/hosts`:**

```bash
sudo sed -i 's/^127.0.1.1.*/127.0.1.1 devops-vm.devops.local devops-vm/' /etc/hosts
```

### 8.7. Скрипт аудита

**18. Копирование скрипта** (выполняется на Windows в папке репозитория):

```bash
scp scripts/audit.sh devops:~/audit.sh
```

Запуск на сервере:

```bash
bash ~/audit.sh
```

## 9. Контейнеризация

- **Способ установки Docker Engine:** Официальный репозиторий Docker (согласно инструкции, пакет `docker.io` из репозитория Ubuntu не использовался).
- **Версия Docker Engine:** Docker Engine - Community, версия 29.9.1.
- **Участники группы `docker`:** Пользователь `devops` (добавлен для запуска контейнеров без `sudo`).
- **Расположение проекта на сервере:** `/home/devops/app`.
- **Расположение файла `.env` и его права:** `/home/devops/app/.env`. Владелец `devops`, права `600` (чтение и запись только для владельца).
- **Публикуемые порты и адреса:** Приложение доступно только локально на адресе `127.0.0.1:5000`. Порт базы данных (5432) наружу не публикуется.
- **Именованные тома:** `app_db_data` (создан для хранения данных PostgreSQL). Команда `docker compose down` сохраняет том, `docker compose down -v` удаляет его.
- **Конфигурация обратного прокси-сервера:** Nginx перенаправляет запросы с `https://devops.local/app/` на `http://127.0.0.1:5000/` (с использованием `proxy_pass` и заголовков `X-Forwarded-*`).