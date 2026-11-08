param(
    [Parameter(Mandatory = $true)][string]$GodotPath
)
$ErrorActionPreference = 'Stop'
$taskProject = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskSuites = @(
    @{ Name = 'ui-management-tests'; Scene = 'res://tests/ui/runner.tscn'; Marker = 'UI_MANAGEMENT_TEST_RESULT' },
    @{ Name = 'inventory-core-regression'; Scene = 'res://tests/inventory/runner.tscn'; Marker = 'INVENTORY_TEST_RESULT' },
    @{ Name = 'inventory-ui-regression'; Scene = 'res://tests/inventory/ui_runner.tscn'; Marker = 'INVENTORY_UI_TEST_RESULT' }
)
foreach ($taskSuite in $taskSuites) {
    $taskLog = Join-Path $taskProject ('Log/' + $taskSuite.Name + '.log')
    # Start-Process 的参数需要单独保留带空格路径的引号。
    $taskArguments = @('--headless', '--path', ('"' + $taskProject + '"'), '--quit-after', '1800', '--log-file', ('"' + $taskLog + '"'), $taskSuite.Scene)
    $taskProcess = Start-Process -FilePath $GodotPath -ArgumentList $taskArguments -WindowStyle Hidden -PassThru -Wait
    $taskOutput = Get-Content -LiteralPath $taskLog
    $taskExpectedFailure = $false
    foreach ($taskText in $taskOutput) {
        if ($taskText -eq 'EXPECTED_LOADING_FAILURE_BEGIN') { $taskExpectedFailure = $true; continue }
        if ($taskText -eq 'EXPECTED_LOADING_FAILURE_END') { $taskExpectedFailure = $false; continue }
        if ($taskText -match '^(SCRIPT ERROR|ERROR):') {
            if (-not ($taskExpectedFailure -and $taskText.StartsWith('ERROR: 无法加载目标场景：'))) {
                throw ($taskSuite.Name + ': ' + $taskText)
            }
        }
    }
    $taskResult = @($taskOutput | Select-String ($taskSuite.Marker + ' assertions=\d+ failures=0$'))
    if ($taskProcess.ExitCode -ne 0 -or $taskResult.Count -ne 1 -or $taskExpectedFailure) {
        throw ('Suite failed: ' + $taskSuite.Name + '. See ' + $taskLog)
    }
    Write-Output $taskResult[0].Line
}
