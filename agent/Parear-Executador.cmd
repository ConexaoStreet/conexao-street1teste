@echo off
setlocal
title Executador - Conectar PC

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
echo          EXECUTADOR - CONECTAR PC
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
echo Gerando codigo de conexao...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%AGENT%" -PairFromPc

echo.
echo Sessao encerrada.
pause
endlocal
