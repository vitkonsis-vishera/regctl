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
log_msg "INFO" "=== regctl started ==="

load_config() {
    mkdir -p "$CONFIG_DIR" "$CACHE_DIR"
    if [ ! -f "$CONFIG_FILE" ]; then
        cat << 'EOF' > "$CONFIG_FILE"
UI_LANG=en
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
    UI_LANG="${UI_LANG:-en}"
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
UI_LANG=$UI_LANG
SHOW_TAG_COUNT=$SHOW_TAG_COUNT
SHOW_UPDATED_DATE=$SHOW_UPDATED_DATE
SHOW_SIZE=$SHOW_SIZE
CATALOG_N=$CATALOG_N
ENABLE_CACHE=$ENABLE_CACHE
CACHE_TTL=$CACHE_TTL
HIDE_TAGLESS_IMAGES=$HIDE_TAGLESS_IMAGES
EOF
    log_msg "INFO" "Config saved: UI_LANG=$UI_LANG, SHOW_TAG_COUNT=$SHOW_TAG_COUNT, SHOW_UPDATED_DATE=$SHOW_UPDATED_DATE, SHOW_SIZE=$SHOW_SIZE, CATALOG_N=$CATALOG_N, ENABLE_CACHE=$ENABLE_CACHE, CACHE_TTL=$CACHE_TTL, HIDE_TAGLESS_IMAGES=$HIDE_TAGLESS_IMAGES"
}

clear_cache() {
    if [ -n "$CACHE_DIR" ] && [ -d "$CACHE_DIR" ]; then
        rm -rf "${CACHE_DIR:?}"/* "${CACHE_DIR:?}"/.* 2>/dev/null
    fi
    mkdir -p "$CACHE_DIR"
    log_msg "INFO" "Cache cleared"
}

declare -A T

load_translations() {
    T=()
    if [ "$UI_LANG" == "ru" ]; then
        # Общие / заголовок
        T[err_prefix]="ОШИБКА:"
        T[connected_to]="Подключено к:"
        T[header_hints]="ESC — Назад  |  Ctrl+C — Ввод команд"
        T[press_enter_return]="Нажмите Enter для возврата..."
        T[press_enter_continue]="Нажмите Enter для продолжения..."
        T[press_enter]="Нажмите Enter..."
        T[yes]="Да"
        T[no]="Нет"
        T[cancel]="Отмена"
        T[back]="⬅️ Назад"
        T[enter_cmd_menu]="⌨️ Ввести команду (:)"

        # Зависимости
        T[dep_installing]="Установка отсутствующих пакетов: %s..."
        T[dep_installing_deb]="Установка %s..."
        T[dep_gum_missing]="Пакет %s не найден рядом со скриптом."

        # Командный режим
        T[cmd_mode_title]="РЕЖИМ КОМАНДНОЙ СТРОКИ"
        T[cmd_mode_avail]="Доступные команды: :upload, :settings, :disconnect, :help, :trash, :find, :q, :quit"
        T[cmd_mode_ph]="введите команду..."
        T[cmd_exiting]="Завершение работы..."
        T[cmd_unknown]="Неизвестная команда: %s"

        # Авторизация / подключение
        T[conn_prompt]="Введите параметры подключения к Docker Registry:"
        T[conn_host_ph]="Хост (например, registry2.oikdev.local:5000)"
        T[conn_user_ph]="Имя пользователя (опционально)"
        T[conn_pass_ph]="Пароль (опционально)"
        T[conn_auth_err]="Ошибка аутентификации или реестра (HTTPS). HTTP статус: %s"
        T[conn_try_http]="Не удалось подключиться по HTTPS. Пробуем HTTP-соединение..."
        T[conn_http_ok]="✓ Подключение по HTTP успешно!"
        T[conn_fail]="Не удалось подключиться к %s ни по HTTPS, ни по HTTP."
        T[conn_retry]="Повторить ввод?"

        # Поиск
        T[find_title]="ПОИСК РЕПОЗИТОРИЕВ И ТЕГОВ"
        T[find_ph]="Введите имя репозитория, образа или тега..."
        T[find_read]="Введите запрос для поиска: "
        T[find_cancelled]="Поиск отменен."
        T[find_query]="Поиск по запросу:"
        T[find_spin]="Поиск репозиториев..."
        T[find_nothing]="Ничего не найдено."
        T[find_results]="Результаты поиска для:"
        T[find_filter_ph]="Начните вводить для доп. фильтрации (Enter для выбора)..."

        # Справка
        T[help_title]="СПРАВКА ПО КОМАНДАМ И НАВИГАЦИИ:"
        T[help_upload]="Загрузить образ из файла (.tar, .tar.gz)"
        T[help_settings]="Настройка параметров (язык, колонки, пагинация n)"
        T[help_find]="Поиск репозиториев по подстроке"
        T[help_disconnect]="Отключиться от текущего Registry"
        T[help_help]="Показать эту справку"
        T[help_trash]="Запуск Garbage Collector для очистки"
        T[help_exit]="Выход из утилиты"
        T[help_tip_esc]="Нажмите ESC для возврата на уровень выше."
        T[help_tip_ctrlc]="Нажмите Ctrl+C в любом меню для открытия командной строки."

        # Настройки
        T[set_title]="НАСТРОЙКА ОТОБРАЖЕНИЯ И ПАРАМЕТРОВ"
        T[set_on]="[ВКЛ]"
        T[set_off]="[ВЫКЛ]"
        T[set_tag_count]="Количество тегов"
        T[set_updated_date]="Дата обновления"
        T[set_size]="Размер образа"
        T[set_show_tagless]="Отображать образы без тегов"
        T[set_api_cache]="Кэширование API"
        T[set_cache_ttl]="Время жизни кэша"
        T[set_unit_d]="д"
        T[set_unit_h]="ч"
        T[set_unit_s]="с"
        T[set_ttl_ph]="например: 12h, 1d, 7d или 86400"
        T[set_ttl_prompt]="Введите TTL (ч/д/с): "
        T[set_limit]="Лимит каталога/тегов"
        T[set_limit_ph]="Лимит записей (например 10000)"
        T[set_limit_prompt]="Параметр n: "
        T[set_language]="Язык / Language"
        T[set_clear_cache]="🧹 Очистить кэш"
        T[set_cache_cleared]="✓ Кэш успешно очищен!"
        T[set_save_return]="💾 Сохранить и вернуться"

        # Создание проекта / Insecure daemon
        T[proj_perm_err]="Нет прав или неверные учётные данные для создания проекта '%s' (HTTP %s)."
        T[proj_create_err]="Не удалось создать проект '%s' (HTTP %s)."
        T[daemon_http_warn]="Обнаружена ошибка подключения по HTTP. Настройка Docker Daemon..."
        T[daemon_json_ok]="✓ Файл %s обновлён для работы по HTTP (%s)"
        T[daemon_json_err]="Не удалось обновить %s"
        T[daemon_restarting]="Перезапуск службы Docker..."
        T[daemon_restart_ok]="✓ Docker успешно перезапущен"
        T[daemon_restart_err]="Не удалось перезапустить Docker Daemon."

        # Выбор архива и загрузка образа
        T[arch_title]="ВЫБОР АРХИВА С ОБРАЗОМ"
        T[arch_cur_dir]="Текущий каталог:"
        T[arch_up]="📁 .. (наверх)"
        T[arch_empty]="Папка пуста или нет доступных архивов."
        T[arch_up_enter]="Нажмите Enter для выхода на уровень вверх..."
        T[arch_header]="Выберите архив или директорию:"
        T[push_done]="Загрузка архивов завершена."
        T[push_selected]="Выбран архив:"
        T[push_spin_load]=" [1/2] Распаковка и импорт архива в локальный Docker Daemon..."
        T[push_load_err]="Не удалось выполнить 'docker load' для файла."
        T[push_no_img_name]="Не удалось определить имя загруженного образа из архива."
        T[push_imported]="✓ Образ импортирован:"
        T[push_spin_proj]=" Загрузка списка проектов..."
        T[push_new_proj]="➕ Создать новый проект"
        T[push_choose_proj]="Выберите проект"
        T[push_new_proj_ph]="Имя нового проекта (строчные буквы, цифры, . _ -)"
        T[push_new_proj_prompt]="Проект: "
        T[push_proj_empty]="Имя проекта не может быть пустым."
        T[push_proj_invalid]="Недопустимое имя проекта '%s' (допустимы только строчные латинские буквы, цифры, '.', '_' и '-')."
        T[push_vis_private]="Приватный"
        T[push_vis_public]="Публичный"
        T[push_vis_header]="Видимость проекта '%s':"
        T[push_spin_create_proj]=" Создание проекта '%s'..."
        T[push_proj_ready]="✓ Проект '%s' готов в Registry."
        T[push_proj_std_reg]="ℹ Обычный Registry: namespace '%s' создастся при push."
        T[push_repo_ph]="Образ"
        T[push_repo_prompt]="Образ: "
        T[push_repo_empty]="Имя образа не может быть пустым."
        T[push_tag_ph]="Тег"
        T[push_tag_prompt]="Тег: "
        T[push_target_img]="  Целевой образ:"
        T[push_confirm]="Отправить образ в Registry?"
        T[push_login_err]="Ошибка 'docker login':"
        T[push_spin_push]=" [2/2] Публикация %s в Registry..."
        T[push_http_err]="Не удалось выполнить push из-за HTTP соединения."
        T[push_http_retry]="Повторная попытка с автоматической настройкой Daemon..."
        T[push_spin_retry]=" [2/2] Повторная публикация %s в Registry..."
        T[push_proj_not_found]="Проект '%s' не найден в Registry."
        T[push_proj_create_retry]="Создать проект '%s' в Registry и повторить push?"
        T[push_proj_created_retry]="✓ Проект '%s' создан. Повторяем push..."
        T[push_err]="Не удалось выполнить 'docker push':"
        T[push_ok]="✓ Успешно загружено!"
        T[push_another]="Загрузить ещё один архив?"

        # GC / SSH
        T[ssh_login_ph]="Логин SSH сервера Registry"
        T[ssh_pass_ph]="Пароль SSH (оставьте пустым для SSH-ключа)"
        T[ssh_no_sshpass]="ℹ Утилита sshpass не установлена, будет использован обычный ssh-ввод пароля."
        T[ssh_container_ph]="Имя контейнера registry"
        T[ssh_container_prompt]="Контейнер: "
        T[ssh_gc_run]="Запуск registry garbage-collect (%s)..."
        T[ssh_gc_ok]="✓ Garbage collector завершён успешно."
        T[ssh_gc_err]="✗ Не удалось выполнить Garbage Collector на сервере."
        T[ssh_rm_dir]="Удаление пустого каталога '%s' с диска и перезапуск контейнера..."
        T[ssh_rm_ok]="✓ Каталог %s удалён, контейнер перезапущен."
        T[ssh_rm_notfound]="ℹ Каталог %s не найден (возможно, уже удалён), контейнер перезапущен."
        T[ssh_rm_err]="✗ Ошибка при удалении каталога или перезапуске контейнера."
        T[ssh_running_ok]="✓ Контейнер %s работает (Status: running)."
        T[ssh_running_err]="✗ Контейнер %s не перешёл в состояние running!"

        T[gc_title]="[GC] Запуск Garbage Collector"
        T[gc_harbor_real]="🚀 Запустить реальную очистку (delete_untagged=true)"
        T[gc_harbor_dry]="🔍 Пробный запуск (dry-run)"
        T[gc_reg_real]="🚀 Запустить реальную очистку (--delete-untagged)"
        T[gc_reg_dry]="🔍 Пробный запуск (--dry-run)"
        T[gc_cancel]="⬅️ Отмена"
        T[gc_harbor_ok]="✓ Задача Garbage Collection поставлена в очередь Harbor (HTTP %s)."
        T[gc_harbor_err]="Не удалось запустить GC в Harbor (HTTP %s). Возможно, требуются права администратора Harbor."

        # Теги и артефакты
        T[tagless_std_info]="В обычном Docker Registry безымянные артефакты удаляются через Garbage Collector (:trash)."
        T[tagless_title]="Untagged-артефакты образа:"
        T[tagless_none]="✓ Untagged-артефактов больше нет."
        T[tagless_del_all]="🗑️ Удалить ВСЕ untagged-артефакты"
        T[tagless_choose]="Выберите digest для удаления:"
        T[tagless_confirm_all]="Удалить все untagged-артефакты из %s?"
        T[tagless_deleted]="✓ Удалён %s"
        T[tagless_del_err]="✗ Ошибка удаления %s (HTTP %s)"
        T[tagless_confirm_one]="Удалить артефакт %s?"
        T[tagless_one_ok]="✓ Артефакт удалён"
        T[tagless_one_err]="✗ Ошибка удаления (HTTP %s)"

        T[lbl_image]="Образ:"
        T[tags_empty]="У образа нет тегов."
        T[tags_header]="ТЕГИ И АРТЕФАКТЫ"
        T[hist_spin]=" Анализ манифеста и получение истории слоев..."
        T[hist_err_manifest]="[HTTP %s] Не удалось загрузить манифест тега"
        T[hist_err_config]="[CONFIG_NOT_FOUND] config.digest отсутствует"
        T[hist_err_empty]="[EMPTY_HISTORY] История пуста"
        T[hist_title]="Предполагаемый Dockerfile (история слоев):"
        T[hist_extract_err]="✗ Ошибка извлечения истории:"
        T[digest_spin]=" Получение Digest..."
        T[digest_not_found]="⚠ Digest не найден"

        T[del_tag_multi]="На этот же образ (%s) ссылаются и другие теги (всего: %s)."
        T[del_tag_only_btn]="Удалить только тег"
        T[del_tag_only_confirm]="Удалить только тег '%s' (остальные теги сохранятся)?"
        T[del_tag_only_ok]="✓ Тег %s удалён (артефакт и остальные теги сохранены)."
        T[del_tag_err]="✗ Ошибка удаления тега (HTTP %s)"
        T[del_btn_yes]="Да, удалить"
        T[del_tag_art_confirm]="Удалить тег и артефакт %s:%s?"
        T[del_tag_art_ok]="✓ Тег и артефакт %s:%s успешно удалены."
        T[del_tag_std_note]="Примечание: в обычном Docker Registry удаление манифеста удалит все теги с тем же Digest."
        T[del_tag_std_confirm]="Удалить манифест тега %s:%s?"
        T[del_tag_no_digest]="✗ Не удалось получить Digest для %s:%s"
        T[del_tag_std_ok]="✓ Манифест тега %s успешно удален (Digest: %s...)"
        T[del_http_405]="✗ Удаление отключено на сервере Registry (HTTP 405)."
        T[del_http_405_hint]="Включите REGISTRY_STORAGE_DELETE_ENABLED=true (storage.delete.enabled: true) в конфиге registry."

        T[tag_selected]="Выбран тег:"
        T[tag_act_pull]="📋 Команда docker pull"
        T[tag_act_digest]="🔍 Посмотреть Digest"
        T[tag_act_history]="📜 Посмотреть History (Dockerfile)"
        T[tag_act_delete]="🗑️ Удалить этот тег"
        T[tag_act_back]="⬅️ Назад к тегам"
        T[pull_cmd_title]="Команда для скачивания:"
        T[pull_copied]="(Скопировано в буфер обмена via %s)"

        # Репозитории и проекты
        T[repo_selected]="Выбран образ:"
        T[repo_act_tags]="📋 Выбрать конкретный тег"
        T[repo_act_delete]="🗑️ Удалить образ полностью"
        T[repo_v2_spin]=" Получение списка тегов для %s..."
        T[repo_v2_no_tags]="У образа %s нет активных тегов."
        T[repo_v2_no_digest]="⚠ Не удалось получить Digest для тега %s"
        T[repo_v2_del_ok]="✓ Удалён манифест %s..."
        T[repo_v2_del_err]="✗ Ошибка удаления %s... (HTTP %s)"
        T[repo_v2_summary]="Манифесты: удалено %s, ошибок %s"
        T[repo_del_title]="УДАЛЕНИЕ ОБРАЗА: %s"
        T[repo_del_confirm]="Вы уверены, что хотите полностью удалить репозиторий %s?"
        T[repo_del_harbor_spin]=" Удаление репозитория %s в Harbor..."
        T[repo_del_harbor_ok]="✓ Репозиторий %s полностью удалён из Harbor."
        T[repo_del_harbor_err]="Не удалось удалить репозиторий %s в Harbor (HTTP %s)."
        T[repo_del_ssh_confirm]="Выполнить Garbage Collect и удалить каталог репозитория с диска по SSH?"

        T[proj_del_title]="УДАЛЕНИЕ ПРОЕКТА: %s"
        T[proj_del_btn]="Да, удалить проект"
        T[proj_del_confirm]="Удалить проект '%s' и все его образы?"
        T[proj_del_repos_msg]="Удаление репозиториев проекта '%s'..."
        T[proj_del_repo_ok]="✓ Удалён образ %s"
        T[proj_del_repo_err]="✗ Ошибка удаления %s (HTTP %s)"
        T[proj_del_harbor_ok]="✓ Проект '%s' полностью удалён из Harbor."
        T[proj_del_harbor_err]="Не удалось удалить проект '%s' в Harbor (HTTP %s)."
        T[proj_del_proc_repo]="Обработка %s..."
        T[proj_del_ssh_confirm]="Выполнить Garbage Collect и удалить каталог проекта '%s' с диска по SSH?"

        T[proj_selected]="Выбран проект:"
        T[proj_act_open]="📂 Открыть образы проекта"
        T[proj_act_upload]="📤 Загрузить образ в проект"
        T[proj_act_delete]="🗑️ Удалить проект полностью"
        T[proj_act_back]="⬅️ Назад к проектам"

        T[lbl_project]="Проект:"
        T[proj_no_images]="В этом проекте пока нет образов."
        T[proj_upload_confirm]="Загрузить образ в проект '%s'?"
        T[meta_spin]=" Загрузка метаданных..."

        T[col_project]="ПРОЕКТ"
        T[col_images]="ОБРАЗОВ"
        T[col_image]="ОБРАЗ"
        T[col_tags]="ТЕГОВ"
        T[col_updated]="ОБНОВЛЕН"
        T[col_size]="РАЗМЕР"

        T[main_spin_projects]=" Загрузка списка проектов..."
        T[main_empty_reg]="Реестр пуст или эндпоинт /_catalog недоступен."
        T[main_empty_hint]="Используйте :upload или :push для загрузки первого образа."
        T[main_empty_yes]="Да, загрузить"
        T[main_empty_no]="Нет, отключиться"
        T[main_empty_confirm]="Готовы загрузить первый образ в этот registry?"
    else
        # Common / header
        T[err_prefix]="ERROR:"
        T[connected_to]="Connected to:"
        T[header_hints]="ESC — Back  |  Ctrl+C — Command Mode"
        T[press_enter_return]="Press Enter to return..."
        T[press_enter_continue]="Press Enter to continue..."
        T[press_enter]="Press Enter..."
        T[yes]="Yes"
        T[no]="No"
        T[cancel]="Cancel"
        T[back]="⬅️ Back"
        T[enter_cmd_menu]="⌨️ Enter command (:)"

        # Dependencies
        T[dep_installing]="Installing missing packages: %s..."
        T[dep_installing_deb]="Installing %s..."
        T[dep_gum_missing]="Package %s was not found next to the script."

        # Command mode
        T[cmd_mode_title]="COMMAND MODE"
        T[cmd_mode_avail]="Available commands: :upload, :settings, :disconnect, :help, :trash, :find, :q, :quit"
        T[cmd_mode_ph]="enter command..."
        T[cmd_exiting]="Exiting..."
        T[cmd_unknown]="Unknown command: %s"

        # Auth / connection
        T[conn_prompt]="Enter Docker Registry connection parameters:"
        T[conn_host_ph]="Host (e.g. registry2.oikdev.local:5000)"
        T[conn_user_ph]="Username (optional)"
        T[conn_pass_ph]="Password (optional)"
        T[conn_auth_err]="Authentication or registry error (HTTPS). HTTP status: %s"
        T[conn_try_http]="HTTPS connection failed. Trying HTTP..."
        T[conn_http_ok]="✓ HTTP connection successful!"
        T[conn_fail]="Failed to connect to %s via HTTPS or HTTP."
        T[conn_retry]="Retry?"

        # Search
        T[find_title]="SEARCH REPOSITORIES AND TAGS"
        T[find_ph]="Enter repository, image, or tag name..."
        T[find_read]="Enter search query: "
        T[find_cancelled]="Search cancelled."
        T[find_query]="Search query:"
        T[find_spin]="Searching repositories..."
        T[find_nothing]="Nothing found."
        T[find_results]="Search results for:"
        T[find_filter_ph]="Type to filter results (Enter to select)..."

        # Help
        T[help_title]="COMMANDS AND NAVIGATION HELP:"
        T[help_upload]="Upload an image from archive (.tar, .tar.gz)"
        T[help_settings]="Settings (language, columns, pagination limit n)"
        T[help_find]="Search repositories by substring"
        T[help_disconnect]="Disconnect from current Registry"
        T[help_help]="Show this help"
        T[help_trash]="Run Garbage Collector cleanup"
        T[help_exit]="Exit utility"
        T[help_tip_esc]="Press ESC to go up one level."
        T[help_tip_ctrlc]="Press Ctrl+C in any menu to open Command Mode."

        # Settings
        T[set_title]="DISPLAY AND SETTINGS CONFIGURATION"
        T[set_on]="[ON]"
        T[set_off]="[OFF]"
        T[set_tag_count]="Tag count"
        T[set_updated_date]="Updated date"
        T[set_size]="Image size"
        T[set_show_tagless]="Show tagless images"
        T[set_api_cache]="API caching"
        T[set_cache_ttl]="Cache TTL"
        T[set_unit_d]="d"
        T[set_unit_h]="h"
        T[set_unit_s]="s"
        T[set_ttl_ph]="e.g. 12h, 1d, 7d or 86400"
        T[set_ttl_prompt]="Enter TTL (h/d/s): "
        T[set_limit]="Catalog/tags limit"
        T[set_limit_ph]="Record limit (e.g. 10000)"
        T[set_limit_prompt]="Parameter n: "
        T[set_language]="Language / Язык"
        T[set_clear_cache]="🧹 Clear cache"
        T[set_cache_cleared]="✓ Cache cleared!"
        T[set_save_return]="💾 Save and return"

        # Project creation / Insecure daemon
        T[proj_perm_err]="Insufficient permissions or invalid credentials to create project '%s' (HTTP %s)."
        T[proj_create_err]="Failed to create project '%s' (HTTP %s)."
        T[daemon_http_warn]="HTTP connection error detected. Configuring Docker Daemon..."
        T[daemon_json_ok]="✓ Updated %s for HTTP registry (%s)"
        T[daemon_json_err]="Failed to update %s"
        T[daemon_restarting]="Restarting Docker service..."
        T[daemon_restart_ok]="✓ Docker restarted successfully"
        T[daemon_restart_err]="Failed to restart Docker Daemon."

        # Archive selection & image push
        T[arch_title]="SELECT IMAGE ARCHIVE"
        T[arch_cur_dir]="Current directory:"
        T[arch_up]="📁 .. (up)"
        T[arch_empty]="Directory is empty or no archives found."
        T[arch_up_enter]="Press Enter to go up one level..."
        T[arch_header]="Select an archive or directory:"
        T[push_done]="Archive upload finished."
        T[push_selected]="Selected archive:"
        T[push_spin_load]=" [1/2] Extracting and importing archive into local Docker Daemon..."
        T[push_load_err]="Failed to run 'docker load' for file."
        T[push_no_img_name]="Could not determine loaded image name from archive."
        T[push_imported]="✓ Image imported:"
        T[push_spin_proj]=" Loading projects..."
        T[push_new_proj]="➕ Create new project"
        T[push_choose_proj]="Select project"
        T[push_new_proj_ph]="New project name (lowercase, digits, . _ -)"
        T[push_new_proj_prompt]="Project: "
        T[push_proj_empty]="Project name cannot be empty."
        T[push_proj_invalid]="Invalid project name '%s' (allowed: lowercase letters, digits, '.', '_' and '-')."
        T[push_vis_private]="Private"
        T[push_vis_public]="Public"
        T[push_vis_header]="Visibility for project '%s':"
        T[push_spin_create_proj]=" Creating project '%s'..."
        T[push_proj_ready]="✓ Project '%s' is ready in Registry."
        T[push_proj_std_reg]="ℹ Standard Registry: namespace '%s' will be created on push."
        T[push_repo_ph]="Image"
        T[push_repo_prompt]="Image: "
        T[push_repo_empty]="Image name cannot be empty."
        T[push_tag_ph]="Tag"
        T[push_tag_prompt]="Tag: "
        T[push_target_img]="  Target image:"
        T[push_confirm]="Push image to Registry?"
        T[push_login_err]="'docker login' error:"
        T[push_spin_push]=" [2/2] Pushing %s to Registry..."
        T[push_http_err]="Push failed due to HTTP connection."
        T[push_http_retry]="Retrying with automatic Daemon configuration..."
        T[push_spin_retry]=" [2/2] Retrying push of %s to Registry..."
        T[push_proj_not_found]="Project '%s' not found in Registry."
        T[push_proj_create_retry]="Create project '%s' in Registry and retry push?"
        T[push_proj_created_retry]="✓ Project '%s' created. Retrying push..."
        T[push_err]="Failed to run 'docker push':"
        T[push_ok]="✓ Successfully pushed!"
        T[push_another]="Upload another archive?"

        # GC / SSH
        T[ssh_login_ph]="Registry server SSH username"
        T[ssh_pass_ph]="SSH password (leave empty for SSH key)"
        T[ssh_no_sshpass]="ℹ sshpass is not installed; standard ssh password prompt will be used."
        T[ssh_container_ph]="Registry container name"
        T[ssh_container_prompt]="Container: "
        T[ssh_gc_run]="Running registry garbage-collect (%s)..."
        T[ssh_gc_ok]="✓ Garbage collector finished successfully."
        T[ssh_gc_err]="✗ Failed to run Garbage Collector on server."
        T[ssh_rm_dir]="Removing empty directory '%s' from disk and restarting container..."
        T[ssh_rm_ok]="✓ Directory %s removed, container restarted."
        T[ssh_rm_notfound]="ℹ Directory %s not found (already removed?), container restarted."
        T[ssh_rm_err]="✗ Failed to remove directory or restart container."
        T[ssh_running_ok]="✓ Container %s is running (Status: running)."
        T[ssh_running_err]="✗ Container %s failed to reach running state!"

        T[gc_title]="[GC] Run Garbage Collector"
        T[gc_harbor_real]="🚀 Run cleanup (delete_untagged=true)"
        T[gc_harbor_dry]="🔍 Dry run (dry-run)"
        T[gc_reg_real]="🚀 Run cleanup (--delete-untagged)"
        T[gc_reg_dry]="🔍 Dry run (--dry-run)"
        T[gc_cancel]="⬅️ Cancel"
        T[gc_harbor_ok]="✓ Garbage Collection job queued in Harbor (HTTP %s)."
        T[gc_harbor_err]="Failed to trigger GC in Harbor (HTTP %s). Harbor admin privileges may be required."

        # Tags & artifacts
        T[tagless_std_info]="In a standard Docker Registry, untagged blobs are cleaned via Garbage Collector (:trash)."
        T[tagless_title]="Untagged artifacts for:"
        T[tagless_none]="✓ No untagged artifacts remaining."
        T[tagless_del_all]="🗑️ Delete ALL untagged artifacts"
        T[tagless_choose]="Select digest to delete:"
        T[tagless_confirm_all]="Delete all untagged artifacts from %s?"
        T[tagless_deleted]="✓ Deleted %s"
        T[tagless_del_err]="✗ Error deleting %s (HTTP %s)"
        T[tagless_confirm_one]="Delete artifact %s?"
        T[tagless_one_ok]="✓ Artifact deleted"
        T[tagless_one_err]="✗ Delete error (HTTP %s)"

        T[lbl_image]="Image:"
        T[tags_empty]="No tags found for this image."
        T[tags_header]="TAGS AND ARTIFACTS"
        T[hist_spin]=" Analyzing manifest and fetching layer history..."
        T[hist_err_manifest]="[HTTP %s] Failed to load tag manifest"
        T[hist_err_config]="[CONFIG_NOT_FOUND] config.digest is missing"
        T[hist_err_empty]="[EMPTY_HISTORY] History is empty"
        T[hist_title]="Inferred Dockerfile (layer history):"
        T[hist_extract_err]="✗ Failed to extract history:"
        T[digest_spin]=" Fetching Digest..."
        T[digest_not_found]="⚠ Digest not found"

        T[del_tag_multi]="Other tags also reference this image (%s) (total: %s)."
        T[del_tag_only_btn]="Delete tag only"
        T[del_tag_only_confirm]="Delete only tag '%s' (other tags will remain)?"
        T[del_tag_only_ok]="✓ Tag %s deleted (artifact and other tags preserved)."
        T[del_tag_err]="✗ Error deleting tag (HTTP %s)"
        T[del_btn_yes]="Yes, delete"
        T[del_tag_art_confirm]="Delete tag and artifact %s:%s?"
        T[del_tag_art_ok]="✓ Tag and artifact %s:%s deleted successfully."
        T[del_tag_std_note]="Note: in a standard Docker Registry, deleting a manifest removes all tags sharing the same Digest."
        T[del_tag_std_confirm]="Delete manifest for tag %s:%s?"
        T[del_tag_no_digest]="✗ Could not resolve Digest for %s:%s"
        T[del_tag_std_ok]="✓ Manifest for tag %s deleted (Digest: %s...)"
        T[del_http_405]="✗ Deletion is disabled on the Registry server (HTTP 405)."
        T[del_http_405_hint]="Enable REGISTRY_STORAGE_DELETE_ENABLED=true (storage.delete.enabled: true) in registry config."

        T[tag_selected]="Selected tag:"
        T[tag_act_pull]="📋 Copy/show docker pull command"
        T[tag_act_digest]="🔍 View Digest"
        T[tag_act_history]="📜 View History (Dockerfile)"
        T[tag_act_delete]="🗑️ Delete this tag"
        T[tag_act_back]="⬅️ Back to tags"
        T[pull_cmd_title]="Pull command:"
        T[pull_copied]="(Copied to clipboard via %s)"

        # Repositories & projects
        T[repo_selected]="Selected image:"
        T[repo_act_tags]="📋 Select a specific tag"
        T[repo_act_delete]="🗑️ Delete entire image"
        T[repo_v2_spin]=" Fetching tag list for %s..."
        T[repo_v2_no_tags]="Image %s has no active tags."
        T[repo_v2_no_digest]="⚠ Could not resolve Digest for tag %s"
        T[repo_v2_del_ok]="✓ Deleted manifest %s..."
        T[repo_v2_del_err]="✗ Error deleting %s... (HTTP %s)"
        T[repo_v2_summary]="Manifests: deleted %s, errors %s"
        T[repo_del_title]="DELETE IMAGE: %s"
        T[repo_del_confirm]="Are you sure you want to completely delete repository %s?"
        T[repo_del_harbor_spin]=" Deleting repository %s in Harbor..."
        T[repo_del_harbor_ok]="✓ Repository %s deleted from Harbor."
        T[repo_del_harbor_err]="Failed to delete repository %s in Harbor (HTTP %s)."
        T[repo_del_ssh_confirm]="Run Garbage Collect and delete repository directory from disk via SSH?"

        T[proj_del_title]="DELETE PROJECT: %s"
        T[proj_del_btn]="Yes, delete project"
        T[proj_del_confirm]="Delete project '%s' and all its images?"
        T[proj_del_repos_msg]="Deleting repositories in project '%s'..."
        T[proj_del_repo_ok]="✓ Deleted image %s"
        T[proj_del_repo_err]="✗ Failed to delete %s (HTTP %s)"
        T[proj_del_harbor_ok]="✓ Project '%s' deleted from Harbor."
        T[proj_del_harbor_err]="Failed to delete project '%s' in Harbor (HTTP %s)."
        T[proj_del_proc_repo]="Processing %s..."
        T[proj_del_ssh_confirm]="Run Garbage Collect and delete project directory '%s' from disk via SSH?"

        T[proj_selected]="Selected project:"
        T[proj_act_open]="📂 Open project images"
        T[proj_act_upload]="📤 Upload image to project"
        T[proj_act_delete]="🗑️ Delete entire project"
        T[proj_act_back]="⬅️ Back to projects"

        T[lbl_project]="Project:"
        T[proj_no_images]="There are no images in this project yet."
        T[proj_upload_confirm]="Upload an image to project '%s'?"
        T[meta_spin]=" Loading metadata..."

        T[col_project]="PROJECT"
        T[col_images]="IMAGES"
        T[col_image]="IMAGE"
        T[col_tags]="TAGS"
        T[col_updated]="UPDATED"
        T[col_size]="SIZE"

        T[main_spin_projects]=" Loading projects..."
        T[main_empty_reg]="Registry is empty or /_catalog endpoint is unavailable."
        T[main_empty_hint]="Use :upload or :push to upload the first image."
        T[main_empty_yes]="Yes, upload"
        T[main_empty_no]="No, disconnect"
        T[main_empty_confirm]="Ready to upload the first image to this registry?"
    fi
}

t() {
    local key="$1"
    shift || true
    local fmt="${T[$key]:-$key}"
    if [ $# -gt 0 ]; then
        printf "$fmt" "$@"
    else
        printf "%s" "$fmt"
    fi
}

load_config
load_translations

REQUIRED_DEPENDENCIES=("curl" "jq" "gum" "docker")

install_missing_dependencies() {
    local missing=()
    for cmd in "${REQUIRED_DEPENDENCIES[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        t "dep_installing" "${missing[*]}"; echo
        log_msg "INFO" "Installing missing dependencies: ${missing[*]}"
        sudo apt-get update -y
        for pkg in "${missing[@]}"; do
            if [ "$pkg" == "gum" ]; then
                local local_deb
                local_deb=$(find "$SCRIPT_DIR" -maxdepth 1 -name "*gum*.deb" | head -n 1)

                if [ -n "$local_deb" ] && [ -f "$local_deb" ]; then
                    t "dep_installing_deb" "$local_deb"; echo
                    sudo dpkg -i "$local_deb" || sudo apt-get install -f -y
                else
                    t "dep_gum_missing" "$pkg"; echo
                    log_msg "ERROR" "Package gum not found next to script"
                    exit 1
                fi
            else
                sudo apt-get install -y "$pkg"
            fi
        done
    fi
}

install_missing_dependencies

ERROR_STYLE=""
update_ui_styles() {
    ERROR_STYLE=$(gum style --foreground 196 --bold "$(t 'err_prefix')")
}
update_ui_styles

CONNECTED_URL=""
REGISTRY_URL=""
USERNAME=""
PASSWORD=""
REGISTRY_TYPE="docker-registry"
HARBOR_API_URL=""

prompt_command_mode() {
    clear
    print_header
    echo "$(gum style --foreground 214 --bold "$(t 'cmd_mode_title')")"
    echo "$(gum style --foreground 240 "$(t 'cmd_mode_avail')")"
    echo

    local input_cmd
    input_cmd=$(gum input --value=":" --placeholder="$(t 'cmd_mode_ph')" < /dev/tty)
    local res=$?

    if [ $res -eq 130 ] || [ -z "$input_cmd" ] || [ "$input_cmd" == ":" ]; then
        return 0
    fi

    process_command "$input_cmd"
    return $?
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
        local type_badge="Registry"
        [ "$REGISTRY_TYPE" == "harbor" ] && type_badge="Harbor"
        subtitle="$(gum style --foreground 245 "$(t 'connected_to')") $(gum style --foreground 82 --bold "$CONNECTED_URL") $(gum style --foreground 240 "[$type_badge]")"
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
    subtext=$(gum style --foreground 240 --align center "$(t 'header_hints')")
    echo "$subtext"
    echo
}

configure_registry() {
    clear
    print_header
    echo "$(gum style --foreground 240 "$(t 'conn_prompt')")"
    echo

    REGISTRY_URL=$(gum input --placeholder "$(t 'conn_host_ph')" --value "$REGISTRY_URL" < /dev/tty)
    [ $? -eq 130 ] && return 0

    if [[ "$REGISTRY_URL" == :* ]]; then
        process_command "$REGISTRY_URL"
        return 0
    fi

    USERNAME=$(gum input --placeholder "$(t 'conn_user_ph')" --value "$USERNAME" < /dev/tty)
    [ $? -eq 130 ] && return 0

    PASSWORD=$(gum input --password --placeholder "$(t 'conn_pass_ph')" --value "$PASSWORD" < /dev/tty)
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
    echo "[$timestamp] [$status] endpoint='$endpoint' | $details" >> "$LOG_FILE" 2>/dev/null
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
            log_cache "MISS" "$endpoint" "Cache file missing | file=$cache_key.json"
        fi

        local res
        res=$(curl "${curl_opts[@]}" "${REGISTRY_URL}${endpoint}")
        if [ $? -eq 0 ] && [ -n "$res" ]; then
            echo "$res" > "$cache_file"
            log_cache "WRITE" "$endpoint" "Cached | file=$cache_key.json"
        else
            log_cache "ERROR" "$endpoint" "curl failed or empty response"
        fi
        echo "$res"
    else
        log_cache "BYPASS" "$endpoint" "ENABLE_CACHE=$ENABLE_CACHE, custom_method=$is_custom_method"
        curl "${curl_opts[@]}" "${REGISTRY_URL}${endpoint}"
    fi
}

api_request_paged() {
    local initial_endpoint="$1"
    local json_key="$2"

    local current_endpoint="$initial_endpoint"
    local all_items="[]"

    while [ -n "$current_endpoint" ]; do
        local body
        body=$(api_request "$current_endpoint" -i)

        local headers
        headers=$(echo "$body" | sed -n '1,/^\r\{0,1\}$/p')
        local json_body
        json_body=$(echo "$body" | sed '1,/^\r\{0,1\}$/d')

        if [ -z "$json_body" ]; then
            json_body=$(api_request "$current_endpoint")
        fi

        local page_items
        page_items=$(echo "$json_body" | jq -r ".${json_key} // []" 2>/dev/null)

        if [ -n "$page_items" ] && [ "$page_items" != "null" ]; then
            all_items=$(jq -s '.[0] + .[1]' <(echo "$all_items") <(echo "$page_items"))
        fi

        local next_link
        next_link=$(echo "$headers" | grep -i '^link:' | grep 'rel="next"' | sed -E 's/.*<([^>]+)>.*/\1/' | sed -E 's|^https?://[^/]+||')

        if [ -n "$next_link" ]; then
            current_endpoint="$next_link"
        else
            current_endpoint=""
        fi
    done

    jq -n --argjson items "$all_items" --arg key "$json_key" '{($key): $items}'
}

detect_registry_type() {
    REGISTRY_TYPE="docker-registry"
    HARBOR_API_URL=""

    local reg_host host_no_port
    reg_host=$(echo "$REGISTRY_URL" | sed -E 's|^https?://||; s|/.*||')
    host_no_port="${reg_host%%:*}"

    local candidate_urls=("$REGISTRY_URL")
    if [ "$reg_host" != "$host_no_port" ]; then
        candidate_urls+=("https://${host_no_port}" "http://${host_no_port}")
    fi

    local base_url code body
    for base_url in "${candidate_urls[@]}"; do
        local tmp_body
        tmp_body=$(mktemp)
        local curl_opts=(-s -k -o "$tmp_body" -w "%{http_code}")
        if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
            curl_opts+=(-u "$USERNAME:$PASSWORD")
        fi
        code=$(curl "${curl_opts[@]}" "${base_url}/api/v2.0/ping" 2>/dev/null || echo "000")
        body=$(cat "$tmp_body" 2>/dev/null)
        rm -f "$tmp_body"

        if [ "$code" == "200" ] && echo "$body" | grep -qi "pong"; then
            REGISTRY_TYPE="harbor"
            HARBOR_API_URL="$base_url"
            log_msg "INFO" "Detected registry type: Harbor ($HARBOR_API_URL)"
            return 0
        fi
    done

    log_msg "INFO" "Detected registry type: standard Docker Registry"
}

harbor_encode_repo() {
    local repo_name="$1"
    local mode="${2:-double}"
    if [ "$mode" == "single" ]; then
        echo "$repo_name" | sed 's|/|%2F|g'
    else
        echo "$repo_name" | sed 's|/|%252F|g'
    fi
}

harbor_call() {
    local method="$1"
    local path="$2"
    local data="${3:-}"
    local out_file="$4"

    local base_url="${HARBOR_API_URL:-$REGISTRY_URL}"
    local curl_opts=(-s -S -k -o "$out_file" -w "%{http_code}" -X "$method")
    if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
        curl_opts+=(-u "$USERNAME:$PASSWORD")
    fi
    if [ -n "$data" ]; then
        curl_opts+=(-H "Content-Type: application/json" -d "$data")
    fi

    curl "${curl_opts[@]}" "${base_url}${path}" 2>/dev/null || echo "000"
}

harbor_repo_call() {
    local method="$1"
    local full_repo="$2"
    local suffix="$3"
    local data="${4:-}"
    local out_file="$5"

    local proj="${full_repo%%/*}"
    local repo_name="${full_repo#*/}"
    local enc_repo
    enc_repo=$(harbor_encode_repo "$repo_name" "double")

    local code
    code=$(harbor_call "$method" "/api/v2.0/projects/${proj}/repositories/${enc_repo}${suffix}" "$data" "$out_file")
    if [ "$code" == "404" ] && [[ "$repo_name" == *"/"* ]]; then
        enc_repo=$(harbor_encode_repo "$repo_name" "single")
        code=$(harbor_call "$method" "/api/v2.0/projects/${proj}/repositories/${enc_repo}${suffix}" "$data" "$out_file")
    fi
    echo "$code"
}

fetch_v2_bearer_token() {
    local www_auth="$1"
    local realm service scope
    realm=$(echo "$www_auth" | sed -nE 's/.*realm="([^"]+)".*/\1/p')
    service=$(echo "$www_auth" | sed -nE 's/.*service="([^"]+)".*/\1/p')
    scope=$(echo "$www_auth" | sed -nE 's/.*scope="([^"]+)".*/\1/p')

    [ -z "$realm" ] && return 1

    local token_url="$realm"
    local sep="?"
    [[ "$token_url" == *"?"* ]] && sep="&"
    [ -n "$service" ] && { token_url="${token_url}${sep}service=${service}"; sep="&"; }
    [ -n "$scope" ] && { token_url="${token_url}${sep}scope=${scope}"; }

    local tok_opts=(-s -k)
    if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
        tok_opts+=(-u "$USERNAME:$PASSWORD")
    fi
    curl "${tok_opts[@]}" "$token_url" 2>/dev/null | jq -r '.token // .access_token // empty' 2>/dev/null
}

v2_get_manifest_digest() {
    local repo="$1"
    local tag="$2"

    local tmp_hdr
    tmp_hdr=$(mktemp)

    local curl_opts=(-s -k -I -D "$tmp_hdr"
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json"
        -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json"
        -H "Accept: application/vnd.oci.image.index.v1+json"
        -H "Accept: application/vnd.oci.image.manifest.v1+json")
    if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
        curl_opts+=(-u "$USERNAME:$PASSWORD")
    fi

    curl "${curl_opts[@]}" "${REGISTRY_URL}/v2/${repo}/manifests/${tag}" >/dev/null 2>&1
    local http_code
    http_code=$(grep -iE '^HTTP/' "$tmp_hdr" | tail -n 1 | awk '{print $2}')

    if [ "$http_code" == "401" ]; then
        local www_auth token
        www_auth=$(grep -i '^www-authenticate:' "$tmp_hdr" | tr -d '\r')
        token=$(fetch_v2_bearer_token "$www_auth")
        if [ -n "$token" ]; then
            curl -s -k -I -D "$tmp_hdr" \
                -H "Authorization: Bearer $token" \
                -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
                -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
                -H "Accept: application/vnd.oci.image.index.v1+json" \
                -H "Accept: application/vnd.oci.image.manifest.v1+json" \
                "${REGISTRY_URL}/v2/${repo}/manifests/${tag}" >/dev/null 2>&1
        fi
    fi

    local digest
    digest=$(grep -i '^Docker-Content-Digest:' "$tmp_hdr" | tail -n 1 | awk '{print $2}' | tr -d '\r')
    rm -f "$tmp_hdr"
    echo "$digest"
}

v2_delete_manifest() {
    local repo="$1"
    local digest="$2"

    local tmp_hdr
    tmp_hdr=$(mktemp)

    local curl_opts=(-s -k -o /dev/null -D "$tmp_hdr" -w "%{http_code}" -X DELETE)
    if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
        curl_opts+=(-u "$USERNAME:$PASSWORD")
    fi

    local status_code
    status_code=$(curl "${curl_opts[@]}" "${REGISTRY_URL}/v2/${repo}/manifests/${digest}" 2>/dev/null || echo "000")

    if [ "$status_code" == "401" ]; then
        local www_auth token
        www_auth=$(grep -i '^www-authenticate:' "$tmp_hdr" | tr -d '\r')
        token=$(fetch_v2_bearer_token "$www_auth")
        if [ -n "$token" ]; then
            status_code=$(curl -s -k -o /dev/null -w "%{http_code}" -X DELETE \
                -H "Authorization: Bearer $token" \
                "${REGISTRY_URL}/v2/${repo}/manifests/${digest}" 2>/dev/null || echo "000")
        fi
    fi

    rm -f "$tmp_hdr"
    echo "$status_code"
}

cmd_find() {
    local query="$1"

    if [ -z "$query" ]; then
        clear
        print_header
        echo "$(gum style --foreground 212 --bold "$(t 'find_title')")"
        echo ""
        if command -v gum &>/dev/null; then
            query=$(gum input --placeholder "$(t 'find_ph')" < /dev/tty)
        else
            read -rp "$(t 'find_read')" query
        fi
    fi

    [ -z "$query" ] && t "find_cancelled" && echo && return 0

    clear
    print_header
    echo "$(gum style --foreground 212 --bold "$(t 'find_query')") $(gum style --foreground 255 "'$query'")"
    echo ""

    local tmp_cat
    tmp_cat=$(mktemp)
    export REGISTRY_URL USERNAME PASSWORD ENABLE_CACHE CACHE_TTL CACHE_DIR LOG_FILE CATALOG_N
    export -f api_request api_request_paged log_cache

    gum spin --spinner line --spinner.foreground 208 \
        --title " $(t 'find_spin')" \
        -- bash -c 'api_request_paged "/v2/_catalog?n=${CATALOG_N:-100}" "repositories" > "$1"' _ "$tmp_cat"

    local repos
    repos=$(jq -r '.repositories[]?' "$tmp_cat" 2>/dev/null)
    rm -f "$tmp_cat"

    local filtered_repos
    filtered_repos=$(echo "$repos" | grep -i "$query")

    if [ -z "$filtered_repos" ]; then
        log_cache "SEARCH" "$query" "Nothing found"
        echo "$(gum style --foreground 196 "$(t 'find_nothing')")"
        sleep 1.5
        return 0
    fi

    local matches_count
    matches_count=$(echo "$filtered_repos" | sed '/^$/d' | wc -l)
    log_cache "SEARCH" "$query" "Found repositories: $matches_count"
    clear
    print_header
    echo "$(gum style --foreground 212 --bold "$(t 'find_results')") $(gum style --foreground 255 "'$query'") $(gum style --foreground 242 "($matches_count)")"
    echo ""

    if command -v gum &>/dev/null; then
        local selected_repo
        selected_repo=$(echo "$filtered_repos" | gum filter --height "$VIEW_HEIGHT" --placeholder "$(t 'find_filter_ph')")

        if [ -n "$selected_repo" ]; then
            log_cache "SEARCH_ACTION" "$query" "Selected repo: $selected_repo"
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

    log_msg "INFO" "Checking connection to $raw_host"

    REGISTRY_URL="https://${raw_host}"
    log_msg "INFO" "Trying HTTPS: $REGISTRY_URL"

    local status_code
    status_code=$(api_request "/v2/" -I -o /dev/null -w "%{http_code}" 2>"$tmp_err")
    local curl_exit=$?

    if [ $curl_exit -eq 0 ] && [ "$status_code" -eq 200 ]; then
        log_msg "INFO" "HTTPS connected: $REGISTRY_URL"
        rm -f "$tmp_err"
        return 0
    fi

    if [ $curl_exit -eq 0 ] && [ "$status_code" -ne 000 ]; then
        echo "${ERROR_STYLE} $(t 'conn_auth_err' "$status_code")"
        log_msg "ERROR" "Auth error $REGISTRY_URL (HTTP status: $status_code)"
        rm -f "$tmp_err"
        return 1
    fi

    log_msg "WARN" "HTTPS unavailable (curl exit $curl_exit, status $status_code). Trying HTTP..."
    echo "$(gum style --foreground 214 "$(t 'conn_try_http')")"

    REGISTRY_URL="http://${raw_host}"

    status_code=$(api_request "/v2/" -I -o /dev/null -w "%{http_code}" 2>"$tmp_err")
    curl_exit=$?

    if [ $curl_exit -eq 0 ] && [ "$status_code" -eq 200 ]; then
        log_msg "INFO" "HTTP connected: $REGISTRY_URL"
        echo "$(gum style --foreground 82 "$(t 'conn_http_ok')")"

        fix_insecure_registry_and_restart "$raw_host"

        rm -f "$tmp_err"
        return 0
    fi

    local err_text
    err_text=$(cat "$tmp_err")
    echo "${ERROR_STYLE} $(t 'conn_fail' "$raw_host")"
    [ -n "$err_text" ] && echo "$err_text"
    log_msg "ERROR" "Connection failed $raw_host: $err_text"

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

    log_msg "INFO" "Executing command: $cmd"

    case "$cmd" in
        ":trash"|":clean")
            run_garbage_collector
            ;;
        ":q"|":quit"|":exit")
            clear
            t "cmd_exiting"; echo
            log_msg "INFO" "Exited via $cmd"
            exit 0
            ;;
        ":settings"|":st")
            open_settings
            ;;
        ":upload"|":push")
            push_image_from_archive
            ;;
        ":disconnect"|":ds")
            log_msg "INFO" "Disconnected from $CONNECTED_URL"
            CONNECTED_URL=""
            REGISTRY_URL=""
            USERNAME=""
            PASSWORD=""
            REGISTRY_TYPE="docker-registry"
            HARBOR_API_URL=""
            return 2
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
            echo "$(gum style --foreground 196 "$(t 'cmd_unknown' "$cmd")")"
            log_msg "WARN" "Unknown command: $cmd"
            sleep 1
            ;;
    esac
}

show_help() {
    clear
    print_header
    echo "$(gum style --foreground 214 --bold "$(t 'help_title')")"
    echo
    echo "  $(gum style --bold ':upload :push')     - $(t 'help_upload')"
    echo "  $(gum style --bold ':settings :st')     - $(t 'help_settings')"
    echo "  $(gum style --bold ':find :f')          - $(t 'help_find')"
    echo "  $(gum style --bold ':disconnect :ds')   - $(t 'help_disconnect')"
    echo "  $(gum style --bold ':help :h')          - $(t 'help_help')"
    echo "  $(gum style --bold ':trash :clean')     - $(t 'help_trash')"
    echo "  $(gum style --bold ':exit :quit :q')    - $(t 'help_exit')"
    echo
    echo "  • $(t 'help_tip_esc')"
    echo "  • $(t 'help_tip_ctrlc')"
    echo
    echo "$(gum style --foreground 240 "$(t 'press_enter_return')")"
    read -r _ < /dev/tty
    clear
}

open_settings() {
    while true; do
        clear
        print_header
        echo "$(gum style --foreground 212 --bold "$(t 'set_title')")"
        echo

        local tag_st="$(t 'set_on')"
        [ "$SHOW_TAG_COUNT" != "true" ] && tag_st="$(t 'set_off')"

        local date_st="$(t 'set_on')"
        [ "$SHOW_UPDATED_DATE" != "true" ] && date_st="$(t 'set_off')"

        local size_st="$(t 'set_on')"
        [ "$SHOW_SIZE" != "true" ] && size_st="$(t 'set_off')"

        local hide_tagless_images="$(t 'set_off')"
        [ "$HIDE_TAGLESS_IMAGES" != "true" ] && hide_tagless_images="$(t 'set_on')"

        local cache_st="$(t 'set_on')"
        [ "$ENABLE_CACHE" != "true" ] && cache_st="$(t 'set_off')"

        local ttl_display=""
        if [ "$((CACHE_TTL % 86400))" -eq 0 ]; then
            ttl_display="$((CACHE_TTL / 86400))$(t 'set_unit_d')"
        elif [ "$((CACHE_TTL % 3600))" -eq 0 ]; then
            ttl_display="$((CACHE_TTL / 3600))$(t 'set_unit_h')"
        else
            ttl_display="${CACHE_TTL}$(t 'set_unit_s')"
        fi

        local lang_display="English"
        [ "$UI_LANG" == "ru" ] && lang_display="Русский"

        local options=(
            "$(t 'set_language'): $lang_display"
            "$(t 'set_tag_count') $tag_st"
            "$(t 'set_updated_date') $date_st"
            "$(t 'set_size') $size_st"
            "$(t 'set_show_tagless') $hide_tagless_images"
            "$(t 'set_api_cache') $cache_st"
        )

        if [ "$ENABLE_CACHE" == "true" ]; then
            options+=("$(t 'set_cache_ttl') (TTL = $ttl_display)")
        fi

        options+=(
            "$(t 'set_limit') (n=$CATALOG_N)"
            "$(t 'set_clear_cache')"
            "$(t 'set_save_return')"
        )

        local choice
        choice=$(gum choose "${options[@]}" < /dev/tty)

        if [ $? -eq 130 ]; then
            break
        fi

        case "$choice" in
            *"$(t 'set_language')"*)
                if [ "$UI_LANG" == "en" ]; then
                    UI_LANG="ru"
                else
                    UI_LANG="en"
                fi
                load_translations
                update_ui_styles
                ;;
            *"$(t 'set_tag_count')"*)
                [ "$SHOW_TAG_COUNT" == "true" ] && SHOW_TAG_COUNT="false" || SHOW_TAG_COUNT="true"
                ;;
            *"$(t 'set_updated_date')"*)
                [ "$SHOW_UPDATED_DATE" == "true" ] && SHOW_UPDATED_DATE="false" || SHOW_UPDATED_DATE="true"
                ;;
            *"$(t 'set_size')"*)
                [ "$SHOW_SIZE" == "true" ] && SHOW_SIZE="false" || SHOW_SIZE="true"
                ;;
            *"$(t 'set_api_cache')"*)
                [ "$ENABLE_CACHE" == "true" ] && ENABLE_CACHE="false" || ENABLE_CACHE="true"
                ;;
            *"$(t 'set_cache_ttl')"*)
                local raw_ttl
                raw_ttl=$(gum input --placeholder "$(t 'set_ttl_ph')" --prompt "$(t 'set_ttl_prompt')" < /dev/tty)
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
            *"$(t 'set_limit')"*)
                local new_n
                new_n=$(gum input --placeholder "$(t 'set_limit_ph')" --value "$CATALOG_N" --prompt "$(t 'set_limit_prompt')" < /dev/tty)
                if [[ "$new_n" =~ ^[0-9]+$ ]] && [ "$new_n" -gt 0 ]; then
                    CATALOG_N="$new_n"
                fi
                ;;
            *"$(t 'set_show_tagless')"*)
                if [ "$HIDE_TAGLESS_IMAGES" = "true" ]; then
                    HIDE_TAGLESS_IMAGES="false"
                else
                    HIDE_TAGLESS_IMAGES="true"
                fi
                ;;
            *"$(t 'set_clear_cache')"*)
                clear_cache
                echo "$(gum style --foreground 82 "$(t 'set_cache_cleared')")"
                sleep 1
                ;;
            *"$(t 'set_save_return')"*|"")
                save_config
                break
                ;;
        esac
    done
    clear
}

get_harbor_projects() {
    [ "$REGISTRY_TYPE" != "harbor" ] && return 0

    local tmp_out code page=1
    tmp_out=$(mktemp)
    while true; do
        code=$(harbor_call "GET" "/api/v2.0/projects?page=${page}&page_size=100" "" "$tmp_out")
        if [ "$code" != "200" ]; then
            break
        fi
        local count
        count=$(jq -r 'if type=="array" then length else 0 end' "$tmp_out" 2>/dev/null || echo 0)
        [ "$count" -eq 0 ] && break
        jq -r '.[].name' "$tmp_out" 2>/dev/null
        [ "$count" -lt 100 ] && break
        ((page++))
    done
    rm -f "$tmp_out"
}

get_registry_projects() {
    local catalog_json catalog_projects harbor_projects
    catalog_json=$(api_request_paged "/v2/_catalog?n=${CATALOG_N:-100}" "repositories")
    catalog_projects=$(echo "$catalog_json" | jq -r '.repositories[]?' 2>/dev/null | awk -F'/' '{print $1}')
    harbor_projects=$(get_harbor_projects)

    printf "%s\n%s\n" "$catalog_projects" "$harbor_projects" | sed '/^$/d' | sort -u
}

create_registry_project() {
    local project_name="$1"
    local is_public="${2:-false}"

    if [ "$REGISTRY_TYPE" != "harbor" ]; then
        log_msg "INFO" "Standard registry: project '$project_name' is created implicitly on push"
        return 2
    fi

    local payload
    payload=$(jq -n --arg name "$project_name" --arg pub "$is_public" \
        '{project_name: $name, metadata: {public: $pub}}')

    local tmp_resp http_code
    tmp_resp=$(mktemp)
    http_code=$(harbor_call "POST" "/api/v2.0/projects" "$payload" "$tmp_resp")
    local resp_body
    resp_body=$(cat "$tmp_resp" 2>/dev/null)
    rm -f "$tmp_resp"

    case "$http_code" in
        201|200)
            log_msg "INFO" "Project '$project_name' created in Harbor (HTTP $http_code)"
            return 0
            ;;
        409)
            log_msg "INFO" "Project '$project_name' already exists (HTTP 409)"
            return 0
            ;;
        401|403)
            echo "${ERROR_STYLE} $(t 'proj_perm_err' "$project_name" "$http_code")"
            [ -n "$resp_body" ] && echo "$resp_body"
            log_msg "ERROR" "Create project '$project_name' failed (HTTP $http_code): $resp_body"
            return 1
            ;;
        404|405|000)
            log_msg "WARN" "Harbor API /api/v2.0/projects unavailable (HTTP $http_code)"
            return 2
            ;;
        *)
            echo "${ERROR_STYLE} $(t 'proj_create_err' "$project_name" "$http_code")"
            [ -n "$resp_body" ] && echo "$resp_body"
            log_msg "ERROR" "Create project '$project_name' failed (HTTP $http_code): $resp_body"
            return 1
            ;;
    esac
}

select_archive_file() {
    local current_dir="${1:-$HOME}"

    while true; do
        clear >&2
        print_header >&2
        echo "$(gum style --foreground 212 --bold "$(t 'arch_title')")" >&2
        echo "$(gum style --foreground 240 "$(t 'arch_cur_dir')") $(gum style --foreground 220 "$current_dir")" >&2
        echo >&2

        local options=()

        if [ "$current_dir" != "/" ]; then
            options+=("$(t 'arch_up')")
        fi

        while IFS= read -r dir; do
            [ -n "$dir" ] && options+=("📁 $(basename "$dir")")
        done < <(find "$current_dir" -maxdepth 1 -mindepth 1 -type d ! -name ".*" 2>/dev/null | sort)

        while IFS= read -r file; do
            [ -n "$file" ] && options+=("📦 $(basename "$file")")
        done < <(find "$current_dir" -maxdepth 1 -mindepth 1 -type f \( -name "*.tar" -o -name "*.tar.gz" -o -name "*.tgz" \) 2>/dev/null | sort)

        if [ ${#options[@]} -eq 0 ]; then
            echo "$(gum style --foreground 214 "$(t 'arch_empty')")" >&2
            echo "$(gum style --foreground 240 "$(t 'arch_up_enter')")" >&2
            read -r _ < /dev/tty
            current_dir=$(dirname "$current_dir")
            continue
        fi

        local selection
        selection=$(gum choose "${options[@]}" --height 15 --header "$(t 'arch_header')" < /dev/tty) || return 0

        if [ -z "$selection" ]; then
            return 0
        fi

        local up_clean
        up_clean=$(t 'arch_up' | sed 's/^📁 //' | tr -d '\r')
        local clean_item
        clean_item=$(echo "$selection" | sed 's/^[📁📦] //' | tr -d '\r')

        if [ "$clean_item" == "$up_clean" ]; then
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
    echo "$(gum style --foreground 214 "$(t 'daemon_http_warn')")"
    log_msg "WARN" "Configuring insecure-registry for $reg_host"

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
        echo "$(gum style --foreground 82 "$(t 'daemon_json_ok' "$daemon_json" "$reg_host")")"
    else
        rm -f "$tmp_file"
        echo "${ERROR_STYLE} $(t 'daemon_json_err' "$daemon_json")"
        log_msg "ERROR" "Failed updating $daemon_json"
        return 1
    fi

    echo "$(gum style --foreground 212 "$(t 'daemon_restarting')")"
    if sudo systemctl restart docker; then
        echo "$(gum style --foreground 82 "$(t 'daemon_restart_ok')")"
        log_msg "INFO" "Docker daemon restarted with insecure-registries"
        sleep 2
        return 0
    else
        echo "${ERROR_STYLE} $(t 'daemon_restart_err')"
        log_msg "ERROR" "Failed to restart Docker Daemon"
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
            echo "$(gum style --foreground 214 "$(t 'push_done')")"
            sleep 1
            return 0
        fi

        log_msg "INFO" "Selected archive: $archive_file"
        clear
        print_header
        echo "$(gum style --foreground 212 --bold "$(t 'push_selected')") $archive_file"
        echo

        local load_out
        load_out=$(mktemp)

        if ! gum spin --spinner line --spinner.foreground 208 \
            --title "$(t 'push_spin_load')" \
            -- bash -c 'docker load -i "$1" > "$2" 2>&1' _ "$archive_file" "$load_out"; then
            echo "$ERROR_STYLE $(t 'push_load_err')"
            cat "$load_out"
            log_msg "ERROR" "docker load failed for $archive_file: $(cat "$load_out")"
            rm -f "$load_out"
            read -r _ < /dev/tty
            continue
        fi

        local loaded_image
        loaded_image=$(grep -oP 'Loaded image: \K.*' "$load_out" | tail -n 1 | tr -d '\r')
        if [ -z "$loaded_image" ]; then
            loaded_image=$(grep -oP 'Loaded image ID: \K.*' "$load_out" | tail -n 1 | tr -d '\r')
        fi
        rm -f "$load_out"

        if [ -z "$loaded_image" ]; then
            echo "$ERROR_STYLE $(t 'push_no_img_name')"
            log_msg "ERROR" "Failed to extract image name from docker load output"
            read -r _ < /dev/tty
            continue
        fi

        echo "$(gum style --foreground 82 "$(t 'push_imported')") $loaded_image"
        log_msg "INFO" "Image imported: $loaded_image"
        echo

        local default_name=""
        local default_tag="latest"

        if [[ "$loaded_image" == sha256:* ]]; then
            default_name=$(basename "$archive_file" | sed -E 's/\.(tar\.gz|tgz|tar)$//')
        elif [[ "$loaded_image" == *":"* ]]; then
            default_tag="${loaded_image##*:}"
            default_name="${loaded_image%:*}"
            default_name="${default_name##*/}"
        else
            default_name="${loaded_image##*/}"
        fi

        local target_project="$preset_project"
        if [ -z "$target_project" ]; then
            local tmp_proj
            tmp_proj=$(mktemp)

            export REGISTRY_URL USERNAME PASSWORD ENABLE_CACHE CACHE_TTL CACHE_DIR LOG_FILE CATALOG_N REGISTRY_TYPE HARBOR_API_URL
            export -f api_request api_request_paged harbor_call get_harbor_projects get_registry_projects log_cache

            gum spin --spinner line --spinner.foreground 208 \
                --title "$(t 'push_spin_proj')" \
                -- bash -c 'get_registry_projects > "$1"' _ "$tmp_proj"

            local existing_projects
            existing_projects=$(cat "$tmp_proj")
            rm -f "$tmp_proj"

            local new_proj_label
            new_proj_label="$(t 'push_new_proj')"
            local proj_list=("$new_proj_label")
            while IFS= read -r p; do
                [ -n "$p" ] && proj_list+=("$p")
            done <<< "$existing_projects"

            local proj_choice
            proj_choice=$(gum choose "${proj_list[@]}" --header "$(t 'push_choose_proj')" < /dev/tty) || continue

            if [ "$proj_choice" == "$new_proj_label" ] || [ -z "$proj_choice" ]; then
                target_project=$(gum input --placeholder "$(t 'push_new_proj_ph')" --prompt "$(t 'push_new_proj_prompt')" < /dev/tty) || continue
                target_project=$(echo "$target_project" | tr -d '[:space:]')

                if [ -z "$target_project" ]; then
                    echo "$ERROR_STYLE $(t 'push_proj_empty')"
                    sleep 1.5
                    continue
                fi

                if ! [[ "$target_project" =~ ^[a-z0-9]([a-z0-9._-]*[a-z0-9])?$ ]]; then
                    echo "$ERROR_STYLE $(t 'push_proj_invalid' "$target_project")"
                    read -r _ < /dev/tty
                    continue
                fi

                local is_public="false"
                if [ "$REGISTRY_TYPE" == "harbor" ]; then
                    local vis_choice
                    vis_choice=$(gum choose "$(t 'push_vis_private')" "$(t 'push_vis_public')" --header "$(t 'push_vis_header' "$target_project")" < /dev/tty) || continue
                    [ "$vis_choice" == "$(t 'push_vis_public')" ] && is_public="true"
                fi

                local create_out create_rc_file create_rc
                create_out=$(mktemp)
                create_rc_file=$(mktemp)

                export REGISTRY_URL USERNAME PASSWORD LOG_FILE ERROR_STYLE REGISTRY_TYPE HARBOR_API_URL
                export -f harbor_call create_registry_project log_msg t

                gum spin --spinner line --spinner.foreground 208 \
                    --title "$(t 'push_spin_create_proj' "$target_project")" \
                    -- bash -c '
                        payload=$(jq -n --arg name "$1" --arg pub "$2" "{project_name: \$name, metadata: {public: \$pub}}")
                        if [ "$REGISTRY_TYPE" != "harbor" ]; then echo 2 > "$4"; exit 0; fi
                        code=$(harbor_call "POST" "/api/v2.0/projects" "$payload" "$3")
                        case "$code" in
                            201|200|409) echo 0 > "$4" ;;
                            404|405|000) echo 2 > "$4" ;;
                            *) echo "$code" > "$4" ;;
                        esac
                    ' _ "$target_project" "$is_public" "$create_out" "$create_rc_file"

                create_rc=$(cat "$create_rc_file" 2>/dev/null || echo 1)

                if [ "$create_rc" -eq 0 ]; then
                    echo "$(gum style --foreground 82 "$(t 'push_proj_ready' "$target_project")")"
                    log_msg "INFO" "Project '$target_project' ready in Harbor"
                elif [ "$create_rc" -eq 2 ]; then
                    echo "$(gum style --foreground 214 "$(t 'push_proj_std_reg' "$target_project")")"
                elif [ "$create_rc" -eq 401 ] || [ "$create_rc" -eq 403 ]; then
                    echo "$ERROR_STYLE $(t 'proj_perm_err' "$target_project" "$create_rc")"
                    cat "$create_out"
                    rm -f "$create_out" "$create_rc_file"
                    read -r _ < /dev/tty
                    continue
                else
                    echo "$ERROR_STYLE $(t 'proj_create_err' "$target_project" "$create_rc")"
                    cat "$create_out"
                    rm -f "$create_out" "$create_rc_file"
                    read -r _ < /dev/tty
                    continue
                fi
                rm -f "$create_out" "$create_rc_file"
            else
                target_project="$proj_choice"
            fi
        fi

        local target_repo="$preset_repo"
        if [ -z "$target_repo" ]; then
            target_repo=$(gum input --placeholder "$(t 'push_repo_ph')" --value "$default_name" --prompt "$(t 'push_repo_prompt')" < /dev/tty) || continue
        else
            target_repo="${target_repo#*/}"
        fi
        target_repo="${target_repo#/}"
        target_repo="${target_repo%/}"

        if [ -z "$target_repo" ]; then
            echo "$ERROR_STYLE $(t 'push_repo_empty')"
            sleep 1.5
            continue
        fi

        local target_tag
        target_tag=$(gum input --placeholder "$(t 'push_tag_ph')" --value "$default_tag" --prompt "$(t 'push_tag_prompt')" < /dev/tty) || continue
        [ -z "$target_tag" ] && target_tag="latest"

        local registry_host
        registry_host=$(echo "$REGISTRY_URL" | sed -E 's|^https?://||; s|/.*||')

        local full_target_image="${registry_host}/${target_project}/${target_repo}:${target_tag}"

        echo "$(t 'push_target_img') $(gum style --foreground 220 --bold "$full_target_image")"
        echo

        if ! gum confirm --affirmative "$(t 'yes')" --negative "$(t 'no')" "$(t 'push_confirm')" < /dev/tty; then
            log_msg "INFO" "Push cancelled for $full_target_image"
            continue
        fi

        docker tag "$loaded_image" "$full_target_image"

        if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
            local login_err
            login_err=$(mktemp)
            if ! echo "$PASSWORD" | docker login "$registry_host" -u "$USERNAME" --password-stdin >"$login_err" 2>&1; then
                if grep -q "server gave HTTP response to HTTPS client" "$login_err"; then
                    if fix_insecure_registry_and_restart "$registry_host"; then
                        docker tag "$loaded_image" "$full_target_image" &>/dev/null
                        if ! echo "$PASSWORD" | docker login "$registry_host" -u "$USERNAME" --password-stdin >"$login_err" 2>&1; then
                            echo "$ERROR_STYLE $(t 'push_login_err')"
                            cat "$login_err"
                            log_msg "ERROR" "docker login failed: $(cat "$login_err")"
                            rm -f "$login_err"
                            read -r _ < /dev/tty
                            continue
                        fi
                    else
                        rm -f "$login_err"
                        read -r _ < /dev/tty
                        continue
                    fi
                else
                    echo "$ERROR_STYLE $(t 'push_login_err')"
                    cat "$login_err"
                    log_msg "ERROR" "docker login failed: $(cat "$login_err")"
                    rm -f "$login_err"
                    read -r _ < /dev/tty
                    continue
                fi
            fi
            rm -f "$login_err"
        fi

        echo
        local push_err
        push_err=$(mktemp)
        local push_ok=false

        log_msg "INFO" "Pushing $full_target_image"

        if gum spin --spinner line --spinner.foreground 208 \
            --title "$(t 'push_spin_push' "$full_target_image")" \
            -- bash -c 'docker push "$1" > "$2" 2>&1' _ "$full_target_image" "$push_err"; then
            push_ok=true
        else
            if grep -q "server gave HTTP response to HTTPS client" "$push_err"; then
                echo "$ERROR_STYLE $(t 'push_http_err')"
                echo "$(gum style --foreground 214 "$(t 'push_http_retry')")"
                echo

                if fix_insecure_registry_and_restart "$registry_host"; then
                    docker tag "$loaded_image" "$full_target_image" &>/dev/null
                    if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
                        echo "$PASSWORD" | docker login "$registry_host" -u "$USERNAME" --password-stdin &>/dev/null
                    fi

                    echo
                    if gum spin --spinner line --spinner.foreground 208 \
                        --title "$(t 'push_spin_retry' "$full_target_image")" \
                        -- bash -c 'docker push "$1" > "$2" 2>&1' _ "$full_target_image" "$push_err"; then
                        push_ok=true
                    fi
                fi
            elif grep -qiE "project .* not found" "$push_err"; then
                echo "$ERROR_STYLE $(t 'push_proj_not_found' "$target_project")"
                log_msg "WARN" "Project '$target_project' not found during docker push"

                if gum confirm --affirmative "$(t 'yes')" --negative "$(t 'no')" "$(t 'push_proj_create_retry' "$target_project")" < /dev/tty; then
                    local vis_choice is_public="false"
                    vis_choice=$(gum choose "$(t 'push_vis_private')" "$(t 'push_vis_public')" --header "$(t 'push_vis_header' "$target_project")" < /dev/tty)
                    [ "$vis_choice" == "$(t 'push_vis_public')" ] && is_public="true"

                    REGISTRY_TYPE="harbor"
                    if create_registry_project "$target_project" "$is_public"; then
                        echo "$(gum style --foreground 82 "$(t 'push_proj_created_retry' "$target_project")")"
                        if gum spin --spinner line --spinner.foreground 208 \
                            --title "$(t 'push_spin_retry' "$full_target_image")" \
                            -- bash -c 'docker push "$1" > "$2" 2>&1' _ "$full_target_image" "$push_err"; then
                            push_ok=true
                        fi
                    fi
                fi
            fi
        fi

        if [ "$push_ok" != "true" ]; then
            echo "$ERROR_STYLE $(t 'push_err')"
            cat "$push_err"
            log_msg "ERROR" "docker push failed $full_target_image: $(cat "$push_err")"
            rm -f "$push_err"
            read -r _ < /dev/tty
            continue
        fi

        rm -f "$push_err"
        echo "$(gum style --foreground 82 --bold "$(t 'push_ok')") $full_target_image"
        log_msg "INFO" "Image $full_target_image pushed successfully"
        docker rmi "$full_target_image" "$loaded_image" &>/dev/null || true

        clear_cache

        echo
        if ! gum confirm --affirmative "$(t 'yes')" --negative "$(t 'no')" "$(t 'push_another')" < /dev/tty; then
            break
        fi
    done
}

run_docker_registry_ssh_gc() {
    local delete_repo_path="${1:-}"
    local dry_run="${2:-false}"

    local SSH_LOGIN SSH_PASSWORD SSH_HOST
    SSH_LOGIN=$(gum input --placeholder "$(t 'ssh_login_ph')" < /dev/tty) || return 1
    SSH_PASSWORD=$(gum input --password --placeholder "$(t 'ssh_pass_ph')" < /dev/tty) || return 1

    local clean_url="${CONNECTED_URL#*://}"
    SSH_HOST="${clean_url%%:*}"

    local ssh_exec=()
    if [ -n "$SSH_PASSWORD" ] && command -v sshpass &>/dev/null; then
        ssh_exec=(sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no "${SSH_LOGIN}@${SSH_HOST}")
    else
        if [ -n "$SSH_PASSWORD" ] && ! command -v sshpass &>/dev/null; then
            echo "$(gum style --foreground 214 "$(t 'ssh_no_sshpass')")"
        fi
        ssh_exec=(ssh -o StrictHostKeyChecking=no "${SSH_LOGIN}@${SSH_HOST}")
    fi

    local container_name
    container_name=$("${ssh_exec[@]}" "docker ps --format '{{.Names}}' | grep -E 'registry' | head -n 1" 2>/dev/null | tr -d '\r')
    container_name=$(gum input --placeholder "$(t 'ssh_container_ph')" --value "${container_name:-docker-registry-registry-1}" --prompt "$(t 'ssh_container_prompt')" < /dev/tty) || return 1

    local gc_flags="--delete-untagged"
    [ "$dry_run" == "true" ] && gc_flags="--dry-run"

    echo "$(gum style --foreground 212 "$(t 'ssh_gc_run' "$gc_flags")")"
    log_msg "INFO" "Running registry garbage-collect ($gc_flags) in $container_name on $SSH_HOST"

    local gc_cmd="CFG=/etc/docker/registry/config.yml; docker exec \"$container_name\" test -f /etc/docker-registry/config.yml && CFG=/etc/docker-registry/config.yml; docker exec -i \"$container_name\" registry garbage-collect $gc_flags \"\$CFG\""
    if "${ssh_exec[@]}" "$gc_cmd"; then
        echo "$(gum style --foreground 82 "$(t 'ssh_gc_ok')")"
        log_msg "INFO" "Garbage collection succeeded"
    else
        echo "$(gum style --foreground 196 "$(t 'ssh_gc_err')")"
        log_msg "ERROR" "Garbage collection failed on $SSH_HOST"
    fi

    if [ -n "$delete_repo_path" ] && [ "$dry_run" != "true" ]; then
        echo "$(gum style --foreground 212 "$(t 'ssh_rm_dir' "$delete_repo_path")")"
        local remote_cmd
        remote_cmd=$(cat <<EOF
            MOUNT_SRC=\$(docker inspect "$container_name" --format '{{range .Mounts}}{{if eq .Destination "/var/lib/registry"}}{{.Source}}{{end}}{{end}}' 2>/dev/null)
            [ -z "\$MOUNT_SRC" ] && MOUNT_SRC="/var/lib/docker/volumes/docker-registry_registry-data/_data"
            TARGET_DIR="\${MOUNT_SRC}/docker/registry/v2/repositories/${delete_repo_path}"

            if [ -d "\$TARGET_DIR" ]; then
                docker stop "$container_name" >/dev/null 2>&1 && \
                rm -rf "\$TARGET_DIR" && \
                docker start "$container_name" >/dev/null 2>&1
                exit \$?
            else
                docker restart "$container_name" >/dev/null 2>&1
                exit 2
            fi
EOF
        )

        "${ssh_exec[@]}" "$remote_cmd" &>/dev/null
        local rc=$?
        if [ $rc -eq 0 ]; then
            echo "$(gum style --foreground 82 "$(t 'ssh_rm_ok' "$delete_repo_path")")"
        elif [ $rc -eq 2 ]; then
            echo "$(gum style --foreground 214 "$(t 'ssh_rm_notfound' "$delete_repo_path")")"
        else
            echo "$(gum style --foreground 196 "$(t 'ssh_rm_err')")"
        fi

        local is_running="false"
        for i in {1..10}; do
            sleep 1
            local state
            state=$("${ssh_exec[@]}" "docker inspect --format='{{.State.Status}}' \"$container_name\" 2>/dev/null" | tr -d '\r')
            if [ "$state" = "running" ]; then
                is_running="true"
                break
            fi
        done

        if [ "$is_running" = "true" ]; then
            echo "$(gum style --foreground 82 "$(t 'ssh_running_ok' "$container_name")")"
        else
            echo "$(gum style --foreground 196 "$(t 'ssh_running_err' "$container_name")")"
        fi
    fi

    clear_cache
}

run_garbage_collector() {
    clear
    print_header
    echo "$(gum style --foreground 214 --bold "$(t 'gc_title')")"
    echo
    log_msg "INFO" "Running GC via :trash (type=$REGISTRY_TYPE)"

    if [ "$REGISTRY_TYPE" == "harbor" ]; then
        local mode_choice
        mode_choice=$(gum choose \
            "$(t 'gc_harbor_real')" \
            "$(t 'gc_harbor_dry')" \
            "$(t 'gc_cancel')" < /dev/tty) || return 0

        local dry_run="false"
        case "$mode_choice" in
            "$(t 'gc_harbor_dry')") dry_run="true" ;;
            "$(t 'gc_cancel')"|"") return 0 ;;
        esac

        local payload
        payload=$(jq -n --argjson dry "$dry_run" '{
            schedule: {type: "Manual"},
            parameters: {delete_untagged: true, dry_run: $dry}
        }')

        local tmp_out code
        tmp_out=$(mktemp)
        code=$(harbor_call "POST" "/api/v2.0/system/gc/schedule" "$payload" "$tmp_out")
        local resp
        resp=$(cat "$tmp_out" 2>/dev/null)
        rm -f "$tmp_out"

        if [ "$code" == "201" ] || [ "$code" == "200" ]; then
            echo "$(gum style --foreground 82 "$(t 'gc_harbor_ok' "$code")")"
            log_msg "INFO" "Harbor GC triggered (dry_run=$dry_run)"
            clear_cache
        else
            echo "${ERROR_STYLE} $(t 'gc_harbor_err' "$code")"
            [ -n "$resp" ] && echo "$resp"
            log_msg "ERROR" "Harbor GC failed (HTTP $code): $resp"
        fi
    else
        local mode_choice
        mode_choice=$(gum choose \
            "$(t 'gc_reg_real')" \
            "$(t 'gc_reg_dry')" \
            "$(t 'gc_cancel')" < /dev/tty) || return 0

        case "$mode_choice" in
            "$(t 'gc_reg_real')") run_docker_registry_ssh_gc "" "false" ;;
            "$(t 'gc_reg_dry')") run_docker_registry_ssh_gc "" "true" ;;
            *) return 0 ;;
        esac
    fi

    echo ""
    read -rp "$(t 'press_enter_continue')"
}

manage_tagless_artifacts() {
    local repo="$1"

    if [ "$REGISTRY_TYPE" != "harbor" ]; then
        clear
        print_header
        echo "$(gum style --foreground 214 "$(t 'tagless_std_info')")"
        echo
        gum input --placeholder "$(t 'press_enter_return')"
        return 0
    fi

    while true; do
        clear
        print_header
        echo "$(gum style --foreground 212 --bold "$(t 'tagless_title')") $(gum style --foreground 255 "$repo")"
        echo

        local tmp_art code
        tmp_art=$(mktemp)
        code=$(harbor_repo_call "GET" "$repo" "/artifacts?page_size=100&with_tag=true" "" "$tmp_art")

        local untagged_digests=""
        if [ "$code" == "200" ]; then
            untagged_digests=$(jq -r '.[] | select(.tags == null or (.tags | length) == 0) | .digest' "$tmp_art" 2>/dev/null)
        fi
        rm -f "$tmp_art"

        if [ -z "$untagged_digests" ]; then
            echo "$(gum style --foreground 82 "$(t 'tagless_none')")"
            sleep 1
            break
        fi

        local del_all_lbl back_lbl
        del_all_lbl="$(t 'tagless_del_all')"
        back_lbl="$(t 'back')"
        local choices=("$del_all_lbl")
        while IFS= read -r d; do
            [ -n "$d" ] && choices+=("$d")
        done <<< "$untagged_digests"
        choices+=("$back_lbl")

        local sel
        sel=$(gum choose "${choices[@]}" --header "$(t 'tagless_choose')" < /dev/tty) || break

        case "$sel" in
            "$back_lbl"|"") break ;;
            "$del_all_lbl")
                if gum confirm --affirmative "$(t 'yes')" --negative "$(t 'no')" "$(t 'tagless_confirm_all' "$repo")" < /dev/tty; then
                    local tmp_del del_code
                    tmp_del=$(mktemp)
                    while IFS= read -r d; do
                        [ -z "$d" ] && continue
                        del_code=$(harbor_repo_call "DELETE" "$repo" "/artifacts/${d}" "" "$tmp_del")
                        if [ "$del_code" == "200" ] || [ "$del_code" == "202" ]; then
                            echo "$(gum style --foreground 82 "$(t 'tagless_deleted' "$d")")"
                        else
                            echo "$(gum style --foreground 196 "$(t 'tagless_del_err' "$d" "$del_code")")"
                        fi
                    done <<< "$untagged_digests"
                    rm -f "$tmp_del"
                    clear_cache
                    gum input --placeholder "$(t 'press_enter')"
                    break
                fi
                ;;
            sha256:*)
                if gum confirm --affirmative "$(t 'yes')" --negative "$(t 'no')" "$(t 'tagless_confirm_one' "$sel")" < /dev/tty; then
                    local tmp_del del_code
                    tmp_del=$(mktemp)
                    del_code=$(harbor_repo_call "DELETE" "$repo" "/artifacts/${sel}" "" "$tmp_del")
                    rm -f "$tmp_del"
                    if [ "$del_code" == "200" ] || [ "$del_code" == "202" ]; then
                        echo "$(gum style --foreground 82 "$(t 'tagless_one_ok')")"
                        clear_cache
                    else
                        echo "$(gum style --foreground 196 "$(t 'tagless_one_err' "$del_code")")"
                    fi
                    gum input --placeholder "$(t 'press_enter')"
                fi
                ;;
        esac
    done
}

show_repository_tags() {
    local repo="$1"

    while true; do
        get_term_dimensions
        clear
        print_header
        echo "$(gum style --foreground 212 --bold "$(t 'lbl_image')") $(gum style --foreground 255 "$repo")"

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

        local has_tagless=false
        if [ "$REGISTRY_TYPE" == "harbor" ]; then
            local tmp_art code
            tmp_art=$(mktemp)
            code=$(harbor_repo_call "GET" "$repo" "/artifacts?page_size=100&with_tag=true" "" "$tmp_art")
            if [ "$code" == "200" ] && jq -e 'if type=="array" then .[] else empty end | select(.tags == null or (.tags | length) == 0)' "$tmp_art" >/dev/null 2>&1; then
                has_tagless=true
            fi
            rm -f "$tmp_art"
        fi

        if [ "$has_tagless" = true ]; then
            item_list+=("⚠️  [tagless / untagged]")
        fi

        if [ ${#item_list[@]} -eq 0 ]; then
            echo
            echo "$(gum style --foreground 214 "$(t 'tags_empty')")"
            sleep 1.2
            break
        fi

        echo ""

        local selected_item
        selected_item=$(printf "%s\n" "${item_list[@]}" | gum choose --height "$VIEW_HEIGHT" --header "$(t 'tags_header')")

        [ -z "$selected_item" ] && break

        if [[ "$selected_item" == *"tagless / untagged"* ]]; then
            manage_tagless_artifacts "$repo"
            continue
        fi

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
    echo "$(gum style --foreground 212 --bold "$(t 'lbl_image')") $(gum style --foreground 255 "$repo:$tag")"
    echo

    local target_arch="amd64"
    local target_os="linux"
    local tmp_json
    tmp_json=$(mktemp)

    export REGISTRY_URL USERNAME PASSWORD ENABLE_CACHE CACHE_TTL CACHE_DIR LOG_FILE
    export -f api_request log_cache

    gum spin --spinner line --spinner.foreground 208 \
        --title "$(t 'hist_spin')" \
        -- bash -c '
            repo="$1"; tag="$2"; target_arch="$3"; target_os="$4"; tmp_json="$5"
            manifest_resp=$(api_request "/v2/$repo/manifests/$tag" -i \
                -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
                -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
                -H "Accept: application/vnd.oci.image.index.v1+json" \
                -H "Accept: application/vnd.oci.image.manifest.v1+json")

            http_code=$(echo "$manifest_resp" | grep -E "^HTTP/" | tail -n 1 | awk "{print \$2}")
            manifest_body=$(echo "$manifest_resp" | sed "1,/^\r\{0,1\}\$/d")

            if [ -z "$http_code" ] || [ "$http_code" -ne 200 ]; then
                jq -n --arg code "$http_code" "{err_type: \"manifest\", http_code: \$code}" > "$tmp_json"
                exit 0
            fi

            media_type=$(echo "$manifest_body" | jq -r ".mediaType // empty" 2>/dev/null)
            config_digest=""

            if [[ "$media_type" == *"manifest.list"* ]] || [[ "$media_type" == *"image.index"* ]]; then
                target_digest=$(echo "$manifest_body" | jq -r --arg arch "$target_arch" --arg os "$target_os" \
                    ".manifests[]? | select(.platform.architecture == \$arch and .platform.os == \$os) | .digest" 2>/dev/null | head -n 1)

                if [ -z "$target_digest" ] || [ "$target_digest" == "null" ]; then
                    target_digest=$(echo "$manifest_body" | jq -r ".manifests[0].digest?" 2>/dev/null)
                fi

                if [ -n "$target_digest" ] && [ "$target_digest" != "null" ]; then
                    sub_manifest=$(api_request "/v2/$repo/manifests/$target_digest" \
                        -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
                        -H "Accept: application/vnd.oci.image.manifest.v1+json")
                    config_digest=$(echo "$sub_manifest" | jq -r ".config.digest?" 2>/dev/null)
                fi
            else
                config_digest=$(echo "$manifest_body" | jq -r ".config.digest?" 2>/dev/null)
            fi

            if [ -z "$config_digest" ] || [ "$config_digest" == "null" ]; then
                jq -n "{err_type: \"config\"}" > "$tmp_json"
                exit 0
            fi

            blob_resp=$(api_request "/v2/$repo/blobs/$config_digest" -i)
            blob_body=$(echo "$blob_resp" | sed "1,/^\r\{0,1\}\$/d")

            dockerfile_lines=$(echo "$blob_body" | jq -r ".history[]? | select(.empty_layer != true or .created_by != null) | .created_by" 2>/dev/null | \
                sed "s|/bin/sh -c #(nop) ||g" | \
                sed "s|/bin/sh -c ||g" | \
                grep -v "^\s*$" | \
                sed "/^$/d")

            if [ -n "$dockerfile_lines" ]; then
                jq -n --arg code "$dockerfile_lines" "{dockerfile: \$code}" > "$tmp_json"
            else
                jq -n "{err_type: \"empty\"}" > "$tmp_json"
            fi
        ' _ "$repo" "$tag" "$target_arch" "$target_os" "$tmp_json"

    local err_type http_err_code dockerfile_content
    err_type=$(jq -r '.err_type // empty' "$tmp_json" 2>/dev/null)
    http_err_code=$(jq -r '.http_code // empty' "$tmp_json" 2>/dev/null)
    dockerfile_content=$(jq -r '.dockerfile // empty' "$tmp_json" 2>/dev/null)
    rm -f "$tmp_json"

    if [ -n "$dockerfile_content" ]; then
        echo "$(gum style --foreground 214 --bold "$(t 'hist_title')")"
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
        local err_msg=""
        case "$err_type" in
            manifest) err_msg="$(t 'hist_err_manifest' "$http_err_code")" ;;
            config) err_msg="$(t 'hist_err_config')" ;;
            *) err_msg="$(t 'hist_err_empty')" ;;
        esac
        echo "$(gum style --foreground 196 --bold "$(t 'hist_extract_err')") $err_msg"
        log_msg "ERROR" "Layer history error for $repo:$tag: $err_msg"
    fi

    echo
    gum input --placeholder "$(t 'press_enter_return')"
}

show_tag_digest() {
    local repo="$1"
    local tag="$2"

    clear
    print_header
    echo "$(gum style --foreground 212 --bold "$(t 'lbl_image')") $(gum style --foreground 255 "$repo:$tag")"
    echo

    local digest=""

    if [[ "$tag" == sha256:* ]]; then
        digest="$tag"
    else
        export REGISTRY_URL USERNAME PASSWORD
        export -f fetch_v2_bearer_token v2_get_manifest_digest
        digest=$(gum spin --spinner line --spinner.foreground 208 \
            --title "$(t 'digest_spin')" \
            -- bash -c 'v2_get_manifest_digest "$1" "$2"' _ "$repo" "$tag")
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
            "$(gum style --foreground 196 --bold "$(t 'digest_not_found')")"
    fi

    echo
    gum input --placeholder "$(t 'press_enter_return')"
}

delete_tag() {
    local repo="$1"
    local tag="$2"

    clear
    print_header

    if [ "$REGISTRY_TYPE" == "harbor" ]; then
        local tmp_art code
        tmp_art=$(mktemp)
        code=$(harbor_repo_call "GET" "$repo" "/artifacts/${tag}?with_tag=true" "" "$tmp_art")

        if [ "$code" == "200" ]; then
            local art_digest tag_count
            art_digest=$(jq -r '.digest // empty' "$tmp_art" 2>/dev/null)
            tag_count=$(jq -r '.tags | length // 0' "$tmp_art" 2>/dev/null || echo 0)
            rm -f "$tmp_art"

            if [ -n "$art_digest" ]; then
                if [ "$tag_count" -gt 1 ]; then
                    echo "$(gum style --foreground 214 "$(t 'del_tag_multi' "$art_digest" "$tag_count")")"
                    if gum confirm --affirmative "$(t 'del_tag_only_btn')" --negative "$(t 'cancel')" "$(t 'del_tag_only_confirm' "$tag")"; then
                        local tmp_del del_code
                        tmp_del=$(mktemp)
                        del_code=$(harbor_repo_call "DELETE" "$repo" "/artifacts/${art_digest}/tags/${tag}" "" "$tmp_del")
                        rm -f "$tmp_del"
                        if [ "$del_code" == "200" ] || [ "$del_code" == "202" ]; then
                            echo "$(gum style --foreground 82 "$(t 'del_tag_only_ok' "$tag")")"
                            log_msg "INFO" "Deleted tag $repo:$tag in Harbor"
                            clear_cache
                            gum input --placeholder "$(t 'press_enter')"
                            return 0
                        else
                            echo "$(gum style --foreground 196 "$(t 'del_tag_err' "$del_code")")"
                            log_msg "ERROR" "Failed deleting tag $repo:$tag in Harbor (HTTP $del_code)"
                            gum input --placeholder "$(t 'press_enter')"
                            return 1
                        fi
                    fi
                    return 1
                else
                    if gum confirm --affirmative "$(t 'del_btn_yes')" --negative "$(t 'cancel')" "$(t 'del_tag_art_confirm' "$repo" "$tag")"; then
                        local tmp_del del_code
                        tmp_del=$(mktemp)
                        del_code=$(harbor_repo_call "DELETE" "$repo" "/artifacts/${art_digest}" "" "$tmp_del")
                        rm -f "$tmp_del"
                        if [ "$del_code" == "200" ] || [ "$del_code" == "202" ]; then
                            echo "$(gum style --foreground 82 "$(t 'del_tag_art_ok' "$repo" "$tag")")"
                            log_msg "INFO" "Deleted artifact $repo:$tag ($art_digest) in Harbor"
                            clear_cache
                            gum input --placeholder "$(t 'press_enter')"
                            return 0
                        else
                            echo "$(gum style --foreground 196 "$(t 'tagless_one_err' "$del_code")")"
                            log_msg "ERROR" "Failed deleting artifact $repo:$tag in Harbor (HTTP $del_code)"
                            gum input --placeholder "$(t 'press_enter')"
                            return 1
                        fi
                    fi
                    return 1
                fi
            fi
        else
            rm -f "$tmp_art"
        fi
    fi

    echo "$(gum style --foreground 214 "$(t 'del_tag_std_note')")"
    echo
    if ! gum confirm --affirmative "$(t 'del_btn_yes')" --negative "$(t 'cancel')" "$(t 'del_tag_std_confirm' "$repo" "$tag")"; then
        return 1
    fi

    local digest
    digest=$(v2_get_manifest_digest "$repo" "$tag")
    if [ -z "$digest" ]; then
        echo "$(gum style --foreground 196 "$(t 'del_tag_no_digest' "$repo" "$tag")")"
        log_msg "WARN" "Digest not found for $repo:$tag"
        gum input --placeholder "$(t 'press_enter')"
        return 1
    fi

    local status_code
    status_code=$(v2_delete_manifest "$repo" "$digest")
    if [ "$status_code" -eq 202 ] || [ "$status_code" -eq 200 ]; then
        echo "$(gum style --foreground 82 "$(t 'del_tag_std_ok' "$tag" "${digest:0:18}")")"
        log_msg "INFO" "Deleted $repo:$tag (digest: $digest)"
        clear_cache
        gum input --placeholder "$(t 'press_enter')"
        return 0
    elif [ "$status_code" -eq 405 ]; then
        echo "$(gum style --foreground 196 "$(t 'del_http_405')")"
        echo "$(gum style --foreground 214 "$(t 'del_http_405_hint')")"
        log_msg "ERROR" "HTTP 405 deleting $repo:$tag — delete disabled on server"
    else
        echo "$(gum style --foreground 196 "$(t 'tagless_one_err' "$status_code")")"
        log_msg "ERROR" "Failed deleting $repo:$tag (HTTP $status_code)"
    fi

    gum input --placeholder "$(t 'press_enter')"
    return 1
}

manage_tag_action() {
    local repo="$1"
    local tag="$2"

    while true; do
        clear
        print_header
        echo "$(gum style --foreground 212 --bold "$(t 'tag_selected')") $(gum style --foreground 82 --bold "$repo:$tag")"
        echo

        local action
        action=$(gum choose \
            "$(t 'tag_act_pull')" \
            "$(t 'tag_act_digest')" \
            "$(t 'tag_act_history')" \
            "$(t 'tag_act_delete')" \
            "$(t 'enter_cmd_menu')" \
            "$(t 'tag_act_back')")

        if [[ "$action" == :* ]]; then
            process_command "$action"
            [ $? -eq 2 ] && return 2
            continue
        fi

        case "$action" in
            "$(t 'tag_act_pull')") show_pull_command "$repo" "$tag" ;;
            "$(t 'tag_act_digest')") show_tag_digest "$repo" "$tag" ;;
            "$(t 'tag_act_history')") show_tag_history "$repo" "$tag" ;;
            "$(t 'enter_cmd_menu')")
                prompt_command_mode
                [ $? -eq 2 ] && return 2
                ;;
            "$(t 'tag_act_delete')")
                if delete_tag "$repo" "$tag"; then
                    break
                fi
                ;;
            "$(t 'tag_act_back')"|"") break ;;
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
    echo "$(gum style --foreground 212 --bold "$(t 'lbl_image')") $(gum style --foreground 255 "$repo:$tag")"
    echo
    echo "$(gum style --foreground 214 --bold "$(t 'pull_cmd_title')")"
    echo

    gum style \
        --border rounded \
        --border-foreground 82 \
        --padding "0 1" \
        "$(gum style --foreground 255 --bold "$pull_cmd")"

    echo

    if command -v xclip &>/dev/null; then
        echo -n "$pull_cmd" | xclip -selection clipboard
        echo "$(gum style --foreground 240 "$(t 'pull_copied' 'xclip')")"
    elif command -v pbcopy &>/dev/null; then
        echo -n "$pull_cmd" | pbcopy
        echo "$(gum style --foreground 240 "$(t 'pull_copied' 'pbcopy')")"
    fi

    echo
    gum input --placeholder "$(t 'press_enter_return')"
}

manage_repository_action() {
    local repo="$1"

    while true; do
        clear
        print_header
        echo "$(gum style --foreground 212 --bold "$(t 'repo_selected')") $(gum style --foreground 255 "$repo")"
        echo

        local action
        action=$(gum choose \
            "$(t 'repo_act_tags')" \
            "$(t 'repo_act_delete')" \
            "$(t 'enter_cmd_menu')" \
            "$(t 'back')")

        case "$action" in
            "$(t 'repo_act_tags')")
                show_repository_tags "$repo"
                [ $? -eq 2 ] && return 2
                ;;
            "$(t 'repo_act_delete')")
                delete_repository "$repo"
                break
                ;;
            "$(t 'enter_cmd_menu')")
                prompt_command_mode
                [ $? -eq 2 ] && return 2
                ;;
            "$(t 'back')"|"") break ;;
        esac
    done
}

delete_repository_v2_manifests() {
    local repo="$1"

    local tmp_tags
    tmp_tags=$(mktemp)
    export REGISTRY_URL USERNAME PASSWORD ENABLE_CACHE CACHE_TTL CACHE_DIR LOG_FILE
    export -f log_cache api_request api_request_paged

    gum spin --spinner line --spinner.foreground 208 \
        --title "$(t 'repo_v2_spin' "$repo")" \
        -- bash -c 'api_request_paged "/v2/$1/tags/list?n=100" "tags" > "$2"' _ "$repo" "$tmp_tags"

    local tags_json
    tags_json=$(cat "$tmp_tags")
    rm -f "$tmp_tags"

    local tags
    tags=$(echo "$tags_json" | jq -r '.tags[]?' 2>/dev/null)

    if [ -z "$tags" ]; then
        echo "$(gum style --foreground 214 "$(t 'repo_v2_no_tags' "$repo")")"
        return 0
    fi

    local digests=()
    local d tag
    while IFS= read -r tag; do
        [ -z "$tag" ] && continue
        d=$(v2_get_manifest_digest "$repo" "$tag")
        if [ -n "$d" ]; then
            digests+=("$d")
        else
            echo "$(gum style --foreground 214 "$(t 'repo_v2_no_digest' "$tag")")"
        fi
    done <<< "$tags"

    local unique_digests
    unique_digests=$(printf "%s\n" "${digests[@]}" | sed '/^$/d' | sort -u)

    local deleted_count=0 fail_count=0
    while IFS= read -r d; do
        [ -z "$d" ] && continue
        local status_code
        status_code=$(v2_delete_manifest "$repo" "$d")
        if [ "$status_code" -eq 202 ] || [ "$status_code" -eq 200 ] || [ "$status_code" -eq 404 ]; then
            echo "$(gum style --foreground 82 "$(t 'repo_v2_del_ok' "${d:0:18}")")"
            log_msg "INFO" "Deleted manifest $repo ($d)"
            ((deleted_count++))
        elif [ "$status_code" -eq 405 ]; then
            echo "$(gum style --foreground 196 "$(t 'del_http_405')")"
            echo "$(gum style --foreground 214 "$(t 'del_http_405_hint')")"
            ((fail_count++))
            break
        else
            echo "$(gum style --foreground 196 "$(t 'repo_v2_del_err' "${d:0:18}" "$status_code")")"
            log_msg "ERROR" "Failed deleting $repo ($d): HTTP $status_code"
            ((fail_count++))
        fi
    done <<< "$unique_digests"

    echo "$(gum style --bold "$(t 'repo_v2_summary' "$deleted_count" "$fail_count")")"
    [ "$fail_count" -eq 0 ]
}

delete_repository() {
    local repo="$1"

    clear
    print_header
    echo "$(gum style --foreground 196 --bold "$(t 'repo_del_title' "$repo")")"
    echo

    if ! gum confirm --affirmative "$(t 'del_btn_yes')" --negative "$(t 'cancel')" "$(t 'repo_del_confirm' "$repo")"; then
        log_msg "INFO" "Cancelled delete for $repo"
        return 1
    fi

    if [ "$REGISTRY_TYPE" == "harbor" ]; then
        local tmp_out code
        tmp_out=$(mktemp)
        export REGISTRY_URL USERNAME PASSWORD HARBOR_API_URL
        export -f harbor_call harbor_encode_repo harbor_repo_call

        gum spin --spinner line --spinner.foreground 208 \
            --title "$(t 'repo_del_harbor_spin' "$repo")" \
            -- bash -c 'harbor_repo_call "DELETE" "$1" "" "" "$2" > "$2.code"' _ "$repo" "$tmp_out"

        code=$(cat "${tmp_out}.code" 2>/dev/null || echo "000")
        local resp
        resp=$(cat "$tmp_out" 2>/dev/null)
        rm -f "$tmp_out" "${tmp_out}.code"

        if [ "$code" == "200" ] || [ "$code" == "202" ]; then
            echo "$(gum style --foreground 82 "$(t 'repo_del_harbor_ok' "$repo")")"
            log_msg "INFO" "Repository $repo deleted from Harbor"
        else
            echo "${ERROR_STYLE} $(t 'repo_del_harbor_err' "$repo" "$code")"
            [ -n "$resp" ] && echo "$resp"
            log_msg "ERROR" "Failed deleting $repo in Harbor (HTTP $code): $resp"
        fi
    else
        log_msg "WARN" "Deleting repository $repo in standard Docker Registry"
        delete_repository_v2_manifests "$repo"

        echo
        if gum confirm --affirmative "$(t 'yes')" --negative "$(t 'no')" "$(t 'repo_del_ssh_confirm')" < /dev/tty; then
            run_docker_registry_ssh_gc "$repo" "false"
        fi
    fi

    clear_cache
    echo
    gum input --placeholder "$(t 'press_enter_continue')"
}

delete_project() {
    local project="$1"
    local repos_list="$2"

    clear
    print_header
    echo "$(gum style --foreground 196 --bold "$(t 'proj_del_title' "$project")")"
    echo

    if ! gum confirm --affirmative "$(t 'proj_del_btn')" --negative "$(t 'cancel')" "$(t 'proj_del_confirm' "$project")"; then
        log_msg "INFO" "Cancelled delete for project $project"
        return 1
    fi

    local project_repos
    project_repos=$(echo "$repos_list" | grep -E "^${project}/|^${project}$")

    if [ "$REGISTRY_TYPE" == "harbor" ]; then
        local tmp_list code
        tmp_list=$(mktemp)
        code=$(harbor_call "GET" "/api/v2.0/projects/${project}/repositories?page=1&page_size=100" "" "$tmp_list")
        if [ "$code" == "200" ]; then
            local harbor_repos
            harbor_repos=$(jq -r '.[].name // empty' "$tmp_list" 2>/dev/null)
            [ -n "$harbor_repos" ] && project_repos="$harbor_repos"
        fi
        rm -f "$tmp_list"

        local tmp_out del_code
        tmp_out=$(mktemp)

        if [ -n "$project_repos" ]; then
            echo "$(gum style --foreground 212 "$(t 'proj_del_repos_msg' "$project")")"
            while IFS= read -r repo; do
                [ -z "$repo" ] && continue
                del_code=$(harbor_repo_call "DELETE" "$repo" "" "" "$tmp_out")
                if [ "$del_code" == "200" ] || [ "$del_code" == "202" ]; then
                    echo "$(gum style --foreground 82 "$(t 'proj_del_repo_ok' "$repo")")"
                    log_msg "INFO" "Deleted repo $repo while deleting project $project"
                else
                    echo "$(gum style --foreground 196 "$(t 'proj_del_repo_err' "$repo" "$del_code")")"
                    cat "$tmp_out"
                fi
            done <<< "$project_repos"
        fi

        del_code=$(harbor_call "DELETE" "/api/v2.0/projects/${project}" "" "$tmp_out")
        local resp
        resp=$(cat "$tmp_out" 2>/dev/null)
        rm -f "$tmp_out"

        if [ "$del_code" == "200" ] || [ "$del_code" == "202" ]; then
            echo "$(gum style --foreground 82 --bold "$(t 'proj_del_harbor_ok' "$project")")"
            log_msg "INFO" "Project $project deleted from Harbor"
        else
            echo "${ERROR_STYLE} $(t 'proj_del_harbor_err' "$project" "$del_code")"
            [ -n "$resp" ] && echo "$resp"
            log_msg "ERROR" "Failed deleting project $project in Harbor (HTTP $del_code): $resp"
        fi
    else
        if [ -n "$project_repos" ]; then
            while IFS= read -r repo; do
                [ -z "$repo" ] && continue
                echo "$(gum style --foreground 212 "$(t 'proj_del_proc_repo' "$repo")")"
                delete_repository_v2_manifests "$repo"
            done <<< "$project_repos"
        fi

        echo
        if gum confirm --affirmative "$(t 'yes')" --negative "$(t 'no')" "$(t 'proj_del_ssh_confirm' "$project")" < /dev/tty; then
            run_docker_registry_ssh_gc "$project" "false"
        fi
    fi

    clear_cache
    echo
    gum input --placeholder "$(t 'press_enter_continue')"
    return 0
}

manage_project_action() {
    local project="$1"
    local repos_list="$2"

    while true; do
        clear
        print_header
        echo "$(gum style --foreground 212 --bold "$(t 'proj_selected')") $(gum style --foreground 255 --bold "$project")"
        echo

        local action
        action=$(gum choose \
            "$(t 'proj_act_open')" \
            "$(t 'proj_act_upload')" \
            "$(t 'proj_act_delete')" \
            "$(t 'enter_cmd_menu')" \
            "$(t 'proj_act_back')" < /dev/tty)

        case "$action" in
            "$(t 'proj_act_open')")
                show_project_repositories "$project" "$repos_list"
                local rc=$?
                [ $rc -eq 2 ] && return 2
                return 0
                ;;
            "$(t 'proj_act_upload')")
                push_image_from_archive "$project"
                return 0
                ;;
            "$(t 'proj_act_delete')")
                if delete_project "$project" "$repos_list"; then
                    return 0
                fi
                ;;
            "$(t 'enter_cmd_menu')")
                prompt_command_mode
                [ $? -eq 2 ] && return 2
                ;;
            "$(t 'proj_act_back')"|"")
                return 0
                ;;
        esac
    done
}

show_project_repositories() {
    local project="$1"
    local repos_list="$2"

    while true; do
        get_term_dimensions
        clear
        print_header
        echo "$(gum style --foreground 212 --bold "$(t 'lbl_project')") $(gum style --foreground 255 "$project")"

        local filtered_repos
        filtered_repos=$(echo "$repos_list" | grep -E "^${project}/|^${project}$")

        if [ -z "$filtered_repos" ]; then
            echo
            echo "$(gum style --foreground 214 "$(t 'proj_no_images')")"
            echo
            if gum confirm --affirmative "$(t 'yes')" --negative "$(t 'no')" "$(t 'proj_upload_confirm' "$project")" < /dev/tty; then
                push_image_from_archive "$project"
                return 0
            fi
            break
        fi

        local tmp_csv
        tmp_csv=$(mktemp)
        echo "$(t 'col_image'),$(t 'col_tags'),$(t 'col_updated'),$(t 'col_size')" > "$tmp_csv"

        export REGISTRY_URL USERNAME PASSWORD SHOW_TAG_COUNT SHOW_UPDATED_DATE SHOW_SIZE CATALOG_N ENABLE_CACHE CACHE_TTL CACHE_DIR HIDE_TAGLESS_IMAGES LOG_FILE
        export -f api_request api_request_paged format_bytes get_repo_info log_cache

        gum spin --spinner line --spinner.foreground 208 \
            --title "$(t 'meta_spin')" \
            -- bash -c 'echo "$1" | xargs -I{} -P 8 bash -c "get_repo_info \"{}\"" >> "$2"' _ "$filtered_repos" "$tmp_csv"

        clear
        print_header
        echo "$(gum style --foreground 212 --bold "$(t 'lbl_project')") $(gum style --foreground 255 "$project")"
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
            [ $? -eq 2 ] && return 2
            continue
        fi

        local selected_repo
        selected_repo=$(echo "$selected_row" | head -n 1 | awk -F',' '{print $1}' | tr -d '[:space:]' | sed 's/\x1b\[[0-9;]*m//g')

        [ -z "$selected_repo" ] && break
        [[ "$selected_repo" == *"Usage:"* ]] || [ "$selected_repo" == "$(t 'col_image')" ] && continue

        manage_repository_action "$selected_repo"
        [ $? -eq 2 ] && return 2
    done
}

main() {
    while true; do
        if [ -z "$CONNECTED_URL" ]; then
            configure_registry

            if check_connection_verbose; then
                CONNECTED_URL="$REGISTRY_URL"
                detect_registry_type
            else
                CONNECTED_URL=""
                gum confirm --affirmative "$(t 'yes')" --negative "$(t 'no')" "$(t 'conn_retry')" < /dev/tty || exit 0
                continue
            fi
        fi

        get_term_dimensions
        clear
        print_header

        local tmp_catalog tmp_harbor_proj
        tmp_catalog=$(mktemp)
        tmp_harbor_proj=$(mktemp)

        export REGISTRY_URL USERNAME PASSWORD ENABLE_CACHE CACHE_TTL CACHE_DIR LOG_FILE CATALOG_N REGISTRY_TYPE HARBOR_API_URL
        export -f api_request api_request_paged harbor_call get_harbor_projects log_cache

        gum spin --spinner line --spinner.foreground 208 \
            --title "$(t 'main_spin_projects')" \
            -- bash -c '
                api_request_paged "/v2/_catalog?n=${CATALOG_N:-100}" "repositories" > "$1"
                get_harbor_projects > "$2"
            ' _ "$tmp_catalog" "$tmp_harbor_proj"

        local catalog_json harbor_projects
        catalog_json=$(cat "$tmp_catalog")
        harbor_projects=$(cat "$tmp_harbor_proj")
        rm -f "$tmp_catalog" "$tmp_harbor_proj"

        local repos
        repos=$(echo "$catalog_json" | jq -r '.repositories[]?' 2>/dev/null)

        local projects
        projects=$(printf "%s\n%s\n" "$(echo "$repos" | awk -F'/' '{print $1}')" "$harbor_projects" | sed '/^$/d' | sort -u)

        if [ -z "$projects" ]; then
            clear
            print_header
            echo "$(gum style --foreground 214 "$(t 'main_empty_reg')")"
            echo "$(gum style --foreground 240 "$(t 'main_empty_hint')")"
            echo
            if ! gum confirm --affirmative "$(t 'main_empty_yes')" --negative "$(t 'main_empty_no')" "$(t 'main_empty_confirm')" < /dev/tty; then
                CONNECTED_URL=""
                REGISTRY_URL=""
                USERNAME=""
                PASSWORD=""
                REGISTRY_TYPE="docker-registry"
                HARBOR_API_URL=""
                continue
            fi
            push_image_from_archive
            continue
        fi

        local tmp_csv
        tmp_csv=$(mktemp)
        echo "$(t 'col_project'),$(t 'col_images')" > "$tmp_csv"

        while read -r proj; do
            [ -z "$proj" ] && continue
            local count="N/A"
            if [ "$SHOW_TAG_COUNT" == "true" ]; then
                count=$(echo "$repos" | grep -c -E "^${proj}/|^${proj}$" || true)
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

        [[ "$selected_project" == *"Usage:"* ]] || [ "$selected_project" == "$(t 'col_project')" ] && continue

        manage_project_action "$selected_project" "$repos"
    done
}

main
