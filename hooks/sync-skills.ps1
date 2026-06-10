$json = [Console]::In.ReadToEnd() | ConvertFrom-Json
$filePath = $json.tool_input.file_path

$commandsDir = $env:USERPROFILE + '\.claude\commands'
$hooksDir    = $env:USERPROFILE + '\.claude\hooks'
$settingsFile = $env:USERPROFILE + '\.claude\settings.json'

if ($filePath -like ($commandsDir + '\*') -or $filePath -like ($hooksDir + '\*') -or $filePath -eq $settingsFile) {
    $msg = 'Claude config file modified: ' + $filePath + '. Ask the user if they want to sync this change to their my-claude-skills repo and push to GitHub.'
    @{
        hookSpecificOutput = @{
            hookEventName   = 'PostToolUse'
            additionalContext = $msg
        }
    } | ConvertTo-Json -Compress -Depth 3
}
