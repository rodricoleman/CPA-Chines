@echo off
setlocal
title Restaurar - desfaz o Modo Leve

:: Religa os servicos parados pelo modo-leve.bat e volta o plano de
:: energia para "Equilibrado". (Reiniciar o PC tambem desfaz tudo.)

set "ESTE_SCRIPT=%~f0"
net session >nul 2>&1
if %errorlevel% equ 0 goto :admin
echo Pedindo permissao de administrador...
powershell -NoProfile -Command "Start-Process -FilePath $env:ESTE_SCRIPT -Verb RunAs"
exit /b

:admin
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText($env:ESTE_SCRIPT); iex $s.Substring($s.LastIndexOf('#==PS'+'==#'))"
echo.
pause
exit /b

#==PS==#
$ErrorActionPreference = 'SilentlyContinue'

Write-Host 'Religando servicos...' -ForegroundColor Cyan
$servicos = 'SysMain','WSearch','DiagTrack','dmwappushservice','WerSvc','wuauserv','UsoSvc',
            'BITS','DoSvc','MapsBroker','lfsvc','Spooler','TrkWks'
foreach ($nome in $servicos) {
    $svc = Get-Service -Name $nome -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne 'Running' -and $svc.StartType -eq 'Automatic') {
        Start-Service -Name $nome -ErrorAction SilentlyContinue
        if ($?) { Write-Host "  - $nome ligado" }
    }
}

powercfg /setactive 381b4222-f694-41f0-9628-87d4ccfc5f8b 2>$null | Out-Null
Write-Host 'Plano de energia: Equilibrado' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Pronto! Os outros programas voltam quando voce abrir de novo ou reiniciar o PC.' -ForegroundColor Green
