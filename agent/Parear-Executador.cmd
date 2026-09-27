@echo off
setlocal EnableExtensions
title Executador - Conectar PC

if /I "%~1"=="ELEVATED" goto :elevated

echo.
echo ==============================================
echo          EXECUTADOR - CONECTAR PC
echo ==============================================
echo.
echo Solicitando permissao de Administrador...
echo.

set "EXECUTADOR_SELF=%~f0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$q=[char]34; $p=$env:EXECUTADOR_SELF; try { Start-Process -FilePath 'cmd.exe' -Verb RunAs -ArgumentList ('/k ' + $q + $p + $q + ' ELEVATED'); exit 0 } catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }"

if errorlevel 1 (
  echo.
  echo [ERRO] Nao foi possivel solicitar permissao de Administrador.
  echo Clique com o botao direito neste arquivo e escolha Executar como administrador.
  echo.
  pause
)
exit /b

:elevated
fltmc >nul 2>&1
if errorlevel 1 (
  echo.
  echo [ERRO] Esta janela ainda nao esta como Administrador.
  echo Feche-a e execute o arquivo com o botao direito ^> Executar como administrador.
  echo.
  pause
  exit /b 1
)

set "ROOT=%ProgramData%\Executador"
set "AGENT=%ROOT%\ExecutadorAgent.ps1"

if not exist "%ROOT%" mkdir "%ROOT%"
if errorlevel 1 (
  echo.
  echo [ERRO] Nao foi possivel criar a pasta %ROOT%.
  pause
  exit /b 1
)

echo.
echo ==============================================
echo          EXECUTADOR - CONECTAR PC
echo ==============================================
echo.
echo [1/3] Testando conexao com o servidor...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { $r=Invoke-WebRequest 'https://skzyxapvleyktmgshvfp.supabase.co/functions/v1/agent-api/public/health' -UseBasicParsing -TimeoutSec 20; if($r.StatusCode -ne 200){exit 1} } catch { Write-Host ('Falha: '+$_.Exception.Message) -ForegroundColor Red; exit 1 }"
if errorlevel 1 (
  echo.
  echo [ERRO] O PC nao conseguiu acessar o servidor do Executador.
  echo Verifique internet, proxy, VPN, DNS ou firewall.
  echo.
  pause
  exit /b 1
)

echo.
echo [2/3] Baixando a versao mais nova do Agent...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest 'https://conexaostreet.github.io/conexao-street1teste/agent/ExecutadorAgent.ps1?v=0302' -OutFile '%AGENT%' -UseBasicParsing -TimeoutSec 60; if(!(Test-Path '%AGENT%')){exit 1} } catch { Write-Host ('Falha: '+$_.Exception.Message) -ForegroundColor Red; exit 1 }"
if errorlevel 1 (
  echo.
  echo [ERRO] Nao foi possivel baixar o Agent.
  echo Tente abrir no navegador:
  echo https://conexaostreet.github.io/conexao-street1teste/agent/ExecutadorAgent.ps1
  echo.
  pause
  exit /b 1
)

echo.
echo [3/3] Gerando codigo de conexao...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%AGENT%" -PairFromPc
set "AGENT_EXIT=%ERRORLEVEL%"

if not "%AGENT_EXIT%"=="0" (
  echo.
  echo ============================================================
  echo [ERRO] O Agent terminou com codigo %AGENT_EXIT%.
  echo.
  echo Log:
  echo %ProgramData%\Executador\logs\agent.log
  echo ============================================================
  echo.
  pause
  exit /b %AGENT_EXIT%
)

echo.
echo Sessao do Executador encerrada.
echo.
pause
endlocal
