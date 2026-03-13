# ansible_linux_setup — Автонастройка рабочих станций Red OS

Ansible-плейбук для автоматического развёртывания и настройки рабочих станций под управлением **RED OS** (отечественный Linux).

## Что делает плейбук

Выполняет 6 последовательных шагов:

| Шаг | Задача | Файл |
|-----|--------|------|
| 1 | Preflight-проверки (ОС, сеть, права) | `tasks/preflight.yml` |
| 2 | Полное обновление системы через `dnf` | `tasks/update.yml` |
| 3 | Установка приложений (Яндекс Браузер, Р7-Офис) | `tasks/install_apps.yml` |
| 4 | PCSC-инструменты для работы с токенами | `tasks/install_plugins.yml` |
| 5 | Установка RT-ядра _(опционально)_ | `tasks/install_rt_kernel.yml` |
| 6 | Kaspersky Network Agent _(опционально)_ | `tasks/install_kaspersky.yml` |
| 7 | Ввод машины в домен Windows/Samba _(опционально)_ | `tasks/join_domain.yml` |

## Требования

- **Ansible** 2.9+
- **Python** 3.11 на целевых машинах
- **RED OS** на целевых хостах
- SSH-доступ с ключом `~/.ssh/id_ed25519`
- Пользователь `admin` с правами `sudo`

## Установка и настройка

### 1. Клонирование репозитория

```bash
git clone git@github.com:loowpts/ansible_linux_setup.git
cd ansible_linux_setup
```

### 2. Создание инвентаря

```bash
cp inventory.ini.example inventory.ini
```

Отредактируй `inventory.ini`, добавив IP-адреса своих машин:

```ini
[redos]
192.168.1.10
192.168.1.11
192.168.1.12
```

### 3. Настройка переменных группы

```bash
cp group_vars/redos.yml.example group_vars/redos.yml
```

Заполни `group_vars/redos.yml` реальными значениями:

```yaml
ansible_become_pass: "пароль_admin"
domain_name: "your.domain.local"
dom_user: "ИмяПользователяДомена"
dom_pass: "пароль_домена"
```

### 4. Настройка переменных хоста

Для каждой машины создай файл `host_vars/<IP>.yml`:

```bash
cp host_vars/example.yml.example host_vars/192.168.1.10.yml
```

Заполни параметры — имя машины, адрес сервера Kaspersky, что пропустить при установке.

```yaml
pc_hostname: "PC001"
ksn_server: "192.168.1.5"
ksn_port: "14000"
ksn_ssl_port: "13000"
ksn_use_ssl: "Y"
ksn_gateway_mode: "1"

skip_rt: false      # установить RT-ядро
skip_kav: false     # установить Kaspersky
skip_domain: false  # ввести в домен
```

## Запуск

### Один хост

```bash
ansible-playbook playbook.yml -l 192.168.1.10
```

### Все хосты из инвентаря

```bash
ansible-playbook playbook.yml
```

### Параллельный запуск (с логированием)

Скрипт `run.sh` запускает плейбук параллельно на нескольких машинах и сохраняет лог для каждой.

```bash
# Все машины из инвентаря
./run.sh

# Одна машина
./run.sh 192.168.1.10

# Несколько машин
./run.sh 192.168.1.10,192.168.1.11,192.168.1.12
```

Логи сохраняются в `logs/<IP>_<дата-время>.log`.

Параллельность регулируется переменной `PARALLEL_LIMIT` в `run.sh` (по умолчанию 5).

## Опциональные шаги

В `host_vars/<IP>.yml` можно отключить отдельные шаги:

```yaml
skip_rt: true      # пропустить установку RT-ядра
skip_kav: true     # пропустить Kaspersky
skip_domain: true  # не вводить в домен
```

## Ручные шаги после настройки

После запуска плейбука нужно вручную установить:

- **Рутокен PKCS#11** — драйвер для российских USB-токенов
- **КриптоПро ЭЦП Browser Plugin** — плагин для работы с ЭЦП в браузере

Инструкции по установке смотри на официальных сайтах производителей.

## Структура проекта

```
ansible/
├── ansible.cfg                   # Конфигурация Ansible
├── playbook.yml                  # Главный плейбук
├── run.sh                        # Скрипт параллельного запуска
├── inventory.ini.example         # Пример инвентаря (скопируй в inventory.ini)
├── group_vars/
│   ├── redos.yml                 # Переменные группы (создай из шаблона)
│   └── redos.yml.example         # Шаблон — скопируй и заполни
├── host_vars/
│   ├── <IP>.yml                  # Параметры конкретной машины (создай из шаблона)
│   └── example.yml.example       # Шаблон для host_vars
├── tasks/
│   ├── preflight.yml
│   ├── update.yml
│   ├── install_apps.yml
│   ├── install_plugins.yml
│   ├── install_rt_kernel.yml
│   ├── install_kaspersky.yml
│   └── join_domain.yml
└── logs/                         # Логи выполнения
```
