@echo off
setlocal
title Parear Executador
set "ROOT=%ProgramData%\Executador"
set "AGENT=%ROOT%\ExecutadorAgent.ps1"

if not exist "%ROOT%" mkdir "%ROOT%"

echo Baixando Executador Agent...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest 'https://conexaostreet.github.io/conexao-street1teste/agent/ExecutadorAgent.ps1' -OutFile '%AGENT%' -UseBasicParsing"
if errorlevel 1 (
  echo Nao foi possivel baixar o agente.
  pause
  exit /b 1
)

set /p PAIRCODE=Digite o codigo mostrado no celular: 
if "%PAIRCODE%"=="" (
  echo Codigo vazio.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%AGENT%"" -PairCode ""%PAIRCODE%""'"
echo.
echo Se apareceu PAIR_OK, o computador ja esta vinculado.
echo Agora execute Start-Executador.cmd quando quiser controlar o PC pelo celular.
pause
endlocal
