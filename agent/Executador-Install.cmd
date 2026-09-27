@echo off
setlocal
title Executador Agent
set "PS1=%TEMP%\Executador-Install.ps1"
echo Baixando instalador do Executador...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest 'https://conexaostreet.github.io/conexao-street1teste/agent/install.ps1' -OutFile '%PS1%' -UseBasicParsing"
if errorlevel 1 (
  echo Falha ao baixar o instalador.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
endlocal
