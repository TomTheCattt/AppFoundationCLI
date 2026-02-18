#!/bin/bash
# Logger Utility

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="$HOME/.appfoundation/logs/$(date +%Y-%m-%d).log"
mkdir -p "$(dirname "$LOG_FILE")"

log_info() {
    local msg="$1"
    echo -e "${BLUE}INFO:${NC} $msg" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $msg" >> "$LOG_FILE"
}

log_success() {
    local msg="$1"
    echo -e "${GREEN}✓${NC} $msg" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $msg" >> "$LOG_FILE"
}

log_warn() {
    local msg="$1"
    echo -e "${YELLOW}⚠${NC} $msg" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $msg" >> "$LOG_FILE"
}

log_error() {
    local msg="$1"
    echo -e "${RED}✗${NC} $msg" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $msg" >> "$LOG_FILE"
}

log_step() {
    local msg="$1"
    echo -e "${BLUE}→${NC} $msg" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] STEP: $msg" >> "$LOG_FILE"
}
