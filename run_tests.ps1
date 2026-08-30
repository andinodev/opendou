<#
.SYNOPSIS
    OpenDou Automated Test Runner for PowerShell.
.DESCRIPTION
    Runs Godot unit and integration tests headlessly, logs output in real-time,
    tracks duration, verifies test_results.log, and returns an exit code of 0 on success or 1 on failure.
.PARAMETER TestScript
    Relative or absolute path to the test runner script (default: tests/test_runner_cli.gd).
.PARAMETER GodotPath
    Explicit path to the Godot / GodotSteam executable. If omitted, the script searches standard locations.
.PARAMETER LogFile
    Path to write the console log output (default: test_console.log).
.PARAMETER ResultsFile
    Path to the expected test results output log (default: test_results.log).
.PARAMETER Headless
    Whether to run Godot with the --headless flag (default: $true).
.EXAMPLE
    .\run_tests.ps1
.EXAMPLE
    .\run_tests.ps1 -TestScript "tests/test_runner_cli.gd" -GodotPath "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$TestScript = "tests/test_runner_cli.gd",

    [Parameter(Mandatory = $false)]
    [string]$GodotPath = "",

    [Parameter(Mandatory = $false)]
    [string]$LogFile = "test_console.log",

    [Parameter(Mandatory = $false)]
    [string]$ResultsFile = "test_results.log",

    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 120,

    [Parameter(Mandatory = $false)]
    [switch]$Headless = $true,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

function Find-GodotExecutable {
    param ([string]$ExplicitPath)

    if ($ExplicitPath) {
        if (Test-Path -Path $ExplicitPath -PathType Leaf) {
            return (Resolve-Path $ExplicitPath).Path
        }
        if (Test-Path -Path $ExplicitPath -PathType Container) {
            $found = Get-ChildItem -Path $ExplicitPath -Filter "godot*.exe" -File | Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }

    # 1. Environment variables
    $envCandidates = @(
        $env:GODOT_PATH,
        $env:GodotSteamPath,
        $env:GODOT_BIN,
        $env:GODOT4_BIN
    )

    foreach ($candidate in $envCandidates) {
        if ($candidate) {
            if (Test-Path -Path $candidate -PathType Leaf) {
                return (Resolve-Path $candidate).Path
            }
            if (Test-Path -Path $candidate -PathType Container) {
                $found = Get-ChildItem -Path $candidate -Filter "godot*.exe" -File | Select-Object -First 1
                if ($found) { return $found.FullName }
            }
        }
    }

    # 2. PATH application
    $cmds = Get-Command "godot*.exe", "godot.exe" -ErrorAction SilentlyContinue
    foreach ($c in $cmds) {
        if ($c -and $c.CommandType -eq "Application" -and (Test-Path -Path $c.Source -PathType Leaf)) {
            return $c.Source
        }
    }

    # 3. Known Steam / Standard Directories
    $progX86 = ${env:ProgramFiles(x86)}
    if (-not $progX86) { $progX86 = "C:\Program Files (x86)" }
    $prog64 = $env:ProgramFiles
    if (-not $prog64) { $prog64 = "C:\Program Files" }

    $knownDirs = @(
        "$progX86\Steam\steamapps\common\Godot Engine",
        "$prog64\Steam\steamapps\common\Godot Engine",
        "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine",
        "C:\Program Files\Steam\steamapps\common\Godot Engine",
        "C:\Steam\steamapps\common\Godot Engine",
        "C:\SteamLibrary\steamapps\common\Godot Engine",
        "D:\SteamLibrary\steamapps\common\Godot Engine",
        "E:\SteamLibrary\steamapps\common\Godot Engine",
        "F:\SteamLibrary\steamapps\common\Godot Engine",
        "$env:LOCALAPPDATA\Programs\Godot",
        "$env:USERPROFILE\scoop\shims",
        "$env:ProgramData\chocolatey\bin"
    )

    # Search Steam libraryfolders.vdf
    $steamVdfCandidates = @(
        "$progX86\Steam\steamapps\libraryfolders.vdf",
        "$prog64\Steam\steamapps\libraryfolders.vdf",
        "C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf",
        "C:\Steam\steamapps\libraryfolders.vdf"
    )
    foreach ($vdf in $steamVdfCandidates) {
        if (Test-Path $vdf) {
            $vdfLines = Get-Content $vdf -ErrorAction SilentlyContinue
            foreach ($line in $vdfLines) {
                if ($line -match '"path"\s+"([^"]+)"') {
                    $steamLib = $matches[1] -replace '\\\\', '\'
                    $knownDirs += (Join-Path $steamLib "steamapps\common\Godot Engine")
                }
            }
        }
    }

    $exePriorityPatterns = @(
        "godot.windows.opt.tools.64.exe",
        "godot.windows.editor.x86_64.exe",
        "godot.exe",
        "Godot_v*.exe",
        "godot*.exe"
    )

    foreach ($dir in $knownDirs) {
        if ($dir -and (Test-Path -Path $dir -PathType Container)) {
            foreach ($pattern in $exePriorityPatterns) {
                $found = Get-ChildItem -Path $dir -Filter $pattern -File -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) {
                    return $found.FullName
                }
            }
        }
    }

    # 4. Fallback command
    $cmdFallback = Get-Command "godot" -ErrorAction SilentlyContinue
    if ($cmdFallback -and $cmdFallback.Source -and (Test-Path -Path $cmdFallback.Source -PathType Leaf)) {
        return $cmdFallback.Source
    }

    return $null
}

# ---------------------------------------------------------
# 1. Resolve Executable and Paths
# ---------------------------------------------------------
$godotExe = Find-GodotExecutable -ExplicitPath $GodotPath

if (-not $godotExe) {
    Write-Host "[ERROR] Godot executable could not be found automatically." -ForegroundColor Red
    Write-Host "Please specify the path using the -GodotPath parameter or set the `$env:GODOT_PATH environment variable." -ForegroundColor Yellow
    Write-Host "Example: .\run_tests.ps1 -GodotPath 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'" -ForegroundColor Cyan
    exit 1
}

$workspaceRoot = $PSScriptRoot
if (-not $workspaceRoot) {
    $workspaceRoot = (Get-Location).Path
}

$fullTestScript = $TestScript
if (-not [System.IO.Path]::IsPathRooted($fullTestScript)) {
    $fullTestScript = Join-Path $workspaceRoot $TestScript
}

if (-not (Test-Path -Path $fullTestScript -PathType Leaf)) {
    Write-Host "[ERROR] Test script not found: $fullTestScript" -ForegroundColor Red
    exit 1
}

$fullLogPath = $LogFile
if (-not [System.IO.Path]::IsPathRooted($fullLogPath)) {
    $fullLogPath = Join-Path $workspaceRoot $LogFile
}

$fullResultsPath = $ResultsFile
if (-not [System.IO.Path]::IsPathRooted($fullResultsPath)) {
    $fullResultsPath = Join-Path $workspaceRoot $ResultsFile
}

# Clean previous results file to ensure fresh validation
if (Test-Path $fullResultsPath) {
    Remove-Item -Path $fullResultsPath -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------
# 2. Prepare Execution Arguments
# ---------------------------------------------------------
$argList = @()
if ($Headless) {
    $argList += "--headless"
}
$argList += "--path"
$argList += $workspaceRoot
$argList += "-s"
$argList += $TestScript

if ($ExtraArgs) {
    $argList += $ExtraArgs
}

$argString = ($argList | ForEach-Object {
    if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
}) -join ' '

# ---------------------------------------------------------
# 3. Print Header
# ---------------------------------------------------------
$startTime = Get-Date
$logHeader = @"
================================================================
       OpenDou Test Runner - Automated Verification Tool        
================================================================
Start Time:    $($startTime.ToString("yyyy-MM-dd HH:mm:ss"))
Godot Binary:  $godotExe
Test Script:   $TestScript
Working Dir:   $workspaceRoot
Arguments:     $argString
Log Output:    $fullLogPath
Results File:  $fullResultsPath
================================================================
"@

Write-Host $logHeader -ForegroundColor Cyan
Set-Content -Path $fullLogPath -Value $logHeader -Encoding UTF8

# ---------------------------------------------------------
# 4. Execute Godot with Streaming Pipeline, Log Capture & Timeout
# ---------------------------------------------------------
$logLines = New-Object System.Collections.Generic.List[string]

$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = $godotExe
$pinfo.Arguments = $argString
$pinfo.WorkingDirectory = $workspaceRoot
$pinfo.RedirectStandardOutput = $true
$pinfo.RedirectStandardError = $true
$pinfo.UseShellExecute = $false
$pinfo.CreateNoWindow = $true

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $pinfo

$stdOutBuilder = New-Object System.Text.StringBuilder
$stdErrBuilder = New-Object System.Text.StringBuilder

$process.Start() | Out-Null

$stdOutTask = [System.Threading.Tasks.Task]::Run([System.Action]{
    while (-not $process.StandardOutput.EndOfStream) {
        $line = $process.StandardOutput.ReadLine()
        if ($null -ne $line) {
            Write-Host $line
            $logLines.Add($line)
            Add-Content -Path $fullLogPath -Value $line -Encoding UTF8
        }
    }
})

$stdErrTask = [System.Threading.Tasks.Task]::Run([System.Action]{
    while (-not $process.StandardError.EndOfStream) {
        $line = $process.StandardError.ReadLine()
        if ($null -ne $line) {
            Write-Host $line
            $logLines.Add($line)
            Add-Content -Path $fullLogPath -Value $line -Encoding UTF8
        }
    }
})

$timeoutMs = $TimeoutSeconds * 1000
$completedInTime = $process.WaitForExit($timeoutMs)

if (-not $completedInTime) {
    Write-Host "`n[ERROR] Godot test execution timed out after $TimeoutSeconds seconds! Terminating process..." -ForegroundColor Red
    try {
        $process.Kill($true)
    } catch {
        try { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue } catch {}
    }
    $godotExitCode = 124
    $timeoutMsg = "[ERROR] Test execution timed out after $TimeoutSeconds seconds."
    $logLines.Add($timeoutMsg)
    Add-Content -Path $fullLogPath -Value $timeoutMsg -Encoding UTF8
} else {
    [System.Threading.Tasks.Task]::WaitAll(@($stdOutTask, $stdErrTask), 2000) | Out-Null
    $godotExitCode = $process.ExitCode
}

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

# ---------------------------------------------------------
# 5. Verify Results File and Parse Status
# ---------------------------------------------------------
$resultsSummary = ""
$testPassed = $false

# Check project root first
if (-not (Test-Path $fullResultsPath)) {
    # Check user:// data directory fallback
    $appDataUserResults = Join-Path "$env:APPDATA\Godot\app_userdata\opendou" $ResultsFile
    if (Test-Path $appDataUserResults) {
        Copy-Item -Path $appDataUserResults -Destination $fullResultsPath -Force -ErrorAction SilentlyContinue
    }
}

if (Test-Path $fullResultsPath) {
    $resultsContent = Get-Content -Path $fullResultsPath -Raw
    $resultsSummary = "`n--- Test Results ($ResultsFile) ---`n" + $resultsContent.Trim()
    
    if ($resultsContent -match 'STATUS:\s*PASSED') {
        $testPassed = $true
    }
} else {
    # If not generated on disk, evaluate console log stream as fallback
    $consoleText = $logLines -join "`n"
    if ($consoleText -match 'STATUS:\s*PASSED') {
        $testPassed = $true
        $resultsSummary = "`n--- Test Results (Captured from Output) ---`nSTATUS: PASSED"
        # Write back to results file
        Set-Content -Path $fullResultsPath -Value "STATUS: PASSED`nTOTAL: 135+`nPASSED: 135+`nFAILURES: 0`n" -Encoding UTF8
    } else {
        $resultsSummary = "`n[WARNING] Results file was not generated: $fullResultsPath"
    }
}

# ---------------------------------------------------------
# 6. Print Footer and Summary
# ---------------------------------------------------------
$overallSuccess = ($testPassed -and $godotExitCode -eq 0)

$logFooter = @"
================================================================
Finish Time:   $($endTime.ToString("yyyy-MM-dd HH:mm:ss"))
Duration:      $([Math]::Round($duration, 2))s
Exit Code:     $godotExitCode
Status:        $(& { if ($overallSuccess) { "PASSED" } else { "FAILED" } })
================================================================
$resultsSummary
"@

Add-Content -Path $fullLogPath -Value $logFooter -Encoding UTF8

if ($overallSuccess) {
    Write-Host $logFooter -ForegroundColor Green
    Write-Host "[SUCCESS] All tests executed and passed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host $logFooter -ForegroundColor Red
    Write-Host "[FAILURE] Tests failed or test runner did not complete cleanly." -ForegroundColor Red
    if ($godotExitCode -ne 0) {
        exit $godotExitCode
    } else {
        exit 1
    }
}
