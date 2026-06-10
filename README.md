# my-claude-skills

Personal Claude Code commands and settings, synced across machines.

## Setup on a new machine

```bash
git clone git@github.com:kpetrianakis/my-claude-skills.git
cd my-claude-skills

# Copy skills
cp commands/*.md ~/.claude/commands/

# Optionally merge settings (don't overwrite blindly if you have local settings)
cp settings.json ~/.claude/settings.json
```

On Windows (PowerShell):
```powershell
git clone git@github.com:kpetrianakis/my-claude-skills.git
cd my-claude-skills

New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\commands" | Out-Null
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\hooks"    | Out-Null

Copy-Item commands\*.md  "$env:USERPROFILE\.claude\commands\"
Copy-Item hooks\*.ps1    "$env:USERPROFILE\.claude\hooks\"
Copy-Item settings.json  "$env:USERPROFILE\.claude\settings.json"
```

## Contents

| File | Description |
|------|-------------|
| `commands/php83-upgrade.md` | PHP 7.4 → 8.3 upgrade skill — phased process covering env setup, Docker, breaking-change fixes, and deployment |
| `hooks/sync-skills.ps1` | PostToolUse hook — fires after any Write/Edit to `~/.claude/commands/` or `~/.claude/settings.json` and asks whether to push the change to this repo |
| `settings.json` | Claude Code global settings (includes the hook registration) |
