# Regresión del recorrido de los 8 mundos (IMP-040): ejecuta el piloto automático invulnerable
# (las caídas al vacío sí cuentan) en cada mundo y falla si no llega a la puerta del jefe dentro
# del límite de fotogramas o si supera el máximo de caídas.
#
#   powershell -File godot/tests/run_autopilot_all.ps1 -Godot "C:\ruta\Godot_v4.7.2-stable_win64.exe"
#   (o con la variable de entorno GODOT; -Worlds 3,8 para ejecutar sólo algunos)
#
# Devuelve 0 si los mundos pedidos pasan. Los límites dan margen sobre la línea base medida
# (comentario de cada fila); si un cambio de nivel la mejora o empeora a propósito, se ajustan aquí.

param(
	[string]$Godot = $env:GODOT,
	[int[]]$Worlds = @(1, 2, 3, 4, 5, 6, 7, 8)
)

# mundo (número del jugador) => límite de fotogramas y de caídas
$limits = @{
	1 = @{ frames = 5500; falls = 4 }    # base: 3 440 fotogramas, 1 caída
	2 = @{ frames = 6000; falls = 4 }    # base: 3 766, 1
	3 = @{ frames = 8000; falls = 2 }    # base: 5 445, 0
	4 = @{ frames = 7000; falls = 2 }    # base: 4 369, 0
	5 = @{ frames = 16000; falls = 6 }   # base: 11 851, 3 (cruce en tren de la sección E, IMP-029)
	6 = @{ frames = 7000; falls = 2 }    # base: 4 592, 0
	7 = @{ frames = 8000; falls = 2 }    # base: 5 217, 0
	8 = @{ frames = 7000; falls = 2 }    # base: 4 705, 0
}

if (-not $Godot -or -not (Test-Path $Godot)) {
	Write-Error "Indica el ejecutable de Godot con -Godot o la variable de entorno GODOT"
	exit 2
}
$project = Join-Path $PSScriptRoot ".."
$failed = @()

foreach ($w in $Worlds) {
	$lim = $limits[$w]
	$out = & $Godot --headless --path $project --fixed-fps 60 res://tests/Autopilot.tscn -- "world=$w" godmode "max_frames=$($lim.frames)" 2>&1 | Out-String
	$code = $LASTEXITCODE
	$line = ($out -split "`r?`n" | Where-Object { $_ -match "LLEGA A LA PUERTA|NO llega" } | Select-Object -Last 1)
	$falls = if ($line -match "golpes/ca\S*das (\d+)") { [int]$Matches[1] } else { -1 }
	$ok = $code -eq 0 -and $falls -ge 0 -and $falls -le $lim.falls
	if ($out -match "leaked|still in use") {
		$ok = $false
		$line += " [el motor avisa de objetos sin liberar al salir]"
	}
	Write-Host ("Mundo {0}: {1} {2}" -f $w, $(if ($ok) { "OK  " } else { "FALLA" }), $line)
	if (-not $ok) { $failed += $w }
}

if ($failed.Count -gt 0) {
	Write-Host "Mundos con regresión: $($failed -join ', ')"
	exit 1
}
Write-Host "Los $($Worlds.Count) mundos llegan a la puerta del jefe dentro de los límites"
exit 0
