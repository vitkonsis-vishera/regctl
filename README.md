# regctl - Terminal Docker Registry Manager

[English](#english) | [Русский](#русский)

---

<a name="english"></a>
## 🇬🇧 English

**regctl** is a feature-rich, interactive Terminal User Interface (TUI) tool written in Bash for managing Docker Registries (Docker Registry v2 API / Harbor). It provides an intuitive CLI dashboard to inspect, upload, analyze, and purge Docker images directly from your terminal.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Bash](https://img.shields.io/badge/bash-%3E%3D4.0-brightgreen.svg)

---

### ✨ Features

* 🖥️ **Interactive TUI Interface**: Powered by [`charmbracelet/gum`](https://github.com/charmbracelet/gum) for clean lists, interactive filtering, and styled tables.
* 🔒 **HTTP & HTTPS Support**: Automatic fallback to HTTP with auto-configuration of Docker's `insecure-registries` in `/etc/docker/daemon.json`.
* 📦 **Direct Archive Upload**: Import `.tar`, `.tar.gz`, or `.tgz` Docker image archives, tag them, and push directly to your registry with interactive menu prompts.
* 🔍 **Search & Filtering**: Search repositories, tags, and images using built-in command mode (`:find`).
* 📜 **Layer History & Inspection**: Inspect image layer histories and attempt to reconstruct original `Dockerfile` instructions.
* 🗑️ **Tag & Repository Purging**: Completely delete specific tags or entire repositories (includes automated Remote SSH Garbage Collection to free up actual disk space).
* ⚡ **API Caching**: Local caching mechanism (`~/.cache/regctl`) to speed up broad catalog browsing with customizable TTL.
* 📄 **Pagination Support**: Fully handles RFC 5988 `Link` headers for paginated catalog responses (`/v2/_catalog`).

---

### 📋 Prerequisites & Dependencies

The script automatically attempts to install missing dependencies on Debian/Ubuntu systems via `apt-get`:

* **Bash** 4.0+
* **curl**
* **jq**
* **docker**
* **gum** ([charmbracelet/gum](https://github.com/charmbracelet/gum)) — *If `gum` is not available in package managers, place a `.deb` package of `gum` in the same directory as the script.*
* **sshpass** / **ssh** (optional, required for Remote Garbage Collection over SSH).
* **xclip** or **pbcopy** (optional, for copying `docker pull` commands to clipboard).

---

### 🚀 Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/your-username/regctl.git
   cd regctl
   ```

2. Make the script executable:
   ```bash
   chmod +x regctl.sh
   ```

3. Run `regctl`:
   ```bash
   ./regctl.sh
   ```

---

### ⌨️ Command Mode Reference

Press `Ctrl+C` in most navigation views to invoke the **Command Mode** prompt (`:`):

| Command | Shortcuts | Description |
| :--- | :--- | :--- |
| `:upload` | `:push` | Opens the file browser to select a `.tar` archive and push it to the registry |
| `:find <query>`| `:f` | Search repositories or tags matching `<query>` |
| `:settings` | `:st` | Open UI settings (toggle tag count, size display, cache TTL, etc.) |
| `:trash` | `:clean`| Execute remote Docker Registry Garbage Collector over SSH |
| `:disconnect` | `:ds` | Disconnect from the current registry and switch connection parameters |
| `:help` | `:h` | Display in-app command help screen |
| `:quit` | `:q`, `:exit` | Exit `regctl` |

---

### ⚙️ Configuration

Configurations are automatically generated and saved at `~/.config/regctl/config.env`:

```env
SHOW_TAG_COUNT=true
SHOW_UPDATED_DATE=true
SHOW_SIZE=true
CATALOG_N=10000
ENABLE_CACHE=true
CACHE_TTL=300
HIDE_TAGLESS_IMAGES=false
```

Logs are stored in `/var/log/regctl/log` (or fallback path) for debugging connectivity and cache hits.

---

<br/>

---

<a name="русский"></a>
## 🇷🇺 Русский

**regctl** — это интерактивная утилита командной строки (TUI) на Bash для управления приватными реестрами Docker (Docker Registry v2 API / Harbor). Позволяет просматривать, загружать, анализировать и полностью удалять Docker-образы через удобный консольный интерфейс.

---

### ✨ Основные возможности

* 🖥️ **Интерактивный TUI-интерфейс**: Работает на базе [`charmbracelet/gum`](https://github.com/charmbracelet/gum), обеспечивая стильные таблицы, списки и выбор элементов.
* 🔒 **Поддержка HTTP и HTTPS**: Автоматическое переключение на HTTP с возможностью автонастройки `insecure-registries` в файле `/etc/docker/daemon.json`.
* 📦 **Загрузка из архивов**: Поддержка файлов `.tar`, `.tar.gz` и `.tgz`. Скрипт сам выполнит `docker load`, задаст новые теги и отправит образ в Registry (`docker push`).
* 🔍 **Поиск по реестру**: Поиск по репозиториям и тегам с помощью встроенной команды `:find`.
* 📜 **Анализ слоев (Dockerfile)**: Просмотр истории слоев образа и попытка восстановления исходного Dockerfile.
* 🗑️ **Удаление и очистка диска**: Удаление отдельных тегов или репозиториев целиком с последующим удалением каталогов и запуском Garbage Collector через SSH.
* ⚡ **Кэширование API**: Локальный кэш (`~/.cache/regctl`) с гибкой настройкой TTL для ускорения работы с крупными каталогами.
* 📄 **Поддержка пагинации**: Корректная обработка заголовков RFC 5988 `Link` при запросе списка репозиториев.

---

### 📋 Зависимости

При отсутствии необходимых утилит скрипт пытается автоматически установить их через `apt-get` (для Debian/Ubuntu):

* **Bash** 4.0+
* **curl**
* **jq**
* **docker**
* **gum** ([charmbracelet/gum](https://github.com/charmbracelet/gum)) — *Если `gum` отсутствует в репозиториях дистрибутива, положите файл `.deb` с пакетом `gum` рядом со скриптом.*
* **sshpass** / **ssh** (опционально, требуется для выполнения полных очисток диска на сервере).
* **xclip** или **pbcopy** (опционально, для копирования команд `docker pull` в буфер обмена).

---

### 🚀 Быстрый запуск

1. Склонируйте репозиторий:
   ```bash
   git clone https://github.com/your-username/regctl.git
   cd regctl
   ```

2. Сделайте скрипт исполняемым:
   ```bash
   chmod +x regctl.sh
   ```

3. Запустите утилиту:
   ```bash
   ./regctl.sh
   ```

---

### ⌨️ Справочник команд командного режима

Нажатие `Ctrl+C` в меню навигации вызывает строку ввода команд (`:`):

| Команда | Сокращение | Описание |
| :--- | :--- | :--- |
| `:upload` | `:push` | Выбор `.tar` архива через файловый менеджер и отправка в Registry |
| `:find <запрос>`| `:f` | Быстрый поиск по репозиториям и тегам |
| `:settings` | `:st` | Меню настроек (отображение размера, даты, TTL кэша и т.д.) |
| `:trash` | `:clean`| Удаление неиспользуемых слоев (Garbage Collector) на сервере через SSH |
| `:disconnect` | `:ds` | Отключение от текущего реестра и смена данных подключения |
| `:help` | `:h` | Вызов справки по командам |
| `:quit` | `:q`, `:exit` | Выход из программы |

---

### ⚙️ Конфигурация

Файл конфигурации автоматически создается по пути `~/.config/regctl/config.env`:

```env
SHOW_TAG_COUNT=true
SHOW_UPDATED_DATE=true
SHOW_SIZE=true
CATALOG_N=10000
ENABLE_CACHE=true
CACHE_TTL=300
HIDE_TAGLESS_IMAGES=false
```

Логи работы утилиты сохраняются в `/var/log/regctl/log`.

---

### 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
