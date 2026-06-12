# Fastly CIDR → AWG-Manager Subscription

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Русская версия](README.ru.md)](README.ru.md)

Automatically fetch Fastly's public IP ranges and generate a plain-text subscription file compatible with [AWG-Manager](https://github.com/hoaxisr/awg-manager) routing subscriptions.

The script calls the [Fastly Public IP List API](https://www.fastly.com/documentation/reference/api/utils/public-ip-list/), extracts IPv4 and/or IPv6 CIDR ranges, and writes them into a simple text file — one network per line, ready to use with AWG-Manager's route subscriptions or IP routing rules.

**TL;DR:** Subscribe in AWG-Manager to `https://raw.githubusercontent.com/otherot/fastly-cidr/main/fastly.txt` and get Fastly's CIDR ranges automatically updated.

---

## How It Works

1. `generate.sh` fetches `https://api.fastly.com/public-ip-list`
2. Extracts IPv4 and/or IPv6 CIDR ranges
3. Writes them to `fastly.txt` — plain text, one CIDR per line
4. With `AUTO_COMMIT=1`, commits and pushes changes to GitHub
5. AWG-Manager subscribes to the Raw URL and auto-updates its route table

## Quick Start

### One-line install (recommended)

```bash
bash <(curl -sL https://raw.githubusercontent.com/otherot/fastly-cidr/main/install.sh)
```

This downloads and runs the installer directly — no clone needed.

### Clone and install

```bash
git clone https://github.com/otherot/fastly-cidr.git
cd fastly-cidr
bash install.sh
```

The installer will ask you:

| Step | Question | Options |
|------|----------|---------|
| 1 | Update period | Every 6h / 12h / daily (recommended) / weekly |
| 2 | IP versions | IPv4 only / IPv6 only / IPv4+IPv6 (recommended) |
| 3 | Git auto-push | Automatically commit & push to GitHub? |
| 4 | Cron setup | Add a crontab entry? |

After completion it runs a test, configures cron if selected, and prints the Raw URL for AWG-Manager.

## Manual Usage (Without Installer)

```bash
# One-shot generation
IPV4=1 IPV6=1 AUTO_COMMIT=0 bash generate.sh

# View the result
head fastly.txt
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `IPV4` | `1` | Include IPv4 ranges (`1` = yes, `0` = no) |
| `IPV6` | `1` | Include IPv6 ranges (`1` = yes, `0` = no) |
| `OUTPUT` | `./fastly.txt` | Output file path |
| `AUTO_COMMIT` | `0` | Auto commit & push when content changes (`1` = yes) |

## Using the Subscription in AWG-Manager

### Method 1 — Subscription Tab (Recommended)

1. Open your AWG-Manager web interface
2. Go to **Subscriptions** tab
3. Click **Add Subscription**
4. Fill in:
   - **Name:** `Fastly CDN`
   - **URL:** `https://raw.githubusercontent.com/otherot/fastly-cidr/main/fastly.txt`
5. Save

AWG-Manager will periodically fetch and apply the list. Since the list contains CIDR networks only (no domains), you can reference it in both DNS and IP routing rules.

### Method 2 — IP Routing Tab

Copy the contents of `fastly.txt` directly into the **Subnets** field of an IP routing rule.

## Output File Format

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

Lines starting with `#` are comments (ignored by AWG-Manager). The actual content is one CIDR per line, combining both IPv4 and IPv6 ranges sorted naturally.

## Using on a Dedicated Server

```bash
# Clone and install
git clone https://github.com/otherot/fastly-cidr.git
cd fastly-cidr
bash install.sh
```

During setup the installer can:
- Add a crontab entry to run on your chosen schedule
- Auto-commit and push the generated file to GitHub so AWG-Manager always picks up the latest list

### Manual Cron Example

If you prefer to configure cron manually instead of using the installer:

```cron
# Fetch Fastly CIDR every day at 03:17
17 3 * * * cd /home/user/fastly-cidr && IPV4=1 IPV6=1 AUTO_COMMIT=1 bash generate.sh >> /home/user/fastly-cidr/cron.log 2>&1
```

## How to Host Your Own Copy

The generated `fastly.txt` is published in this repository for convenience. If you want to host your own version:

1. Fork the repository
2. Clone your fork on a server
3. Run `install.sh` or configure `generate.sh` manually
4. Set `AUTO_COMMIT=1` so it pushes updates to your fork
5. Use your fork's Raw URL in AWG-Manager

## Dependencies

- `curl` — HTTP requests to Fastly API
- `jq` — JSON parsing
- `git` — GitHub publishing (optional, only needed for auto-commit)

```bash
# Debian / Ubuntu
sudo apt install curl jq git

# Alpine
apk add curl jq git
```

## License

MIT — use it however you like.

---

> **Russian version:** [README.ru.md](README.ru.md)
