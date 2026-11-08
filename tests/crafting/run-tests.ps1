param([string]$GodotPath, [switch]$IncludeUI)
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
if (-not $GodotPath) {
    $taskSettings = Get-Content -LiteralPath (Join-Path $taskRoot '.vscode/settings.json') -Raw | ConvertFrom-Json
    $GodotPath = $taskSettings.'godotTools.editorPath.godot4'
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) { throw '请使用 -GodotPath 指定 Godot 4。' }
$taskSuites = @(@{Scene='runner'; Marker='CRAFTING_TEST_RESULT'})
if ($IncludeUI) { $taskSuites += @{Scene='ui_runner'; Marker='CRAFTING_UI_TEST_RESULT'} }
New-Item -ItemType Directory -Path (Join-Path $taskRoot 'Log') -Force | Out-Null
foreach ($taskSuite in $taskSuites) {
    $taskLog = Join-Path $taskRoot ('Log/crafting-' + $taskSuite.Scene + '.log')
    $taskArguments = @('--headless', '--path', ('"' + $taskRoot + '"'),
        ('res://tests/crafting/' + $taskSuite.Scene + '.tscn'), '--quit-after', '1200', '--log-file', ('"' + $taskLog + '"'))
    $taskProcess = Start-Process -FilePath $GodotPath -ArgumentList $taskArguments -WindowStyle Hidden -PassThru
    if (-not $taskProcess.WaitForExit(60000)) { Stop-Process -Id $taskProcess.Id; throw '合成测试超时。' }
    $taskContent = Get-Content -LiteralPath $taskLog -Raw
    $taskResult = [regex]::Match($taskContent, $taskSuite.Marker + ' assertions=\d+ failures=0')
    if ($taskProcess.ExitCode -ne 0 -or -not $taskResult.Success -or $taskContent -match '(?m)^(SCRIPT ERROR|ERROR):') {
        Write-Output $taskContent
        throw ('合成测试失败：' + $taskLog)
    }
    Write-Output $taskResult.Value
}
