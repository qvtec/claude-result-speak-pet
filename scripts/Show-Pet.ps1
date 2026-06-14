param(
    [string]$Message = "Hello!",
    [string]$PetImageDir = "",
    [string]$PetBaseName = "cat2",
    [string]$LabelImagePath = "",
    [int]$DisplaySeconds = 5,
    [int]$PetSize = 100
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class NoActivateForm : Form {
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams {
        get {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x08000000; // WS_EX_NOACTIVATE
            cp.ExStyle |= 0x00080000; // WS_EX_LAYERED — 作成時に設定必須
            return cp;
        }
    }
}

public static class LayeredWin {
    [StructLayout(LayoutKind.Sequential)] struct POINT  { public int x, y; }
    [StructLayout(LayoutKind.Sequential)] struct SIZE   { public int cx, cy; }
    [StructLayout(LayoutKind.Sequential)] struct BLEND  { public byte Op, Flags, Alpha, Format; }
    [StructLayout(LayoutKind.Sequential)] struct BITMAPINFOHEADER {
        public int biSize, biWidth, biHeight;
        public short biPlanes, biBitCount;
        public int biCompression, biSizeImage, biXPPM, biYPPM, biClrUsed, biClrImportant;
    }

    [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr hdc);
    [DllImport("gdi32.dll")] static extern IntPtr CreateDIBSection(IntPtr hdc,
        ref BITMAPINFOHEADER bmi, uint usage, out IntPtr bits, IntPtr section, uint offset);
    [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr obj);
    [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr dc);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr obj);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
    [DllImport("user32.dll")] static extern bool UpdateLayeredWindow(
        IntPtr hwnd, IntPtr hdcDst, IntPtr pptDst, ref SIZE psize,
        IntPtr hdcSrc, ref POINT pptSrc, int crKey, ref BLEND blend, int flags);
    [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int i);
    [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr h, int i, int v);
    [DllImport("kernel32.dll")] static extern void RtlZeroMemory(IntPtr dst, int len);

    static IntPtr _memDC, _hBmp, _oldBmp;
    static int _w, _h;

    public static void Init(int w, int h) {
        _w = w; _h = h;
        _memDC = CreateCompatibleDC(IntPtr.Zero);
        var hdr = new BITMAPINFOHEADER {
            biSize = System.Runtime.InteropServices.Marshal.SizeOf(typeof(BITMAPINFOHEADER)),
            biWidth = w, biHeight = -h, biPlanes = 1, biBitCount = 32
        };
        IntPtr bits;
        _hBmp = CreateDIBSection(IntPtr.Zero, ref hdr, 0, out bits, IntPtr.Zero, 0);
        _oldBmp = SelectObject(_memDC, _hBmp);
    }

    public static void MakeLayered(IntPtr hwnd) {
        SetWindowLong(hwnd, -20, GetWindowLong(hwnd, -20) | 0x80000);
    }

    public static Graphics GetGraphics() {
        var g = Graphics.FromHdc(_memDC);
        g.Clear(Color.Transparent);
        return g;
    }

    public static void Paint(IntPtr hwnd) {
        IntPtr sDC = GetDC(IntPtr.Zero);
        var sz  = new SIZE  { cx = _w, cy = _h };
        var src = new POINT { x  = 0,  y  = 0  };
        var bf  = new BLEND { Op = 0, Flags = 0, Alpha = 255, Format = 1 };
        UpdateLayeredWindow(hwnd, sDC, IntPtr.Zero, ref sz, _memDC, ref src, 0, ref bf, 2);
        ReleaseDC(IntPtr.Zero, sDC);
    }

    public static void Dispose() {
        SelectObject(_memDC, _oldBmp);
        DeleteDC(_memDC);
        DeleteObject(_hBmp);
    }
}
"@ -ReferencedAssemblies System.Windows.Forms,System.Drawing

$PET_W    = $PetSize
$PET_H    = $PetSize
$BUBBLE_W = 200
$BUBBLE_H = 68
$MARGIN   = 16
$FORM_W   = [Math]::Max($PET_W, $BUBBLE_W) + 20
$FORM_H   = $PET_H + $BUBBLE_H + 4
$bubbleX  = [int](($FORM_W - $BUBBLE_W) / 2)

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
[LayeredWin]::Init($FORM_W, $FORM_H)

# 画像ロード（高品質縮小）
function Load-Scaled([string]$path, [int]$w, [int]$h) {
    if (-not $path -or -not (Test-Path $path)) { return $null }
    $src = [System.Drawing.Image]::FromFile($path)
    $dst = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g   = [System.Drawing.Graphics]::FromImage($dst)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($src, 0, 0, $w, $h)
    $g.Dispose(); $src.Dispose()
    return $dst
}

$labelBmp  = Load-Scaled $LabelImagePath $BUBBLE_W $BUBBLE_H
$petFrames = @()
if ($PetImageDir -and (Test-Path $PetImageDir)) {
    foreach ($f in (Get-ChildItem "$PetImageDir\${PetBaseName}_*.png" | Sort-Object Name)) {
        $petFrames += Load-Scaled $f.FullName $PET_W $PET_H
    }
}

# 1フレーム描画
function Draw-Frame([int]$idx) {
    $g = [LayeredWin]::GetGraphics()
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias

    # 吹き出し
    if ($labelBmp) {
        $g.DrawImage($labelBmp, $bubbleX, 0, $BUBBLE_W, $BUBBLE_H)
    } else {
        $r    = 14
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddArc($bubbleX,                      0,                      $r*2, $r*2, 180, 90)
        $path.AddArc($bubbleX + $BUBBLE_W - $r*2,   0,                      $r*2, $r*2, 270, 90)
        $path.AddArc($bubbleX + $BUBBLE_W - $r*2,   $BUBBLE_H - $r*2,       $r*2, $r*2,   0, 90)
        $path.AddArc($bubbleX,                      $BUBBLE_H - $r*2,       $r*2, $r*2,  90, 90)
        $path.CloseFigure()
        $g.FillPath([System.Drawing.Brushes]::White, $path)
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::DimGray, 1)
        $g.DrawPath($pen, $path)
        $pen.Dispose(); $path.Dispose()
    }

    # メッセージテキスト
    $font = New-Object System.Drawing.Font("Segoe UI Emoji", 10, [System.Drawing.FontStyle]::Regular)
    $sf   = New-Object System.Drawing.StringFormat
    $sf.Alignment     = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $rect = New-Object System.Drawing.RectangleF([float]$bubbleX, 0.0, [float]$BUBBLE_W, [float]$BUBBLE_H)
    $g.DrawString($Message, $font, [System.Drawing.Brushes]::Black, $rect, $sf)
    $font.Dispose(); $sf.Dispose()

    # ペット
    if ($petFrames.Count -gt 0 -and $null -ne $petFrames[$idx]) {
        $petX = [int](($FORM_W - $PET_W) / 2)
        $g.DrawImage($petFrames[$idx], $petX, $BUBBLE_H - 4, $PET_W, $PET_H)
    } else {
        $ef  = New-Object System.Drawing.Font("Segoe UI Emoji", 72)
        $sf2 = New-Object System.Drawing.StringFormat
        $sf2.Alignment = $sf2.LineAlignment = [System.Drawing.StringAlignment]::Center
        $er  = New-Object System.Drawing.RectangleF(0.0, [float]$BUBBLE_H, [float]$FORM_W, [float]$PET_H)
        $g.DrawString([char]::ConvertFromUtf32(0x1F431), $ef, [System.Drawing.Brushes]::Black, $er, $sf2)
        $ef.Dispose(); $sf2.Dispose()
    }

    $g.Dispose()
    [LayeredWin]::Paint($form.Handle)
}

# フォーム作成（TransparencyKey なし）
$form = New-Object NoActivateForm
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.TopMost         = $true
$form.ShowInTaskbar   = $false
$form.StartPosition   = [System.Windows.Forms.FormStartPosition]::Manual
$form.Width           = $FORM_W
$form.Height          = $FORM_H
$form.Left            = $screen.Right  - $FORM_W - $MARGIN
$form.Top             = $screen.Bottom - $FORM_H - $MARGIN

$form.add_HandleCreated({
    [LayeredWin]::MakeLayered($form.Handle)
    Draw-Frame 0
})
$form.add_Click({ $form.Close() })

# アニメーション
$script:fi = 0
$animTimer  = $null
if ($petFrames.Count -ge 2) {
    $animTimer          = New-Object System.Windows.Forms.Timer
    $animTimer.Interval = 800
    $animTimer.add_Tick({
        $script:fi = ($script:fi + 1) % $petFrames.Count
        Draw-Frame $script:fi
    })
    $animTimer.Start()
}

$closeTimer          = New-Object System.Windows.Forms.Timer
$closeTimer.Interval = $DisplaySeconds * 1000
$closeTimer.add_Tick({ $form.Close(); $closeTimer.Stop() })
$closeTimer.Start()

[System.Windows.Forms.Application]::Run($form)

if ($animTimer) { $animTimer.Stop(); $animTimer.Dispose() }
[LayeredWin]::Dispose()
if ($labelBmp) { $labelBmp.Dispose() }
foreach ($f in $petFrames) { if ($f) { $f.Dispose() } }
