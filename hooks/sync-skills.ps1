$json = [Console]::In.ReadToEnd() | ConvertFrom-Json
$filePath = $json.tool_input.file_path

$commandsDir = $env:USERPROFILE + '\.claude\commands'
$hooksDir    = $env:USERPROFILE + '\.claude\hooks'
$skillsDir   = $env:USERPROFILE + '\.claude\skills'
$settingsFile = $env:USERPROFILE + '\.claude\settings.json'

# Repo location varies per machine. Prefer an explicit override
# ($env:MY_CLAUDE_SKILLS_REPO), otherwise probe common clone locations.
function Find-RepoMirror {
    if ($env:MY_CLAUDE_SKILLS_REPO) { return $env:MY_CLAUDE_SKILLS_REPO }
    $candidates = @(
        (Join-Path $env:USERPROFILE 'my-claude-skills'),
        (Join-Path $env:USERPROFILE 'source\my-claude-skills'),
        (Join-Path $env:USERPROFILE 'code\my-claude-skills'),
        (Join-Path $env:USERPROFILE 'projects\my-claude-skills')
    )
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c '.git')) { return $c }
    }
    return $null
}
$repoMirror = Find-RepoMirror

if ($filePath -like ($commandsDir + '\*') -or $filePath -like ($hooksDir + '\*') -or $filePath -like ($skillsDir + '\*') -or $filePath -eq $settingsFile) {
    # my-claude-skills is a PUBLIC repo. settings.json in particular tends to
    # accumulate machine-specific or sensitive content over time (API keys in
    # MCP server configs, permission rules naming internal tools, personal
    # automation details, absolute paths with real usernames) that commands/
    # and skills/ files don't usually carry. Flag it specially.
    $settingsWarning = ''
    if ($filePath -eq $settingsFile) {
        $settingsWarning = ' This is settings.json specifically, and the mirror repo is PUBLIC — before syncing, read through the actual diff line by line and confirm with the user there is nothing machine-specific or sensitive in it (API keys, tokens, internal hostnames, real usernames in paths, personal device/automation names, etc.). Do not just diff-and-push on autopilot for this file.'
    }
    if ($repoMirror) {
        $msg = 'Claude config file modified: ' + $filePath + '. Ask the user if they want to sync this change to their my-claude-skills repo. If yes: copy the file into the mirror at ' + $repoMirror + ' (preserving the relative path under .claude/ — note that skills live under .claude/skills/<name>/ and should be copied as a whole folder into skills/<name>/ in the repo, not file-by-file), then commit and push to git@github.com:kpetrianakis/my-claude-skills.git.' + $settingsWarning
    } else {
        $msg = 'Claude config file modified: ' + $filePath + '. This looks like it belongs in the my-claude-skills repo (git@github.com:kpetrianakis/my-claude-skills.git), but no local clone was found in the usual locations. Ask the user where their local clone of that repo lives on this machine, then copy the file there (preserving the relative path under .claude/ — skills are folders, copy the whole folder), commit, and push. Suggest they set $env:MY_CLAUDE_SKILLS_REPO permanently to skip this question next time.' + $settingsWarning
    }
    @{
        hookSpecificOutput = @{
            hookEventName   = 'PostToolUse'
            additionalContext = $msg
        }
    } | ConvertTo-Json -Compress -Depth 3
}
