# my-claude-skills

Personal Claude Code commands, skills, and settings, synced across machines.

This repo holds two different kinds of Claude Code capability:
- **`commands/`** — single-file custom slash commands (`~/.claude/commands/*.md`),
  invoked explicitly by typing `/name`.
- **`skills/`** — folder-based Skills (`~/.claude/skills/<name>/SKILL.md`),
  which Claude can auto-invoke by matching your request against the skill's
  description, in addition to explicit `/name` invocation. Each skill folder
  may also contain its own `README.md` with usage directions specific to it.

## Setup on a new machine

```bash
git clone git@github.com:kpetrianakis/my-claude-skills.git
cd my-claude-skills

# Copy commands
cp commands/*.md ~/.claude/commands/

# Copy skills (each is a folder — copy the whole thing)
mkdir -p ~/.claude/skills
cp -r skills/* ~/.claude/skills/

# Optionally merge settings (don't overwrite blindly if you have local settings)
cp settings.json ~/.claude/settings.json
```

On Windows (PowerShell):
```powershell
git clone git@github.com:kpetrianakis/my-claude-skills.git
cd my-claude-skills

New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\commands" | Out-Null
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\hooks"    | Out-Null
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills"   | Out-Null

Copy-Item commands\*.md  "$env:USERPROFILE\.claude\commands\"
Copy-Item hooks\*.ps1    "$env:USERPROFILE\.claude\hooks\"
Copy-Item settings.json  "$env:USERPROFILE\.claude\settings.json"
Copy-Item -Recurse skills\* "$env:USERPROFILE\.claude\skills\"
```

To pick up future updates on a machine you've already set up: `git pull`,
then re-run the relevant `cp`/`Copy-Item` lines above (or symlink instead of
copying — see a given skill's own `README.md` for that option).

**Note:** `hooks/sync-skills.ps1` currently only watches `~/.claude/commands/`,
`~/.claude/hooks/`, and `~/.claude/settings.json` to auto-offer a sync back to
this repo — it does not yet watch `~/.claude/skills/`, so skill edits need a
manual copy-commit-push for now.

## Contents

| File | Description |
|------|-------------|
| `commands/php83-upgrade.md` | PHP 7.4 → 8.3 upgrade skill — phased process covering env setup, Docker, breaking-change fixes, and deployment |
| `skills/wol-reference-lookup/` | Detects Bible and JW-publication references (Greek or English) in pasted text and fetches their real content from wol.jw.org — supports bible-only/publications-only/both modes; see its own `README.md` for usage |
| `hooks/sync-skills.ps1` | PostToolUse hook — fires after any Write/Edit to `~/.claude/commands/` or `~/.claude/settings.json` and asks whether to push the change to this repo |
| `settings.json` | Claude Code global settings (includes the hook registration) |
