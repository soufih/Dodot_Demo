param(
    [string]$GodotPath,
    [switch]$Import,
    [switch]$IncludeUI,
    [switch]$IncludeGameplay,
    [switch]$EquipmentOnly,
    [switch]$IncludeEquipmentUI,
    [switch]$IncludeEquipmentGameplay,
    [switch]$WarehouseOnly,
    [switch]$IncludeWarehouseUI,
    [switch]$IncludeWarehouseGameplay,
    [switch]$IncludePlayerDefaults
)

$ErrorActionPreference = 'Stop'
if ($WarehouseOnly -and $EquipmentOnly) { throw '-WarehouseOnly 与 -EquipmentOnly 不能同时指定。' }
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

$testLog = Join-Path $logDir $(if ($WarehouseOnly) { 'warehouse-tests.log' } elseif ($EquipmentOnly) { 'equipment-tests.log' } else { 'inventory-tests.log' })
$testArguments = @('--headless', '--path', ('"' + $projectRoot + '"'), 'res://tests/inventory/runner.tscn', '--quit-after', '600', '--log-file', ('"' + $testLog + '"'))
if ($EquipmentOnly) { $testArguments += @('--', '--equipment-only') }
if ($WarehouseOnly) { $testArguments += @('--', '--warehouse-only') }
$exitCode = Invoke-Godot $testArguments
$content = Get-Content -LiteralPath $testLog -Raw
Write-Output $content
$resultPattern = if ($WarehouseOnly) { 'WAREHOUSE_SERVICE_TEST_RESULT assertions=\d+ failures=0' } elseif ($EquipmentOnly) { 'EQUIPMENT_SERVICE_TEST_RESULT assertions=\d+ failures=0' } else { 'INVENTORY_TEST_RESULT assertions=\d+ failures=0' }

# 脚本编译/运行出错时 Godot 仍可能返回 0，必须同时检查日志和完成标记。
if ($exitCode -ne 0 -or $content -match '(?m)^(SCRIPT ERROR|ERROR):' -or
    $content -notmatch $resultPattern) {
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

# 可选运行装备场景的真实拖放、手工布局保持和正式工作区接入回归。
if ($IncludeEquipmentUI) {
    $equipmentUiLog = Join-Path $logDir 'equipment-ui-tests.log'
    $equipmentUiCode = Invoke-Godot @('--headless', '--path', ('"' + $projectRoot + '"'), 'res://tests/inventory/equipment_ui_runner.tscn', '--quit-after', '600', '--log-file', ('"' + $equipmentUiLog + '"'))
    $equipmentUiContent = Get-Content -LiteralPath $equipmentUiLog -Raw
    Write-Output $equipmentUiContent
    if ($equipmentUiCode -ne 0 -or $equipmentUiContent -match '(?m)^(SCRIPT ERROR|ERROR):' -or
        $equipmentUiContent -notmatch 'EQUIPMENT_UI_TEST_RESULT assertions=\d+ failures=0') {
        throw "装备 UI 测试失败。请检查 $equipmentUiLog"
    }
}

# 装备正式接入：真实 Hero、键鼠拖放、战斗属性、HUD 和跨场景会话。
if ($IncludeEquipmentGameplay) {
    $equipmentGameplayLog = Join-Path $logDir 'equipment-gameplay-tests.log'
    $equipmentGameplayCode = Invoke-Godot @('--headless', '--path', ('"' + $projectRoot + '"'), 'res://tests/inventory/equipment_gameplay_runner.tscn', '--quit-after', '1800', '--log-file', ('"' + $equipmentGameplayLog + '"'))
    $equipmentGameplayContent = Get-Content -LiteralPath $equipmentGameplayLog -Raw
    Write-Output $equipmentGameplayContent
    if ($equipmentGameplayCode -ne 0 -or $equipmentGameplayContent -match '(?m)^(SCRIPT ERROR|ERROR):' -or
        $equipmentGameplayContent -notmatch 'EQUIPMENT_GAMEPLAY_TEST_RESULT assertions=\d+ failures=0') {
        throw "装备正式接入测试失败。请检查 $equipmentGameplayLog"
    }
}

# 仓库网格显示、原生滚动和拖放、整理按钮与会话重绑。
if ($IncludeWarehouseUI) {
    $warehouseUiLog = Join-Path $logDir 'warehouse-ui-tests.log'
    $warehouseUiCode = Invoke-Godot @('--headless', '--path', ('"' + $projectRoot + '"'), 'res://tests/inventory/warehouse_ui_runner.tscn', '--quit-after', '600', '--log-file', ('"' + $warehouseUiLog + '"'))
    $warehouseUiContent = Get-Content -LiteralPath $warehouseUiLog -Raw
    Write-Output $warehouseUiContent
    if ($warehouseUiCode -ne 0 -or $warehouseUiContent -match '(?m)^(SCRIPT ERROR|ERROR):' -or
        $warehouseUiContent -notmatch 'WAREHOUSE_UI_TEST_RESULT assertions=\d+ failures=0') {
        throw "仓库 UI 测试失败。请检查 $warehouseUiLog"
    }
    $warehouseLabLog = Join-Path $logDir 'warehouse-lab-tests.log'
    $warehouseLabCode = Invoke-Godot @('--headless', '--path', ('"' + $projectRoot + '"'), 'res://tests/inventory/warehouse_lab_runner.tscn', '--quit-after', '600', '--log-file', ('"' + $warehouseLabLog + '"'))
    $warehouseLabContent = Get-Content -LiteralPath $warehouseLabLog -Raw
    Write-Output $warehouseLabContent
    if ($warehouseLabCode -ne 0 -or $warehouseLabContent -match '(?m)^(SCRIPT ERROR|ERROR):' -or
        $warehouseLabContent -notmatch 'WAREHOUSE_LAB_TEST_RESULT assertions=\d+ failures=0') {
        throw "仓库完整界面测试失败。请检查 $warehouseLabLog"
    }
}

# 仓库正式接入：真实角色移动、E 交互、家园、三窗口存取与会话生命周期。
if ($IncludeWarehouseGameplay) {
    $warehouseGameplayLog = Join-Path $logDir 'warehouse-gameplay-tests.log'
    $warehouseGameplayCode = Invoke-Godot @('--headless', '--path', ('"' + $projectRoot + '"'), 'res://tests/inventory/warehouse_gameplay_runner.tscn', '--quit-after', '2400', '--log-file', ('"' + $warehouseGameplayLog + '"'))
    $warehouseGameplayContent = Get-Content -LiteralPath $warehouseGameplayLog -Raw
    Write-Output $warehouseGameplayContent
    if ($warehouseGameplayCode -ne 0 -or $warehouseGameplayContent -match '(?m)^(SCRIPT ERROR|ERROR):' -or
        $warehouseGameplayContent -notmatch 'WAREHOUSE_GAMEPLAY_TEST_RESULT assertions=\d+ failures=0') {
        throw "仓库正式接入测试失败。请检查 $warehouseGameplayLog"
    }
}

# 新游戏默认装备、材料发放、会话复用及实际仓库合成。
if ($IncludePlayerDefaults) {
    $defaultsLog = Join-Path $logDir 'player-defaults-tests.log'
    $defaultsCode = Invoke-Godot @('--headless', '--path', ('"' + $projectRoot + '"'), 'res://tests/inventory/player_defaults_runner.tscn', '--quit-after', '1800', '--log-file', ('"' + $defaultsLog + '"'))
    $defaultsContent = Get-Content -LiteralPath $defaultsLog -Raw
    Write-Output $defaultsContent
    if ($defaultsCode -ne 0 -or $defaultsContent -match '(?m)^(SCRIPT ERROR|ERROR):' -or
        $defaultsContent -notmatch 'PLAYER_DEFAULTS_TEST_RESULT assertions=\d+ failures=0') {
        throw "玩家初始物品测试失败。请检查 $defaultsLog"
    }
}

# 正式资源、拾取交互、玩家生命周期与 UIManager 接入测试。
if ($IncludeGameplay) {
    $gameplayLog = Join-Path $logDir 'inventory-gameplay-tests.log'
    $gameplayCode = Invoke-Godot @('--headless', '--path', ('"' + $projectRoot + '"'), 'res://tests/inventory/gameplay_runner.tscn', '--quit-after', '1800', '--log-file', ('"' + $gameplayLog + '"'))
    $gameplayContent = Get-Content -LiteralPath $gameplayLog -Raw
    Write-Output $gameplayContent
    if ($gameplayCode -ne 0 -or $gameplayContent -match '(?m)^(SCRIPT ERROR|ERROR):' -or
        $gameplayContent -notmatch 'INVENTORY_GAMEPLAY_TEST_RESULT assertions=\d+ failures=0') {
        throw "背包游戏接入测试失败。请检查 $gameplayLog"
    }

    $labLog = Join-Path $logDir 'inventory-gameplay-lab-tests.log'
    $labCode = Invoke-Godot @('--headless', '--path', ('"' + $projectRoot + '"'), 'res://tests/inventory/gameplay_lab_runner.tscn', '--quit-after', '1800', '--log-file', ('"' + $labLog + '"'))
    $labContent = Get-Content -LiteralPath $labLog -Raw
    Write-Output $labContent
    if ($labCode -ne 0 -or $labContent -match '(?m)^(SCRIPT ERROR|ERROR):' -or
        $labContent -notmatch 'INVENTORY_GAMEPLAY_LAB_TEST_RESULT assertions=\d+ failures=0') {
        throw "真实角色接入测试台检查失败。请检查 $labLog"
    }
}
