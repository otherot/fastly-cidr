# Fastly CIDR → Подписка для AWG-Manager

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![English version](README.md)](README.md)

Автоматическая генерация списка CIDR-диапазонов Fastly в формате подписки для [AWG-Manager](https://github.com/hoaxisr/awg-manager).

Скрипт запрашивает [Fastly Public IP List API](https://www.fastly.com/documentation/reference/api/utils/public-ip-list/), извлекает IPv4 и/или IPv6 CIDR-диапазоны и сохраняет их в текстовый файл — одну сеть на строку. Файл совместим с подписками маршрутов AWG-Manager.

**Коротко:** Добавьте в AWG-Manager подписку на `https://raw.githubusercontent.com/otherot/fastly-cidr/main/fastly.txt`, и роутер будет автоматически получать актуальные сети Fastly.

---

## Как это работает

1. `generate.sh` запрашивает `https://api.fastly.com/public-ip-list`
2. Извлекает IPv4 и/или IPv6 CIDR-диапазоны
3. Сохраняет в `fastly.txt` — простой текст, одна сеть на строку
4. С опцией `AUTO_COMMIT=1` — коммитит и пушит изменения в GitHub
5. AWG-Manager подписывается на Raw URL и авто-обновляет маршруты

## Быстрая установка

### Установка одной строкой (рекомендуется)

```bash
bash <(curl -sL https://raw.githubusercontent.com/otherot/fastly-cidr/main/install.sh)
```

Команда скачивает и запускает установщик напрямую — клонировать репозиторий не нужно.

### Клонирование и установка

```bash
git clone https://github.com/otherot/fastly-cidr.git
cd fastly-cidr
bash install.sh
```

Установщик задаст вопросы:

| Шаг | Вопрос | Варианты |
|-----|--------|----------|
| 1 | Период обновления | Каждые 6 ч / 12 ч / раз в сутки (рекомендуется) / раз в неделю |
| 2 | Версии IP | Только IPv4 / только IPv6 / IPv4+IPv6 (рекомендуется) |
| 3 | Авто-push в GitHub | Автоматически коммитить и пушить изменения? |
| 4 | Cron | Добавить задание в crontab? |

После установки выполняется тестовый запуск, настраивается cron (если выбрано) и выводится Raw URL для AWG-Manager.

## Ручной запуск (без установщика)

```bash
# Разовый запуск
IPV4=1 IPV6=1 AUTO_COMMIT=0 bash generate.sh

# Посмотреть результат
head fastly.txt
```

### Переменные окружения

| Переменная | По умолчанию | Описание |
|------------|-------------|----------|
| `IPV4` | `1` | Включать IPv4 (`1` = да, `0` = нет) |
| `IPV6` | `1` | Включать IPv6 (`1` = да, `0` = нет) |
| `OUTPUT` | `./fastly.txt` | Путь к выходному файлу |
| `AUTO_COMMIT` | `0` | Авто-коммит и пуш при изменениях (`1` = да) |

## Подключение в AWG-Manager

### Способ 1 — Вкладка «Подписки» (рекомендуется)

1. Откройте веб-интерфейс AWG-Manager
2. Перейдите во вкладку **«Подписки»**
3. Нажмите **«Добавить подписку»**
4. Заполните:
   - **Имя:** `Fastly CDN`
   - **URL:** `https://raw.githubusercontent.com/otherot/fastly-cidr/main/fastly.txt`
5. Сохраните

AWG-Manager будет периодически забирать обновления и применять их. Так как файл содержит только CIDR-сети (без доменов), его можно использовать как в DNS-, так и в IP-маршрутизации.

### Способ 2 — Вкладка «Маршрутизация по IP»

Скопируйте содержимое `fastly.txt` в поле **Subnets** правила IP-маршрутизации.

## Формат выходного файла

```text
# Fastly CDN IP ranges
# Generated: 2026-06-12T03:17:00Z
# Source:  https://api.fastly.com/public-ip-list
# IPv4 ranges: 19
# IPv6 ranges: 2

23.235.32.0/20
43.249.72.0/22
...
2a04:4e42::/32
...
```

Строки, начинающиеся с `#`, — комментарии (игнорируются AWG-Manager). Основное содержимое — одна CIDR-сеть на строку.

## Использование на выделенном сервере

```bash
git clone https://github.com/otherot/fastly-cidr.git
cd fastly-cidr
bash install.sh
```

Установщик может:
- Добавить задание в crontab с выбранным периодом
- Автоматически коммитить и пушить сгенерированный файл в GitHub, чтобы AWG-Manager всегда получал актуальный список

### Ручная настройка cron

Если вы не используете установщик:

```cron
# Запускать каждый день в 03:17
17 3 * * * cd /home/user/fastly-cidr && IPV4=1 IPV6=1 AUTO_COMMIT=1 bash generate.sh >> /home/user/fastly-cidr/cron.log 2>&1
```

## Как хостить свою копию

Сгенерированный `fastly.txt` публикуется в этом репозитории для удобства. Если хотите хостить свою версию:

1. Сделайте форк репозитория
2. Клонируйте форк на сервер
3. Запустите `install.sh` или настройте `generate.sh` вручную
4. Включите `AUTO_COMMIT=1`, чтобы обновления пушились в ваш форк
5. Используйте Raw URL вашего форка в AWG-Manager

## Зависимости

- `curl` — HTTP-запросы к Fastly API
- `jq` — парсинг JSON
- `git` — публикация в GitHub (опционально)

```bash
# Debian / Ubuntu
sudo apt install curl jq git

# Alpine
apk add curl jq git
```

## Лицензия

MIT — используйте как угодно.

---

> **English version:** [README.md](README.md)
