param([string]$PairCode)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Root = Join-Path $env:ProgramData "Executador"
$AgentPath = Join-Path $Root "ExecutadorAgent.ps1"
$AgentUrl = "https://conexaostreet.github.io/conexao-street1teste/agent/ExecutadorAgent.ps1"
$TaskName = "Executador Agent"

function Test-Admin {
  return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if(!(Test-Admin)) {
  $args = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"'
  if($PairCode) { $args += ' -PairCode "' + $PairCode + '"' }
  Start-Process powershell.exe -Verb RunAs -ArgumentList $args
  exit
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "          EXECUTADOR AGENT - WINDOWS" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

New-Item -ItemType Directory -Force -Path $Root | Out-Null
try {
  & icacls.exe $Root /inheritance:r /grant:r "*S-1-5-18:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F" | Out-Null
} catch {}

Write-Host "[1/4] Baixando agente..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $AgentUrl -OutFile $AgentPath -UseBasicParsing

if(!$PairCode) {
  Write-Host ""
  Write-Host "No celular, abra Executador > Conectar PC." -ForegroundColor Yellow
  $PairCode = Read-Host "Digite o codigo exibido no painel"
}

if([string]::IsNullOrWhiteSpace($PairCode)) { throw "Codigo de pareamento vazio." }

Write-Host "[2/4] Pareando este computador..." -ForegroundColor Cyan
$out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AgentPath -PairCode $PairCode 2>&1
if($LASTEXITCODE -ne 0) { throw ($out | Out-String) }
Write-Host ($out | Out-String) -ForegroundColor Green

Write-Host "[3/4] Instalando inicializacao automatica..." -ForegroundColor Cyan
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

$agentArg = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $AgentPath + '" -Daemon'
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $agentArg
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Executador: diagnostico e reparo autorizado deste computador." | Out-Null

Write-Host "[4/4] Iniciando agente..." -ForegroundColor Cyan
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "Executador instalado e conectado." -ForegroundColor Green
Write-Host "Agora voce pode iniciar diagnosticos pelo celular." -ForegroundColor Green
Write-Host ""
Read-Host "Pressione ENTER para fechar"
