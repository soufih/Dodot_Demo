param(
    [string]$GodotPath,
    [switch]$Import,
    [switch]$IncludeUI
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
if (-not $GodotPath) {
    $settingsPath = Join-Path $projectRoot '.vscode\settings.json'
    if (Test-Path -LiteralPath $settingsPath) {
        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        $GodotPath = $settings.'godotTools.editorPath.godot4'
    }
}
if (-not $GodotPath) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { $GodotPath = $command.Source }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw '找不到 Godot 4。请传入 -GodotPath 指定可执行文件。'
}

$logDir = Join-Path $projectRoot 'Log'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

# Windows GUI 版 Godot 需要显式等待进程。引号确保带空格路径可用。
function Invoke-Godot([string[]]$GodotArguments) {
    $process = Start-Process -FilePath $GodotPath -ArgumentList $GodotArguments -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(60000)) {
        Stop-Process -Id $process.Id
        throw 'Godot 测试超过 60 秒，已终止测试进程。'
    }
    $process.Refresh()
    return $process.ExitCode
}

if ($Import) {
    $importLog = Join-Path $logDir 'inventory-import.log'
    $importCode = Invoke-Godot @('--headless', '--editor', '--import', '--quit', '--path', ('"' + $projectRoot + '"'), '--log-file', ('"' + $importLog + '"'))
    if ($importCode -ne 0) { throw "Godot 导入失败。请检查 $importLog" }
}

$testLog = Join-Path $logDir 'inventory-tests.log'
$exitCode = Invoke-Godot @('--headless', '--path', ('"' + $projectRoot + '"'), 'res://tests/inventory/runner.tscn', '--quit-after', '600', '--log-file', ('"' + $testLog + '"'))
$content = Get-Content -LiteralPath $testLog -Raw
Write-Output $content

# 脚本编译/运行出错时 Godot 仍可能返回 0，必须同时检查日志和完成标记。
if ($exitCode -ne 0 -or $content -match '(?m)^(SCRIPT ERROR|ERROR):' -or
    $content -notmatch 'INVENTORY_TEST_RESULT assertions=\d+ failures=0') {
    throw "背包测试失败。请检查 $testLog"
}

# 可选运行真实 UI 场景的表单、拖放和边框长按交互回归。
if ($IncludeUI) {
    $uiLog = Join-Path $logDir 'inventory-ui-tests.log'
    $uiCode = Invoke-Godot @('--headless', '--path', ('"' + $projectRoot + '"'), 'res://tests/inventory/ui_runner.tscn', '--quit-after', '600', '--log-file', ('"' + $uiLog + '"'))
    $uiContent = Get-Content -LiteralPath $uiLog -Raw
    Write-Output $uiContent
    if ($uiCode -ne 0 -or $uiContent -match '(?m)^(SCRIPT ERROR|ERROR):' -or
        $uiContent -notmatch 'INVENTORY_UI_TEST_RESULT assertions=\d+ failures=0') {
        throw "背包 UI 测试失败。请检查 $uiLog"
    }
}
