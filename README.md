# docker-frappe-setup

Local Frappe/ERPNext development environment using Docker and custom installation scripts.

## Prerequisites

- Python
- Docker & Docker Compose
- Git
- Bash (Linux/macOS/WSL)

---

## Installing Docker with Lazydocker (Docker Desktop Alternative)

Docker Desktop is heavy and has licensing restrictions. The lean setup: **Docker Engine** (headless) + **Lazydocker** (terminal UI).

### 1. Install Docker Engine

**Linux (Ubuntu/Debian) — official script:**

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in, or run: newgrp docker
```

**macOS — via Homebrew:**

```bash
brew install docker docker-compose
```

**WSL — same as Linux** (install Docker Engine inside WSL, no Docker Desktop needed). Homebrew isn't standard on WSL, use the Linux script below for lazydocker.

### 2. Install Docker Compose

**Linux — already included** with the official `get.docker.com` script above. Verify:

docker compose version

**macOS — included** with `brew install docker` above.

**Linux / WSL — standalone install (if missing):**

# Install Docker Compose plugin manually
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

Verify with `docker compose version`.

### 3. Install Lazydocker

Lazydocker is a terminal UI for Docker — view containers, logs, stats, restart/stop, all from your terminal without leaving it.

**macOS — with Homebrew:**

```bash
brew install lazydocker
```

**Linux / WSL — direct install script:**

```bash
curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
```

### 4. Verify

```bash
docker --version
docker compose version
lazydocker --version
```

Run `lazydocker` in your project folder to see containers, images, volumes, and logs in one screen.  
(`lazydocker` is a standalone TUI — no Docker Desktop running in the background.)

---

## Quick Start (Docker - Recommended)

### 1. Clone and Setup

```bash
# Clone the repository
git clone <your-repo-url>
cd frappe-env-setup

# Create environment file (or copy from template)
cp .env.project_name .env.local-dev
```

### 2. Configure Environment

Edit `.env.local-dev` with your settings:

```bash
PROJECT_NAME=frappe-dev
PROJECT_IP_NUMBER=1

FRAPPE_CONTAINER_NAME=frappe-local-dev
MARIADB_CONTAINER_NAME=mariadb-local-dev
REDIS_CACHE_CONTAINER_NAME=redis-cache-local-dev
REDIS_QUEUE_CONTAINER_NAME=redis-queue-local-dev
REDIS_SOCKETIO_CONTAINER_NAME=redis-socketio-local-dev

SITE_NAME=localhost
SITE_ADMIN_PASSWORD=administrator
FRAPPE_PORT_START=8000
SOCKETIO_PORT_START=9000

MYSQL_ROOT_PASSWORD=root
MYSQL_PASSWORD=frappe123
```

### 3. Start Docker Services

```bash
# Start all services (MariaDB, Redis, Frappe)
docker-compose --env-file ./.env.local-dev up -d

# Verify services are running
docker ps
```

### 4. Install Frappe (Inside Container)

```bash
# Enter the Frappe container
docker exec -e "TERM=xterm-256color" -it frappe-local-dev bash

# Run the installation script
./frappe-init-script.sh
```

Or use the helper script:

```bash
./run-docker.sh
```

---

## Accessing Frappe

After installation:

- **URL:** <http://localhost:8000>
- **Username:** Administrator
- **Password:** administrator (or as set in `SITE_ADMIN_PASSWORD`)

---

## Common Commands

```bash
# Start Frappe bench
bench start

# Create new site
bench new-site site2.local

# List sites
bench list-sites

# Switch site
bench use site2.local

# Install app
bench install-app erpnext

# Run migrations
bench migrate

# Clear cache
bench clear-cache

# View logs
bench logs
```

---

## Project Structure

```
frappe-env-setup/
├── frappe-init-script.sh   # Main installation script
├── docker-compose.yml       # Docker services configuration
├── run-docker.sh            # Quick Docker launcher
├── custom-mariadb/          # Custom MariaDB config
├── .env.project_name        # Environment template
└── README.md
```

---

## Troubleshooting (this section out of instalation guide, read if u have a problem with installation/post-installation)

### Frappe Version Requirements

| Frappe Version | Python | Node.js | EOL |
|---------------|--------|---------|-----|
| version-14    | 3.11+  | 18+     | Jan 2026 |
| version-15    | 3.12+  | 20+     | End 2027 |
| version-16    | 3.14+  | 24+     | End 2029 |

To change the Frappe version, edit these variables in `frappe-init-script.sh`:

```bash
readonly NODE_VERSION="24"    # Match your chosen version
readonly PYTHON_VERSION="3.14"
readonly FRAPPE_VERSION="version-16"
```

This script defaults to **version-16** (latest).

### MariaDB Connection Issues

```bash
# Check if MariaDB is running
sudo systemctl status mariadb

# Test connection
mysql -u root -p -h localhost
```

### Redis Connection Issues

```bash
# Check if Redis is running
redis-cli ping
# Should return: PONG
```

### Port Already in Use

Change ports in `.env.local-dev`:

```bash
FRAPPE_PORT_START=8001
```

### Node.js Version Incompatible Error

If you see this error when running `bench start`:

```
error The engine "node" is incompatible with this module. Expected version ">=24". Got "20.19.2"
error Commands cannot run with an incompatible environment.
```

**Solution:**

1. **Check your current Node.js version:**

   ```bash
   node --version
   ```

2. **Upgrade to Node.js 24+ using nvm:**

   ```bash
   # Install nvm if not installed
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
   source ~/.bashrc
   
   # Install Node.js 24
   nvm install 24
   nvm use 24
   
   # Set as default
   nvm alias default 24
   ```

**Note:** Frappe version-16 requires Node.js 24+ and Python 3.14+. If you need to use an older Frappe version (version-15 or version-14), you can use Node.js 18 or 20 respectively.
