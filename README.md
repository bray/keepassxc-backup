# KeePassXC Backup

## Description

Back up a snapshot of your KeePassXC database(s) to a local directory, and optionally sync backups to Proton Drive via `rclone`.

## Usage

1. Install required dependencies:
   - [common-functions.sh](https://github.com/bray/dotfiles/blob/main/.local/share/scripts/common-functions.sh)
   - [rclone](https://rclone.org/install/) (optional, for Proton Drive sync)

2. Set up your environment:
   ```bash
   # Create and secure the configuration file
   mkdir -p ~/.config/back-up-keepassxc
   touch ~/.config/back-up-keepassxc/.env
   chmod 600 ~/.config/back-up-keepassxc/.env
   ```

3. Configure your `.env` file with the following variables:
   ```bash
   # Optional variables

   # Backup directory (default: ./keepassxc_backups)
   # BACKUP_DIR_BASE="./keepassxc_backups"

   # Path to `rclone` CLI (default: $(command -v rclone))
   # RCLONE_BIN="/path/to/rclone"

   # Rclone remote name for Proton Drive
   # PROTON_DRIVE_REMOTE_NAME="proton"

   # Base destination path in Proton Drive
   # PROTON_DRIVE_DIR_BASE="backups/keepassxc"

   # Enable healthchecks.io integration
   # HEALTHCHECKS_URL="your_url"
   ```

4. Run the backup:
   ```bash
   # Manual backup
   ./back-up-keepassxc.sh /path/to/your/database1.kdbx /path/to/your/database2.kdbx
   
   # Or use the wrapper for automated backups
   ./back-up-keepassxc-wrapper.sh /path/to/your/database1.kdbx /path/to/your/database2.kdbx
   ```

## Security

- The `.env` file should be readable only by your user (`chmod 600`)
- All backup files are set to mode 600

## Wrapper

The wrapper script (`back-up-keepassxc-wrapper.sh`) is designed to run the main backup script via `cron` or `LaunchAgent`, with optional [healthchecks.io](https://healthchecks.io/) integration as a dead man's switch.