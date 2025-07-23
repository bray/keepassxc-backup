#!/usr/bin/env bash

# Repository: https://github.com/bray/keepassxc-backup
# KeePassXC Database Backup Script - Wrapper
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Brian Ray
#
# A wrapper to run the KeePassXC backup script via cron or LaunchAgent.
# Optionally integrates with healthchecks.io as a dead man's switch.
#
# Usage:
#   ./back-up-keepassxc-wrapper.sh
#
# For full documentation, see README.md.

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.config/back-up-keepassxc"
ENV_FILE="${CONFIG_DIR}/.env"

source_common_functions() {
  local path="${XDG_DATA_HOME:-${HOME}/.local/share}/scripts/common-functions.sh"

  if [[ -f "$path" ]]; then
    # shellcheck source=/dev/null
    source "$path"
  else
    echo "Error: common-functions.sh not found. Please install it first."
    exit 1
  fi
}

load_config() {
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
  fi
  
  HEALTHCHECKS_URL="${HEALTHCHECKS_URL:-}"
}

log_ping_healthchecks_error() {
  log_error "Failed to ping healthchecks.io start"
}

check_healthchecks_url() {
  if [[ -z "${HEALTHCHECKS_URL}" ]]; then
    log "HEALTHCHECKS_URL is not set. Skipping healthchecks.io integration.\n"
  fi
}

ping_healthchecks() {
  local status="$1"  # "start", "0", or any non-zero number
  local stderr="${2:-}"  # Optional stderr for non-zero status pings
  local ping_url=""
  local curl_args=(-fsS --max-time 10 --retry 5)

  [[ -n "$HEALTHCHECKS_URL" ]] || return 0

  case "$status" in
    "start")
      ping_url="${HEALTHCHECKS_URL}/start"
      ;;
    0)
      ping_url="${HEALTHCHECKS_URL}/0"
      ;;
    [1-9]*)
      local clean_stderr
      if [[ -n "$stderr" ]]; then
        # Remove ANSI escape codes (e.g. colors) from stderr
        clean_stderr=$(echo "$stderr" | sed $'s/\x1b\\[[0-9;?]*[ -/]*[@-~]//g')
      fi

      curl_args+=(--data-raw "$clean_stderr")
      ping_url="${HEALTHCHECKS_URL}/${status}"
      ;;
    *)
      log_error "Invalid healthchecks status: ${status}"
      return 1
      ;;
  esac

  if curl "${curl_args[@]}" "${ping_url}" > /dev/null; then
    log "Pinged healthchecks.io with status: ${status}."
  else
    log_ping_healthchecks_error
  fi
}

run_with_capture() {
  local stderr_file
  stderr_file=$(mktemp)
  local status_code
  local stderr_content

  set +e
  "$@" 2> >(tee "$stderr_file" >&2)
  status_code=$?
  set -e

  stderr_content=$(cat "$stderr_file")
  rm -f "$stderr_file"

  CAPTURED_STATUS=$status_code
  CAPTURED_STDERR="$stderr_content"
}

main() {
  source_common_functions
  load_config
  check_healthchecks_url
  ping_healthchecks "start"
  run_with_capture "${SCRIPT_DIR}/back-up-keepassxc.sh" "$@"
  ping_healthchecks "$CAPTURED_STATUS" "$CAPTURED_STDERR"
}

main "$@"
