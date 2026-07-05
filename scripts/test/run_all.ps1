param(
	[string]$Godot = "",
	[string]$TestPattern = "*_check.gd",
	[int]$TimeoutSec = 45,
	[switch]$KeepGoing,
	[switch]$StrictOutput,
	[switch]$List
)

$ErrorActionPreference = "Stop"

function Resolve-Executable {
	param([string]$Candidate)
	if ([string]::IsNullOrWhiteSpace($Candidate)) {
		return $null
	}
	if (Test-Path -LiteralPath $Candidate) {
		return (Resolve-Path -LiteralPath $Candidate).Path
	}
	$command = Get-Command $Candidate -ErrorAction SilentlyContinue
	if ($null -ne $command) {
		return $command.Source
	}
	return $null
}

function Resolve-Godot {
	param([string]$Requested)

	$resolved = Resolve-Executable $Requested
	if ($null -ne $resolved) {
		return $resolved
	}

	$resolved = Resolve-Executable $env:GODOT4
	if ($null -ne $resolved) {
		return $resolved
	}

	$resolved = Resolve-Executable "godot"
	if ($null -ne $resolved) {
		return $resolved
	}

	$wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
	if (Test-Path -LiteralPath $wingetRoot) {
		$wingetExecutables = Get-ChildItem -LiteralPath $wingetRoot -Directory -ErrorAction SilentlyContinue |
			Where-Object { $_.Name -match "Godot" } |
			ForEach-Object {
				Get-ChildItem -LiteralPath $_.FullName -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue
			} |
			Where-Object { $_.Name -match "godot" -and $_.Name -notmatch "headless|server" }
		$wingetMatch = $wingetExecutables |
			Where-Object { $_.Name -match "console" } |
			Sort-Object LastWriteTime -Descending |
			Select-Object -First 1
		if ($null -eq $wingetMatch) {
			$wingetMatch = $wingetExecutables |
				Sort-Object LastWriteTime -Descending |
				Select-Object -First 1
		}
		if ($null -ne $wingetMatch) {
			return $wingetMatch.FullName
		}
	}

	throw "Could not locate Godot. Set `$env:GODOT4, pass -Godot, install a 'godot' command, or install Godot through WinGet."
}

function Test-StrictOutputAllowedLine {
	param([string]$Line)
	return $Line -match '^\s*WARNING:\s+ObjectDB instances leaked at exit \(run with --verbose for details\)\.\s*$' -or
		$Line -match '^\s*ERROR:\s+\d+\s+resources? still in use at exit \(run with --verbose for details\)\.\s*$'
}

function Get-StrictOutputIssues {
	param([string]$Output)

	$issues = @()
	if ([string]::IsNullOrEmpty($Output)) {
		return $issues
	}

	$lines = $Output -split "\r?\n"
	for ($i = 0; $i -lt $lines.Count; $i++) {
		$line = $lines[$i]
		if (Test-StrictOutputAllowedLine -Line $line) {
			continue
		}

		$reason = $null
		if ($line -match '\bSCRIPT ERROR:') {
			$reason = "SCRIPT ERROR"
		} elseif ($line -match '\bParse Error\b') {
			$reason = "Parse Error"
		} elseif ($line -match '^\s*ERROR:') {
			$reason = "runtime ERROR"
		}

		if ($null -ne $reason) {
			$issues += [pscustomobject]@{
				LineNumber = $i + 1
				Reason = $reason
				Line = $line
			}
		}
	}

	return $issues
}

function Invoke-GodotScript {
	param(
		[string]$GodotPath,
		[string]$RepoRoot,
		[System.IO.FileInfo]$ScriptFile,
		[string]$LogDir,
		[int]$TimeoutSeconds,
		[bool]$StrictOutput
	)

	$logPath = Join-Path $LogDir ($ScriptFile.BaseName + ".log")
	$relativeScript = $ScriptFile.FullName.Substring($RepoRoot.Length).TrimStart("\", "/") -replace "\\", "/"
	$arguments = @("--headless", "--path", $RepoRoot, "--script", $relativeScript)
	$started = Get-Date

	$job = Start-Job -ArgumentList $GodotPath, $RepoRoot, $relativeScript -ScriptBlock {
		param([string]$InnerGodotPath, [string]$InnerRepoRoot, [string]$InnerScript)
		Set-Location -LiteralPath $InnerRepoRoot
		$lines = & $InnerGodotPath --headless --path $InnerRepoRoot --script $InnerScript 2>&1 |
			ForEach-Object { $_.ToString() }
		[pscustomobject]@{
			ExitCode = $LASTEXITCODE
			Output = ($lines -join [Environment]::NewLine)
		}
	}

	$completed = Wait-Job -Job $job -Timeout $TimeoutSeconds
	$output = ""
	$exitCode = -1
	if ($null -ne $completed) {
		$payload = Receive-Job -Job $job
		if ($null -ne $payload) {
			$exitCode = [int]$payload.ExitCode
			$output = [string]$payload.Output
		}
	} else {
		Stop-Job -Job $job -ErrorAction SilentlyContinue
	}
	Remove-Job -Job $job -Force -ErrorAction SilentlyContinue

	$elapsed = [int]((Get-Date) - $started).TotalMilliseconds
	$strictOutputIssues = @()
	if ($StrictOutput) {
		$strictOutputIssues = @(Get-StrictOutputIssues -Output $output)
	}
	$status = if ($null -eq $completed) { "TIMEOUT" } elseif ($exitCode -eq 0 -and $strictOutputIssues.Count -eq 0) { "PASS" } else { "FAIL" }
	$strictModeText = if ($StrictOutput) { "ON" } else { "OFF" }
	$strictHeader = @(
		"strict_output: $strictModeText"
	)
	if ($StrictOutput) {
		$strictHeader += "strict_output_issues: $($strictOutputIssues.Count)"
		foreach ($issue in $strictOutputIssues) {
			$strictHeader += "strict_output_issue: line $($issue.LineNumber) [$($issue.Reason)] $($issue.Line)"
		}
	}

	$header = @(
		"command: `"$GodotPath`" $($arguments -join ' ')",
		"exit_code: $exitCode",
		"elapsed_ms: $elapsed",
		"status: $status"
	) + $strictHeader + @(
		"",
		"--- output ---",
		$output
	)
	Set-Content -LiteralPath $logPath -Value $header -Encoding UTF8

	return [pscustomobject]@{
		Name = $ScriptFile.Name
		Status = $status
		ExitCode = $exitCode
		ElapsedMs = $elapsed
		Log = $logPath
		StrictOutputIssues = $strictOutputIssues
	}
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..\..")).Path
$godotPath = Resolve-Godot $Godot
$testScripts = Get-ChildItem -LiteralPath $scriptRoot -Filter $TestPattern -File |
	Sort-Object Name

if ($testScripts.Count -eq 0) {
	throw "No test scripts matched '$TestPattern' in $scriptRoot."
}

if ($List) {
	$testScripts | ForEach-Object { $_.FullName }
	exit 0
}

$logDir = Join-Path $repoRoot "artifacts\test-logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

Write-Host "Godot: $godotPath"
Write-Host "Repo:  $repoRoot"
Write-Host "Logs:  $logDir"
Write-Host ""

$results = @()
foreach ($testScript in $testScripts) {
	$result = Invoke-GodotScript -GodotPath $godotPath -RepoRoot $repoRoot -ScriptFile $testScript -LogDir $logDir -TimeoutSeconds $TimeoutSec -StrictOutput $StrictOutput.IsPresent
	$results += $result
	if ($result.Status -ne "PASS" -and -not $KeepGoing) {
		break
	}
}

"{0,-42} {1,-8} {2,8}  {3}" -f "Test", "Status", "Ms", "Log"
"{0,-42} {1,-8} {2,8}  {3}" -f "----", "------", "--", "---"
foreach ($result in $results) {
	"{0,-42} {1,-8} {2,8}  {3}" -f $result.Name, $result.Status, $result.ElapsedMs, $result.Log
}

$failed = @($results | Where-Object { $_.Status -ne "PASS" })
if ($failed.Count -gt 0) {
	Write-Host ""
	Write-Host "Failed tests:"
	foreach ($result in $failed) {
		Write-Host ("- {0} ({1}) -> {2}" -f $result.Name, $result.Status, $result.Log)
		if ($StrictOutput -and $result.StrictOutputIssues.Count -gt 0) {
			foreach ($issue in $result.StrictOutputIssues) {
				Write-Host ("  strict line {0}: [{1}] {2}" -f $issue.LineNumber, $issue.Reason, $issue.Line)
			}
		}
	}
	exit 1
}

exit 0
