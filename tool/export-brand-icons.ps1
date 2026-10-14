$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path $PSScriptRoot -Parent
$source = [System.Drawing.Image]::FromFile((Join-Path $projectRoot 'assets/brand/moneyflow-master.png'))
function Export-Icon([string]$relative, [int]$size) {
    $bitmap = New-Object System.Drawing.Bitmap $size,$size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#0F1115'))
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($source, 0, 0, $size, $size)
        $bitmap.Save((Join-Path $projectRoot $relative), [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
try {
    foreach ($density in @{mdpi=48;hdpi=72;xhdpi=96;xxhdpi=144;xxxhdpi=192}.GetEnumerator()) {
        Export-Icon "android/app/src/main/res/mipmap-$($density.Key)/ic_launcher.png" $density.Value
    }
    $catalog = Get-Content (Join-Path $projectRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json') -Raw | ConvertFrom-Json
    foreach ($entry in $catalog.images) {
        if ($entry.filename) {
            $size = [double]::Parse(($entry.size -split 'x')[0], [Globalization.CultureInfo]::InvariantCulture) * [double](($entry.scale -replace 'x',''))
            Export-Icon "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($entry.filename)" ([int]$size)
        }
    }
    foreach ($size in 16,32,64,128,256,512,1024) { Export-Icon "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png" $size }
    foreach ($size in 192,512) {
        Export-Icon "web/icons/Icon-$size.png" $size
        Export-Icon "web/icons/Icon-maskable-$size.png" $size
    }
    Export-Icon 'web/favicon.png' 32
    Export-Icon 'assets/brand/play-store-icon.png' 512
    Export-Icon 'assets/brand/windows-256.png' 256
    # ICO container with a PNG-compressed 256px image, supported by Windows.
    $bytes = [IO.File]::ReadAllBytes((Join-Path $projectRoot 'assets/brand/windows-256.png'))
    $stream = [IO.File]::Create((Join-Path $projectRoot 'windows/runner/resources/app_icon.ico'))
    $writer = New-Object IO.BinaryWriter $stream
    try {
        $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]1)
        $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0)
        $writer.Write([uint16]1); $writer.Write([uint16]32)
        $writer.Write([uint32]$bytes.Length); $writer.Write([uint32]22); $writer.Write($bytes)
    } finally { $writer.Dispose() }
} finally { $source.Dispose() }
