@echo off
setlocal
title Executador Agent
set "ROOT=%ProgramData%\Executador"
set "AGENT=%ROOT%\ExecutadorAgent.ps1"

if not exist "%ROOT%" mkdir "%ROOT%"

echo Atualizando Executador Agent...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest 'https://conexaostreet.github.io/conexao-street1teste/agent/ExecutadorAgent.ps1' -OutFile '%AGENT%' -UseBasicParsing"
if errorlevel 1 (
  echo Nao foi possivel baixar o agente.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%AGENT%"" -Daemon'"
endlocal
