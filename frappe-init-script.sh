#!/bin/bash
# Compatible with: Linux, macOS, Windows (WSL/Git Bash)
# Usage: ./frappe-bench-startup.sh
# 
# Features:
# - Single site initialization (multi-site ready bench)
# - Strict Node.js version from NODE_VERSION variable
# - Idempotent (safe to re-run)

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# =============================================================================
# CONFIGURATION
# =============================================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/tmp/frappe-install-$(date +%Y%m%d-%H%M%S).log"

# Version Configuration - CHANGE THESE AS NEEDED
readonly NODE_VERSION="24"          # Node.js version (must be available in NVM)
readonly PYTHON_VERSION="3.14"      # Python version (must be available in pyenv)
readonly FRAPPE_VERSION="version-16" # Frappe branch

# =============================================================================
# OS DETECTION
# =============================================================================
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if grep -q Microsoft /proc/version 2>/dev/null; then
            OS_TYPE="wsl"
        else
            OS_TYPE="linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS_TYPE="macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]]; then
        OS_TYPE="windows"
    else
        OS_TYPE="unknown"
    fi
}

detect_os

# =============================================================================
# PACKAGE MANAGER DETECTION
# =============================================================================
get_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v brew >/dev/null 2>&1; then
        echo "brew"
    else
        echo "unknown"
    fi
}

# =============================================================================
# COLORS & LOGGING
# =============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# =============================================================================
# ERROR HANDLER
# =============================================================================
handle_error() {
    local exit_code=$?
    log_error "Script failed at line $1 with exit code $exit_code"
    log_error "Check log file: $LOG_FILE"
    exit $exit_code
}

trap 'handle_error $LINENO' ERR

# =============================================================================
# ENVIRONMENT CHECK
# =============================================================================
check_environment() {
    log_info "Checking environment..."
    log_info "Detected OS: $OS_TYPE"
    log_info "Package Manager: $(get_package_manager)"

    if [[ ! -f /.dockerenv ]] && [[ "$OS_TYPE" != "windows" ]] && [[ "$OS_TYPE" != "wsl" ]]; then
        log_warning "Not running in Docker container"
    fi

    # Required environment variables
    local required_vars=(
        "MARIADB_CONTAINER_NAME"
        "REDIS_CACHE_CONTAINER_NAME"
        "REDIS_QUEUE_CONTAINER_NAME"
        "REDIS_SOCKETIO_CONTAINER_NAME"
        "SITE_NAME"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable $var is not set"
            exit 1
        fi
    done

    log_success "Environment check passed"
}

# =============================================================================
# WORKSPACE SETUP
# =============================================================================
setup_workspace() {
    log_info "Setting up workspace permissions..."

    if [[ -d "/workspace" ]]; then
        sudo chown -R "$(whoami)":"$(whoami)" /workspace 2>/dev/null || true
        log_success "Workspace permissions set"
    else
        log_warning "Workspace directory not found, skipping..."
    fi
}

# =============================================================================
# SHELL SETUP
# =============================================================================
setup_shell() {
    log_info "Setting up shell environment..."

    # Add useful aliases (avoid duplicates)
    if ! grep -q "alias bench=" ~/.bashrc 2>/dev/null; then
        cat >> ~/.bashrc << 'EOF'

# Frappe aliases
alias ll='ls -al'
alias bench='~/.local/bin/bench'
alias frappe-logs='tail -f ~/frappe-bench/logs/*'
EOF
    fi

    # Apply immediately
    alias ll='ls -al' 2>/dev/null || true

    log_success "Shell environment configured"
}

# =============================================================================
# SYSTEM DEPENDENCIES
# =============================================================================
install_system_deps() {
    log_info "Installing system dependencies..."

    local pkg_manager
    pkg_manager=$(get_package_manager)

    case "$pkg_manager" in
        "apt")
            install_deps_apt
            ;;
        "yum"|"dnf")
            install_deps_redhat
            ;;
        "pacman")
            install_deps_arch
            ;;
        "brew")
            install_deps_macos
            ;;
        *)
            log_warning "Unknown package manager, trying apt as default..."
            install_deps_apt
            ;;
    esac

    log_success "System dependencies installed"
}

install_deps_apt() {
    sudo apt update -qq || log_warning "apt update failed, continuing..."

    local packages=(
        "build-essential"
        "zlib1g-dev"
        "libncurses5-dev"
        "libgdbm-dev"
        "libnss3-dev"
        "libssl-dev"
        "libsqlite3-dev"
        "libreadline-dev"
        "libffi-dev"
        "libbz2-dev"
        "curl"
        "git"
        "vim"
        "wget"
        "netcat-openbsd"
        "libxml2-dev"
        "libxslt1-dev"
        "libldap2-dev"
        "libsasl2-dev"
    )

    sudo apt-get install -y "${packages[@]}" || log_warning "Some packages failed, continuing..."
}

install_deps_redhat() {
    local installer="yum"
    command -v dnf >/dev/null 2>&1 && installer="dnf"

    sudo $installer update -y || log_warning "$installer update failed, continuing..."

    local packages=(
        "gcc"
        "gcc-c++"
        "make"
        "zlib-devel"
        "ncurses-devel"
        "gdbm-devel"
        "nss-devel"
        "openssl-devel"
        "sqlite-devel"
        "readline-devel"
        "libffi-devel"
        "bzip2-devel"
        "curl"
        "git"
        "vim"
        "wget"
        "nmap-ncat"
        "libxml2-devel"
        "libxslt-devel"
        "openldap-devel"
    )

    sudo $installer install -y "${packages[@]}" || log_warning "Some packages failed, continuing..."
}

install_deps_arch() {
    sudo pacman -Sy || log_warning "pacman update failed, continuing..."

    local packages=(
        "base-devel"
        "zlib"
        "ncurses"
        "gdbm"
        "nss"
        "openssl"
        "sqlite"
        "readline"
        "libffi"
        "bzip2"
        "curl"
        "git"
        "vim"
        "wget"
        "gnu-netcat"
        "libxml2"
        "libxslt"
        "libldap"
    )

    sudo pacman -S --noconfirm "${packages[@]}" || log_warning "Some packages failed, continuing..."
}

install_deps_macos() {
    if ! command -v brew >/dev/null 2>&1; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    brew update || log_warning "brew update failed, continuing..."

    local packages=(
        "openssl"
        "readline"
        "sqlite3"
        "xz"
        "zlib"
        "tcl-tk"
        "curl"
        "git"
        "vim"
        "wget"
        "netcat"
        "libxml2"
        "libxslt"
        "openldap"
    )

    for package in "${packages[@]}"; do
        brew install "$package" || log_warning "Failed to install $package, continuing..."
    done
}

# =============================================================================
# NODE.JS SETUP
# =============================================================================
setup_nodejs() {
    log_info "Setting up Node.js ${NODE_VERSION}..."

    # Install NVM if not exists
    if [[ ! -d "$HOME/.nvm" ]]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    fi

    # Load NVM into current shell
    export NVM_DIR="$HOME/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"

    # Check if requested version is already installed
    if ! nvm ls 2>/dev/null | grep -q "v${NODE_VERSION}"; then
        log_info "Node.js ${NODE_VERSION} not installed, installing..."
        
        if ! nvm install "$NODE_VERSION"; then
            log_error "Failed to install Node.js ${NODE_VERSION}"
            log_info "Available versions (last 10):"
            nvm ls-remote --node 2>/dev/null | tail -10 | awk '{print $1}' || true
            exit 1
        fi
    fi

    # STRICTLY use the defined NODE_VERSION - no fallback
    log_info "Activating Node.js ${NODE_VERSION}..."
    nvm use "$NODE_VERSION"
    
    # Set as default for new shells
    nvm alias default "$NODE_VERSION" 2>/dev/null || true

    # Verify the active version matches
    local active_version
    active_version=$(node --version 2>/dev/null | sed 's/^v//')
    
    if [[ -z "$active_version" ]]; then
        log_error "Node.js not found after installation"
        exit 1
    fi

    # Install global packages
    log_info "Installing global npm packages..."
    npm install -g yarn || log_warning "yarn installation failed, continuing..."
    npm install -g node-sass 2>/dev/null || log_warning "node-sass installation failed (optional), continuing..."

    # Final verification
    log_info "✓ Node: $(node --version) | NPM: $(npm --version) | Yarn: $(yarn --version 2>/dev/null || echo 'N/A')"
    log_success "Node.js ${NODE_VERSION} activated successfully"
}

# =============================================================================
# PYTHON SETUP
# =============================================================================
setup_python() {
    log_info "Setting up Python ${PYTHON_VERSION}..."

    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"

    # Install pyenv if not exists
    if [[ ! -d "$PYENV_ROOT" ]]; then
        log_info "Installing pyenv..."
        curl https://pyenv.run | bash || {
            log_warning "pyenv installation failed, trying git clone..."
            git clone https://github.com/pyenv/pyenv.git ~/.pyenv 2>/dev/null || true
        }
    fi

    # Add to shell profiles (avoid duplicates)
    for profile in ~/.bashrc ~/.zshrc ~/.profile; do
        if [[ -f "$profile" ]] || [[ "$profile" == ~/.bashrc ]]; then
            if ! grep -q "PYENV_ROOT" "$profile" 2>/dev/null; then
                {
                    echo ''
                    echo 'export PYENV_ROOT="$HOME/.pyenv"'
                    echo 'export PATH="$PYENV_ROOT/bin:$PATH"'
                    echo 'eval "$(pyenv init --path)" 2>/dev/null || true'
                    echo 'eval "$(pyenv init -)" 2>/dev/null || true'
                } >> "$profile" 2>/dev/null || true
            fi
        fi
    done

    # Initialize pyenv for current session
    if [[ -f "$PYENV_ROOT/bin/pyenv" ]]; then
        eval "$($PYENV_ROOT/bin/pyenv init --path)" 2>/dev/null || true
        eval "$($PYENV_ROOT/bin/pyenv init -)" 2>/dev/null || true
    fi

    # OS-specific Python build dependencies
    case "$OS_TYPE" in
        "macos")
            if command -v brew >/dev/null 2>&1; then
                export LDFLAGS="-L$(brew --prefix openssl)/lib -L$(brew --prefix readline)/lib -L$(brew --prefix sqlite)/lib -L$(brew --prefix zlib)/lib"
                export CPPFLAGS="-I$(brew --prefix openssl)/include -I$(brew --prefix readline)/include -I$(brew --prefix sqlite)/include -I$(brew --prefix zlib)/include"
                export PYTHON_CONFIGURE_OPTS="--enable-framework"
            fi
            ;;
        "wsl")
            export PYTHON_CONFIGURE_OPTS="--enable-shared"
            ;;
    esac

    # Install Python version
    log_info "Compiling Python ${PYTHON_VERSION} (this may take a while)..."
    if command -v pyenv >/dev/null 2>&1; then
        if ! pyenv versions 2>/dev/null | grep -q "$PYTHON_VERSION"; then
            pyenv install -v "$PYTHON_VERSION" 2>&1 || {
                log_warning "Python ${PYTHON_VERSION} installation failed"
                log_info "Trying to use system Python as fallback..."
                if command -v python3 >/dev/null 2>&1; then
                    log_info "Using system Python: $(python3 --version)"
                    return 0
                fi
                log_error "No Python available"
                exit 1
            }
        fi

        pyenv global "$PYTHON_VERSION" 2>/dev/null || true
    fi

    # Verify Python installation
    if command -v python >/dev/null 2>&1; then
        log_info "Python: $(python --version)"
    elif command -v python3 >/dev/null 2>&1; then
        log_info "Python: $(python3 --version)"
        # Create python symlink if needed
        if [[ ! -L "$HOME/.local/bin/python" ]] && [[ -d "$HOME/.local/bin" ]]; then
            ln -sf "$(command -v python3)" "$HOME/.local/bin/python" 2>/dev/null || true
        fi
    else
        log_error "No Python executable found"
        exit 1
    fi

    # Ensure pip is available
    if ! command -v pip >/dev/null 2>&1 && ! command -v pip3 >/dev/null 2>&1; then
        log_warning "pip not found, installing..."
        if command -v python3 >/dev/null 2>&1; then
            python3 -m ensurepip --default-pip 2>/dev/null || {
                curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
                python3 /tmp/get-pip.py
                rm -f /tmp/get-pip.py
            }
        fi
    fi

    log_success "Python environment configured"
}

# =============================================================================
# FRAPPE BENCH INSTALLATION
# =============================================================================
install_frappe_bench() {
    log_info "Installing Frappe Bench..."

    # Try different pip commands
    local pip_cmd=""
    if command -v pip >/dev/null 2>&1; then
        pip_cmd="pip"
    elif command -v pip3 >/dev/null 2>&1; then
        pip_cmd="pip3"
    else
        log_error "No pip command found"
        exit 1
    fi

    # Install or upgrade frappe-bench
    $pip_cmd install --upgrade frappe-bench || {
        log_warning "pip install had warnings, checking if bench is available..."
    }

    # Find bench executable
    local bench_path=""
    if [[ -f "$HOME/.local/bin/bench" ]]; then
        bench_path="$HOME/.local/bin/bench"
    elif command -v bench >/dev/null 2>&1; then
        bench_path=$(command -v bench)
    elif [[ -n "${PYENV_ROOT:-}" ]] && [[ -f "$PYENV_ROOT/shims/bench" ]]; then
        bench_path="$PYENV_ROOT/shims/bench"
    fi

    if [[ -n "$bench_path" ]]; then
        log_info "Found bench at: $bench_path"
        "$bench_path" --version || true
        # Add to bashrc if not exists
        if ! grep -q "alias bench=" ~/.bashrc 2>/dev/null; then
            echo "alias bench='$bench_path'" >> ~/.bashrc 2>/dev/null || true
        fi
        export BENCH_CMD="$bench_path"
    else
        log_error "bench command not found after installation"
        log_info "Searching for bench..."
        find "$HOME" -name "bench" -type f 2>/dev/null | head -5 || true
        exit 1
    fi

    log_success "Frappe Bench installed"
}

# =============================================================================
# FRAPPE BENCH INITIALIZATION
# =============================================================================
init_frappe_bench() {
    log_info "Initializing Frappe Bench..."

    # Find Python executable
    local python_path=""
    if command -v pyenv >/dev/null 2>&1 && pyenv which python >/dev/null 2>&1; then
        python_path=$(pyenv which python)
    elif command -v python3 >/dev/null 2>&1; then
        python_path=$(command -v python3)
    elif command -v python >/dev/null 2>&1; then
        python_path=$(command -v python)
    else
        log_error "No Python executable found"
        exit 1
    fi

    log_info "Using Python at: $python_path"

    # Use the bench command we found earlier
    local bench_cmd="${BENCH_CMD:-$HOME/.local/bin/bench}"

    # Determine working directory
    local work_dir="/workspace"
    if [[ ! -d "$work_dir" ]]; then
        work_dir="$HOME"
    fi
    cd "$work_dir" || {
        log_error "Cannot access working directory: $work_dir"
        exit 1
    }

    # Check if frappe-bench already exists
    if [[ -d "frappe-bench" ]]; then
        log_warning "frappe-bench directory already exists, skipping initialization"
        cd frappe-bench || exit 1
        export FRAPPE_BENCH_DIR="$(pwd)"
        return 0
    fi

    # Initialize bench with proper configuration
    log_info "Creating frappe-bench in $(pwd)..."
    "$bench_cmd" init \
        --skip-redis-config-generation \
        --python "$python_path" \
        --frappe-branch "$FRAPPE_VERSION" \
        frappe-bench \
        --verbose

    # Verify directory was created
    if [[ ! -d "frappe-bench" ]]; then
        log_error "frappe-bench directory was not created"
        log_info "Current directory contents:"
        ls -la
        exit 1
    fi

    cd frappe-bench || exit 1
    export FRAPPE_BENCH_DIR="$(pwd)"
    log_info "Frappe Bench directory: $FRAPPE_BENCH_DIR"

    log_success "Frappe Bench initialized"
}

# =============================================================================
# BENCH CONFIGURATION (GLOBAL - MULTI-SITE READY)
# =============================================================================
setup_bench_config() {
    log_info "Setting up bench requirements and configuration..."

    # Find frappe-bench directory
    local bench_dir=""
    if [[ -n "${FRAPPE_BENCH_DIR:-}" ]] && [[ -d "$FRAPPE_BENCH_DIR" ]]; then
        bench_dir="$FRAPPE_BENCH_DIR"
    elif [[ -d "/workspace/frappe-bench" ]]; then
        bench_dir="/workspace/frappe-bench"
    elif [[ -d "$HOME/frappe-bench" ]]; then
        bench_dir="$HOME/frappe-bench"
    elif [[ -d "frappe-bench" ]]; then
        bench_dir="$(pwd)/frappe-bench"
    else
        log_error "Cannot find frappe-bench directory"
        exit 1
    fi

    log_info "Using frappe-bench at: $bench_dir"
    cd "$bench_dir" || exit 1

    local bench_cmd="${BENCH_CMD:-$HOME/.local/bin/bench}"

    # Install requirements (global)
    "$bench_cmd" setup requirements || log_warning "Setup requirements had warnings"

    # Configure database and redis connections (GLOBAL - applies to all sites)
    # These settings go to common_site_config.json
    "$bench_cmd" set-mariadb-host "$MARIADB_CONTAINER_NAME"
    "$bench_cmd" set-redis-cache-host "redis://${REDIS_CACHE_CONTAINER_NAME}:6379"
    "$bench_cmd" set-redis-queue-host "redis://${REDIS_QUEUE_CONTAINER_NAME}:6379"
    "$bench_cmd" set-redis-socketio-host "redis://${REDIS_SOCKETIO_CONTAINER_NAME}:6379"

    # Configure Git settings for cross-platform compatibility
    if [[ -d "apps/frappe" ]]; then
        cd apps/frappe/ || exit 1
        git config core.autocrlf input
        git config core.filemode false
        # Windows/WSL specific git configs
        if [[ "$OS_TYPE" == "windows" ]] || [[ "$OS_TYPE" == "wsl" ]]; then
            git config core.longpaths true
            git config core.preloadindex true
        fi
        cd "$bench_dir" || exit 1
    else
        log_warning "apps/frappe directory not found, skipping git config"
    fi

    log_success "Bench configuration completed (multi-site ready)"
}

# =============================================================================
# CREATE SITE (SINGLE SITE - MULTI-SITE READY BENCH)
# =============================================================================
create_site() {
    log_info "Creating site: ${SITE_NAME}"

    # Find frappe-bench directory
    local bench_dir=""
    if [[ -n "${FRAPPE_BENCH_DIR:-}" ]] && [[ -d "$FRAPPE_BENCH_DIR" ]]; then
        bench_dir="$FRAPPE_BENCH_DIR"
    elif [[ -d "/workspace/frappe-bench" ]]; then
        bench_dir="/workspace/frappe-bench"
    elif [[ -d "$HOME/frappe-bench" ]]; then
        bench_dir="$HOME/frappe-bench"
    elif [[ -d "frappe-bench" ]]; then
        bench_dir="$(pwd)/frappe-bench"
    else
        log_error "Cannot find frappe-bench directory for site creation"
        exit 1
    fi

    cd "$bench_dir" || exit 1

    local bench_cmd="${BENCH_CMD:-$HOME/.local/bin/bench}"
    local admin_password="${SITE_ADMIN_PASSWORD:-administrator}"

    # Check if site already exists
    if [[ -d "sites/${SITE_NAME}" ]]; then
        log_warning "Site '${SITE_NAME}' already exists, skipping creation"
        "$bench_cmd" --site "${SITE_NAME}" clear-cache || true
        "$bench_cmd" use "${SITE_NAME}" || true
    else
        # Create new site
        # Sanitize site name for database name (replace special chars with underscore)
        local db_name="${SITE_NAME//[^a-zA-Z0-9]/_}"
        
        log_info "Creating new site: ${SITE_NAME} (database: ${db_name})"
        "$bench_cmd" new-site "${SITE_NAME}" \
            --mariadb-root-password root \
            --admin-password "$admin_password" \
            --no-mariadb-socket \
            --db-name "$db_name" \
            --verbose || {
                log_error "Failed to create site: ${SITE_NAME}"
                exit 1
            }

        # Configure site settings (using --site flag for multi-site safety)
        "$bench_cmd" --site "${SITE_NAME}" set-config developer_mode 1
        "$bench_cmd" --site "${SITE_NAME}" clear-cache
        
        # Set as default site
        "$bench_cmd" use "${SITE_NAME}"
    fi

    log_success "Site '${SITE_NAME}' created successfully"
    log_info "To add more sites later, run: bench new-site <site-name>"
}

# =============================================================================
# SERVICE CONNECTIVITY CHECK
# =============================================================================
check_service() {
    local host=$1
    local port=$2
    local timeout=${3:-5}

    if command -v nc >/dev/null 2>&1; then
        timeout "$timeout" nc -z "$host" "$port" 2>/dev/null
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "
import socket,sys
try:
    s=socket.socket()
    s.settimeout($timeout)
    s.connect(('$host',$port))
    s.close()
    sys.exit(0)
except:
    sys.exit(1)" 2>/dev/null
    else
        log_warning "No network tools available, skipping connectivity check"
        return 0
    fi
}

# =============================================================================
# WAIT FOR DEPENDENCIES
# =============================================================================
wait_for_dependencies() {
    log_info "Waiting for database and redis services..."

    # Install network tools if needed
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq 2>/dev/null || true
        sudo apt-get install -y netcat-openbsd curl wget 2>/dev/null || true
    fi

    local max_attempts=30
    local attempt=1

    # Wait for MariaDB
    log_info "Checking MariaDB connection (${MARIADB_CONTAINER_NAME}:3306)..."
    while ! check_service "$MARIADB_CONTAINER_NAME" 3306 && [[ $attempt -le $max_attempts ]]; do
        log_info "Waiting for MariaDB... (attempt $attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done

    if [[ $attempt -gt $max_attempts ]]; then
        log_error "MariaDB connection timeout after ${max_attempts} attempts"
        exit 1
    fi
    log_success "MariaDB is ready"

    # Wait for Redis services
    local redis_services=(
        "$REDIS_CACHE_CONTAINER_NAME"
        "$REDIS_QUEUE_CONTAINER_NAME"
        "$REDIS_SOCKETIO_CONTAINER_NAME"
    )

    for redis_service in "${redis_services[@]}"; do
        attempt=1
        while ! check_service "$redis_service" 6379 && [[ $attempt -le 10 ]]; do
            log_info "Waiting for $redis_service... (attempt $attempt/10)"
            sleep 2
            ((attempt++))
        done
        if [[ $attempt -le 10 ]]; then
            log_success "$redis_service is ready"
        else
            log_warning "$redis_service may not be ready"
        fi
    done

    log_success "All dependencies are ready"
}

# =============================================================================
# PRINT CREDENTIALS
# =============================================================================
print_credentials() {
    log_success "🎉 INSTALLATION COMPLETED SUCCESSFULLY!"

    local bench_dir="${FRAPPE_BENCH_DIR:-$(pwd)/frappe-bench}"
    local admin_password="${SITE_ADMIN_PASSWORD:-administrator}"

    cat << EOF

${GREEN}╔══════════════════════════════════════════════════════════╗
║                    ACCESS CREDENTIALS                     ║
╚══════════════════════════════════════════════════════════╝${NC}

${GREEN}🌐 WEB ACCESS:${NC}
   URL: http://localhost:${FRAPPE_PORT_START:-8000}
   Site: ${SITE_NAME}

${GREEN}👤 FRAPPE ADMIN:${NC}
   Username: Administrator
   Password: ${admin_password}
   Email: admin@${SITE_NAME}

${GREEN}🗄️ DATABASE (MariaDB):${NC}
   Host: ${MARIADB_CONTAINER_NAME}
   Port: 3306
   Root Password: ${MYSQL_ROOT_PASSWORD:-root}

${GREEN}📦 REDIS SERVICES:${NC}
   Cache: ${REDIS_CACHE_CONTAINER_NAME}:6379
   Queue: ${REDIS_QUEUE_CONTAINER_NAME}:6379
   SocketIO: ${REDIS_SOCKETIO_CONTAINER_NAME}:6379

${GREEN}🚀 NEXT STEPS:${NC}
   1. cd ${bench_dir}
   2. ${GREEN}bench start${NC}
   3. Access: ${GREEN}http://localhost:${FRAPPE_PORT_START:-8000}${NC}
   4. Login: Administrator / ${admin_password}

${GREEN}📋 USEFUL COMMANDS:${NC}
   • bench start                    # Start Frappe server
   • bench restart                  # Restart all services
   • bench new-site <name>          # Create additional site (multi-site!)
   • bench use <site>               # Switch active site
   • bench list-sites               # List all sites
   • bench install-app <app>        # Install app to current site
   • bench migrate                  # Run database migrations
   • bench clear-cache              # Clear all caches
   • bench console                  # Open Frappe console
   • bench backup --all-sites       # Backup all sites

${GREEN}📁 IMPORTANT PATHS:${NC}
   • Frappe Bench: ${bench_dir}
   • Site Files: ${bench_dir}/sites/${SITE_NAME}
   • Apps: ${bench_dir}/apps/
   • Logs: ${bench_dir}/logs/

${YELLOW}⚠️  SECURITY NOTE:${NC}
   Change default passwords in production environment!

${GREEN}╔══════════════════════════════════════════════════════════╗
║                  INSTALLATION SUMMARY                     ║
╚══════════════════════════════════════════════════════════╝${NC}

EOF

    # Show installed versions
    echo -e "${BLUE}📦 INSTALLED VERSIONS:${NC}"
    echo "   • Python: $(python --version 2>&1 | cut -d' ' -f2 || echo 'N/A')"
    echo "   • Node.js: $(node --version 2>/dev/null | cut -c2- || echo 'N/A')"
    echo "   • NPM: $(npm --version 2>/dev/null || echo 'N/A')"
    echo "   • Yarn: $(yarn --version 2>/dev/null || echo 'N/A')"
    echo "   • Frappe Bench: $(~/.local/bin/bench version --format plain 2>/dev/null || echo 'Unknown')"

    echo ""
    echo -e "${GREEN}🎊 Happy coding with Frappe! 🎊${NC}"
    echo ""
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================
main() {
    log_info "Starting Frappe installation..."
    log_info "Log file: $LOG_FILE"
    log_info "Node.js Version: ${NODE_VERSION}"
    log_info "Python Version: ${PYTHON_VERSION}"
    log_info "Frappe Version: ${FRAPPE_VERSION}"

    check_environment
    setup_workspace
    setup_shell
    install_system_deps
    setup_nodejs
    setup_python
    install_frappe_bench
    wait_for_dependencies
    init_frappe_bench
    setup_bench_config
    create_site

    log_success "✅ Frappe installation completed successfully!"

    # Show final status
    log_info "Showing final bench version..."
    ~/.local/bin/bench version 2>/dev/null || true

    # Print all credentials and important info
    print_credentials
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
