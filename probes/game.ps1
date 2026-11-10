param([string]$Action, [string]$A1, [string]$A2, [string]$A3)
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class W {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern IntPtr PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
}
"@
Add-Type -AssemblyName System.Drawing
function Win {
  $p = Get-Process hoi3_tfh -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($p -and $p.MainWindowHandle -ne 0) { return $p }
  return $null
}
$dir = (Get-Location).Path
switch ($Action) {
  'launch' {
    if (-not (Win)) { Start-Process -FilePath "C:\Users\David\Hearts of Iron 3\hoi3_tfh.exe" -WorkingDirectory "C:\Users\David\Hearts of Iron 3" }
    for ($i = 0; $i -lt 90; $i++) { if (Win) { break }; Start-Sleep -Seconds 2 }
    $p = Win
    if ($p) { "window '$($p.MainWindowTitle)' pid $($p.Id)" } else { 'no window after 3 minutes' }
  }
  'shot' {
    $p = Win; if (-not $p) { 'no window'; break }
    $r = New-Object W+RECT; [W]::GetClientRect($p.MainWindowHandle, [ref]$r) | Out-Null
    $o = New-Object W+POINT; [W]::ClientToScreen($p.MainWindowHandle, [ref]$o) | Out-Null
    $bmp = New-Object System.Drawing.Bitmap $r.R, $r.B
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc()
    [W]::PrintWindow($p.MainWindowHandle, $hdc, 3) | Out-Null
    $g.ReleaseHdc($hdc)
    $path = Join-Path $dir $A1
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    "client $($r.R)x$($r.B) at $($o.X),$($o.Y) saved $A1"
  }
  'click' {
    $p = Win; if (-not $p) { 'no window'; break }
    $x = [int]$A1; $y = [int]$A2
    $l = [IntPtr](($y -shl 16) -bor ($x -band 0xFFFF))
    [W]::PostMessage($p.MainWindowHandle, 0x200, [IntPtr]::Zero, $l) | Out-Null
    Start-Sleep -Milliseconds 200
    [W]::PostMessage($p.MainWindowHandle, 0x201, [IntPtr]1, $l) | Out-Null
    Start-Sleep -Milliseconds 100
    [W]::PostMessage($p.MainWindowHandle, 0x202, [IntPtr]::Zero, $l) | Out-Null
    "clicked $x,$y"
  }
}
