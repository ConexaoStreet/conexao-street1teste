@echo off
setlocal
title Executador Agent

fltmc >nul 2>&1
if errorlevel 1 (
  echo Solicitando permissao de Administrador...
  powershell.exe -NoProfile -Command "Start-Process -FilePath 'cmd.exe' -Verb RunAs -ArgumentList '/c','\"%~f0\"'"
  exit /b
)

set "ROOT=%ProgramData%\Executador"
set "AGENT=%ROOT%\ExecutadorAgent.ps1"

if not exist "%ROOT%" mkdir "%ROOT%"

echo.
echo ==============================================
echo             EXECUTADOR AGENT
echo ==============================================
echo.
echo Atualizando o Agent...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest 'https://conexaostreet.github.io/conexao-street1teste/agent/ExecutadorAgent.ps1' -OutFile '%AGENT%' -UseBasicParsing"
if errorlevel 1 (
  echo.
  echo Nao foi possivel baixar o Agent.
  pause
  exit /b 1
)

echo.
echo Iniciando como Administrador...
echo Mantenha esta janela aberta enquanto usar o Executador no celular.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%AGENT%" -Daemon

echo.
echo Executador encerrado.
pause
endlocal
