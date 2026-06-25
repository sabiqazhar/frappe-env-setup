# docker-frappe-setup

Local Frappe/ERPNext development environment using Docker and custom installation scripts.

## Prerequisites

- Python
- Docker & Docker Compose
- Git
- Bash (Linux/macOS/WSL)

---

## Installing Python with `uv` (Newbie Guide)

Hey guys! 👋 Before we dive into Frappe, let's get Python on your machine. The old way involves `pyenv`, system package managers, and crying over compile errors. The new way is `uv`.

### What's `uv`?

`uv` is a Python tool that does everything — installs Python itself, creates virtual environments, installs packages, and does it **10-100x faster** than `pip`. Built by the same folks who made Ruff (the fast linter). One binary, zero fuss.

### 1. Install `uv`

**Linux / macOS / WSL:**

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Restart your terminal, then check it worked:

```bash
uv --version
```

### 2. Install Python with `uv`

Pick the Python version your Frappe version needs. Here's the cheat sheet from the Troubleshooting table below:

| Frappe Version | Python | Install command |
|----------------|--------|----------------|
| version-16     | 3.14   | `uv python install 3.14` |
| version-15     | 3.12   | `uv python install 3.12` |
| version-14     | 3.11   | `uv python install 3.11` |

Example (for Frappe v16):

```bash
uv python install 3.14
```

**What just happened?** `uv` downloaded and compiled Python and stashed it in `~/.local/share/uv/python/`. No `sudo`, no system packages, no messing with your OS Python.

List what you've got:

```bash
uv python list
```

Pin a version for this project (creates a `.python-version` file):

```bash
uv python pin 3.14
```

### 3. Create a Virtual Environment

```bash
# Stand in your Frappe project folder
cd ~/frappe-dev
uv venv
```

Activate it:

**Linux / macOS / WSL:**

```bash
source .venv/bin/activate
```

When you see `(.venv)` in your prompt, it worked.

### 4. Install Packages the `uv` Way

```bash
uv pip install frappe-bench
```

Or from a requirements file:

```bash
uv pip install -r requirements.txt
```

### Quick Reference

| Command | What it does |
|---------|-------------|
| `uv python install 3.14` | Download & compile Python 3.14 |
| `uv python pin 3.14` | Lock this folder to Python 3.14 |
| `uv python list` | Show installed Python versions |
| `uv venv` | Create a `.venv` in the current directory |
| `uv pip install <pkg>` | Install a package (10x faster than pip) |
| `uv run script.py` | Run a script without activating the venv |
| `uv pip freeze` | List installed packages |

### Why This Matters for Frappe 🧠

Frappe runs on Python. `bench` (Frappe's CLI) is a Python package. When the Docker setup below runs `frappe-init-script.sh`, that script installs Python inside the container automatically — so you don't *need* `uv` for the Docker path. But if you ever:

- Develop custom apps on your host machine
- Deal with Python version mismatches (classic Frappe pain)

...then `uv` saves your day. One command to get the exact Python version, one command to install bench, no conflicts.

### Pro Tips 💡

- **Multiple Python versions?** `uv` keeps them side-by-side. Pin different versions per project.
- **Lazy activation?** `uv run python myscript.py` works without sourcing `.venv/bin/activate`.
- **Forgot the pin?** `uv python pin 3.14` fixes it retroactively.

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
frappe-init-script/
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
