param(
    [string]$Message = "Hello!",
    [string]$PetImageDir = "",
    [string]$PetBaseName = "cat2",
    [string]$LabelImagePath = "",
    [int]$DisplaySeconds = 5
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Resize-HighQuality([string]$Path, [int]$W, [int]$H) {
    $src = [System.Drawing.Image]::FromFile($Path)
    $dst = New-Object System.Drawing.Bitmap($W, $H)
    $g = [System.Drawing.Graphics]::FromImage($dst)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($src, 0, 0, $W, $H)
    $g.Dispose(); $src.Dispose()
    return $dst
}

$CHROMA   = [System.Drawing.Color]::FromArgb(1, 0, 0)
$PET_W    = 100
$PET_H    = 100
$BUBBLE_W = 200
$BUBBLE_H = 64
$MARGIN   = 16
$FORM_W   = [Math]::Max($PET_W, $BUBBLE_W) + 20
$FORM_H   = $PET_H + $BUBBLE_H + 8

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea

$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.BackColor       = $CHROMA
$form.TransparencyKey = $CHROMA
$form.TopMost         = $true
$form.ShowInTaskbar   = $false
$form.StartPosition   = [System.Windows.Forms.FormStartPosition]::Manual
$form.Width           = $FORM_W
$form.Height          = $FORM_H
$form.Left            = $screen.Right  - $FORM_W - $MARGIN
$form.Top             = $screen.Bottom - $FORM_H - $MARGIN

# 吹き出しラベル
$label = New-Object System.Windows.Forms.Label
$label.Text        = $Message
$label.Font        = New-Object System.Drawing.Font("Segoe UI Emoji", 10)
$label.ForeColor   = [System.Drawing.Color]::Black
$label.TextAlign   = [System.Drawing.ContentAlignment]::MiddleCenter
$label.Padding     = New-Object System.Windows.Forms.Padding(0, 0, 0, 8)
$label.Width       = $BUBBLE_W
$label.Height      = $BUBBLE_H
$label.Left        = [int](($FORM_W - $BUBBLE_W) / 2)
$label.Top         = 0
$label.Cursor      = [System.Windows.Forms.Cursors]::Hand
if ($LabelImagePath -and (Test-Path $LabelImagePath)) {
    $label.BackgroundImage       = Resize-HighQuality $LabelImagePath $BUBBLE_W $BUBBLE_H
    $label.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Stretch
    $label.BackColor             = [System.Drawing.Color]::Transparent
    $label.BorderStyle           = [System.Windows.Forms.BorderStyle]::None
} else {
    $label.BackColor   = [System.Drawing.Color]::White
    $label.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
}
$form.Controls.Add($label)

$petBox = New-Object System.Windows.Forms.PictureBox
$petBox.SetBounds([int](($FORM_W - $PET_W) / 2), ($BUBBLE_H - 4), $PET_W, $PET_H)
$petBox.SizeMode  = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
$petBox.BackColor = $CHROMA

$frames = @()
if ($PetImageDir -and (Test-Path $PetImageDir)) {
    $frames = @(Get-ChildItem "$PetImageDir\${PetBaseName}_*.png" | Sort-Object Name | ForEach-Object {
        Resize-HighQuality $_.FullName $PET_W $PET_H
    })
}
if ($frames.Count -eq 0) {
    $bmp = New-Object System.Drawing.Bitmap($PET_W, $PET_H)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear($CHROMA)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $f   = New-Object System.Drawing.Font("Segoe UI Emoji", 52)
    $sf  = New-Object System.Drawing.StringFormat
    $sf.Alignment     = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $pr  = New-Object System.Drawing.RectangleF(0.0, 0.0, [float]$PET_W, [float]$PET_H)
    $g.DrawString([char]::ConvertFromUtf32(0x1F431), $f, [System.Drawing.Brushes]::Black, $pr, $sf)
    $f.Dispose(); $sf.Dispose(); $g.Dispose()
    $frames += $bmp
}
$petBox.Image = $frames[0]
$form.Controls.Add($petBox)

$closeAction = { $form.Close() }
$form.Add_Click($closeAction)
$label.Add_Click($closeAction)
$petBox.Add_Click($closeAction)

$script:frameIdx = 0
$animTimer = $null
if ($frames.Count -ge 2) {
    $animTimer = New-Object System.Windows.Forms.Timer
    $animTimer.Interval = 800
    $animTimer.Add_Tick({
        $script:frameIdx = ($script:frameIdx + 1) % $frames.Count
        $petBox.Image = $frames[$script:frameIdx]
    })
    $animTimer.Start()
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $DisplaySeconds * 1000
$timer.Add_Tick({ $form.Close(); $timer.Stop() })
$timer.Start()

[System.Windows.Forms.Application]::Run($form)

if ($animTimer) { $animTimer.Stop(); $animTimer.Dispose() }
foreach ($img in $frames) { $img.Dispose() }
