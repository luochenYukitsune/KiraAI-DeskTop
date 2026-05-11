#!/usr/bin/env bash
set -euo pipefail

# Resolve repo root (one level up from this script)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
cd "$REPO_ROOT"

# Python executable selection
# macOS GUI apps launch with a stripped PATH (/usr/bin:/bin:/usr/sbin:/sbin),
# where /usr/bin/python3 is the system stub (3.9). We need Python 3.10+, so
# search common install locations (Homebrew, python.org) before falling back.
check_python_version() {
  local bin="$1"
  [ -n "$bin" ] && [ -x "$bin" ] || return 1
  local ver
  ver=$("$bin" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null) || return 1
  local major minor
  major=$(echo "$ver" | cut -d. -f1)
  minor=$(echo "$ver" | cut -d. -f2)
  [ "$major" = "3" ] && [ "$minor" -ge 10 ]
}

PYTHON_BIN=""
for candidate in \
  /opt/homebrew/bin/python3.13 \
  /opt/homebrew/bin/python3.12 \
  /opt/homebrew/bin/python3.11 \
  /opt/homebrew/bin/python3.10 \
  /opt/homebrew/bin/python3 \
  /usr/local/bin/python3.13 \
  /usr/local/bin/python3.12 \
  /usr/local/bin/python3.11 \
  /usr/local/bin/python3.10 \
  /usr/local/bin/python3 \
  /Library/Frameworks/Python.framework/Versions/3.13/bin/python3 \
  /Library/Frameworks/Python.framework/Versions/3.12/bin/python3 \
  /Library/Frameworks/Python.framework/Versions/3.11/bin/python3 \
  /Library/Frameworks/Python.framework/Versions/3.10/bin/python3 \
  "$(command -v python3 2>/dev/null || true)" \
  "$(command -v python 2>/dev/null || true)"
do
  if check_python_version "$candidate"; then
    PYTHON_BIN="$candidate"
    echo "Using Python $("$PYTHON_BIN" --version 2>&1) at $PYTHON_BIN"
    break
  fi
done

if [ -z "$PYTHON_BIN" ]; then
  echo "Error: Python 3.10+ not found." >&2
  echo "Searched: /opt/homebrew/bin, /usr/local/bin, /Library/Frameworks/Python.framework, PATH" >&2
  echo "Install Python 3.10+ from https://www.python.org/downloads/ or via Homebrew." >&2
  exit 1
fi

# Step 1: Migrate .venv -> venv (backward compatibility)
if [ -d .venv ] && [ ! -d venv ]; then
  echo "[compat] Renaming .venv to venv..."
  mv .venv venv
fi

# Recreate venv if its Python is too old (e.g. previously built with /usr/bin/python3 3.9)
if [ -d venv ] && [ -x venv/bin/python ]; then
  if ! check_python_version venv/bin/python; then
    venv_ver=$(venv/bin/python -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null || echo "unknown")
    echo "[compat] Existing venv uses Python $venv_ver (<3.10), recreating with $PYTHON_BIN"
    rm -rf venv
  fi
fi

# Step 1: Create venv if missing
if [ ! -d venv ]; then
  echo "[1/3] Creating virtual environment..."
  "$PYTHON_BIN" -m venv venv
else
  echo "Virtual environment already exists."
fi

# Step 2: Activate venv
echo "[2/3] Activating virtual environment..."
# shellcheck disable=SC1091
source venv/bin/activate

# Step 3: Install dependencies
echo "[3/3] Installing dependencies..."
python -m pip install --upgrade pip
if [ -f requirements.txt ]; then
  pip install -r requirements.txt
else
  echo "requirements.txt not found, skipping dependency installation."
fi

# Step 4: Run the app
echo "=============================="
echo " Launching application..."
echo "=============================="

if [ -f main.py ]; then
  exec python main.py
else
  echo "Error: main.py not found."
  exit 1
fi
