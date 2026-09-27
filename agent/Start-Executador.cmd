@echo off
setlocal EnableExtensions
title Executador Agent

if /I "%~1"=="ELEVATED" goto :elevated

echo.
echo ==============================================
echo             EXECUTADOR AGENT
echo ==============================================
echo.
echo Solicitando permissao de Administrador...
echo.

set "EXECUTADOR_SELF=%~f0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$q=[char]34; $p=$env:EXECUTADOR_SELF; try { Start-Process -FilePath 'cmd.exe' -Verb RunAs -ArgumentList ('/k ' + $q + $p + $q + ' ELEVATED'); exit 0 } catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }"

if errorlevel 1 (
  echo.
  echo [ERRO] Nao foi possivel solicitar permissao de Administrador.
  pause
)
exit /b

:elevated
fltmc >nul 2>&1
if errorlevel 1 (
  echo.
  echo [ERRO] Esta janela ainda nao esta como Administrador.
  pause
  exit /b 1
)

set "ROOT=%ProgramData%\Executador"
set "AGENT=%ROOT%\ExecutadorAgent.ps1"
if not exist "%ROOT%" mkdir "%ROOT%"

echo.
echo Atualizando o Executador Agent...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest 'https://conexaostreet.github.io/conexao-street1teste/agent/ExecutadorAgent.ps1?v=0302' -OutFile '%AGENT%' -UseBasicParsing -TimeoutSec 60 } catch { Write-Host ('Falha: '+$_.Exception.Message) -ForegroundColor Red; exit 1 }"
if errorlevel 1 (
  echo.
  echo [ERRO] Nao foi possivel atualizar o Agent.
  pause
  exit /b 1
)

echo.
echo Executador iniciado como Administrador.
echo Mantenha esta janela aberta enquanto usar o celular.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%AGENT%" -Daemon
set "AGENT_EXIT=%ERRORLEVEL%"

echo.
if not "%AGENT_EXIT%"=="0" echo [ERRO] Agent terminou com codigo %AGENT_EXIT%.
echo Log: %ProgramData%\Executador\logs\agent.log
echo.
pause
endlocal
