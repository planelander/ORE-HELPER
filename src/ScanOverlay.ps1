# Local screen OCR only; no game memory access or injected game hooks.
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
if (-not ('OreOps.ScanNative' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
namespace OreOps {
    public static class ScanNative {
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint id);
        [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int index);
        [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int index, int value);
        [DllImport("user32.dll")] public static extern bool GetCursorPos(out Point p);
        [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int key);
        [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
        [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out Rect r);
        [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref Point p);
        [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left; public int Top; public int Right; public int Bottom; }
        [StructLayout(LayoutKind.Sequential)] public struct Point { public int X; public int Y; }
    }
}
'@
}

function Get-ScanSignatureValue([string]$Text) {
    # A tight selection must contain exactly one integer, optionally with RS label.
    # Reject other HUD values, decimals, and units rather than guessing.
    $clean = $Text.Trim() -replace '(?i)\b(RS|SIGNATURE)\b\s*[:=]?', ''
    $clean = $clean.Trim()
    if ($clean -notmatch '^\d{1,3}(?:[, ]\d{3})+$|^\d{4,6}$') { return $null }
    [int]$value = $clean -replace '[, ]', ''
    if ($value -lt 1000 -or $value -gt 999999) { return $null }
    return $value
}

function Test-ScanGameForeground {
    [uint32]$foregroundId = 0
    $null = [OreOps.ScanNative]::GetWindowThreadProcessId([OreOps.ScanNative]::GetForegroundWindow(), [ref]$foregroundId)
    $process = Get-Process -Id $foregroundId -ErrorAction SilentlyContinue
    return [bool]($process -and $process.ProcessName -eq 'StarCitizen')
}

function Get-AutomaticScanRegion {
    $h = [OreOps.ScanNative]::GetForegroundWindow()
    $rect = [OreOps.ScanNative+Rect]::new()
    $origin = [OreOps.ScanNative+Point]::new()
    if (-not [OreOps.ScanNative]::GetClientRect($h, [ref]$rect) -or
        -not [OreOps.ScanNative]::ClientToScreen($h, [ref]$origin)) { return $null }
    $width = $rect.Right - $rect.Left; $height = $rect.Bottom - $rect.Top
    if ($width -lt 400 -or $height -lt 300) { return $null }
    # Search the central scan returns; exclude upper-center overlay and side displays.
    [pscustomobject]@{
        Left = $origin.X + [int]($width * 0.25)
        Top = $origin.Y + [int]($height * 0.27)
        Width = [int]($width * 0.5)
        Height = [int]($height * 0.38)
    }
}

function Get-AutomaticScanValue($Lines) {
    $values = @($Lines | Where-Object { $_.HasMarker } | ForEach-Object {
        Get-ScanSignatureValue ([string]$_.Text)
    } | Where-Object { $null -ne $_ } | Select-Object -Unique)
    # Multiple markers with different signatures must not be combined into one ore.
    if ($values.Count -eq 1) { return $values[0] }
    return $null
}

function Update-ScanOverlayPosition {
    $handle = ([System.Windows.Interop.WindowInteropHelper]::new($script:scanOverlay)).Handle
    if ($handle -eq [IntPtr]::Zero -and $script:scanBadge) {
        $handle = ([System.Windows.Interop.WindowInteropHelper]::new($script:scanBadge)).Handle
    }
    if ($handle -eq [IntPtr]::Zero) { return }
    $source = [System.Windows.Interop.HwndSource]::FromHwnd($handle)
    $scale = $source.CompositionTarget.TransformFromDevice
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $left = $bounds.Left; $top = $bounds.Top; $width = $bounds.Width; $height = $bounds.Height
    $gameRect = [OreOps.ScanNative+Rect]::new()
    if ((Test-ScanGameForeground) -and [OreOps.ScanNative]::GetWindowRect([OreOps.ScanNative]::GetForegroundWindow(), [ref]$gameRect)) {
        $left = $gameRect.Left; $top = $gameRect.Top
        $width = $gameRect.Right - $left; $height = $gameRect.Bottom - $top
    }
    # Keep the ore name near the top center, above the cockpit view.
    $script:scanOverlay.Left = ($left + $width / 2) * $scale.M11 - $script:scanOverlay.Width / 2
    $script:scanOverlay.Top = ($top + $height * 0.07) * $scale.M22
    if ($script:scanBadge) {
        $script:scanBadge.Left = ($left + 18) * $scale.M11
        $script:scanBadge.Top = ($top + $height) * $scale.M22 - $script:scanBadge.Height - 18
    }
}

function Get-ScanOverlayMatches([int]$Value) {
    $candidates = foreach ($signature in $data.signatures) {
        for ($count = 1; $count -le 10; $count++) {
            $expected = [double]$signature.base * $count
            $difference = [Math]::Abs($Value - $expected) / $expected * 100
            if ($difference -le 0.5) {
                [pscustomobject]@{ name=$signature.name; count=$count; error=$difference; category=$signature.category }
            }
        }
    }
    @($candidates | Sort-Object error, name)
}

function Show-DetectedScanOre([int]$Value) {
    $matches = @(Get-ScanOverlayMatches $Value | Where-Object { $_.category -eq 'Ship-mineable ore' })
    if ($matches.Count -eq 0) { return $false }
    $names = @($matches | ForEach-Object { if ($_.name -eq 'Quantainium') { 'Quantanium' } else { $_.name } } | Select-Object -Unique)
    $script:scanOverlayText.Text = $names -join ' / '
    $script:scanLastRead = [DateTime]::UtcNow
    if ($script:scanEnabled) { $script:scanOverlay.Show() }
    Update-ScanOverlayPosition
    (Find-Control 'ScanOverlayStatus').Text = "Read RS $Value -> $($script:scanOverlayText.Text)"
    return $true
}

$script:scanRegion = $null
$script:scanPowerShell = $null
$script:scanPending = $null
$script:scanPrevious = $null
$script:scanRepeat = 0
$script:scanOverlay = $null
$script:scanBadge = $null
$script:scanEnabled = $false
$script:scanFault = $null
$script:scanFaultAt = [DateTime]::MinValue
$script:scanLastRead = [DateTime]::MinValue

# Runs on a background runspace so OCR cannot freeze the WPF interface.
$script:scanWorker = {
    param($left, $top, $width, $height, [bool]$automatic = $false)
    $ErrorActionPreference = 'Stop'
    Add-Type -AssemblyName System.Drawing, System.Runtime.WindowsRuntime
    if (-not ('OreOps.ScanImage' -as [type])) {
        Add-Type -ReferencedAssemblies System.Drawing @'
using System.Drawing;
namespace OreOps {
    public static class ScanImage {
        public static Bitmap WhiteText(Bitmap image) {
            Bitmap filtered = new Bitmap(image.Width, image.Height);
            for (int y = 0; y < image.Height; y++)
                for (int x = 0; x < image.Width; x++) {
                    Color c = image.GetPixel(x, y);
                    bool text = c.R > 140 && c.G > 140 && c.B > 125 &&
                        c.R >= c.G * 0.94 && c.R >= c.B * 0.94;
                    filtered.SetPixel(x, y, text ? Color.Black : Color.White);
                }
            return filtered;
        }
        public static Rectangle[] Markers(Bitmap image) {
            int w = image.Width, h = image.Height;
            bool[] orange = new bool[w*h];
            for (int y=0; y<h; y++) for (int x=0; x<w; x++) {
                Color c=image.GetPixel(x,y);
                // Scan pins can be orange or yellow depending on HUD state.
                orange[y*w+x]=c.R>130 && c.G>55 && c.G<c.R*1.10 && c.B<c.G*0.8;
            }
            var boxes=new System.Collections.Generic.List<Rectangle>();
            var queue=new System.Collections.Generic.Queue<int>();
            for(int i=0;i<orange.Length;i++) {
                if(!orange[i]) continue;
                orange[i]=false; queue.Enqueue(i);
                int minX=w,minY=h,maxX=0,maxY=0,count=0;
                while(queue.Count>0) {
                    int p=queue.Dequeue(), x=p%w, y=p/w; count++;
                    minX=System.Math.Min(minX,x); maxX=System.Math.Max(maxX,x);
                    minY=System.Math.Min(minY,y); maxY=System.Math.Max(maxY,y);
                    for(int dy=-1;dy<=1;dy++) for(int dx=-1;dx<=1;dx++) {
                        int nx=x+dx,ny=y+dy;
                        if(nx<0||ny<0||nx>=w||ny>=h) continue;
                        int n=ny*w+nx;
                        if(orange[n]) { orange[n]=false; queue.Enqueue(n); }
                    }
                }
                int bh=maxY-minY+1,bw=maxX-minX+1;
                if(count<12 || bh<7 || bh>55 || bw<4 || bw>bh*2) continue;
                int left=maxX+1, top=System.Math.Max(0,minY-bh);
                int right=System.Math.Min(w,left+bh*9),bottom=System.Math.Min(h,maxY+bh+1);
                if(right>left && bottom>top) boxes.Add(Rectangle.FromLTRB(left,top,right,bottom));
            }
            return boxes.ToArray();
        }
    }
}
'@
    }
    $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime]
    $null = [Windows.Storage.FileAccessMode, Windows.Storage, ContentType=WindowsRuntime]
    $null = [Windows.Storage.Streams.IRandomAccessStream, Windows.Storage.Streams, ContentType=WindowsRuntime]
    $null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType=WindowsRuntime]
    $null = [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType=WindowsRuntime]
    $null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime]
    $null = [Windows.Media.Ocr.OcrResult, Windows.Foundation, ContentType=WindowsRuntime]
    $null = [Windows.Media.Ocr.OcrLine, Windows.Foundation, ContentType=WindowsRuntime]
    $null = [Windows.Media.Ocr.OcrWord, Windows.Foundation, ContentType=WindowsRuntime]
    $asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetGenericArguments().Count -eq 1 -and
        $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    } | Select-Object -First 1
    function Await-Scan($Operation, [Type]$ResultType) {
        $task = $asTask.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
        if (-not $task.Wait(10000)) { throw 'Windows OCR timed out.' }
        $task.Result
    }
    if ($null -eq $script:cachedScanEngine) {
        $script:cachedScanEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
    }
    $engine = $script:cachedScanEngine
    if ($null -eq $engine) { throw 'Windows OCR language is unavailable. Install a supported Windows language pack.' }
    $path = Join-Path ([IO.Path]::GetTempPath()) ('oreops-scan-' + [guid]::NewGuid() + '.png')
    $bitmap = $null; $graphics = $null; $stream = $null; $software = $null; $enlarged = $null
    try {
        $bitmap = [System.Drawing.Bitmap]::new($width, $height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($left, $top, 0, 0, $bitmap.Size)
        $regions = if ($automatic) { @([OreOps.ScanImage]::Markers($bitmap) | Sort-Object { [Math]::Abs(($_.Left - $_.Height / 3) - $width / 2) + [Math]::Abs(($_.Top + $_.Height / 3) - $height / 3) } | Select-Object -First 24) } else { @([System.Drawing.Rectangle]::new(0,0,$width,$height)) }
        foreach ($region in $regions) {
            $crop = $bitmap.Clone($region, $bitmap.PixelFormat)
            try {
                foreach ($style in @('color', 'filtered')) {
                $foundNumber = $false
                if ($automatic) {
                    # Preserve the original antialiased digits first. Thresholding
                    # alone can erase their thinner strokes on a translucent HUD.
                    $filtered = if ($style -eq 'color') { [System.Drawing.Bitmap]::new($crop) } else { [OreOps.ScanImage]::WhiteText($crop) }
                    $factor = 2.0
                    try { $enlarged = [System.Drawing.Bitmap]::new($filtered, [int]($region.Width * $factor), [int]($region.Height * $factor)) }
                    finally { $filtered.Dispose() }
                    $enlarged.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
                } else { $crop.Save($path, [System.Drawing.Imaging.ImageFormat]::Png) }
                $file = Await-Scan ([Windows.Storage.StorageFile]::GetFileFromPathAsync($path)) ([Windows.Storage.StorageFile])
                $stream = Await-Scan ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
                $decoder = Await-Scan ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
                $software = Await-Scan ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
                [Windows.Media.Ocr.OcrResult]$result = Await-Scan ($engine.RecognizeAsync($software)) ([Windows.Media.Ocr.OcrResult])
                if (-not $automatic) { [string]$result.Text }
                else {
                    foreach ($line in $result.Lines) {
                        # White digits immediately to the right of a detected orange icon.
                        # The condensed HUD digit 1 is sometimes read as i, I, or l.
                        $numberText = ($line.Text.Trim() -creplace '[iIl]', '1').Trim([char[]]' ,.:;')
                        if ($numberText -match '^\d{1,3}(?:[, ]\d{3})+$|^\d{4,6}$') {
                            [pscustomobject]@{ Text=[string]$numberText; HasMarker=$true }
                            $foundNumber = $true
                        }
                    }
                }
                if ($software) { $software.Dispose(); $software=$null }
                if ($stream) { $stream.Dispose(); $stream=$null }
                if ($enlarged) { $enlarged.Dispose(); $enlarged=$null }
                if ($foundNumber -or -not $automatic) { break }
                }
                # Return the nearest readable marker immediately instead of OCRing
                # every remaining cockpit label before the UI receives the result.
                if ($foundNumber) { return }
            } finally {
                $crop.Dispose()
                if ($software) { $software.Dispose(); $software=$null }
                if ($stream) { $stream.Dispose(); $stream=$null }
                if ($enlarged) { $enlarged.Dispose(); $enlarged=$null }
            }
        }
    } finally {
        if ($software) { $software.Dispose() }
        if ($stream) { $stream.Dispose() }
        if ($graphics) { $graphics.Dispose() }
        if ($bitmap) { $bitmap.Dispose() }
        if ($enlarged) { $enlarged.Dispose() }
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
}

function Stop-ScanOverlay {
    $script:scanEnabled = $false
    $scanTimer.Stop()
    if ($script:scanPowerShell) {
        $script:scanPowerShell.Stop()
        $script:scanPowerShell.Dispose()
    }
    $script:scanPowerShell = $null
    $script:scanPending = $null
    $script:scanPrevious = $null
    $script:scanRepeat = 0
    $script:scanFault = $null
    if ($script:scanOverlay) { $script:scanOverlay.Close() }
    if ($script:scanBadge) { $script:scanBadge.Close() }
    $script:scanBadge = $null
    $script:scanOverlay = $null
    (Find-Control 'ToggleScanOverlay').Content = 'START OVERLAY (F3)'
    (Find-Control 'ScanOverlayStatus').Text = 'Automatic scan overlay stopped. Press F3 in game to enable it.'
}

$script:scanTimer = [System.Windows.Threading.DispatcherTimer]::new()
$scanTimer.Interval = [TimeSpan]::FromMilliseconds(100)
$scanTimer.Add_Tick({
    try {
        $inGame = Test-ScanGameForeground
        if ($inGame) {
            if ($script:scanEnabled) { $script:scanBadge.Show() }
            Update-ScanOverlayPosition
        }
        if (-not $inGame) {
            $script:scanBadge.Hide()
            $script:scanOverlay.Hide()
            $script:scanPrevious = $null; $script:scanRepeat = 0
            if (-not $script:scanFault) { (Find-Control 'ScanOverlayStatus').Text = 'Overlay enabled. Waiting for Star Citizen to have focus.' }
        }
        if ($script:scanFault) {
            $script:scanOverlay.Hide()
            if (([DateTime]::UtcNow - $script:scanFaultAt).TotalSeconds -lt 3) { return }
            $script:scanFault = $null
        }
        if ($inGame -and ([DateTime]::UtcNow - $script:scanLastRead).TotalSeconds -gt 5) {
            $script:scanOverlay.Hide()
            $script:scanOverlayText.Text = ''
        }
        if ($script:scanPending) {
            if (-not $script:scanPending.IsCompleted) { return }
            $output = $script:scanPowerShell.EndInvoke($script:scanPending)
            if ($script:scanPowerShell.HadErrors) { throw $script:scanPowerShell.Streams.Error[0] }
            $script:scanPending = $null
            if ($inGame) {
                $value = Get-AutomaticScanValue $output
                (Find-Control 'ScanOverlayStatus').Text = if ($null -ne $value) { "Read RS $value. Checking ore signatures..." } else { 'Overlay enabled. No single readable scan marker in the captured HUD.' }
                if ($null -ne $value -and $value -eq $script:scanPrevious) { $script:scanRepeat++ }
                else { $script:scanPrevious = $value; $script:scanRepeat = 1 }
                if ($null -ne $value) {
                    if (-not (Show-DetectedScanOre $value)) {
                        (Find-Control 'ScanOverlayStatus').Text = "Read RS $value. No ship-ore match in the current signature database."
                    }
                }
                if ($script:scanEnabled -and $script:scanOverlayText.Text) { $script:scanOverlay.Show(); Update-ScanOverlayPosition }
                else { $script:scanOverlay.Hide() }
            }
        }
        if (-not $inGame) { return }
        $r = Get-AutomaticScanRegion
        if ($null -eq $r) {
            (Find-Control 'ScanOverlayStatus').Text = 'Overlay enabled. Could not determine the game capture area.'
            return
        }
        if ($null -eq $script:scanPowerShell) { $script:scanPowerShell = [PowerShell]::Create() }
        else { $script:scanPowerShell.Commands.Clear(); $script:scanPowerShell.Streams.Error.Clear() }
        $null = $script:scanPowerShell.AddScript($script:scanWorker.ToString()).AddArgument($r.Left).AddArgument($r.Top).AddArgument($r.Width).AddArgument($r.Height).AddArgument($true)
        $script:scanPending = $script:scanPowerShell.BeginInvoke()
    } catch {
        $message = $_.Exception.Message
        if ($script:scanPowerShell) { $script:scanPowerShell.Dispose() }
        $script:scanPowerShell = $null; $script:scanPending = $null
        $script:scanFault = $message
        $script:scanFaultAt = [DateTime]::UtcNow
        $script:scanOverlay.Hide()
        $script:scanOverlayText.Text = ''
        (Find-Control 'ScanOverlayStatus').Text = "Scan recognition unavailable: $message"
    }
})

function Toggle-ScanOverlay {
    if ($script:scanOverlay) {
        $script:scanEnabled = -not $script:scanEnabled
        if (-not $script:scanEnabled) { $script:scanOverlay.Hide(); $script:scanBadge.Hide() }
        (Find-Control 'ToggleScanOverlay').Content = if ($script:scanEnabled) { 'HIDE OVERLAY (F3)' } else { 'SHOW OVERLAY (F3)' }
        (Find-Control 'ScanOverlayStatus').Text = 'Scan detection is running continuously. F3 only changes overlay visibility.'
        return
    }
    $script:scanFault = $null
    $script:scanLastRead = [DateTime]::MinValue
    $script:scanOverlay = [System.Windows.Window]::new()
    $script:scanBadge = [System.Windows.Window]::new()
    $scanBadge.WindowStyle = 'None'; $scanBadge.ResizeMode = 'NoResize'
    $scanBadge.AllowsTransparency = $true; $scanBadge.Background = 'Transparent'
    $scanBadge.Topmost = $true; $scanBadge.ShowActivated = $false
    $scanBadge.ShowInTaskbar = $false; $scanBadge.IsHitTestVisible = $false
    $scanBadge.Width = 154; $scanBadge.Height = 42
    [xml]$badgeXaml = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Background="#D9101016" BorderBrush="#FFB87A" BorderThickness="8,1,1,3" CornerRadius="16,4,4,16" Padding="10,4">
    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
        <TextBlock Text="ORE//OPS" Foreground="#FFB87A" FontFamily="Segoe UI" FontSize="13" FontWeight="Bold"/>
        <Border Background="#C7B5EF" CornerRadius="5" Padding="5,2" Margin="8,0,0,0">
            <TextBlock Text="ON" Foreground="#101016" FontFamily="Segoe UI" FontSize="9" FontWeight="Bold"/>
        </Border>
    </StackPanel>
</Border>
'@
    $scanBadge.Content = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($badgeXaml))
    $scanBadge.Add_SourceInitialized({
        $h = ([System.Windows.Interop.WindowInteropHelper]::new($script:scanBadge)).Handle
        $style = [OreOps.ScanNative]::GetWindowLong($h, -20)
        $null = [OreOps.ScanNative]::SetWindowLong($h, -20, ($style -bor 0x20 -bor 0x80 -bor 0x08000000))
    })
    $scanOverlay.WindowStyle = 'None'; $scanOverlay.ResizeMode = 'NoResize'
    $scanOverlay.AllowsTransparency = $true; $scanOverlay.Background = '#CC101016'
    $scanOverlay.Topmost = $true; $scanOverlay.ShowActivated = $false
    $scanOverlay.ShowInTaskbar = $false; $scanOverlay.IsHitTestVisible = $false
    $scanOverlay.Width = 480
    $scanOverlay.SizeToContent = 'Height'
    $scanOverlay.Left = [System.Windows.SystemParameters]::WorkArea.Left + 24
    $scanOverlay.Top = [System.Windows.SystemParameters]::WorkArea.Top + 24
    $script:scanOverlayText = [System.Windows.Controls.TextBlock]::new()
    $scanOverlayText.Foreground = '#FFB87A'; $scanOverlayText.FontFamily = 'Segoe UI'
    $scanOverlayText.FontSize = if ($script:overlayFontSize) { $script:overlayFontSize } else { 17 }
    $scanOverlayText.Margin = '16'; $scanOverlayText.MaxWidth = 480
    $scanOverlayText.TextAlignment = 'Center'
    $scanOverlayText.TextWrapping = 'Wrap'; $scanOverlayText.Text = ''
    $scanOverlay.Content = $scanOverlayText
    $scanOverlay.Add_SourceInitialized({
        $handle = ([System.Windows.Interop.WindowInteropHelper]::new($script:scanOverlay)).Handle
        $style = [OreOps.ScanNative]::GetWindowLong($handle, -20)
        # WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE
        $null = [OreOps.ScanNative]::SetWindowLong($handle, -20, ($style -bor 0x20 -bor 0x80 -bor 0x08000000))
        Update-ScanOverlayPosition
    })
    $script:scanEnabled = $true
    (Find-Control 'ToggleScanOverlay').Content = 'HIDE OVERLAY (F3)'
    (Find-Control 'ScanOverlayStatus').Text = 'Scan detection is running continuously. F3 only changes overlay visibility.'
    $scanTimer.Start()
    if (Test-ScanGameForeground) { $script:scanBadge.Show(); Update-ScanOverlayPosition }
}
(Find-Control 'ToggleScanOverlay').Add_Click({ Toggle-ScanOverlay })

# Observe F3 without reserving it in other applications or consuming game input.
$script:scanF3Down = $false
function Invoke-ScanOverlayHotkey([bool]$Pressed, [bool]$InGame) {
    if ($Pressed -and -not $script:scanF3Down -and $InGame) {
        Toggle-ScanOverlay
    }
    $script:scanF3Down = $Pressed
}
$script:scanHotkeyTimer = [System.Windows.Threading.DispatcherTimer]::new()
$scanHotkeyTimer.Interval = [TimeSpan]::FromMilliseconds(50)
$scanHotkeyTimer.Add_Tick({
    $pressed = ([int][OreOps.ScanNative]::GetAsyncKeyState(0x72) -band 0x8000) -ne 0
    Invoke-ScanOverlayHotkey $pressed (Test-ScanGameForeground)
})
$scanHotkeyTimer.Start()
$window.Add_Closed({
    $scanHotkeyTimer.Stop()
    Stop-ScanOverlay
})
