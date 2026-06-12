# Fastly CIDR → AWG-Manager Subscription

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Генератор CIDR-подписки Fastly для [AWG-Manager](https://github.com/hoaxisr/awg-manager). Автоматически получает актуальные диапазоны IP-адресов Fastly CDN через их [публичное API](https://www.fastly.com/documentation/reference/api/utils/public-ip-list/) и формирует текстовый файл, совместимый с подписками маршрутов AWG-Manager.

## Как это работает

1. Скрипт `generate.sh` запрашивает `https://api.fastly.com/public-ip-list`
2. Извлекает IPv4 и/или IPv6 CIDR-диапазоны
3. Сохраняет в `fastly.txt` — простой текст, одна сеть на строку
4. При включённом `AUTO_COMMIT` — коммитит и пушит изменения в GitHub
5. AWG-Manager подписывается на Raw URL файла и автоматически обновляет маршруты

## Быстрая установка

```bash
# Клонируйте репозиторий
git clone https://github.com/otherot/fastly-cidr.git
cd fastly-cidr

# Запустите установщик
bash install.sh
```

Установщик задаст вопросы:
- **Период обновления** — каждые 6/12 часов, раз в сутки или раз в неделю
- **Версии IP** — только IPv4, только IPv6 или обе
- **Авто-push** — автоматически коммитить и пушить в GitHub
- **Cron** — добавить задание в crontab

## Использование без установщика

```bash
# Запуск вручную
IPV4=1 IPV6=1 AUTO_COMMIT=0 bash generate.sh

# Результат в fastly.txt
head fastly.txt
```

### Переменные окружения

| Переменная   | По умолчанию | Описание                                      |
|-------------|-------------|-----------------------------------------------|
| `IPV4`      | `1`         | Включить IPv4 диапазоны (`1` — да, `0` — нет) |
| `IPV6`      | `1`         | Включить IPv6 диапазоны (`1` — да, `0` — нет) |
| `OUTPUT`    | `./fastly.txt` | Путь к выходному файлу                     |
| `AUTO_COMMIT` | `0`       | Делать git commit + push при изменениях        |

## Подключение в AWG-Manager

1. Откройте веб-интерфейс AWG-Manager
2. Перейдите во вкладку **«Подписки»**
3. Нажмите **«Добавить подписку»**
4. Заполните:
   - **Имя**: `Fastly CDN`
   - **URL**: `https://raw.githubusercontent.com/otherot/fastly-cidr/main/fastly.txt`
5. Сохраните

AWG-Manager будет автоматически обновлять список согласно внутреннему расписанию.

### Альтернативно — через IP-роутинг

Можно скопировать содержимое `fastly.txt` и вставить в поле **Subnets** правила IP-маршрутизации (вкладка «Маршрутизация по IP»).

## Формат выходного файла

```text
# Fastly CDN IP ranges
# Generated: 2026-06-12T03:17:00Z
# Source:  https://api.fastly.com/public-ip-list
# IPv4 ranges: 45
# IPv6 ranges: 12

23.235.32.0/20
43.249.72.0/22
...
2a04:4e42::/32
...
```

Строки, начинающиеся с `#`, игнорируются AWG-Manager — это комментарии с метаинформацией.

## Зависимости

- `curl` — HTTP-запросы к Fastly API
- `jq` — парсинг JSON
- `git` — публикация в GitHub (опционально)

```bash
# Debian/Ubuntu
sudo apt install curl jq git

# Alpine
apk add curl jq git
```

## Лицензия

MIT — используйте как угодно.
