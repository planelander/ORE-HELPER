param(
    [string]$OutputName = "Ops Helper.exe"
)

$ErrorActionPreference = "Stop"
if ($OutputName -ne 'Ops Helper.exe') {
    throw 'The release filename must be Ops Helper.exe.'
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$iconSource = Join-Path $projectRoot "assets\ore-ops-logo-arrastra-v7.png"
$iconPath = Join-Path $PSScriptRoot "ore-ops.ico"
$distDirectory = Join-Path $projectRoot "dist"
$outputPath = Join-Path $distDirectory $OutputName
$temporaryOutput = "$outputPath.new.exe"

Add-Type -AssemblyName System.Drawing

function New-MultiSizeIcon([string]$SourcePath, [string]$DestinationPath) {
    $source = [System.Drawing.Bitmap]::FromFile($SourcePath)
    $frames = New-Object System.Collections.Generic.List[object]
    try {
        foreach ($size in @(16, 24, 32, 48, 64, 128, 256)) {
            $bitmap = New-Object System.Drawing.Bitmap(
                $size,
                $size,
                [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.Clear([System.Drawing.Color]::Transparent)
                $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

                $scale = [Math]::Min($size / $source.Width, $size / $source.Height)
                $width = [int][Math]::Round($source.Width * $scale)
                $height = [int][Math]::Round($source.Height * $scale)
                $x = [int](($size - $width) / 2)
                $y = [int](($size - $height) / 2)
                $graphics.DrawImage($source, $x, $y, $width, $height)
            } finally {
                $graphics.Dispose()
            }

            $memory = New-Object IO.MemoryStream
            try {
                $bitmap.Save($memory, [System.Drawing.Imaging.ImageFormat]::Png)
                $frames.Add([pscustomobject]@{ Size = $size; Bytes = $memory.ToArray() })
            } finally {
                $memory.Dispose()
                $bitmap.Dispose()
            }
        }
    } finally {
        $source.Dispose()
    }

    $stream = New-Object IO.FileStream(
        $DestinationPath,
        [IO.FileMode]::Create,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None)
    $writer = New-Object IO.BinaryWriter($stream)
    try {
        $writer.Write([uint16]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]$frames.Count)
        [uint32]$offset = 6 + (16 * $frames.Count)
        foreach ($frame in $frames) {
            $dimension = if ($frame.Size -eq 256) { 0 } else { $frame.Size }
            $writer.Write([byte]$dimension)
            $writer.Write([byte]$dimension)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([uint16]1)
            $writer.Write([uint16]32)
            $writer.Write([uint32]$frame.Bytes.Length)
            $writer.Write($offset)
            $offset += [uint32]$frame.Bytes.Length
        }
        foreach ($frame in $frames) {
            $writer.Write([byte[]]$frame.Bytes)
        }
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

if (-not (Test-Path -LiteralPath $iconSource)) {
    throw "Logo source was not found: $iconSource"
}

New-Item -ItemType Directory -Path $distDirectory -Force | Out-Null
New-MultiSizeIcon $iconSource $iconPath

$compiler = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$automationAssembly = Get-ChildItem "$env:WINDIR\Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation" -Recurse -Filter System.Management.Automation.dll |
    Select-Object -First 1 -ExpandProperty FullName

if (-not (Test-Path -LiteralPath $compiler)) {
    throw "The .NET Framework C# compiler was not found."
}
if ([string]::IsNullOrWhiteSpace($automationAssembly)) {
    throw "Windows PowerShell automation assembly was not found."
}

$compilerArguments = @(
    "/nologo",
    "/target:winexe",
    "/optimize+",
    "/platform:anycpu",
    "/out:$temporaryOutput",
    "/win32icon:$iconPath",
    "/reference:System.dll",
    "/reference:System.Core.dll",
    "/reference:System.Windows.Forms.dll",
    "/reference:$automationAssembly",
    "/resource:$(Join-Path $projectRoot 'src\MiningHelper.ps1'),OreOps.MiningHelper.ps1",
    "/resource:$(Join-Path $projectRoot 'src\ScanOverlay.ps1'),OreOps.ScanOverlay.ps1",
    "/resource:$(Join-Path $projectRoot 'data\mining-data.json'),OreOps.MiningData.json",
    "/resource:$(Join-Path $projectRoot 'data\ore-buyers.json'),OreOps.OreBuyers.json",
    "/resource:$(Join-Path $projectRoot 'data\mining-compiled.json'),OreOps.MiningSnapshot.json",
    "/resource:$(Join-Path $projectRoot 'data\ground-mining-locations.json'),OreOps.GroundMiningLocations.json",
    "/resource:$(Join-Path $projectRoot 'data\trade-ships.json'),OreOps.TradeShips.json",
    (Join-Path $PSScriptRoot "Program.cs")
)

& $compiler $compilerArguments
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Move-Item -LiteralPath $temporaryOutput -Destination $outputPath -Force
# Prune previous release executables only after the new build is installed.
$resolvedDist = [IO.Path]::GetFullPath($distDirectory).TrimEnd('\') + '\'
$resolvedOutput = [IO.Path]::GetFullPath($outputPath)
foreach ($oldBuild in (Get-ChildItem -LiteralPath $distDirectory -File | Where-Object { $_.Name -like 'ORE-OPS*.exe' -or $_.Name -eq 'Ops Helper.exe' -or $_.Name -eq 'Ops Helper.exe.new.exe' })) {
    $resolvedOld = [IO.Path]::GetFullPath($oldBuild.FullName)
    if (-not $resolvedOld.StartsWith($resolvedDist, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Cleanup target is outside the release folder: $resolvedOld"
    }
    if ($resolvedOld -ne $resolvedOutput) {
        try { Remove-Item -LiteralPath $resolvedOld -Force }
        catch { Write-Warning "Could not remove older build '$($oldBuild.Name)'. Close that app and run the build again." }
    }
}
Write-Output "Built standalone launcher: $outputPath"
