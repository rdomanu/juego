# Captura la VENTANA del juego (PrintWindow, sin robar el foco) — LA herramienta de verificación
# visual del proyecto. En el renderer Compatibility, get_viewport().get_texture().get_image()
# PIERDE contenido (lección 2026-08-14/15: un día de cacería fantasma) — la verdad es la ventana.
# Uso: powershell -ExecutionPolicy Bypass -File tools\captura_ventana.ps1 -Salida C:\ruta\cap.png
param([string]$Salida = "$env:TEMP\ventana_comisario.png")

$codigo = @"
using System;
using System.Runtime.InteropServices;
public class CapVentana {
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdc, uint flags);
}
"@
Add-Type -TypeDefinition $codigo
Add-Type -AssemblyName System.Drawing

$proc = Get-Process | Where-Object { $_.ProcessName -like 'Godot*' -and $_.MainWindowTitle -like 'Comisario*' } | Select-Object -First 1
if (-not $proc) { Write-Output 'SIN ventana Comisario'; exit 1 }

$rect = New-Object CapVentana+RECT
[CapVentana]::GetWindowRect($proc.MainWindowHandle, [ref]$rect) | Out-Null
$ancho = $rect.Right - $rect.Left
$alto = $rect.Bottom - $rect.Top
$bmp = New-Object System.Drawing.Bitmap($ancho, $alto)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $gfx.GetHdc()
[CapVentana]::PrintWindow($proc.MainWindowHandle, $hdc, 2) | Out-Null
$gfx.ReleaseHdc($hdc)
$bmp.Save($Salida)
Write-Output ("capturada " + $ancho + "x" + $alto + " -> " + $Salida)
