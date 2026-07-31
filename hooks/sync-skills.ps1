$json = [Console]::In.ReadToEnd() | ConvertFrom-Json
$filePath = $json.tool_input.file_path

$commandsDir = $env:USERPROFILE + '\.claude\commands'
$hooksDir    = $env:USERPROFILE + '\.claude\hooks'
$skillsDir   = $env:USERPROFILE + '\.claude\skills'
$settingsFile = $env:USERPROFILE + '\.claude\settings.json'

if ($filePath -like ($commandsDir + '\*') -or $filePath -like ($hooksDir + '\*') -or $filePath -like ($skillsDir + '\*') -or $filePath -eq $settingsFile) {
    $msg = 'Claude config file modified: ' + $filePath + '. Ask the user if they want to sync this change to their my-claude-skills repo. If yes: copy the file into the mirror at C:\Users\KostasPetrianakis\my-claude-skills (preserving the relative path under .claude/ — note that skills live under .claude/skills/<name>/ and should be copied as a whole folder into skills/<name>/ in the repo, not file-by-file), then commit and push to git@github.com:kpetrianakis/my-claude-skills.git.'
    @{
        hookSpecificOutput = @{
            hookEventName   = 'PostToolUse'
            additionalContext = $msg
        }
    } | ConvertTo-Json -Compress -Depth 3
}
