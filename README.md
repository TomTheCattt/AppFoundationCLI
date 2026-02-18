# AppFoundation CLI

Standalone command-line tool for managing AppFoundation projects.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/yourname/appfoundation-cli/main/install.sh | bash
```

## Commands

### `appfoundation init <name>`
Initialize a new project

```bash
appfoundation init MyBankingApp
```

### `appfoundation add <type> <name>`
Add module or feature to existing project

```bash
# Add feature
appfoundation add feature Auth

# Add module
appfoundation add module analytics
```

### `appfoundation update`
Check and apply updates

```bash
# Check for updates
appfoundation update --check

# Apply updates
appfoundation update --apply
```

### `appfoundation sync`
Sync local cache with remote templates

```bash
appfoundation sync
```

### `appfoundation doctor`
Health check for project and dependencies

```bash
appfoundation doctor
```

## Configuration

Global config: `~/.appfoundation/config.json`

```json
{
  "remote": "https://github.com/yourname/AppFoundation.git",
  "defaultBranch": "main",
  "cacheDir": "~/.appfoundation/cache",
  "autoUpdate": true
}
```

Project config: `.appfoundation/config.json`

## Requirements

- Git
- Xcode 15.0+
- Optional: xcodegen, CocoaPods, jq

## Development

```bash
# Test locally
./bin/appfoundation --help

# Install locally
sudo cp bin/appfoundation /usr/local/bin/
```

## License

MIT
