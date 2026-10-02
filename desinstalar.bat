@echo off
setlocal
title Desinstalar - remove o que nao e importante (Proxybet fica)

:: =====================================================================
::  DESINSTALAR
::  Remove programas que deixam o PC pesado, em 2 etapas:
::    A) Apps inuteis que vem com o Windows (Candy Crush, Xbox, Noticias,
::       Clima, Cortana, Teams pessoal...) -> removidos automaticamente
::    B) Outros programas instalados -> pergunta S/N um por um
::       (se so apertar ENTER, o programa FICA)
::
::  NUNCA sao removidos:
::    - Proxybet (qualquer coisa com "proxybet" no nome ou na pasta)
::    - WhatsApp
::    - Google Chrome
::    - Drivers (audio, video, touchpad, wi-fi...), Windows, Microsoft Edge,
::      Visual C++, .NET, DirectX e outras pecas que os programas precisam
::
::  Antes de comecar, cria um PONTO DE RESTAURACAO do Windows.
::  Gera um log na Area de Trabalho: desinstalar-log.txt
:: =====================================================================

:: ------------------------- CONFIGURACOES ----------------------------
:: Outros programas que NUNCA devem ser removidos (parte do nome,
:: separados por virgula). Ex: set "MANTER_EXTRA=anydesk,discord"
set "MANTER_EXTRA="

:: 1 = so MOSTRA o que seria removido, sem remover nada (teste)
:: 0 = remove de verdade
set "SIMULAR=0"
:: --------------------------------------------------------------------

:: Precisa de administrador para desinstalar
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
$simular = ($env:SIMULAR -eq '1')

$log = Join-Path ([Environment]::GetFolderPath('Desktop')) 'desinstalar-log.txt'
Start-Transcript -Path $log -Force | Out-Null

Write-Host ''
Write-Host '=========== DESINSTALAR ===========' -ForegroundColor Cyan
if ($simular) { Write-Host 'MODO SIMULACAO: nada sera removido de verdade.' -ForegroundColor Yellow }
Write-Host ''

# ------------------------------------------------------------- PROTECAO
# Tudo que bater aqui NUNCA e removido. A checagem olha nome, fabricante,
# pasta de instalacao e comando de desinstalacao.
$proxybetRegex = 'proxy[\s_.-]*bet'

$protegerRegex = @(
    $proxybetRegex,
    'whatsapp',
    'chrome', 'google update',
    # Windows e pecas que outros programas precisam
    'microsoft edge', 'webview2', 'visual c\+\+', 'vcredist', '\.net', 'dotnet',
    'directx', 'windows (sdk|app runtime|desktop runtime|driver|security|defender)',
    'microsoft update health', 'pc health check', 'gameinput',
    # Drivers e utilitarios de hardware
    'driver', 'chipset', 'firmware', 'bios', 'audio', 'sound', 'touchpad', 'bluetooth',
    'wi-?fi', 'wireless', 'ethernet', '\blan\b', 'graphics', 'display',
    'realtek', 'intel', 'nvidia', '\bamd\b', 'radeon', 'synaptics', '\belan', 'dolby',
    'nahimic', 'conexant', 'waves', 'qualcomm', 'mediatek', 'broadcom', 'killer'
) -join '|'

# Apps da Store que tambem nunca sao removidos
$protegerAppx = 'WindowsStore|StorePurchaseApp|DesktopAppInstaller|SecHealthUI|Defender|' +
                'WindowsCalculator|Windows\.Photos|WindowsNotepad|Paint|WindowsTerminal|' +
                'VCLibs|UI\.Xaml|NET\.Native|WindowsAppRuntime|Edge|WebView|HEIF|HEVC|VP9|' +
                'WebMedia|WebpImage|RawImage|AV1|ScreenSketch|' + $proxybetRegex + '|whatsapp'

if ($env:MANTER_EXTRA) {
    $extras = $env:MANTER_EXTRA -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } |
              ForEach-Object { [regex]::Escape($_) }
    if ($extras) {
        $protegerRegex += '|' + ($extras -join '|')
        $protegerAppx  += '|' + ($extras -join '|')
    }
}

function Protegido([string[]]$textos) {
    $junto = ($textos | Where-Object { $_ }) -join ' | '
    return ($junto -match $protegerRegex)
}

$removidos = New-Object System.Collections.ArrayList
$mantidos  = New-Object System.Collections.ArrayList

# ------------------------------------------------- PONTO DE RESTAURACAO
if (-not $simular) {
    Write-Host 'Criando ponto de restauracao (pode demorar um pouco)...' -ForegroundColor Cyan
    Enable-ComputerRestore -Drive "$env:SystemDrive\"
    # o Windows so deixa criar 1 ponto a cada 24h; isso libera
    New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore' `
        -Name 'SystemRestorePointCreationFrequency' -Value 0 -PropertyType DWord -Force | Out-Null
    Checkpoint-Computer -Description 'Antes do desinstalar.bat' -RestorePointType 'MODIFY_SETTINGS'
    if ($?) { Write-Host 'Ponto de restauracao criado.' -ForegroundColor Green }
    else    { Write-Host 'Nao foi possivel criar o ponto de restauracao (seguindo mesmo assim).' -ForegroundColor DarkYellow }
    Write-Host ''
}

# ------------------------------------- A) APPS INUTEIS DA STORE (automatico)
Write-Host 'ETAPA A - Removendo apps inuteis que vem com o Windows...' -ForegroundColor Cyan
$lixoAppx = @(
    '*CandyCrush*', '*BubbleWitch*', '*king.com*', '*Disney*', '*TikTok*', '*Instagram*',
    '*Facebook*', '*AmazonPrimeVideo*', '*LinkedIn*', '*Hulu*', '*Roblox*',
    'Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.BingFinance', 'Microsoft.BingSports',
    'Microsoft.BingSearch', 'Microsoft.GetHelp', 'Microsoft.Getstarted',
    'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.ZuneMusic', 'Microsoft.ZuneVideo',
    'Microsoft.People', 'Microsoft.MixedReality.Portal', 'Microsoft.SkypeApp', 'Microsoft.YourPhone',
    'Microsoft.WindowsFeedbackHub', 'Microsoft.WindowsMaps', 'Microsoft.Microsoft3DViewer',
    'Microsoft.Print3D', 'Microsoft.MicrosoftOfficeHub', 'Microsoft.Office.OneNote',
    'Microsoft.OutlookForWindows', 'Microsoft.Todos', 'Microsoft.PowerAutomateDesktop',
    'Microsoft.549981C3F5F10', 'Microsoft.Copilot', 'Microsoft.Windows.DevHome',
    'Clipchamp.Clipchamp', 'MicrosoftTeams', 'MSTeams',
    'Microsoft.GamingApp', 'Microsoft.XboxApp', 'Microsoft.XboxGamingOverlay',
    'Microsoft.XboxGameOverlay', 'Microsoft.XboxSpeechToTextOverlay', 'Microsoft.Xbox.TCUI'
)

$appsInstalados = @(Get-AppxPackage -AllUsers)
$provisionados  = @(Get-AppxProvisionedPackage -Online)
$achouAppx = $false

foreach ($padrao in $lixoAppx) {
    foreach ($pkg in @($appsInstalados | Where-Object { $_.Name -like $padrao })) {
        if ($pkg.Name -match $protegerAppx -or (Protegido @($pkg.Name, $pkg.InstallLocation))) {
            [void]$mantidos.Add($pkg.Name); continue
        }
        $achouAppx = $true
        if ($simular) {
            Write-Host "  [simulacao] removeria: $($pkg.Name)"
        } else {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
            if ($?) { Write-Host "  - $($pkg.Name) removido" }
            else    { Write-Host "  - $($pkg.Name) (nao deu para remover)" -ForegroundColor DarkGray }
        }
        [void]$removidos.Add($pkg.Name)
    }
    # impede que o app volte quando um usuario novo for criado
    foreach ($prov in @($provisionados | Where-Object { $_.DisplayName -like $padrao })) {
        if ($prov.DisplayName -match $protegerAppx -or (Protegido @($prov.DisplayName))) { continue }
        if (-not $simular) {
            Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue | Out-Null
        }
    }
}
if (-not $achouAppx) { Write-Host '  Nenhum app inutil encontrado.' -ForegroundColor Green }
Write-Host ''

# ------------------------------- B) PROGRAMAS INSTALADOS (pergunta um por um)
Write-Host 'ETAPA B - Outros programas instalados' -ForegroundColor Cyan
Write-Host 'Para cada programa responda:  s = desinstalar   ENTER = manter   p = parar de perguntar'
Write-Host 'Na duvida, aperte ENTER (o programa fica).' -ForegroundColor Yellow
Write-Host ''

$chaves = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$programas = @(Get-ItemProperty -Path $chaves -ErrorAction SilentlyContinue | Where-Object {
    $_.DisplayName -and
    $_.SystemComponent -ne 1 -and
    -not $_.ParentKeyName -and
    $_.ReleaseType -notmatch 'Update|Hotfix' -and
    $_.DisplayName -notmatch '\bKB\d{6,}' -and
    ($_.UninstallString -or $_.QuietUninstallString)
} | Sort-Object DisplayName -Unique)

$parar = $false
foreach ($prog in $programas) {
    $nome = [string]$prog.DisplayName
    $infos = @($nome, $prog.Publisher, $prog.InstallLocation, $prog.DisplayIcon,
               $prog.UninstallString, $prog.QuietUninstallString)
    if (Protegido $infos) { [void]$mantidos.Add($nome); continue }
    if ($parar) { [void]$mantidos.Add($nome); continue }

    $tam = ''
    if ($prog.EstimatedSize) { $tam = ' ({0} MB)' -f [math]::Round($prog.EstimatedSize / 1024) }
    $resp = Read-Host "Desinstalar '$nome'$tam ? [s/N/p]"
    $resp = ([string]$resp).Trim().ToLower()

    if ($resp -eq 'p') { $parar = $true; [void]$mantidos.Add($nome); continue }
    if ($resp -notin @('s', 'sim', 'y')) { [void]$mantidos.Add($nome); continue }

    # checagem final de seguranca antes de rodar qualquer comando
    if (Protegido $infos) { [void]$mantidos.Add($nome); continue }

    if ($simular) {
        Write-Host "  [simulacao] desinstalaria: $nome"
        [void]$removidos.Add($nome); continue
    }

    Write-Host "  Desinstalando $nome ... (se abrir uma janela, siga ate o fim)" -ForegroundColor DarkCyan
    $u = [string]$prog.UninstallString
    if ($u -match 'msiexec' -and $u -match '(\{[0-9A-Fa-f-]{36}\})') {
        $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/x $($Matches[1]) /qn /norestart" -Wait -PassThru
    } else {
        $cmd = if ($prog.QuietUninstallString) { [string]$prog.QuietUninstallString } else { $u }
        $p = Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$cmd`"" -Wait -PassThru
    }
    if ($p -and $p.ExitCode -in @(0, 1605, 1614, 3010)) {
        Write-Host "  - $nome removido" -ForegroundColor Green
        [void]$removidos.Add($nome)
    } else {
        Write-Host "  - ${nome}: o desinstalador terminou com codigo $($p.ExitCode) (confira se saiu)" -ForegroundColor DarkYellow
        [void]$removidos.Add("$nome (verificar)")
    }
}

# ------------------------------------------------------------------ RESUMO
Write-Host ''
Write-Host '===================================' -ForegroundColor Cyan
if ($simular) { Write-Host 'SIMULACAO - seria removido:' -ForegroundColor Yellow }
else          { Write-Host 'Removido:' -ForegroundColor Yellow }
if ($removidos.Count -eq 0) { Write-Host '  (nada)' }
else { $removidos | Sort-Object -Unique | ForEach-Object { Write-Host "  - $_" } }

Write-Host ''
$temProxybet = @($programas | Where-Object {
    (@($_.DisplayName, $_.InstallLocation, $_.DisplayIcon, $_.UninstallString) -join ' ') -match $proxybetRegex
}).Count -gt 0 -or @(Get-Process | Where-Object { $_.Name -match $proxybetRegex }).Count -gt 0
Write-Host 'Proxybet: MANTIDO (nunca e removido por este script).' -ForegroundColor Green
if (-not $temProxybet) {
    Write-Host '  (o Proxybet nao aparece como programa instalado - normal se ele e so uma pasta/atalho)' -ForegroundColor DarkGray
}
Write-Host 'WhatsApp e Google Chrome: MANTIDOS.' -ForegroundColor Green
Write-Host ''
Write-Host "Log salvo em: $log"
if (-not $simular -and $removidos.Count -gt 0) {
    Write-Host 'Reinicie o PC para terminar a limpeza.' -ForegroundColor Cyan
    Write-Host 'Se algo der errado: Painel de Controle > Recuperacao > Abrir Restauracao do Sistema.' -ForegroundColor DarkGray
}
Stop-Transcript | Out-Null
