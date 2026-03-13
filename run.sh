#!/bin/bash

# =============================================================================
#  run.sh — запуск playbook с параллельным логированием по каждой машине
#
#  Все машины:       ./run.sh
#  Одна машина:      ./run.sh 192.168.0.132
#  Несколько машин:  ./run.sh 192.168.0.132, 192.168.0.133
#
#  Параллельность:   меняй PARALLEL_LIMIT (по умолчанию 5)
# =============================================================================

LOG_DIR="$(cd "$(dirname "$0")" && pwd)/logs"
PLAYBOOK="playbook.yml"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
PARALLEL_LIMIT=5

mkdir -p "$LOG_DIR"

# --- Определяем список хостов ---
if [[ -n "$1" ]]; then
    IFS=',' read -ra HOSTS <<< "$1"
else
    HOSTS=($(ansible-inventory --list | python3 -c "
import sys, json
data = json.load(sys.stdin)
hosts = set()
for key, val in data.items():
    if key in ('_meta', 'all'):
        continue
    if isinstance(val, dict) and 'hosts' in val:
        hosts.update(val['hosts'])
print('\n'.join(hosts))
"))
fi

if [[ ${#HOSTS[@]} -eq 0 ]]; then
    echo "Ошибка: не удалось получить список хостов из inventory"
    exit 1
fi

echo "Хосты для настройки: ${HOSTS[*]}"
echo "Параллельность: $PARALLEL_LIMIT"
echo "Логи будут в: $LOG_DIR"
echo ""

# --- Функция запуска одной машины в фоне ---
run_host() {
    local HOST="$1"
    local LOG_FILE="${LOG_DIR}/${HOST}_${TIMESTAMP}.log"

    {
        echo "============================================="
        echo "  Хост      : $HOST"
        echo "  Время     : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "  Playbook  : $PLAYBOOK"
        echo "============================================="
        echo ""

        ansible-playbook "$PLAYBOOK" -l "$HOST" 2>&1

        EXIT_CODE=$?
        echo ""
        echo "============================================="
        if [[ $EXIT_CODE -eq 0 ]]; then
            echo "  РЕЗУЛЬТАТ : УСПЕХ"
        else
            echo "  РЕЗУЛЬТАТ : ОШИБКА (код $EXIT_CODE)"
        fi
        echo "  Завершено : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "============================================="

        exit $EXIT_CODE
    } > "$LOG_FILE" 2>&1

    echo "  [СТАРТ] $HOST → $LOG_FILE"
}

# --- Параллельный запуск с ограничением ---
PIDS=()
HOSTS_MAP=()
FAILED_HOSTS=()

for HOST in "${HOSTS[@]}"; do
    HOST=$(echo "$HOST" | tr -d ' ')

    # Ждём если достигнут лимит параллельных процессов
    while [[ ${#PIDS[@]} -ge $PARALLEL_LIMIT ]]; do
        NEW_PIDS=()
        for PID in "${PIDS[@]}"; do
            if kill -0 "$PID" 2>/dev/null; then
                NEW_PIDS+=("$PID")
            else
                wait "$PID"
                EXIT=$?
                for ENTRY in "${HOSTS_MAP[@]}"; do
                    ENTRY_PID="${ENTRY%%:*}"
                    ENTRY_HOST="${ENTRY##*:}"
                    if [[ "$ENTRY_PID" == "$PID" ]]; then
                        if [[ $EXIT -ne 0 ]]; then
                            FAILED_HOSTS+=("$ENTRY_HOST")
                            echo "  [ОШИБКА] $ENTRY_HOST (код $EXIT)"
                        else
                            echo "  [ГОТОВО] $ENTRY_HOST"
                        fi
                    fi
                done
            fi
        done
        PIDS=("${NEW_PIDS[@]}")
        [[ ${#PIDS[@]} -ge $PARALLEL_LIMIT ]] && sleep 2
    done

    run_host "$HOST" &
    PID=$!
    PIDS+=("$PID")
    HOSTS_MAP+=("${PID}:${HOST}")
done

# --- Ждём завершения оставшихся процессов ---
echo ""
echo "Ожидание завершения всех машин..."

for PID in "${PIDS[@]}"; do
    wait "$PID"
    EXIT=$?
    for ENTRY in "${HOSTS_MAP[@]}"; do
        ENTRY_PID="${ENTRY%%:*}"
        ENTRY_HOST="${ENTRY##*:}"
        if [[ "$ENTRY_PID" == "$PID" ]]; then
            if [[ $EXIT -ne 0 ]]; then
                FAILED_HOSTS+=("$ENTRY_HOST")
                echo "  [ОШИБКА] $ENTRY_HOST (код $EXIT)"
            else
                echo "  [ГОТОВО] $ENTRY_HOST"
            fi
        fi
    done
done

# --- Итог ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Все логи сохранены в: $LOG_DIR"

if [[ ${#FAILED_HOSTS[@]} -gt 0 ]]; then
    echo "  ОШИБКИ на машинах:"
    for H in "${FAILED_HOSTS[@]}"; do
        echo "    ✗ $H  →  ${LOG_DIR}/${H}_${TIMESTAMP}.log"
    done
    exit 1
else
    echo "  Все машины настроены успешно ✓"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
