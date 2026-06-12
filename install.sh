#!/usr/bin/env bash
set -euo pipefail

#=============================================================================
# Fastly CIDR → AWG-Manager Subscription — Installer
#=============================================================================
# Interactive setup script that configures periodic Fastly CIDR fetching
# and git publishing for use as an AWG-Manager routing subscription.
#=============================================================================

clear
cat << 'BANNER'
╔══════════════════════════════════════════════════════════════╗
║     Fastly CIDR → AWG-Manager Subscription Installer        ║
║     Генератор CIDR-подписки Fastly для AWG-Manager          ║
╚══════════════════════════════════════════════════════════════╝

BANNER

# --- Helpers -----------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

say()  { echo -e "  $*"; }
ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; }

choose() {
    # choose <prompt> <default> <option1> <option2> ...
    # Sets the global CHOICE_RESULT variable with the selected index
    local prompt="$1"
    local default="$2"
    shift 2
    local options=("$@")
    local choice

    echo ""
    say "${CYAN}${prompt}${NC}"
    for i in "${!options[@]}"; do
        echo "      [${i}] ${options[$i]}"
    done

    while true; do
        echo ""
        read -r -p "  Ваш выбор [${default}]: " choice
        choice="${choice:-$default}"
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 0 && choice < ${#options[@]} )); then
            CHOICE_RESULT="$choice"
            return
        fi
        warn "Введите число от 0 до $((${#options[@]} - 1))"
    done
}

yesno() {
    # yesno <prompt> [default: Y]
    # Returns 0 for yes, 1 for no
    local prompt="$1"
    local default="${2:-Y}"
    local yn

    if [[ "$default" == "Y" ]]; then
        read -r -p "  ${prompt} [Y/n]: " yn
        yn="${yn:-y}"
    else
        read -r -p "  ${prompt} [y/N]: " yn
        yn="${yn:-n}"
    fi

    [[ "$yn" =~ ^[Yy]$ ]]
}

# --- Requirements check ------------------------------------------------
say "Проверка зависимостей..."

MISSING=()
for cmd in curl jq git; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING+=("$cmd")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    err "Не хватает: ${MISSING[*]}"
    echo ""
    say "Установите недостающие пакеты:"
    say "  Debian/Ubuntu: sudo apt install ${MISSING[*]}"
    say "  Alpine:        apk add ${MISSING[*]}"
    exit 1
fi
ok "Все зависимости найдены (curl, jq, git)"

# --- Step 1: Update period --------------------------------------------
choose \
    "Шаг 1/4 — Период обновления:" \
    "2" \
    "Каждые 6 часов" \
    "Каждые 12 часов" \
    "Раз в сутки (рекомендуется)" \
    "Раз в неделю"

PERIODS=("*/6 * * * *" "17 */12 * * *" "17 3 * * *" "17 3 * * 1")
PERIOD_LABELS=("каждые 6 часов" "каждые 12 часов" "раз в сутки" "раз в неделю")
CRON_SCHEDULE="${PERIODS[$CHOICE_RESULT]}"
PERIOD_LABEL="${PERIOD_LABELS[$CHOICE_RESULT]}"
ok "Период: ${PERIOD_LABEL}"

# --- Step 2: IP versions ----------------------------------------------
choose \
    "Шаг 2/4 — Версии IP:" \
    "2" \
    "Только IPv4" \
    "Только IPv6" \
    "IPv4 + IPv6 (рекомендуется)"

case "$CHOICE_RESULT" in
    0) IPV4=1; IPV6=0; IP_LABEL="только IPv4" ;;
    1) IPV4=0; IPV6=1; IP_LABEL="только IPv6" ;;
    2) IPV4=1; IPV6=1; IP_LABEL="IPv4 + IPv6" ;;
esac
ok "Версии IP: ${IP_LABEL}"

# --- Step 3: Git auto-push --------------------------------------------
if yesno "Шаг 3/4 — Автоматически коммитить и пушить изменения в GitHub?"; then
    AUTO_COMMIT=1
    ok "Авто-коммит: включён"
else
    AUTO_COMMIT=0
    ok "Авто-коммит: выключен"
fi

# --- Step 4: Cron -----------------------------------------------------
if yesno "Шаг 4/4 — Добавить задание в cron (crontab)?"; then
    SETUP_CRON=1
    ok "Cron: будет настроен"
else
    SETUP_CRON=0
    ok "Cron: не настраивается (запускайте generate.sh вручную)"
fi

# --- Determine repo path ----------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${SCRIPT_DIR}"

# Check if we're inside the repo already (generate.sh exists)
if [[ ! -f "${REPO_DIR}/generate.sh" ]]; then
    warn "Скрипт generate.sh не найден рядом с install.sh"
    say "Убедитесь, что install.sh запускается из корня репозитория fastly-cidr"
    say "Клонируйте репозиторий:"
    say "  git clone https://github.com/<user>/fastly-cidr.git"
    say "  cd fastly-cidr && bash install.sh"
    exit 1
fi

# --- GitHub remote check ----------------------------------------------
GIT_REMOTE=""
if git -C "${REPO_DIR}" rev-parse --is-inside-work-tree &>/dev/null; then
    GIT_REMOTE=$(git -C "${REPO_DIR}" remote get-url origin 2>/dev/null || echo "")
fi

if [[ -n "$GIT_REMOTE" ]]; then
    # Extract user/repo from remote URL
    if [[ "$GIT_REMOTE" =~ github\.com[:/]([^/]+)/([^/]+?)(\.git)?$ ]]; then
        GH_USER="${BASH_REMATCH[1]}"
        GH_REPO="${BASH_REMATCH[2]}"
        RAW_URL="https://raw.githubusercontent.com/${GH_USER}/${GH_REPO}/main/fastly.txt"
        ok "Репозиторий: ${GH_USER}/${GH_REPO}"
    else
        RAW_URL="<не удалось определить URL — настройте вручную>"
    fi
else
    warn "Не найден git remote — это не git-репозиторий"
    RAW_URL="<настройте после публикации>"
    GH_USER="<user>"
    GH_REPO="<repo>"
fi

# --- Create .env config -----------------------------------------------
ENV_FILE="${REPO_DIR}/.env"

cat > "${ENV_FILE}" << EOF
# Fastly CIDR Generator config
# Generated by install.sh on $(date -u +"%Y-%m-%dT%H:%M:%SZ")

IPV4=${IPV4}
IPV6=${IPV6}
OUTPUT=${REPO_DIR}/fastly.txt
AUTO_COMMIT=${AUTO_COMMIT}
EOF

ok "Конфиг сохранён в .env"

# --- Make generate.sh executable -------------------------------------
chmod +x "${REPO_DIR}/generate.sh"

# --- Test run ---------------------------------------------------------
echo ""
say "Выполняю тестовый запуск..."
echo ""

export IPV4 IPV6
export OUTPUT="${REPO_DIR}/fastly.txt"
export AUTO_COMMIT="${AUTO_COMMIT}"

if bash "${REPO_DIR}/generate.sh"; then
    ok "Тестовый запуск успешен!"
else
    err "Тестовый запуск завершился с ошибкой (код $?)"
    say "Проверьте вывод выше и сетевое соединение с api.fastly.com"
    exit 1
fi

# --- Setup cron -------------------------------------------------------
if [[ "$SETUP_CRON" == "1" ]]; then
    CRON_ENTRY="${CRON_SCHEDULE} cd ${REPO_DIR} && source .env && ./generate.sh >> ${REPO_DIR}/cron.log 2>&1"

    # Remove any existing entry for this script
    (crontab -l 2>/dev/null | grep -v "fastly-cidr/generate.sh" || true) > /tmp/crontab.$$

    echo "$CRON_ENTRY" >> /tmp/crontab.$$
    crontab /tmp/crontab.$$
    rm -f /tmp/crontab.$$

    ok "Cron-задание добавлено: ${CRON_SCHEDULE}"
fi

# --- Summary ----------------------------------------------------------
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Установка завершена!"
echo ""
echo "  Подписка для AWG-Manager:"
echo "    ${RAW_URL}"
echo ""
echo "  Параметры:"
echo "    Период:     ${PERIOD_LABEL}"
echo "    IP версии:  ${IP_LABEL}"
echo "    Авто-push:  $([[ $AUTO_COMMIT == 1 ]] && echo 'да' || echo 'нет')"
echo "    Cron:       $([[ $SETUP_CRON == 1 ]] && echo 'да' || echo 'нет')"
echo ""
echo "  Файлы:"
echo "    Конфиг:     ${ENV_FILE}"
echo "    CIDR файл:  ${REPO_DIR}/fastly.txt"
echo ""
echo "  Как использовать в AWG-Manager:"
echo "    1. Вкладка «Подписки» → «Добавить подписку»"
echo "    2. Имя: Fastly CDN"
echo "    3. URL:  ${RAW_URL}"
echo "    4. Сохранить и дождаться загрузки"
echo "═══════════════════════════════════════════════════════════════"

# --- Push initial file if auto-commit is on --------------------------
if [[ "$AUTO_COMMIT" == "1" && -n "$GIT_REMOTE" ]]; then
    echo ""
    if yesno "Запушить сгенерированный fastly.txt в GitHub сейчас?"; then
        cd "${REPO_DIR}"
        git add fastly.txt .env
        git commit -m "Initial Fastly CIDR setup — $(date -u +"%Y-%m-%dT%H:%M:%SZ")" || true
        git push
        ok "Файл запушен в GitHub"
    fi
fi
