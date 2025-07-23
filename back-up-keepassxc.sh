#!/usr/bin/env bash

# Repository: https://github.com/bray/keepassxc-backup
# KeePassXC Database Backup Script
# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Brian Ray
#
# Back up a snapshot of your KeePassXC database(s) to a local directory, and optionally sync backups to Proton Drive via `rclone`.
#
# Usage:
#   ./back-up-keepassxc.sh /path/to/your/database1.kdbx /path/to/your/database2.kdbx
#
# For full documentation, see README.md.

set -euo pipefail
IFS=$'\n\t'

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

set_env_var_defaults() {
  RCLONE_BIN="${RCLONE_BIN:-$(command -v rclone 2>/dev/null || true)}"
}

check_proton_drive_env_vars() {
  [[ -x "${RCLONE_BIN:-}" ]] || return 0

  local remote_name_set=0
  local dest_path_set=0

  if [[ -n "${PROTON_DRIVE_REMOTE_NAME:-}" ]]; then
    remote_name_set=1
  fi

  if [[ -n "${PROTON_DRIVE_DIR_BASE:-}" ]]; then
    dest_path_set=1
  fi

  if (( remote_name_set || dest_path_set )); then
    if (( !remote_name_set || !dest_path_set )); then
      fail "If either PROTON_DRIVE_REMOTE_NAME or PROTON_DRIVE_DIR_BASE is set, both must be set."
    fi

    if [[ ! -x "${RCLONE_BIN:-}" ]]; then
      fail "RCLONE_BIN is required when using Proton Drive upload, but was not found."
    fi

    PROTON_DRIVE_DIR="${PROTON_DRIVE_DIR_BASE}/${YEAR}/${MONTH}/${DAY}/"
    PROTON_DRIVE_CONFIGURED=1
  fi
}

check_file() {
  if [[ ! -f "$1" ]]; then
    fail "File $1 not found. Please create it first."
  fi
}

check_files() {
  check_file "$ENV_FILE"
}

load_config() {
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
  fi

  set_env_var_defaults

  BACKUP_DIR_BASE="${BACKUP_DIR_BASE:-keepassxc_backups}"
  YEAR=$(date +'%Y')
  MONTH=$(date +'%m')
  DAY=$(date +'%d')
  BACKUP_DIR="${BACKUP_DIR_BASE}/${YEAR}/${MONTH}/${DAY}"

  PROTON_DRIVE_CONFIGURED=0
}

print_config() {
  log "\nConfiguration:"
  log "  Output directory: ${BACKUP_DIR}/"
  log "  Database files: $(IFS=','; echo "${KEEPASSXC_DATABASE_FILES[*]}")"

  if (( PROTON_DRIVE_CONFIGURED )); then
    log "  Rclone CLI: ${RCLONE_BIN}"
    log "  Proton Drive remote name: ${PROTON_DRIVE_REMOTE_NAME:-}"
    log "  Proton Drive destination path: ${PROTON_DRIVE_DIR:-}"
  else
    log "  Proton Drive backup: [not configured]"
  fi

  log
}

copy_database_files() {
  log "Copying database files to ${BACKUP_DIR}/"

  mkdir -p "${BACKUP_DIR}" && chmod -R 700 "${BACKUP_DIR_BASE}"
  cp "${KEEPASSXC_DATABASE_FILES[@]}" "${BACKUP_DIR}/" && chmod 600 "${BACKUP_DIR}/"*

  log_success "Database files copied."
}

rclone_to_proton_drive() {
  (( PROTON_DRIVE_CONFIGURED )) || return 0

  if [[ -d "${BACKUP_DIR}" ]]; then
    log "\nUploading backups to Proton Drive..."

    "$RCLONE_BIN" copy -v --stats-one-line "${BACKUP_DIR}" "${PROTON_DRIVE_REMOTE_NAME}:${PROTON_DRIVE_DIR}"

    log_success "Backups uploaded to Proton Drive."
  else
    log_error "Backups directory path not found: ${BACKUP_DIR}"
  fi
}

now() {
  date +"%-m/%-d/%Y %-I:%M:%S %p %Z"
}

clean_up() {
  log "\nCleaning up..."

  echo -e "\nFinished KeePassXC backup process at $(now)."
}

trap clean_up EXIT

check_database_files() {
  if [[ $# -eq 0 ]]; then
    fail "Please provide the path to your KeePassXC database files as arguments."
  fi

  KEEPASSXC_DATABASE_FILES=("$@")

  for file in "${KEEPASSXC_DATABASE_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
      fail "Database file not found: $file"
    fi
  done
}

main() {
  echo "Started KeePassXC backup process at $(now)."

  source_common_functions
  check_database_files "$@"
  load_config
  check_proton_drive_env_vars
  check_files
  print_config

  copy_database_files
  rclone_to_proton_drive
}

main "$@"