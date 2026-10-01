@echo off
setlocal
title Modo Leve - so Proxybet + Google Chrome

:: =====================================================================
::  MODO LEVE
::  Fecha tudo que nao for necessario e deixa rodando apenas:
::    - Proxybet (e tudo que ele abrir)
::    - Google Chrome
::    - O que o Windows precisa para funcionar (sistema, audio,
::      rede, touchpad, video, barra de tarefas)
::
::  Dica: abra o Proxybet e o Chrome ANTES de rodar este script.
::  Para desfazer: rode "restaurar.bat" ou reinicie o PC.
:: =====================================================================

:: ------------------------- CONFIGURACOES ----------------------------
:: Outros programas que NAO devem ser fechados (nome do .exe, sem
:: ".exe", separados por virgula). Ex: set "MANTER_EXTRA=anydesk,obs64"
set "MANTER_EXTRA="

:: 1 = mostra a lista e pede ENTER antes de fechar | 0 = fecha direto
set "CONFIRMAR=1"
:: 1 = para servicos do Windows que nao sao necessarios (volta ao reiniciar)
set "PARAR_SERVICOS=1"
:: 1 = ativa o plano de energia "Alto desempenho"
set "ALTO_DESEMPENHO=1"
:: 1 = apaga arquivos temporarios
set "LIMPAR_TEMP=1"
:: --------------------------------------------------------------------

:: Precisa de administrador para fechar tudo e parar servicos
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

function MemLivreMB { [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024) }

Write-Host ''
Write-Host '=========== MODO LEVE ===========' -ForegroundColor Cyan
$memAntes = MemLivreMB
Write-Host "RAM livre agora: $memAntes MB"
Write-Host ''

# ---------------------------------------------------------------- 1) PROCESSOS
# Programas que ficam abertos (e tudo que eles abrirem por baixo)
$manterNomes = @('chrome', 'chromedriver', 'proxybet')
if ($env:MANTER_EXTRA) {
    $manterNomes += $env:MANTER_EXTRA -split ',' | ForEach-Object { ($_.Trim() -replace '\.exe$', '').ToLower() } | Where-Object { $_ }
}
# Qualquer processo com "proxybet" / "proxy bet" no nome ou na pasta fica aberto
$manterRegex = 'proxy[\s_.-]*bet'

# Drivers e utilitarios de hardware (audio, touchpad, video, teclas do notebook)
$driverRegex = '\\(DriverStore|Realtek|Synaptics|Elantech|ELAN|Intel|NVIDIA Corporation|AMD|ATI Technologies|Dolby|Waves|Conexant|Nahimic|ASUS|ASUSTeK|Lenovo|Dell|HP|Hewlett-Packard|Acer|Samsung|MSI)\\'

$winDir   = $env:WINDIR.ToLower() + '\'
$minhaSes = (Get-Process -Id $PID).SessionId
$procs    = @(Get-CimInstance Win32_Process)

$porPid = @{}
$filhos = @{}
foreach ($p in $procs) {
    $porPid[[int]$p.ProcessId] = $p
    $pp = [int]$p.ParentProcessId
    if (-not $filhos.ContainsKey($pp)) { $filhos[$pp] = New-Object System.Collections.ArrayList }
    [void]$filhos[$pp].Add($p)
}

$manter = New-Object 'System.Collections.Generic.HashSet[int]'

# Nao fechar este proprio script (powershell -> cmd -> ...)
$atual = [int]$PID
while ($atual -gt 4 -and $porPid.ContainsKey($atual) -and $manter.Add($atual)) {
    $atual = [int]$porPid[$atual].ParentProcessId
}

# Proxybet, Chrome e extras + todos os processos filhos deles
$fila = New-Object System.Collections.Queue
foreach ($p in $procs) {
    $nome    = ($p.Name -replace '\.exe$', '').ToLower()
    $caminho = [string]$p.ExecutablePath
    if ($manterNomes -contains $nome -or $p.Name -match $manterRegex -or $caminho -match $manterRegex) {
        if ($manter.Add([int]$p.ProcessId)) { $fila.Enqueue($p) }
    }
}
while ($fila.Count -gt 0) {
    $pai = $fila.Dequeue()
    foreach ($f in @($filhos[[int]$pai.ProcessId])) {
        if (-not $f) { continue }
        # evita confundir com PID reaproveitado: o filho tem que ser mais novo que o pai
        if ($pai.CreationDate -and $f.CreationDate -and $f.CreationDate -lt $pai.CreationDate) { continue }
        if ($manter.Add([int]$f.ProcessId)) { $fila.Enqueue($f) }
    }
}

# Fecha: processos do usuario que estao FORA da pasta do Windows,
# que nao sao drivers e que nao estao na lista de manter
$alvos = @()
foreach ($p in $procs) {
    if ($manter.Contains([int]$p.ProcessId)) { continue }
    if ($p.SessionId -ne $minhaSes) { continue }
    $caminho = [string]$p.ExecutablePath
    if (-not $caminho) { continue }
    if ($caminho.ToLower().StartsWith($winDir)) { continue }
    if ($caminho -match $driverRegex) { continue }
    $alvos += $p
}

if ($alvos.Count -eq 0) {
    Write-Host 'Nenhum programa extra aberto. Ja esta leve.' -ForegroundColor Green
} else {
    Write-Host 'Programas que serao FECHADOS:' -ForegroundColor Yellow
    $alvos | Group-Object Name | Sort-Object Name | ForEach-Object {
        Write-Host ('  - {0}  ({1}x)' -f $_.Name, $_.Count)
    }
    Write-Host ''
    Write-Host 'Ficam abertos: Proxybet, Google Chrome e o sistema.' -ForegroundColor Green
    Write-Host 'ATENCAO: trabalho nao salvo nesses programas sera perdido.' -ForegroundColor Red
    if ($env:CONFIRMAR -eq '1') {
        Read-Host 'Aperte ENTER para continuar (ou feche esta janela para cancelar)' | Out-Null
    }
    $fechados = 0
    foreach ($p in $alvos) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        if ($?) { $fechados++ }
    }
    Write-Host "$fechados processos fechados." -ForegroundColor Green
}

# ---------------------------------------------------------------- 2) SERVICOS
if ($env:PARAR_SERVICOS -eq '1') {
    Write-Host ''
    Write-Host 'Parando servicos desnecessarios (voltam ao reiniciar)...' -ForegroundColor Cyan
    $servicos = @(
        'SysMain',          # Superfetch (usa muito disco/RAM)
        'WSearch',          # Indexacao da pesquisa do Windows
        'DiagTrack',        # Telemetria
        'dmwappushservice', # Telemetria
        'WerSvc',           # Relatorio de erros
        'wuauserv',         # Windows Update
        'UsoSvc',           # Orquestrador do Windows Update
        'BITS',             # Downloads em segundo plano
        'DoSvc',            # Otimizacao de entrega (update P2P)
        'MapsBroker',       # Mapas offline
        'lfsvc',            # Localizacao
        'RetailDemo',       # Modo demonstracao de loja
        'Fax',
        'Spooler',          # Impressora (pare se nao for imprimir)
        'XblAuthManager', 'XblGameSave', 'XboxNetApiSvc', 'XboxGipSvc',
        'WMPNetworkSvc',    # Compartilhamento do Windows Media Player
        'TrkWks',           # Rastreamento de links
        'wisvc'             # Windows Insider
    )
    foreach ($nome in $servicos) {
        $svc = Get-Service -Name $nome -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq 'Running') {
            Stop-Service -Name $nome -Force -ErrorAction SilentlyContinue
            if ($?) { Write-Host "  - $nome parado" }
        }
    }
}

# ---------------------------------------------------------------- 3) ENERGIA
if ($env:ALTO_DESEMPENHO -eq '1') {
    Write-Host ''
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Plano de energia: Alto desempenho' -ForegroundColor Cyan
    } else {
        Write-Host 'Plano "Alto desempenho" nao existe neste PC (mantido o atual).' -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------- 4) TEMP
if ($env:LIMPAR_TEMP -eq '1') {
    Write-Host ''
    Write-Host 'Limpando arquivos temporarios...' -ForegroundColor Cyan
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
}

Start-Sleep -Seconds 2
$memDepois = MemLivreMB
Write-Host ''
Write-Host '=================================' -ForegroundColor Cyan
Write-Host "RAM livre antes:  $memAntes MB"
Write-Host "RAM livre depois: $memDepois MB  (+$($memDepois - $memAntes) MB)" -ForegroundColor Green
Write-Host 'Pronto! PC no modo leve.' -ForegroundColor Green
