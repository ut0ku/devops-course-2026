# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины

- **Наименование VM:** devops-vm
- **ОЗУ:** 2048 МБ
- **Ядер процессора:** 2
- **Объём диска:** 25 ГБ (динамически расширяемый)
- **Тип и версия гостевой ОС:** Ubuntu Server 24.04 LTS (Noble Numbat), 64-bit
- **Средство виртуализации:** VirtualBox 7.x

## 2. Сетевые интерфейсы

| Интерфейс | Тип адаптера | IP-адрес | Назначение |
|---|---|---|---|
| enp0s3 | NAT | 10.0.2.15/24 | Доступ в интернет (репозитории пакетов) |
| enp0s8 | Host-only Adapter | 192.168.56.107/24 | Прямой доступ с хостовой системы, devops.local |

**NAT** — гостевая система в сегменте `10.0.2.0/24`, доступ в интернет через гипервизор, входящие соединения только через проброс портов.

**Host-only** — изолированный сегмент `192.168.56.0/24`, гостевая система доступна с хостовой напрямую.

## 3. Правило проброса портов

| Адаптер | Имя правила | Протокол | IP хоста | Порт хоста | IP гостя | Порт гостя |
|---|---|---|---|---|---|---|
| Adapter 1 (NAT) | SSH | TCP | 127.0.0.1 | 2222 | (пусто) | 2222 |

**Порт гостя** — 2222 (не 22!), потому что SSH перенастроен на нестандартный порт в шаге 2.3.

## 4. Учётные записи

| Имя | Группы | Способ аутентификации |
|---|---|---|
| student | student, sudo, users | Пароль (для консоли и sudo) |
| devops | devops, sudo, users | SSH-ключ `devops_vm` (ed25519), пароль для sudo |

**Пользователь `devops`** создан в задании 1, добавлен в группу `sudo`.
**Пользователь `root`** — вход по SSH **запрещён** (`PermitRootLogin no`).

## 5. Служба SSH

- **Порт:** 2222 (нестандартный)
- **Файл конфигурации:** `/etc/ssh/sshd_config.d/99-hardening.conf`
- **Бэкап основного конфига:** `/etc/ssh/sshd_config.backup`
- **Метод активации:** `ssh.service` (не `ssh.socket`)

**Изменённые директивы:**

| Директива | Значение | Назначение |
|---|---|---|
| Port | 2222 | Нестандартный порт |
| PermitRootLogin | no | Запрет входа под root |
| PasswordAuthentication | no | Только ключи |
| PubkeyAuthentication | yes | Ключевая аутентификация |
| PermitEmptyPasswords | no | Запрет пустых паролей |
| MaxAuthTries | 3 | 3 попытки на подключение |
| LoginGraceTime | 30 | 30 секунд на вход |
| AllowUsers | devops | Только пользователь devops |
| X11Forwarding | no | X11 запрещён |
| ClientAliveInterval | 300 | Пинг клиента каждые 300 сек |
| ClientAliveCountMax | 2 | Разрыв через 2 пропущенных пинга |

**Важно:** в `/etc/ssh/sshd_config.d/50-cloud-init.conf` строка `PasswordAuthentication yes` **закомментирована** (иначе она переопределила бы значение из `99-hardening.conf`).

## 6. Правила межсетевого экрана

- **Утилита:** UFW (Uncomplicated Firewall)
- **Статус:** active
- **Политики по умолчанию:** `deny incoming`, `allow outgoing`, `disabled routed`
- **Логирование:** medium

| Порт | Протокол | Действие | Комментарий |
|---|---|---|---|
| 2222 | TCP | LIMIT | SSH rate-limited |
| 80 | TCP | ALLOW | HTTP |
| 443 | TCP | ALLOW | HTTPS |

**`LIMIT`** — блокировка источника, инициировавшего 6+ соединений за 30 секунд (защита от брутфорса).

## 7. Снимки состояния

| Наименование | Момент создания | Что зафиксировано |
|---|---|---|
| 01-clean-install | После установки Ubuntu, до всех изменений | Чистая система |
| 02-keys-configured | После задания 1 | Пользователь devops, ключи, ~/.ssh/config |
| 03-ssh-hardened | После задания 2 | Hardening SSH (порт 2222, запрет root/паролей) |

## 8. Инструкция по восстановлению (Команды)

**8.1. Восстановление пользователей и SSH**
1. Запуск SSH:
   `sudo systemctl enable --now ssh.service`
2. Создание пользователя `devops`:
   `sudo adduser devops`
3. Выдача прав sudo:
   `sudo usermod -aG sudo devops`

**8.2. Настройка ключей**
4. Копирование открытого ключа на сервер:
   `ssh-copy-id -i ~/.ssh/devops_vm.pub -p 2222 devops@127.0.0.1`

**8.3. Hardening SSH**
5. Бэкап конфига:
   `sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup`
6. Создание дополняющего файла:
   `sudo nano /etc/ssh/sshd_config.d/99-hardening.conf`
   port 2222
   PermitRootLogin no
   PasswordAuthentication no
   PubkeyAuthentication yes
   PermitEmptyPassword no
   MaxAuthTries 3
   LoginGraceTime 30
   AllowUsers devops
   X11Forwarding no
   ClientAliveInterval 300
   ClientAliveCountMax 2
7. Комментирование конфликтной строки:
   `sudo sed -i 's/^PasswordAuthentication yes/#PasswordAuthentication yes/' /etc/ssh/sshd_config.d/50-cloud-init.conf`
8-10. Переключение на service и перезапуск:
   `sudo systemctl disable --now ssh.socket`
   `sudo systemctl enable --now ssh.service`
   `sudo systemctl restart ssh`

**8.4. Проброс портов (в VirtualBox)**
11. Выключить VM. В настройках сети (Adapter 1 -> Advanced -> Port Forwarding) поменять Guest Port с `22` на `2222`.

**8.5. Межсетевой экран**
12-13. Задание политик и создание правил:
   `sudo ufw default deny incoming`
   `sudo ufw default allow outgoing`
   `sudo ufw allow 2222/tcp comment 'SSH'`
   `sudo ufw allow 80/tcp comment 'HTTP'`
   `sudo ufw allow 443/tcp comment 'HTTPS'`
14. Активация:
   `sudo ufw enable`
15. Замена на limit:
   `sudo ufw delete allow 2222/tcp`
   `sudo ufw limit 2222/tcp comment 'SSH rate-limited'`
16. Включение логирования:
   `sudo ufw logging medium`

**8.6. Доменное имя**
17. Установка hostname:
   `sudo hostnamectl set-hostname devops-vm`
18. Настройка FQDN в hosts:
   `sudo sed -i 's/^127.0.1.1.*/127.0.1.1 devops-vm.devops.local devops-vm/' /etc/hosts`

**8.7. Скрипт аудита**
21. Копирование скрипта (выполняется на Windows в папке репозитория):
   `scp scripts/audit.sh devops:~/audit.sh`
   Запуск `bash ~/audit.sh`