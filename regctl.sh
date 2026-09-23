#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.config/regctl"
CONFIG_FILE="${CONFIG_DIR}/config.env"
CACHE_DIR="${HOME}/.cache/regctl"
LOG_DIR="/var/log/regctl"
LOG_FILE="${LOG_DIR}/log"

init_logging() {
    if [ ! -d "$LOG_DIR" ]; then
        sudo mkdir -p "$LOG_DIR" 2>/dev/null || mkdir -p "$LOG_DIR" 2>/dev/null
        sudo chmod 777 "$LOG_DIR" 2>/dev/null || true
    fi
    if [ ! -f "$LOG_FILE" ]; then
        sudo touch "$LOG_FILE" 2>/dev/null || touch "$LOG_FILE" 2>/dev/null
        sudo chmod 666 "$LOG_FILE" 2>/dev/null || true
    fi
}

log_msg() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    if [ -w "$LOG_FILE" ] || [ -w "$LOG_DIR" ]; then
        echo "[$timestamp] [$level] $msg" >> "$LOG_FILE" 2>/dev/null
    fi
}

init_logging
log_msg "INFO" "=== Запуск regctl ==="

load_config() {
    mkdir -p "$CONFIG_DIR" "$CACHE_DIR"
    if [ ! -f "$CONFIG_FILE" ]; then
        cat << 'EOF' > "$CONFIG_FILE"
SHOW_TAG_COUNT=true
SHOW_UPDATED_DATE=true
SHOW_SIZE=true
CATALOG_N=10000
ENABLE_CACHE=true
CACHE_TTL=300
HIDE_TAGLESS_IMAGES=false
EOF
    fi
    source "$CONFIG_FILE"
    SHOW_TAG_COUNT="${SHOW_TAG_COUNT:-true}"
    SHOW_UPDATED_DATE="${SHOW_UPDATED_DATE:-true}"
    SHOW_SIZE="${SHOW_SIZE:-true}"
    CATALOG_N="${CATALOG_N:-10000}"
    ENABLE_CACHE="${ENABLE_CACHE:-true}"
    CACHE_TTL="${CACHE_TTL:-300}"
    HIDE_TAGLESS_IMAGES="${HIDE_TAGLESS_IMAGES:-false}"
}

save_config() {
    cat << EOF > "$CONFIG_FILE"
SHOW_TAG_COUNT=$SHOW_TAG_COUNT
SHOW_UPDATED_DATE=$SHOW_UPDATED_DATE
SHOW_SIZE=$SHOW_SIZE
CATALOG_N=$CATALOG_N
ENABLE_CACHE=$ENABLE_CACHE
CACHE_TTL=$CACHE_TTL
HIDE_TAGLESS_IMAGES=$HIDE_TAGLESS_IMAGES
EOF
    log_msg "INFO" "Конфигурация сохранена: SHOW_TAG_COUNT=$SHOW_TAG_COUNT, SHOW_UPDATED_DATE=$SHOW_UPDATED_DATE, SHOW_SIZE=$SHOW_SIZE, CATALOG_N=$CATALOG_N, ENABLE_CACHE=$ENABLE_CACHE, CACHE_TTL=$CACHE_TTL, HIDE_TAGLESS_IMAGES=$HIDE_TAGLESS_IMAGES"
}

clear_cache() {
    if [ -n "$CACHE_DIR" ] && [ -d "$CACHE_DIR" ]; then
        rm -rf "${CACHE_DIR:?}"/* "${CACHE_DIR:?}"/.* 2>/dev/null
    fi
    mkdir -p "$CACHE_DIR"
    log_msg "INFO" "Кэш успешно очищен"
}

load_config

REQUIRED_DEPENDENCIES=("curl" "jq" "gum" "docker")

install_missing_dependencies() {
    local missing=()
    for cmd in "${REQUIRED_DEPENDENCIES[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "Установка отсутствующих пакетов: ${missing[*]}..."
        log_msg "INFO" "Установка отсутствующих зависимостей: ${missing[*]}"
        sudo apt-get update -y
        for pkg in "${missing[@]}"; do
            if [ "$pkg" == "gum" ]; then
                local local_deb
                local_deb=$(find "$SCRIPT_DIR" -maxdepth 1 -name "*gum*.deb" | head -n 1)

                if [ -n "$local_deb" ] && [ -f "$local_deb" ]; then
                    echo "Установка $local_deb..."
                    sudo dpkg -i "$local_deb" || sudo apt-get install -f -y
                else
                    echo "Пакет $pkg не найден рядом со скриптом."
                    log_msg "ERROR" "Пакет gum не найден рядом со скриптом"
                    exit 1
                fi
            else
                sudo apt-get install -y "$pkg"
            fi
        done
    fi
}

install_missing_dependencies

CONNECTED_URL=""
REGISTRY_URL=""
USERNAME=""
PASSWORD=""

prompt_command_mode() {
    clear
    print_header
    echo "$(gum style --foreground 214 --bold "РЕЖИМ КОМАНДНОЙ СТРОКИ")"
    echo "$(gum style --foreground 240 "Доступные команды: :upload, :settings, :disconnect, :help, :q, :quit")"
    echo
    
    local input_cmd
    input_cmd=$(gum input --value=":" --placeholder="введите команду..." < /dev/tty)
    local res=$?
    
    if [ $res -eq 130 ] || [ -z "$input_cmd" ] || [ "$input_cmd" == ":" ]; then
        return 0
    fi

    process_command "$input_cmd"
}

get_term_dimensions() {
    TERM_LINES=$(tput lines 2>/dev/null || echo 24)
    TERM_COLS=$(tput cols 2>/dev/null || echo 80)

    VIEW_HEIGHT=$(( TERM_LINES - 12 ))
    [ "$VIEW_HEIGHT" -lt 5 ] && VIEW_HEIGHT=5

    P_COL1_WIDTH=$(( (TERM_COLS - 6) * 70 / 100 ))
    P_COL2_WIDTH=$(( (TERM_COLS - 6) * 30 / 100 ))
    [ "$P_COL1_WIDTH" -lt 10 ] && P_COL1_WIDTH=20
    [ "$P_COL2_WIDTH" -lt 5 ] && P_COL2_WIDTH=10

    R_COL1_WIDTH=$(( (TERM_COLS - 10) * 40 / 100 ))
    R_COL2_WIDTH=$(( (TERM_COLS - 10) * 15 / 100 ))
    R_COL3_WIDTH=$(( (TERM_COLS - 10) * 20 / 100 ))
    R_COL4_WIDTH=$(( (TERM_COLS - 10) * 25 / 100 ))
    [ "$R_COL1_WIDTH" -lt 10 ] && R_COL1_WIDTH=20
    [ "$R_COL2_WIDTH" -lt 5 ] && R_COL2_WIDTH=10
    [ "$R_COL3_WIDTH" -lt 5 ] && R_COL3_WIDTH=12
    [ "$R_COL4_WIDTH" -lt 5 ] && R_COL4_WIDTH=10
}

print_header() {
    local term_cols
    term_cols=$(tput cols 2>/dev/null || echo 80)
    local logo
    logo=$(cat << 'EOF'
\e[38;5;196m ▄▄▄  ▄▄▄  ▄▄▄    ▄▄▄  ▄▄▄▄▄  ▄  \e[0m
\e[38;5;202m █  █ █    █ ▀    █      █    █  \e[0m
\e[38;5;208m █▀▀▄ █▀▀  █ ▄▄   █      █    █  \e[0m
\e[38;5;214m    █  █ █▄▄▄ ▀▄▄█   █▄▄▄   █    █▄▄▄  \e[0m
EOF
)

    local subtitle
    if [ -n "$CONNECTED_URL" ]; then
        subtitle="$(gum style --foreground 245 'Подключено к:') $(gum style --foreground 82 --bold "$CONNECTED_URL")"
    else
        subtitle="$(gum style --foreground 214 --italic '<< DOCKER REGISTRY CONTROL MANAGER >>')"
    fi

    local header_text
    header_text=$(echo -e "$logo")
    header_text="${header_text}
${subtitle}"

    gum style \
      --width "$term_cols" \
      --align center \
      "$(gum style \
        --border rounded \
        --border-foreground 202 \
        --padding "0 2" \
        --align center \
        "$header_text")"
    
    local subtext
    subtext=$(gum style --foreground 240 --align center "ESC — Назад  |  Ctrl+C — Ввод команд")
    echo "$subtext"
    echo
}

ERROR_STYLE=$(gum style --foreground 196 --bold "ОШИБКА:")

configure_registry() {
    clear
    print_header
    echo "$(gum style --foreground 240 "Введите параметры подключения к Docker Registry:")"
    echo

    REGISTRY_URL=$(gum input --placeholder "Хост (например, registry2.oikdev.local:5000)" --value "$REGISTRY_URL" < /dev/tty)
    [ $? -eq 130 ] && return 0

    if [[ "$REGISTRY_URL" == :* ]]; then
        process_command "$REGISTRY_URL"
        return 0
    fi

    USERNAME=$(gum input --placeholder "Имя пользователя (опционально)" --value "$USERNAME" < /dev/tty)
    [ $? -eq 130 ] && return 0

    PASSWORD=$(gum input --password --placeholder "Пароль (опционально)" --value "$PASSWORD" < /dev/tty)
    [ $? -eq 130 ] && return 0

    REGISTRY_URL="${REGISTRY_URL%/}"
    REGISTRY_URL=$(echo "$REGISTRY_URL" | sed -E 's|^https?://||')
}

log_cache() {
    local status="$1"
    local endpoint="$2"
    local details="$3"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$status] endpoint='$endpoint' | $details" >> "$LOG_FILE"
}

api_request() {
    local endpoint="$1"
    shift
    local curl_opts=(-s -S -k "$@")

    if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
        curl_opts+=(-u "$USERNAME:$PASSWORD")
    fi

    local is_custom_method=false
    for opt in "$@"; do
        if [[ "$opt" == "-X" || "$opt" == "-I" || "$opt" == "-i" ]]; then
            is_custom_method=true
            break
        fi
    done

    if [ "$ENABLE_CACHE" == "true" ] && [ "$is_custom_method" == "false" ]; then
        local reg_host
        reg_host=$(echo "$REGISTRY_URL" | sed -E 's|https?://||; s|/.*||')
        local current_cache_dir="${CACHE_DIR}/${reg_host}"
        mkdir -p "$current_cache_dir"

        local cache_key
        cache_key=$(echo -n "${REGISTRY_URL}${endpoint}${USERNAME}" | md5sum | awk '{print $1}')
        local cache_file="${current_cache_dir}/${cache_key}.json"

        local ttl_seconds=$CACHE_TTL
        if [[ "$CACHE_TTL" =~ ([0-9]+)d ]]; then
            ttl_seconds=$(( ${BASH_REMATCH[1]} * 86400 ))
        fi

        if [ -f "$cache_file" ]; then
            local file_time now_time age
            file_time=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
            now_time=$(date +%s)
            age=$(( now_time - file_time ))

            if [ $age -lt "$ttl_seconds" ]; then
                log_cache "HIT" "$endpoint" "age=${age}s < ttl=${ttl_seconds}s | file=$cache_key.json"
                cat "$cache_file"
                return 0
            else
                log_cache "EXPIRED" "$endpoint" "age=${age}s >= ttl=${ttl_seconds}s | file=$cache_key.json"
            fi
        else
            log_cache "MISS" "$endpoint" "Файл кэша отсутствует | file=$cache_key.json"
        fi

        local res
        res=$(curl "${curl_opts[@]}" "${REGISTRY_URL}${endpoint}")
        if [ $? -eq 0 ] && [ -n "$res" ]; then
            echo "$res" > "$cache_file"
            log_cache "WRITE" "$endpoint" "Данные успешно записаны в кэш | file=$cache_key.json"
        else
            log_cache "ERROR" "$endpoint" "Ошибка запроса curl или пустой ответ"
        fi
        echo "$res"
    else
        log_cache "BYPASS" "$endpoint" "ENABLE_CACHE=$ENABLE_CACHE, custom_method=$is_custom_method"
        curl "${curl_opts[@]}" "${REGISTRY_URL}${endpoint}"
    fi
}

# Функция для запроса с поддержкой пагинации по заголовку Link (RFC 5988)
api_request_paged() {
    local initial_endpoint="$1"
    local json_key="$2" # Например, "repositories" или "tags"

    local current_endpoint="$initial_endpoint"
    local all_items="[]"

    while [ -n "$current_endpoint" ]; do
        local tmp_header
        tmp_header=$(mktemp)
        
        local body
        body=$(api_request "$current_endpoint" -i)
        
        # Разделяем HTTP-заголовки и тело
        local headers
        headers=$(echo "$body" | sed -n '1,/^\r\{0,1\}$/p')
        local json_body
        json_body=$(echo "$body" | sed '1,/^\r\{0,1\}$/d')

        if [ -z "$json_body" ]; then
            # Фоллбэк: простая попытка запроса, если не удалось распарсить
            json_body=$(api_request "$current_endpoint")
        fi

        local page_items
        page_items=$(echo "$json_body" | jq -r ".${json_key} // []" 2>/dev/null)
        
        if [ -n "$page_items" ] && [ "$page_items" != "null" ]; then
            all_items=$(jq -s '.[0] + .[1]' <(echo "$all_items") <(echo "$page_items"))
        fi

        # Парсинг заголовка Link: </v2/_catalog?last=xxx&n=100>; rel="next"
        local next_link
        next_link=$(echo "$headers" | grep -i '^link:' | grep 'rel="next"' | sed -E 's/.*<([^>]+)>.*/\1/')

        rm -f "$tmp_header"

        if [ -n "$next_link" ]; then
            current_endpoint="$next_link"
        else
            current_endpoint=""
        fi
    done

    jq -n --argjson items "$all_items" --arg key "$json_key" '{($key): $items}'
}

cmd_find() {
    local query="$1"

    if [ -z "$query" ]; then
        clear
        print_header
        echo "$(gum style --foreground 212 --bold "ПОИСК РЕПОЗИТОРИЕВ И ТЕГОВ")"
        echo ""
        if command -v gum &>/dev/null; then
            query=$(gum input --placeholder "Введите имя репозитория, образа или тега...")
        else
            read -p "Введите запрос для поиска: " query
        fi
    fi

    [ -z "$query" ] && echo "Поиск отменен." && return 0

    clear
    print_header
    echo "$(gum style --foreground 212 --bold "Поиск по запросу:") $(gum style --foreground 255 "'$query'")"
    echo ""

    local repos
    repos=$(api_request_paged "/v2/_catalog?n=100" "repositories" | jq -r '.repositories[]?' 2>/dev/null)

    local filtered_repos
    filtered_repos=$(echo "$repos" | grep -i "$query")

    if [ -z "$filtered_repos" ]; then
        log_cache "SEARCH" "$query" "Ничего не найдено"
        echo "$(gum style --foreground 196 "Ничего не найдено.")"
        sleep 1.5
        return 0
    fi

    local matches_count
    matches_count=$(echo "$filtered_repos" | sed '/^$/d' | wc -l)
    log_cache "SEARCH" "$query" "Найдено репозиториев: $matches_count"
    clear
    print_header
    echo "$(gum style --foreground 212 --bold "Результаты поиска для:") $(gum style --foreground 255 "'$query'") $(gum style --foreground 242 "($matches_count)")"
    echo ""

    if command -v gum &>/dev/null; then
        local selected_repo
        selected_repo=$(echo "$filtered_repos" | gum filter --height "$VIEW_HEIGHT" --placeholder "Начните вводить для доп. фильтрации (Enter для выбора)...")
        
        if [ -n "$selected_repo" ]; then
            log_cache "SEARCH_ACTION" "$query" "Выбран репозиторий: $selected_repo"
            show_repository_tags "$selected_repo"
        fi
    else
        echo "$filtered_repos"
    fi
}

check_connection_verbose() {
    local raw_host="$REGISTRY_URL"
    local tmp_err
    tmp_err=$(mktemp)

    log_msg "INFO" "Проверка подключения к $raw_host"

    REGISTRY_URL="https://${raw_host}"
    log_msg "INFO" "Попытка подключения по HTTPS: $REGISTRY_URL"
    
    local status_code
    status_code=$(api_request "/v2/" -I -o /dev/null -w "%{http_code}" 2>"$tmp_err")
    local curl_exit=$?

    if [ $curl_exit -eq 0 ] && [ "$status_code" -eq 200 ]; then
        log_msg "INFO" "Успешное подключение по HTTPS к $REGISTRY_URL"
        rm -f "$tmp_err"
        return 0
    fi

    if [ $curl_exit -eq 0 ] && [ "$status_code" -ne 000 ]; then
        echo "${ERROR_STYLE} Ошибка аутентификации или реестра (HTTPS). HTTP status: $status_code"
        log_msg "ERROR" "Ошибка аутентификации $REGISTRY_URL (HTTP status: $status_code)"
        rm -f "$tmp_err"
        return 1
    fi

    log_msg "WARN" "HTTPS недоступен (curl exit $curl_exit, status $status_code). Пробуем HTTP..."
    echo "$(gum style --foreground 214 "Не удалось подключиться по HTTPS. Пробуем HTTP-соединение...")"

    REGISTRY_URL="http://${raw_host}"
    
    status_code=$(api_request "/v2/" -I -o /dev/null -w "%{http_code}" 2>"$tmp_err")
    curl_exit=$?

    if [ $curl_exit -eq 0 ] && [ "$status_code" -eq 200 ]; then
        log_msg "INFO" "Успешное подключение по HTTP к $REGISTRY_URL"
        echo "$(gum style --foreground 82 "✓ Подключение по HTTP успешно!")"
        
        fix_insecure_registry_and_restart "$raw_host"
        
        rm -f "$tmp_err"
        return 0
    fi

    local err_text
    err_text=$(cat "$tmp_err")
    echo "${ERROR_STYLE} Не удалось подключиться к $raw_host ни по HTTPS, ни по HTTP."
    [ -n "$err_text" ] && echo "$err_text"
    log_msg "ERROR" "Ошибка подключения к $raw_host (HTTP/HTTPS): $err_text"
    
    rm -f "$tmp_err"
    return 1
}

format_bytes() {
    local bytes="$1"
    if [ -z "$bytes" ] || [ "$bytes" == "N/A" ] || ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        echo "N/A"
        return
    fi

    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes} B"
    elif [ "$bytes" -lt 1048576 ]; then
        echo "$(( (bytes + 512) / 1024 )) KB"
    elif [ "$bytes" -lt 1073741824 ]; then
        echo "$(( (bytes + 524288) / 1048576 )) MB"
    else
        echo "$(( (bytes + 536870912) / 1073741824 )) GB"
    fi
}

get_repo_info() {
    local repo="$1"
    local tags_count="N/A"
    local created_date="N/A"
    local formatted_size="N/A"

    local tags_json=""
    if [ "$SHOW_TAG_COUNT" == "true" ] || [ "$SHOW_UPDATED_DATE" == "true" ] || [ "$SHOW_SIZE" == "true" ] || [ "$HIDE_TAGLESS_IMAGES" == "true" ]; then
        tags_json=$(api_request_paged "/v2/$repo/tags/list?n=100" "tags")
    fi

    local raw_count
    raw_count=$(echo "$tags_json" | jq -r '.tags | length // 0' 2>/dev/null)
    [ -z "$raw_count" ] && raw_count="0"

    if [ "$HIDE_TAGLESS_IMAGES" == "true" ] && [ "$raw_count" -eq 0 ]; then
        return 0
    fi

    if [ "$SHOW_TAG_COUNT" == "true" ]; then
        tags_count="$raw_count"
    fi

    local last_tag=""
    if [ "$SHOW_UPDATED_DATE" == "true" ] || [ "$SHOW_SIZE" == "true" ]; then
        last_tag=$(echo "$tags_json" | jq -r '.tags[-1]' 2>/dev/null)
    fi

    if [ -n "$last_tag" ] && [ "$last_tag" != "null" ]; then
        local manifest
        manifest=$(api_request "/v2/$repo/manifests/$last_tag" \
            -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
            -H "Accept: application/vnd.oci.image.manifest.v1+json")

        if [ "$SHOW_SIZE" == "true" ]; then
            local size
            size=$(echo "$manifest" | jq '[.layers[]?.size // 0] | add // 0' 2>/dev/null)
            if [ -n "$size" ] && [ "$size" -gt 0 ]; then
                formatted_size=$(format_bytes "$size")
            fi
        fi

        if [ "$SHOW_UPDATED_DATE" == "true" ]; then
            local config_digest
            config_digest=$(echo "$manifest" | jq -r '.config.digest // empty' 2>/dev/null)

            if [ -n "$config_digest" ]; then
                local config_blob
                config_blob=$(api_request "/v2/$repo/blobs/$config_digest")
                local raw_date
                raw_date=$(echo "$config_blob" | jq -r '.created // empty' 2>/dev/null)
                if [ -n "$raw_date" ]; then
                    created_date=$(echo "$raw_date" | cut -d'T' -f1)
                fi
            fi
        fi
    fi

    echo "${repo},${tags_count},${created_date},${formatted_size}"
}

process_command() {
    local cmd="$1"
    cmd=$(echo "$cmd" | xargs)

    log_msg "INFO" "Выполнение команды: $cmd"

    case "$cmd" in
        ":trash"|":clean")
            run_garbage_collector
            ;;
        ":q"|":quit"|":exit")
            clear
            echo "Завершение работы..."
            log_msg "INFO" "Завершение работы через команду $cmd"
            exit 0
            ;;
        ":settings"|":st")
            open_settings
            ;;
        ":upload"|":push")
            push_image_from_archive
            ;;
        ":disconnect"|":ds")
            log_msg "INFO" "Отключение от текущего Registry ($CONNECTED_URL)"
            CONNECTED_URL=""
            REGISTRY_URL=""
            USERNAME=""
            PASSWORD=""
            CURRENT_REGISTRY=""
            CURRENT_PROJECT=""
            CURRNET_REPO=""
            configure_registry
            ;;
        ":help"|":h")
            show_help
            ;;
        ":find"|":f")
            cmd_find
            ;;
        "")
            return 0
            ;;
        *)
            echo "$(gum style --foreground 196 "Неизвестная команда: $cmd")"
            log_msg "WARN" "Введена неизвестная команда: $cmd"
            sleep 1
            ;;
    esac
}

show_help() {
    clear
    print_header
    echo "$(gum style --foreground 214 --bold 'СПРАВКА ПО КОМАНДАМ И НАВИГАЦИИ:')"
    echo
    echo "  $(gum style --bold ':upload :push')     - Загрузить образ из файла (.tar, .tar.gz)"
    echo "  $(gum style --bold ':settings :st')     - Настройка параметров (колонки, размер пагинации n)"
    echo "  $(gum style --bold ':disconnect :ds')   - Отключиться от текущего Registry"
    echo "  $(gum style --bold ':help :h')          - Показать эту справку"
    echo "  $(gum style --bold ':trash :clean')     - Запуск Garbage Collector для очистки"
    echo "  $(gum style --bold ':exit :quit :q')    - Выход из утилиты"
    echo
    echo "  • Нажмите $(gum style --bold 'ESC') для возврата на уровень выше."
    echo "  • Нажмите $(gum style --bold 'Ctrl+C') в любом меню, кроме справки и меню выбора действия для открытия командной строки."
    echo
    echo "$(gum style --foreground 240 "Нажмите Enter для возврата...")"
    read -r _ < /dev/tty
    clear
}

open_settings() {
    while true; do
        clear
        print_header
        echo "$(gum style --foreground 212 --bold 'НАСТРОЙКА ОТОБРАЖЕНИЯ И ПАРАМЕТРОВ')"
        echo

        local tag_st="[ВКЛ]"
        [ "$SHOW_TAG_COUNT" != "true" ] && tag_st="[ВЫКЛ]"

        local date_st="[ВКЛ]"
        [ "$SHOW_UPDATED_DATE" != "true" ] && date_st="[ВЫКЛ]"

        local size_st="[ВКЛ]"
        [ "$SHOW_SIZE" != "true" ] && size_st="[ВЫКЛ]"

        local hide_tagless_images="[ВЫКЛ]"
        [ "$HIDE_TAGLESS_IMAGES" != "true" ] && hide_tagless_images="[ВКЛ]"

        local cache_st="[ВКЛ]"
        [ "$ENABLE_CACHE" != "true" ] && cache_st="[ВЫКЛ]"

        local ttl_display=""
        if [ "$((CACHE_TTL % 86400))" -eq 0 ]; then
            ttl_display="$((CACHE_TTL / 86400))д"
        elif [ "$((CACHE_TTL % 3600))" -eq 0 ]; then
            ttl_display="$((CACHE_TTL / 3600))ч"
        else
            ttl_display="${CACHE_TTL}с"
        fi

        local options=(
            "Количество тегов $tag_st"
            "Дата обновления $date_st"
            "Размер образа $size_st"
            "Отображать образы без тегов $hide_tagless_images"
            "Кэширование API $cache_st"
        )

        if [ "$ENABLE_CACHE" == "true" ]; then
            options+=("Время жизни кэша (TTL = $ttl_display)")
        fi

        options+=(
            "Лимит каталога/тегов (n=$CATALOG_N)"
            "🧹 Очистить кэш"
            "💾 Сохранить и вернуться"
        )

        local choice
        choice=$(gum choose "${options[@]}" < /dev/tty)

        if [ $? -eq 130 ]; then
            break
        fi

        case "$choice" in
            *"Количество тегов"*)
                [ "$SHOW_TAG_COUNT" == "true" ] && SHOW_TAG_COUNT="false" || SHOW_TAG_COUNT="true"
                ;;
            *"Дата обновления"*)
                [ "$SHOW_UPDATED_DATE" == "true" ] && SHOW_UPDATED_DATE="false" || SHOW_UPDATED_DATE="true"
                ;;
            *"Размер образа"*)
                [ "$SHOW_SIZE" == "true" ] && SHOW_SIZE="false" || SHOW_SIZE="true"
                ;;
            *"Кэширование API"*)
                [ "$ENABLE_CACHE" == "true" ] && ENABLE_CACHE="false" || ENABLE_CACHE="true"
                ;;
            *"Время жизни кэша"*)
                local raw_ttl
                raw_ttl=$(gum input --placeholder "например: 12h, 1d, 7d или 86400" --prompt "Введите TTL (ч/д/с): " < /dev/tty)
                raw_ttl=$(echo "$raw_ttl" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

                if [[ "$raw_ttl" =~ ^([0-9]+)d$ ]]; then
                    local num="${BASH_REMATCH[1]}"
                    [ "$num" -gt 0 ] && CACHE_TTL=$(( num * 86400 ))
                elif [[ "$raw_ttl" =~ ^([0-9]+)h$ ]]; then
                    local num="${BASH_REMATCH[1]}"
                    [ "$num" -gt 0 ] && CACHE_TTL=$(( num * 3600 ))
                elif [[ "$raw_ttl" =~ ^[0-9]+$ ]] && [ "$raw_ttl" -gt 0 ]; then
                    CACHE_TTL="$raw_ttl"
                fi
                ;;
            *"Лимит каталога"*)
                local new_n
                new_n=$(gum input --placeholder "Лимит записей (например 10000)" --value "$CATALOG_N" --prompt "Параметр n: " < /dev/tty)
                if [[ "$new_n" =~ ^[0-9]+$ ]] && [ "$new_n" -gt 0 ]; then
                    CATALOG_N="$new_n"
                fi
                ;;
            *"Отображать образы без тегов"*)
                if [ "$HIDE_TAGLESS_IMAGES" = "true" ]; then
                    HIDE_TAGLESS_IMAGES="false"
                else
                    HIDE_TAGLESS_IMAGES="true"
                fi
                ;;
            *"Очистить кэш"*)
                clear_cache
                echo "$(gum style --foreground 82 "✓ Кэш успешно очищен!")"
                sleep 1
                ;;
            *"Сохранить и вернуться"*|"")
                save_config
                break
                ;;
        esac
    done
    clear
}

get_registry_projects() {
    local catalog_json
    catalog_json=$(api_request_paged "/v2/_catalog?n=100" "repositories")
    echo "$catalog_json" | jq -r '.repositories[]?' 2>/dev/null | awk -F'/' '{print $1}' | sort -u
}

select_archive_file() {
    local current_dir="${1:-$HOME}"

    while true; do
        clear >&2
        print_header >&2
        echo "$(gum style --foreground 212 --bold "ВЫБОР АРХИВА С ОБРАЗОМ")" >&2
        echo "$(gum style --foreground 240 "Текущий каталог:") $(gum style --foreground 220 "$current_dir")" >&2
        echo >&2

        local options=()

        if [ "$current_dir" != "/" ]; then
            options+=("📁 .. (наверх)")
        fi

        while IFS= read -r dir; do
            [ -n "$dir" ] && options+=("📁 $(basename "$dir")")
        done < <(find "$current_dir" -maxdepth 1 -mindepth 1 -type d ! -name ".*" 2>/dev/null | sort)

        while IFS= read -r file; do
            [ -n "$file" ] && options+=("📦 $(basename "$file")")
        done < <(find "$current_dir" -maxdepth 1 -mindepth 1 -type f \( -name "*.tar" -o -name "*.tar.gz" -o -name "*.tgz" \) 2>/dev/null | sort)

        if [ ${#options[@]} -eq 0 ]; then
            echo "$(gum style --foreground 214 "Папка пуста или нет доступных архивов.")" >&2
            echo "$(gum style --foreground 240 "Нажмите Enter для выхода на уровень вверх...")" >&2
            read -r _ < /dev/tty
            current_dir=$(dirname "$current_dir")
            continue
        fi

        local selection
        selection=$(gum choose "${options[@]}" --height 15 --header "Выберите архив или директорию:" < /dev/tty) || return 0

        if [ -z "$selection" ]; then
            return 0
        fi

        local clean_item
        clean_item=$(echo "$selection" | sed 's/^[📁📦] //' | tr -d '\r')

        if [ "$clean_item" == ".. (наверх)" ]; then
            current_dir=$(dirname "$current_dir")
        elif [ -d "$current_dir/$clean_item" ]; then
            current_dir="$current_dir/$clean_item"
        elif [ -f "$current_dir/$clean_item" ]; then
            echo "$current_dir/$clean_item"
            return 0
        fi
    done
}

fix_insecure_registry_and_restart() {
    local reg_host="$1"
    echo "$(gum style --foreground 214 "Обнаружена ошибка подключения по HTTP. Настройка Docker Daemon...")"
    log_msg "WARN" "Запуск автоматической настройки insecure-registry для $reg_host"

    local daemon_json="/etc/docker/daemon.json"
    
    sudo mkdir -p /etc/docker

    if [ ! -s "$daemon_json" ] || ! sudo jq empty "$daemon_json" 2>/dev/null; then
        echo "{}" | sudo tee "$daemon_json" >/dev/null
    fi

    local tmp_file
    tmp_file=$(mktemp)

    if sudo jq --arg reg "$reg_host" '
        .["insecure-registries"] = ((.["insecure-registries"] // []) + [$reg] | unique)
    ' "$daemon_json" > "$tmp_file"; then
        sudo cp "$tmp_file" "$daemon_json"
        sudo chmod 644 "$daemon_json"
        rm -f "$tmp_file"
        echo "$(gum style --foreground 82 "✓ Файл $daemon_json был исправлен для работы по http ($reg_host)")"
    else
        rm -f "$tmp_file"
        echo "${ERROR_STYLE} Не удалось обновить $daemon_json"
        log_msg "ERROR" "Ошибка валидации/записи JSON через jq"
        return 1
    fi

    echo "$(gum style --foreground 212 "Перезапуск службы Docker...")"
    if sudo systemctl restart docker; then
        echo "$(gum style --foreground 82 "✓ Docker успешно перезапущен")"
        log_msg "INFO" "Docker daemon успешно перезапущен с обновленным insecure-registries"
        sleep 2
        return 0
    else
        echo "${ERROR_STYLE} Не удалось перезапустить Docker Daemon."
        log_msg "ERROR" "Не удалось перезапустить Docker Daemon"
        return 1
    fi
}

push_image_from_archive() {
    local preset_project="${1:-}"
    local preset_repo="${2:-}"

    while true; do
        local archive_file
        archive_file=$(select_archive_file "$HOME")

        if [ -z "$archive_file" ] || [ ! -f "$archive_file" ]; then
            clear
            print_header
            echo "$(gum style --foreground 214 "Загрузка архивов завершена.")"
            sleep 1
            return 0
        fi

        log_msg "INFO" "Выбран файл для импорта: $archive_file"
        clear
        print_header
        echo "$(gum style --foreground 212 --bold "Выбран архив:") $archive_file"
        echo

        local load_out
        load_out=$(mktemp)

        if ! gum spin --spinner line --spinner.foreground 208 \
            --title " [1/2] Распаковка и импорт архива в локальный Docker Daemon..." \
            -- bash -c "docker load -i '$archive_file' > '$load_out' 2>&1"; then
            echo "$ERROR_STYLE Не удалось выполнить 'docker load' для файла."
            cat "$load_out"
            log_msg "ERROR" "Ошибка docker load файла $archive_file: $(cat "$load_out")"
            rm -f "$load_out"
            read -r _ < /dev/tty
            continue
        fi

        local loaded_image
        loaded_image=$(grep -oP 'Loaded image: \K.*' "$load_out" | tail -n 1)
        rm -f "$load_out"

        if [ -z "$loaded_image" ]; then
            echo "$ERROR_STYLE Не удалось определить имя загруженного образа из архива."
            log_msg "ERROR" "Не удалось извлечь имя образа из результата docker load"
            read -r _ < /dev/tty
            continue
        fi

        echo "$(gum style --foreground 82 "✓ Образ импортирован:") $loaded_image"
        log_msg "INFO" "Образ успешно импортирован локально: $loaded_image"
        echo

        local default_name=""
        local default_tag="latest"

        if [[ "$loaded_image" == *":"* ]]; then
            default_tag="${loaded_image##*:}"
            default_name="${loaded_image%:*}"
        else
            default_name="$loaded_image"
        fi
        default_name="${default_name##*/}"

        local target_project="$preset_project"
        if [ -z "$target_project" ]; then
            local existing_projects
            existing_projects=$(get_registry_projects)

            local proj_list=("➕ Создать новый проект")
            while IFS= read -r p; do
                [ -n "$p" ] && proj_list+=("$p")
            done <<< "$existing_projects"

            local proj_choice
            proj_choice=$(gum choose "${proj_list[@]}" --header "Выберите проект" < /dev/tty) || continue

            local clean_proj
            clean_proj=$(echo "$proj_choice" | tr -d '[:space:]' | sed 's/\x1b\[[0-9;]*m//g')

            if [[ "$clean_proj" == *"Создатьновыйпроект"* ]] || [ -z "$clean_proj" ]; then
                target_project=$(gum input --placeholder "Имя нового проекта" --prompt "Проект: " < /dev/tty) || continue
            else
                target_project="$proj_choice"
            fi
        fi

        local target_repo="$preset_repo"
        if [ -z "$target_repo" ]; then
            target_repo=$(gum input --placeholder "Образ" --value "$default_name" --prompt "Образ: " < /dev/tty) || continue
        else
            target_repo="${target_repo#*/}"
        fi

        local target_tag
        target_tag=$(gum input --placeholder "Тег" --value "$default_tag" --prompt "Тег: " < /dev/tty) || continue

        local registry_host
        registry_host=$(echo "$REGISTRY_URL" | sed -E 's|^https?://||')

        local full_target_image="${registry_host}/${target_project}/${target_repo}:${target_tag}"

        echo "  Целевой образ: $(gum style --foreground 220 --bold "$full_target_image")"
        echo

        if ! gum confirm "Отправить образ в Registry?" < /dev/tty; then
            log_msg "INFO" "Публикация образа $full_target_image отменена пользователем"
            continue
        fi

        docker tag "$loaded_image" "$full_target_image"

        if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
            echo "$PASSWORD" | docker login "$registry_host" -u "$USERNAME" --password-stdin &>/dev/null
        fi

        echo
        local push_err
        push_err=$(mktemp)

        log_msg "INFO" "Начало загрузки образа $full_target_image в реестр"

        if ! gum spin --spinner line --spinner.foreground 208 \
            --title " [2/2] Публикация $full_target_image в Registry..." \
            -- bash -c "docker push '$full_target_image' > '$push_err' 2>&1"; then
            
            if grep -q "server gave HTTP response to HTTPS client" "$push_err"; then
                echo "$ERROR_STYLE Не удалось выполнить push из-за HTTP соединения."
                echo "$(gum style --foreground 214 "Повторная попытка с автоматической настройкой Daemon...")"
                echo
                
                if fix_insecure_registry_and_restart "$registry_host"; then
                    docker tag "$loaded_image" "$full_target_image" &>/dev/null
                    if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
                        echo "$PASSWORD" | docker login "$registry_host" -u "$USERNAME" --password-stdin &>/dev/null
                    fi

                    echo
                    if ! gum spin --spinner line --spinner.foreground 208 \
                        --title " [2/2] Повторная публикация $full_target_image в Registry..." \
                        -- bash -c "docker push '$full_target_image' > '$push_err' 2>&1"; then
                        
                        echo "$ERROR_STYLE Повторный push также завершился ошибкой:"
                        cat "$push_err"
                        log_msg "ERROR" "Повторная попытка docker push $full_target_image не удалась: $(cat "$push_err")"
                        rm -f "$push_err"
                        read -r _ < /dev/tty
                        continue
                    fi
                else
                    rm -f "$push_err"
                    read -r _ < /dev/tty
                    continue
                fi
            else
                echo "$ERROR_STYLE Не удалось выполнить 'docker push':"
                cat "$push_err"
                log_msg "ERROR" "Ошибка docker push $full_target_image: $(cat "$push_err")"
                rm -f "$push_err"
                read -r _ < /dev/tty
                continue
            fi
        fi

        rm -f "$push_err"
        echo "$(gum style --foreground 82 --bold "✓ Успешно загружено!") $full_target_image"
        log_msg "INFO" "Образ $full_target_image успешно загружен в Registry"
        docker rmi "$full_target_image" "$loaded_image" &>/dev/null || true

        clear_cache

        echo
        if ! gum confirm --affirmative "Да" --negative "Нет" "Загрузить ещё один архив?" < /dev/tty; then
            break
        fi
    done
}

run_garbage_collector() {
    clear
    print_header
    echo -e "\033[33m[GC] Запуск Garbage Collector...\033[0m"
    log_msg "INFO" "Запуск garbage collection через :trash"
    
    local SSH_LOGIN
    local SSH_PASSWORD
    local SSH_HOST
    
    SSH_LOGIN=$(gum input --placeholder "Логин ssh" < /dev/tty) || return
    SSH_PASSWORD=$(gum input --password --placeholder "Пароль ssh" < /dev/tty) || return
    
    local clean_url="${CONNECTED_URL#*://}"
    SSH_HOST="${clean_url%%:*}"

    if sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no "${SSH_LOGIN}@${SSH_HOST}" \
        "docker exec -i docker-registry-registry-1 registry garbage-collect --dry-run /etc/docker-registry/config.yml"
    then
        echo ""
        echo -e "\033[32m[OK] Очистка неиспользуемых слоев и неактивных тегов успешно завершена.\033[0m"
        log_msg "INFO" "Garbage collection завершился успешно"
        clear_cache
    else
        echo ""
        echo -e "\033[31m[ERROR] Не удалось выполнить Garbage Collector.\033[0m"
        log_msg "ERROR" "Ошибка при выполнении Garbage Collection в контейнере docker-registry-registry-1"
    fi

    echo ""
    read -rp "Нажмите Enter для продолжения..."
}

show_repository_tags() {
    local repo="$1"

    while true; do
        get_term_dimensions
        clear
        print_header
        echo "$(gum style --foreground 212 --bold "Образ:") $(gum style --foreground 255 "$repo")"

        # Получаем полный список тегов с учетом пагинации
        local tags_json
        tags_json=$(api_request_paged "/v2/${repo}/tags/list?n=100" "tags")

        local raw_tags
        raw_tags=$(echo "$tags_json" | jq -r '.tags[]?' 2>/dev/null)

        local item_list=()

        if [ -n "$raw_tags" ] && [ "$raw_tags" != "null" ]; then
            while IFS= read -r t; do
                [ -n "$t" ] && item_list+=("$t")
            done <<< "$raw_tags"
        fi

        # Проверка tagless через Harbour API / Кэш дайджестов
        local has_tagless=false

        local harbor_endpoint="/api/v2.0/projects/${repo%%/*}/repositories/${repo#*/}/artifacts"
        local harbor_res
        harbor_res=$(api_request "$harbor_endpoint" 2>/dev/null)

        if echo "$harbor_res" | jq -e 'if type=="array" then .[] else empty end | select(.tags == null or (.tags | length) == 0)' >/dev/null 2>&1; then
            has_tagless=true
        else
            local repo_cache_file="${CACHE_DIR}/${REGISTRY_HOST}/repos/${repo//\//_}_meta.json"
            if [ -f "$repo_cache_file" ]; then
                local active_tags_pattern
                active_tags_pattern=$(echo "$raw_tags" | tr '\n' '|' | sed 's/|$//')
                
                local orphan_count
                orphan_count=$(jq -r --arg pattern "$active_tags_pattern" '
                    [.manifests[]? | select(.tag == null or (.tag | test($pattern) | not))] | length
                ' "$repo_cache_file" 2>/dev/null || echo 0)

                [ "$orphan_count" -gt 0 ] && has_tagless=true
            fi
        fi

        if [ "$has_tagless" = true ]; then
            item_list+=("⚠️  [tagless / untagged]")
        fi

        echo ""

        local selected_item
        selected_item=$(printf "%s\n" "${item_list[@]}" | gum choose --height "$VIEW_HEIGHT" --header "ТЕГИ И АРТЕФАКТЫ")

        [ -z "$selected_item" ] && break

        manage_tag_action "$repo" "$selected_item"
        [ $? -eq 2 ] && return 2
    done
}

show_tag_history() {
    local repo="$1"
    local tag="$2"

    get_term_dimensions
    clear
    print_header
    echo "$(gum style --foreground 212 --bold "Образ:") $(gum style --foreground 255 "$repo:$tag")"
    echo

    local target_arch="amd64"
    local target_os="linux"
    local tmp_json
    tmp_json=$(mktemp)

    gum spin --spinner line --spinner.foreground 208 \
        --title " Анализ манифеста и получение истории слоев..." \
        -- bash -c "
            REGISTRY_URL='$REGISTRY_URL'
            USERNAME='$USERNAME'
            PASSWORD='$PASSWORD'
            ENABLE_CACHE='$ENABLE_CACHE'
            CACHE_TTL='$CACHE_TTL'
            CACHE_DIR='$CACHE_DIR'
            $(declare -f api_request)

            manifest_resp=\$(api_request '/v2/$repo/manifests/$tag' -i \
                -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' \
                -H 'Accept: application/vnd.docker.distribution.manifest.list.v2+json' \
                -H 'Accept: application/vnd.oci.image.index.v1+json' \
                -H 'Accept: application/vnd.oci.image.manifest.v1+json')

            http_code=\$(echo \"\$manifest_resp\" | grep -E '^HTTP/' | tail -n 1 | awk '{print \$2}')
            manifest_body=\$(echo \"\$manifest_resp\" | sed '1,/^\r\{0,1\}\$/d')

            if [ -z \"\$http_code\" ] || [ \"\$http_code\" -ne 200 ]; then
                jq -n --arg err \"[HTTP \$http_code] Не удалось загрузить манифест тега\" '{error: \$err}' > '$tmp_json'
                exit 0
            fi

            media_type=\$(echo \"\$manifest_body\" | jq -r '.mediaType // empty' 2>/dev/null)
            config_digest=\"\"

            if [[ \"\$media_type\" == *\"manifest.list\"* ]] || [[ \"\$media_type\" == *\"image.index\"* ]]; then
                target_digest=\$(echo \"\$manifest_body\" | jq -r --arg arch '$target_arch' --arg os '$target_os' \
                    '.manifests[]? | select(.platform.architecture == \$arch and .platform.os == \$os) | .digest' 2>/dev/null | head -n 1)

                if [ -z \"\$target_digest\" ] || [ \"\$target_digest\" == \"null\" ]; then
                    target_digest=\$(echo \"\$manifest_body\" | jq -r '.manifests[0].digest?' 2>/dev/null)
                fi

                if [ -n \"\$target_digest\" ] && [ \"\$target_digest\" != \"null\" ]; then
                    sub_manifest=\$(api_request \"/v2/$repo/manifests/\$target_digest\" \
                        -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' \
                        -H 'Accept: application/vnd.oci.image.manifest.v1+json')
                    config_digest=\$(echo \"\$sub_manifest\" | jq -r '.config.digest?' 2>/dev/null)
                fi
            else
                config_digest=\$(echo \"\$manifest_body\" | jq -r '.config.digest?' 2>/dev/null)
            fi

            if [ -z \"\$config_digest\" ] || [ \"\$config_digest\" == \"null\" ]; then
                jq -n --arg err \"[CONFIG_NOT_FOUND] config.digest отсутствует\" '{error: \$err}' > '$tmp_json'
                exit 0
            fi

            blob_resp=\$(api_request \"/v2/$repo/blobs/\$config_digest\" -i)
            blob_body=\$(echo \"\$blob_resp\" | sed '1,/^\r\{0,1\}\$/d')

            dockerfile_lines=\$(echo \"\$blob_body\" | jq -r '.history[]? | select(.empty_layer != true or .created_by != null) | .created_by' 2>/dev/null | \
                sed 's|/bin/sh -c #(nop) ||g' | \
                sed 's|/bin/sh -c ||g' | \
                grep -v '^\s*$' | \
                sed '/^$/d')

            if [ -n \"\$dockerfile_lines\" ]; then
                jq -n --arg code \"\$dockerfile_lines\" '{dockerfile: \$code}' > '$tmp_json'
            else
                jq -n --arg err \"[EMPTY_HISTORY] История пуста\" '{error: \$err}' > '$tmp_json'
            fi
        "

    local err_msg
    err_msg=$(jq -r '.error // empty' "$tmp_json" 2>/dev/null)
    local dockerfile_content
    dockerfile_content=$(jq -r '.dockerfile // empty' "$tmp_json" 2>/dev/null)

    rm -f "$tmp_json"

    if [ -n "$dockerfile_content" ]; then
        echo "$(gum style --foreground 214 --bold "Предполагаемый Dockerfile (история слоев):")"
        echo
        local clean_code
        clean_code=$(echo "$dockerfile_content" | grep -v '^\s*$' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        gum style \
            --border rounded \
            --border-foreground 240 \
            --padding "0 1" \
            --width "$(( TERM_COLS - 4 ))" \
            "$clean_code"
    else
        echo "$(gum style --foreground 196 --bold "✗ Ошибка извлечения истории:") $err_msg"
        log_msg "ERROR" " Ошибка извлечения истории слоев для $repo:$tag: $err_msg"
    fi

    echo
    gum input --placeholder "Нажмите Enter для возврата..."
}

show_tag_digest() {
    local repo="$1"
    local tag="$2"

    clear
    print_header
    echo "$(gum style --foreground 212 --bold "Образ:") $(gum style --foreground 255 "$repo:$tag")"
    echo

    local digest=""

    if [[ "$tag" == sha256:* ]]; then
        digest="$tag"
    elif [[ "$tag" == *"tagless"* ]]; then
        digest=""
    else
        digest=$(gum spin --spinner line --spinner.foreground 208 \
            --title " Получение Digest..." \
            -- bash -c "
                REGISTRY_URL='$REGISTRY_URL'
                USERNAME='$USERNAME'
                PASSWORD='$PASSWORD'
                ENABLE_CACHE='$ENABLE_CACHE'
                CACHE_TTL='$CACHE_TTL'
                CACHE_DIR='$CACHE_DIR'
                LOG_FILE='$LOG_FILE'
                $(declare -f log_cache)
                $(declare -f api_request)
                api_request '/v2/$repo/manifests/$tag' -I \
                    -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' \
                    -H 'Accept: application/vnd.docker.distribution.manifest.list.v2+json' \
                    -H 'Accept: application/vnd.oci.image.index.v1+json' \
                    | grep -i 'Docker-Content-Digest' | awk '{print \$2}' | tr -d '\r'
            ")
    fi

    if [ -n "$digest" ]; then
        gum style \
            --border rounded \
            --border-foreground 208 \
            --padding "0 1" \
            "$(gum style --foreground 245 'Digest:') $(gum style --foreground 220 --bold "$digest")"
    else
        gum style \
            --border rounded \
            --border-foreground 196 \
            --padding "0 1" \
            "$(gum style --foreground 196 --bold '⚠ Digest не найден')"
    fi

    echo
    gum input --placeholder "Нажмите Enter для возврата..."
}

manage_tag_action() {
    local repo="$1"
    local tag="$2"

    while true; do
        clear
        print_header
        echo "$(gum style --foreground 212 --bold "Выбран тег:") $(gum style --foreground 82 --bold "$repo:$tag")"
        echo

        local action
        action=$(gum choose \
            "📋 Команда docker pull" \
            "🔍 Посмотреть Digest" \
            "📜 Посмотреть History (Dockerfile)" \
            "🗑️ Удалить этот тег" \
            "⌨️ Ввести команду (:)" \
            "⬅️ Назад к тегам")

        if [[ "$action" == :* ]]; then
            process_command "$action"
            [ $? -eq 2 ] && return 2
            continue
        fi

        case "$action" in
            "📋 Команда docker pull") show_pull_command "$repo" "$tag" ;;
            "🔍 Посмотреть Digest") show_tag_digest "$repo" "$tag" ;;
            "📜 Посмотреть History (Dockerfile)") show_tag_history "$repo" "$tag" ;;
            "⌨️ Ввести команду (:)")
                prompt_command_mode
                [ $? -eq 2 ] && return 2
                ;;
            "🗑️ Удалить этот тег")
                clear
                print_header
                if gum confirm --affirmative "Да, удалить" --negative "Отмена" "Удалить манифест тега $repo:$tag?"; then
                    local digest
                    digest=$(api_request "/v2/$repo/manifests/$tag" -I \
                        -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' \
                        -H 'Accept: application/vnd.docker.distribution.manifest.list.v2+json' \
                        -H 'Accept: application/vnd.oci.image.index.v1+json' \
                        | grep -i 'Docker-Content-Digest' | awk '{print $2}' | tr -d '\r')

                    if [ -n "$digest" ]; then
                        local status_code
                        status_code=$(api_request "/v2/$repo/manifests/$digest" -X DELETE -o /dev/null -w "%{http_code}")
                        if [ "$status_code" -eq 202 ] || [ "$status_code" -eq 200 ]; then
                            local del_ok
                            del_ok=$(gum style --foreground 82 "✓ Тег $tag успешно удален")
                            echo "$del_ok"
                            log_msg "INFO" "Удален тег $repo:$tag (digest: $digest)"
                            clear_cache
                        else
                            local del_err
                            del_err=$(gum style --foreground 196 "✗ Ошибка удаления (HTTP $status_code)")
                            echo "$del_err"
                            log_msg "ERROR" "Ошибка удаления тега $repo:$tag (HTTP $status_code)"
                        fi
                    else
                        log_msg "WARN" "Не удалось извлечь digest для удаления $repo:$tag"
                    fi
                    gum input --placeholder "Нажмите Enter..."
                    break
                fi
                ;;
            "⬅️ Назад к тегам"|"") break ;;
        esac
    done
}

show_pull_command() {
    local repo="$1"
    local tag="$2"

    local registry_host
    registry_host=$(echo "$REGISTRY_URL" | sed -E 's|^https?://||')
    local pull_cmd="docker pull ${registry_host}/${repo}:${tag}"

    clear
    print_header
    echo "$(gum style --foreground 212 --bold "Образ:") $(gum style --foreground 255 "$repo:$tag")"
    echo
    echo "$(gum style --foreground 214 --bold "Команда для скачивания:")"
    echo

    gum style \
        --border rounded \
        --border-foreground 82 \
        --padding "0 1" \
        "$(gum style --foreground 255 --bold "$pull_cmd")"

    echo

    if command -v xclip &>/dev/null; then
        echo -n "$pull_cmd" | xclip -selection clipboard
        echo "$(gum style --foreground 240 "(Скопировано в буфер обмена via xclip)")"
    elif command -v pbcopy &>/dev/null; then
        echo -n "$pull_cmd" | pbcopy
        echo "$(gum style --foreground 240 "(Скопировано в буфер обмена via pbcopy)")"
    fi

    echo
    gum input --placeholder "Нажмите Enter для возврата..."
}

manage_repository_action() {
    local repo="$1"

    while true; do
        clear
        print_header
        local repo_msg
        repo_msg=$(gum style --foreground 212 --bold "Выбран образ: ")
        echo "$repo_msg" $(gum style --foreground 255 "$repo")
        echo

        local action
        action=$(gum choose \
            "📋 Выбрать конкретный тег" \
            "🗑️ Удалить образ полностью" \
            "⌨️ Ввести команду (:)" \
            "⬅️ Назад")

        case "$action" in
            "📋 Выбрать конкретный тег")
                show_repository_tags "$repo"
                [ $? -eq 2 ] && return 2
                ;;
            "🗑️ Удалить образ полностью")
                delete_repository "$repo"
                break
                ;;
            "⌨️ Ввести команду (:)")
                prompt_command_mode
                [ $? -eq 2 ] && return 2
                ;;
            "⬅️ Назад"|"") break ;;
        esac
    done
}

delete_repository() {
    local repo="$1"

    clear
    print_header
    local title_msg
    title_msg=$(gum style --foreground 196 --bold "УДАЛЕНИЕ ОБРАЗА: $repo")
    echo "$title_msg"
    echo

    if ! gum confirm --affirmative "Да, удалить" --negative "Отмена" "Вы уверены, что хотите полностью удалить репозиторий $repo (манифесты и файлы с диска)?"; then
        log_msg "INFO" "Отменено полное удаление образа $repo"
        return
    fi

    log_msg "WARN" "Запуск полного удаления всех манифестов и каталога образа $repo"

    local tags_json
    tags_json=$(gum spin --spinner line --spinner.foreground 208 \
        --title " Получение списка тегов для $repo..." \
        -- bash -c "
            REGISTRY_URL='$REGISTRY_URL'
            USERNAME='$USERNAME'
            PASSWORD='$PASSWORD'
            ENABLE_CACHE='$ENABLE_CACHE'
            CACHE_TTL='$CACHE_TTL'
            CACHE_DIR='$CACHE_DIR'
            LOG_FILE='$LOG_FILE'
            $(declare -f log_cache)
            $(declare -f api_request)
            $(declare -f api_request_paged)
            api_request_paged '/v2/$repo/tags/list?n=100' 'tags'
        ")

    local tags
    tags=$(echo "$tags_json" | jq -r '.tags[]?' 2>/dev/null)

    if [ -n "$tags" ]; then
        local del_start_msg
        del_start_msg=$(gum style --foreground 212 "Удаление манифестов по тегам...")
        echo "$del_start_msg"
        local deleted_count=0
        local fail_count=0

        while read -r tag; do
            [ -z "$tag" ] && continue
            
            local digest
            digest=$(api_request "/v2/$repo/manifests/$tag" -I \
                -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
                -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
                -H "Accept: application/vnd.oci.image.index.v1+json" \
                | grep -i "Docker-Content-Digest" | awk '{print $2}' | tr -d '\r')

            if [ -n "$digest" ]; then
                local status_code
                status_code=$(api_request "/v2/$repo/manifests/$digest" -X DELETE -o /dev/null -w "%{http_code}")
                
                if [ "$status_code" -eq 202 ] || [ "$status_code" -eq 200 ]; then
                    echo "$(gum style --foreground 82 "✓ Удален тег $tag (Digest: ${digest:0:18}...)")"
                    log_msg "INFO" "Удален тег $repo:$tag ($digest)"
                    ((deleted_count++))
                else
                    echo "$(gum style --foreground 196 "✗ Ошибка удаления $tag (HTTP $status_code)")"
                    log_msg "ERROR" "Ошибка удаления $repo:$tag (HTTP status: $status_code)"
                    ((fail_count++))
                fi
            else
                echo "$(gum style --foreground 214 "⚠ Не удалось получить Digest для тега $tag")"
                log_msg "WARN" "Не удалось найти digest для тега $repo:$tag"
                ((fail_count++))
            fi
        done <<< "$tags"
        
        echo "$(gum style --bold "Удаление манифестов завершено. Успешно: $deleted_count, ошибок: $fail_count")"
    else
        echo "$(gum style --foreground 214 "У образа нет активных тегов (уже очищены или tagless).")"
    fi

    echo
    echo "$(gum style --foreground 214 --bold "[GC & PURGE] Автоматическая очистка диска...")"
    
    local SSH_LOGIN SSH_PASSWORD SSH_HOST
    SSH_LOGIN=$(gum input --placeholder "Логин SSH (для очистки файлов и перезапуска)" < /dev/tty) || return
    SSH_PASSWORD=$(gum input --password --placeholder "Пароль SSH" < /dev/tty) || return

    local clean_url="${CONNECTED_URL#*://}"
    SSH_HOST="${clean_url%%:*}"

    log_msg "INFO" "Запуск registry garbage-collect через SSH на $SSH_HOST"
    if sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no "${SSH_LOGIN}@${SSH_HOST}" \
        "docker exec -i docker-registry-registry-1 registry garbage-collect /etc/docker-registry/config.yml --delete-untagged" &>/dev/null; then
        echo "$(gum style --foreground 82 "✓ Garbage collector успешно очистил неиспользуемые слои.")"
        log_msg "INFO" "Garbage collection завершён успешно"
    else
        echo "$(gum style --foreground 196 "✗ Не удалось выполнить Garbage Collector на сервере.")"
        log_msg "ERROR" "Ошибка при выполнении Garbage Collection на $SSH_HOST"
    fi

    local check_tags
    check_tags=$(api_request "/v2/$repo/tags/list")
    local remain_count
    remain_count=$(echo "$check_tags" | jq -r '.tags | if . == null then 0 else length end' 2>/dev/null || echo 0)

    if [ "$remain_count" -eq 0 ]; then
        echo "$(gum style --foreground 212 "Тегов не осталось. Подготовка к удалению каталога репозитория с диска...")"
        log_msg "INFO" "У репозитория $repo нет тегов. Запуск физического удаления каталога..."

        local remote_cmd
        remote_cmd=$(cat <<EOF
            REPO_DIR=\$(docker inspect docker-registry-registry-1 --format '{{range .Mounts}}{{if eq .Destination "/var/lib/registry"}}{{.Source}}{{end}}{{end}}' 2>/dev/null)/docker/registry/v2/repositories/${repo}
            if [ -z "\$REPO_DIR" ] || [ ! -d "\$REPO_DIR" ]; then
                REPO_DIR="/var/lib/docker/volumes/docker-registry_registry-data/_data/docker/registry/v2/repositories/${repo}"
            fi

            if [ -d "\$REPO_DIR" ]; then
                docker stop docker-registry-registry-1 >/dev/null 2>&1 && \
                rm -rf "\$REPO_DIR"
                exit 0
            else
                exit 2
            fi
EOF
        )

        if sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no "${SSH_LOGIN}@${SSH_HOST}" "$remote_cmd" &>/dev/null; then
            echo "$(gum style --foreground 82 "✓ Каталог репозитория $repo физически удалён с диска.")"
            log_msg "INFO" "Каталог репозитория $repo успешно удален с сервера."
        else
            echo "$(gum style --foreground 196 "⚠ Каталог репозитория не найден на сервере или произошла ошибка при остановке/удалении.")"
            log_msg "WARN" "Не удалось физически удалить каталог репозитория $repo на сервере."
        fi
    else
        echo "$(gum style --foreground 214 "У репозитория $repo всё ещё есть теги ($remain_count шт.). Каталог на диске сохранен.")"
    fi

    echo "$(gum style --foreground 212 "Перезапуск контейнера registry...")"
    log_msg "INFO" "Выполнение docker restart docker-registry-registry-1 на $SSH_HOST"

    if sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no "${SSH_LOGIN}@${SSH_HOST}" \
        "docker restart docker-registry-registry-1" &>/dev/null; then
        echo "$(gum style --foreground 82 "✓ Команда restart отправлена.")"
        log_msg "INFO" "Команда docker restart завершена успешно."
    else
        echo "$(gum style --foreground 196 "✗ Ошибка при вызове docker restart.")"
        log_msg "ERROR" "Сбой команды docker restart docker-registry-registry-1"
    fi

    echo "$(gum style --foreground 208 "Проверка статуса поднятия контейнера registry...")"
    log_msg "INFO" "Ожидание запуска и проверка статуса docker-registry-registry-1"

    local is_running="false"
    for i in {1..10}; do
        sleep 1
        local container_state
        container_state=$(sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no "${SSH_LOGIN}@${SSH_HOST}" \
            "docker inspect --format='{{.State.Status}}' docker-registry-registry-1 2>/dev/null" | tr -d '\r')

        if [ "$container_state" = "running" ]; then
            is_running="true"
            break
        fi
    done

    if [ "$is_running" = "true" ]; then
        echo "$(gum style --foreground 82 "✓ Контейнер registry успешно поднялся (Status: running).")"
        log_msg "INFO" "Контейнер docker-registry-registry-1 успешно запущен (Status: running)."
    else
        echo "$(gum style --foreground 196 "✗ Контейнер registry не поднялся за отведенное время!")"
        log_msg "ERROR" "Контейнер docker-registry-registry-1 не в состоянии running после restart."
    fi

    local catalog_check
    catalog_check=$(api_request "/v2/_catalog")
    if echo "$catalog_check" | jq -e --arg r "$repo" '.repositories[]? | select(. == $r)' >/dev/null 2>&1; then
        echo "$(gum style --foreground 214 "ℹ Репозиторий всё ещё отображается в /v2/_catalog (возможно, кэш registry).")"
        log_msg "WARN" "Репозиторий $repo всё еще виден в /v2/_catalog"
    else
        echo "$(gum style --foreground 82 "✓ Репозиторий $repo больше не отображается в /v2/_catalog.")"
        log_msg "INFO" "Репозиторий $repo успешно исчез из /v2/_catalog"
    fi

    clear_cache
    echo
    gum input --placeholder "Нажмите Enter для продолжения..."
}

show_project_repositories() {
    local project="$1"
    local repos_list="$2"

    while true; do
        get_term_dimensions
        clear
        print_header
        echo "$(gum style --foreground 212 --bold "Проект: ") $(gum style --foreground 255 "$project")"

        local filtered_repos
        filtered_repos=$(echo "$repos_list" | grep -E "^${project}/|^${project}$")

        local tmp_csv
        tmp_csv=$(mktemp)
        echo "ОБРАЗ,ТЕГОВ,ОБНОВЛЕН,РАЗМЕР" > "$tmp_csv"

        # Правильный экспорт функций и всех необходимых переменных для использования в xargs
        export REGISTRY_URL USERNAME PASSWORD SHOW_TAG_COUNT SHOW_UPDATED_DATE SHOW_SIZE CATALOG_N ENABLE_CACHE CACHE_TTL CACHE_DIR HIDE_TAGLESS_IMAGES LOG_FILE
        export -f api_request api_request_paged format_bytes get_repo_info log_cache

        gum spin --spinner line --spinner.foreground 208 \
            --title " Загрузка метаданных..." \
            -- bash -c "echo '$filtered_repos' | xargs -I{} -P 8 bash -c 'get_repo_info \"{}\"' >> '$tmp_csv'"

        clear
        print_header
        echo "$(gum style --foreground 212 --bold "Проект: ") $(gum style --foreground 255 "$project")"
        echo

        local tmp_select
        tmp_select=$(mktemp)

        gum table \
            --border rounded \
            --border.foreground 202 \
            --header.foreground 214 \
            --header.bold \
            --selected.foreground 0 \
            --selected.background 212 \
            --widths "${R_COL1_WIDTH},${R_COL2_WIDTH},${R_COL3_WIDTH},${R_COL4_WIDTH}" \
            --height "$VIEW_HEIGHT" < "$tmp_csv" > "$tmp_select"

        local res=$?
        local selected_row
        selected_row=$(cat "$tmp_select")
        rm -f "$tmp_csv" "$tmp_select"

        if [ $res -eq 130 ]; then
            prompt_command_mode
            continue
        fi

        local selected_repo
        selected_repo=$(echo "$selected_row" | head -n 1 | awk -F',' '{print $1}' | tr -d '[:space:]' | sed 's/\x1b\[[0-9;]*m//g')

        [ -z "$selected_repo" ] && break
        [[ "$selected_repo" == *"Usage:"* ]] || [ "$selected_repo" == "ОБРАЗ" ] && continue

        manage_repository_action "$selected_repo"
    done
}

main() {
    while true; do
        if [ -z "$CONNECTED_URL" ]; then
            configure_registry

            if check_connection_verbose; then
                CONNECTED_URL="$REGISTRY_URL"
            else
                CONNECTED_URL=""
                gum confirm "Повторить ввод?" < /dev/tty || exit 0
                continue
            fi
        fi

        get_term_dimensions
        clear
        print_header

        # Используем пагинированный вызов для сбора всех репозиториев
        local catalog_json
        catalog_json=$(api_request_paged "/v2/_catalog?n=100" "repositories")
        local repos
        repos=$(echo "$catalog_json" | jq -r '.repositories[]?' 2>/dev/null)

        if [ "$repos" == "null" ] || [ -z "$repos" ]; then
            clear
            print_header
            echo "$(gum style --foreground 214 "Реестр пуст или эндпоинт /_catalog недоступен.")"
            echo "$(gum style --foreground 240 "Используйте :upload или :push для загрузки первого образа.")"
            echo
            if ! gum confirm --affirmative "Да, загрузить" --negative "Нет, отключиться" "Готовы загрузить первый образ в этот registry?" < /dev/tty; then
                break
            fi
            prompt_command_mode
            continue
        fi

        local tmp_csv
        tmp_csv=$(mktemp)
        echo "ПРОЕКТ,ОБРАЗОВ" > "$tmp_csv"

        local projects
        projects=$(echo "$repos" | awk -F'/' '{print $1}' | sort -u)

        while read -r proj; do
            [ -z "$proj" ] && continue
            local count="N/A"
            if [ "$SHOW_TAG_COUNT" == "true" ]; then
                count=$(echo "$repos" | grep -c -E "^${proj}/|^${proj}$")
            fi
            echo "${proj},${count}" >> "$tmp_csv"
        done <<< "$projects"

        clear
        print_header

        local tmp_select
        tmp_select=$(mktemp)

        gum table \
            --border rounded \
            --border.foreground 202 \
            --header.foreground 214 \
            --header.bold \
            --selected.foreground 0 \
            --selected.background 212 \
            --widths "${P_COL1_WIDTH},${P_COL2_WIDTH}" \
            --height "$VIEW_HEIGHT" < "$tmp_csv" > "$tmp_select"

        local res=$?
        local selected_row
        selected_row=$(cat "$tmp_select")
        rm -f "$tmp_csv" "$tmp_select"

        if [ $res -eq 130 ]; then
            prompt_command_mode
            continue
        fi

        local selected_project
        selected_project=$(echo "$selected_row" | head -n 1 | awk -F',' '{print $1}' | tr -d '[:space:]' | sed 's/\x1b\[[0-9;]*m//g')

        if [ -z "$selected_project" ]; then
            continue
        fi

        [[ "$selected_project" == *"Usage:"* ]] || [ "$selected_project" == "ПРОЕКТ" ] && continue

        show_project_repositories "$selected_project" "$repos"
    done
}

main
