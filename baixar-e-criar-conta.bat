@echo off
setlocal
title Proxybet - baixar o bot e criar conta

:: =====================================================================
::  BAIXAR E CRIAR CONTA
::  1) Baixa o bot do Proxybet para a pasta Downloads
::  2) Abre o site do Proxybet no Google Chrome para criar a conta
::  3) Abre o arquivo baixado (instalador) ou a pasta dele
::
::  Nao precisa de administrador. E so dar dois cliques.
:: =====================================================================

:: ------------------------- CONFIGURACOES ----------------------------
set "URL_DOWNLOAD=https://proxybet.com.br/api/download/app"
set "URL_CADASTRO=https://proxybet.com.br"
:: Pasta onde o bot vai ser salvo (padrao: Downloads do usuario)
set "PASTA_DESTINO=%USERPROFILE%\Downloads"
:: 1 = abre o instalador depois de baixar | 0 = so mostra a pasta
set "ABRIR_INSTALADOR=1"
:: --------------------------------------------------------------------

set "ESTE_SCRIPT=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText($env:ESTE_SCRIPT); iex $s.Substring($s.LastIndexOf('#==PS'+'==#'))"
echo.
pause
exit /b

#==PS==#
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # deixa o download muito mais rapido
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function AbrirNoChrome($url) {
    $chrome = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    if ($chrome) { Start-Process -FilePath $chrome -ArgumentList $url }
    else         { Start-Process $url }   # navegador padrao
}

Write-Host ''
Write-Host '====== PROXYBET: BAIXAR E CRIAR CONTA ======' -ForegroundColor Cyan
Write-Host ''

# ---------------------------------------------------------------- 1) SITE
# Abre o site primeiro: da para ir criando a conta enquanto o bot baixa
Write-Host "Abrindo o site para criar a conta: $env:URL_CADASTRO" -ForegroundColor Cyan
AbrirNoChrome $env:URL_CADASTRO

# ---------------------------------------------------------------- 2) DOWNLOAD
$pasta = $env:PASTA_DESTINO
if (-not (Test-Path $pasta)) { New-Item -ItemType Directory -Path $pasta -Force | Out-Null }
$temp = Join-Path $pasta ('proxybet-download-' + [guid]::NewGuid().ToString('N') + '.tmp')

Write-Host ''
Write-Host "Baixando o bot de: $env:URL_DOWNLOAD" -ForegroundColor Cyan
Write-Host 'Aguarde, isso pode levar alguns minutos...'
try {
    $resp = Invoke-WebRequest -Uri $env:URL_DOWNLOAD -OutFile $temp -PassThru -UseBasicParsing `
            -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'
} catch {
    Remove-Item $temp -Force -ErrorAction SilentlyContinue
    Write-Host ''
    Write-Host "ERRO ao baixar: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Abrindo o link de download no navegador para baixar manualmente...' -ForegroundColor Yellow
    AbrirNoChrome $env:URL_DOWNLOAD
    return
}

# Descobre o nome do arquivo: cabecalho do servidor > link final > tipo do arquivo
$nome = $null
$cd = [string]$resp.Headers['Content-Disposition']
if ($cd -match "filename\*=(?:UTF-8'')?""?([^"";]+)") { $nome = [Uri]::UnescapeDataString($matches[1]) }
elseif ($cd -match 'filename="?([^";]+)"?')            { $nome = $matches[1] }
if (-not $nome) {
    try {
        $final = [IO.Path]::GetFileName($resp.BaseResponse.ResponseUri.AbsolutePath)
        if ($final -match '\.[A-Za-z0-9]{2,5}$') { $nome = $final }
    } catch {}
}
if (-not $nome) {
    $bytes = New-Object byte[] 2
    $fs = [IO.File]::OpenRead($temp); [void]$fs.Read($bytes, 0, 2); $fs.Close()
    $magic = [Text.Encoding]::ASCII.GetString($bytes)
    if     ($magic -eq 'MZ') { $nome = 'Proxybet-Setup.exe' }
    elseif ($magic -eq 'PK') { $nome = 'Proxybet.zip' }
    else                     { $nome = 'Proxybet-Setup.exe' }
}
$nome = ($nome.Trim() -replace '[\\/:*?"<>|]', '_')

$arquivo = Join-Path $pasta $nome
if (Test-Path $arquivo) { Remove-Item $arquivo -Force -ErrorAction SilentlyContinue }
if (Test-Path $arquivo) {
    # arquivo antigo em uso: salva com outro nome
    $arquivo = Join-Path $pasta ([IO.Path]::GetFileNameWithoutExtension($nome) + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + [IO.Path]::GetExtension($nome))
}
Move-Item -Path $temp -Destination $arquivo -Force
Unblock-File -Path $arquivo -ErrorAction SilentlyContinue   # tira o aviso "baixado da internet"

$mb = [math]::Round((Get-Item $arquivo).Length / 1MB, 1)
Write-Host ''
Write-Host "Bot baixado: $arquivo ($mb MB)" -ForegroundColor Green

# ---------------------------------------------------------------- 3) ABRIR
$ext = [IO.Path]::GetExtension($arquivo).ToLower()
if ($ext -eq '.zip') {
    $destZip = Join-Path $pasta ([IO.Path]::GetFileNameWithoutExtension($arquivo))
    Write-Host "Extraindo para: $destZip" -ForegroundColor Cyan
    Expand-Archive -Path $arquivo -DestinationPath $destZip -Force
    Get-ChildItem $destZip -Recurse | Unblock-File -ErrorAction SilentlyContinue
    Start-Process explorer.exe $destZip
}
elseif ($env:ABRIR_INSTALADOR -eq '1' -and @('.exe', '.msi') -contains $ext) {
    Write-Host 'Abrindo o instalador...' -ForegroundColor Cyan
    Start-Process -FilePath $arquivo
}
else {
    Start-Process explorer.exe "/select,`"$arquivo`""
}

Write-Host ''
Write-Host 'Pronto! Termine o cadastro no site que abriu no Chrome.' -ForegroundColor Green
