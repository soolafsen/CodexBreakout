$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$distDir = Join-Path $projectRoot 'dist'
$outputExe = Join-Path $distDir 'CandyBreakoutBombast.exe'
$zipPath = Join-Path $distDir 'CandyBreakoutBombast-win64.zip'
$godotCommand = (Get-Command godot -ErrorAction Stop).Source

function Get-GodotVersionParts {
    $versionRaw = (& $godotCommand --version | Out-String).Trim()
    $parts = $versionRaw.Split('.')
    if ($parts.Length -lt 4) {
        throw "Unexpected Godot version format: $versionRaw"
    }

    $shortVersion = "$($parts[0]).$($parts[1]).$($parts[2])"
    $channel = $parts[3]

    [pscustomobject]@{
        Raw = $versionRaw
        ShortVersion = $shortVersion
        Channel = $channel
        FolderName = "$shortVersion.$channel"
        ReleaseTag = "$shortVersion-$channel"
    }
}

function Ensure-ExportTemplates {
    param(
        [pscustomobject]$VersionInfo
    )

    $templateRoot = Join-Path $env:APPDATA 'Godot\export_templates'
    $templateDir = Join-Path $templateRoot $VersionInfo.FolderName
    $releaseTemplate = Join-Path $templateDir 'windows_release_x86_64.exe'
    $debugTemplate = Join-Path $templateDir 'windows_debug_x86_64.exe'

    if ((Test-Path $releaseTemplate) -and (Test-Path $debugTemplate)) {
        return
    }

    New-Item -ItemType Directory -Force $templateRoot | Out-Null
    New-Item -ItemType Directory -Force $templateDir | Out-Null

    $tempRoot = Join-Path $env:TEMP ("codexbreakout-godot-templates-" + [guid]::NewGuid().ToString('N'))
    $tpzPath = Join-Path $tempRoot "Godot_v$($VersionInfo.ReleaseTag)_export_templates.tpz"
    $zipPath = [System.IO.Path]::ChangeExtension($tpzPath, '.zip')
    $extractDir = Join-Path $tempRoot 'extract'
    $url = "https://github.com/godotengine/godot/releases/download/$($VersionInfo.ReleaseTag)/Godot_v$($VersionInfo.ReleaseTag)_export_templates.tpz"

    New-Item -ItemType Directory -Force $tempRoot | Out-Null

    Invoke-WebRequest -Uri $url -OutFile $tpzPath
    Copy-Item $tpzPath $zipPath -Force
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    $candidateRoot = if (Test-Path (Join-Path $extractDir 'templates')) {
        Join-Path $extractDir 'templates'
    } else {
        $extractDir
    }

    Copy-Item (Join-Path $candidateRoot '*') $templateDir -Recurse -Force
}

$version = Get-GodotVersionParts
Ensure-ExportTemplates -VersionInfo $version

New-Item -ItemType Directory -Force $distDir | Out-Null
Remove-Item $outputExe, $zipPath -Force -ErrorAction SilentlyContinue

& $godotCommand --headless --path $projectRoot --export-release "Windows Desktop" $outputExe

for ($i = 0; $i -lt 30 -and -not (Test-Path $outputExe); $i++) {
    Start-Sleep -Seconds 1
}

if (-not (Test-Path $outputExe)) {
    throw "Export finished without creating $outputExe"
}

$readmePath = Join-Path $distDir 'RUN_ME.txt'
@'
Candy Breakout Bombast

1. Double-click CandyBreakoutBombast.exe
2. Move the paddle with the mouse or arrow keys
3. Click or press Space to launch
4. Press F when laser mode is active
'@ | Set-Content -Path $readmePath

Compress-Archive -LiteralPath $outputExe, $readmePath -DestinationPath $zipPath -Force
Write-Host "Exported:"
Write-Host "  $outputExe"
Write-Host "  $zipPath"
