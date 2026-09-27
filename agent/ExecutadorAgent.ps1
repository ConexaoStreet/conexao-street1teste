param(
  [string]$PairCode,
  [switch]$PairFromPc,
  [switch]$Daemon,
  [switch]$InventoryNow
)

Set-StrictMode -Version 2
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$AgentVersion = "0.3.0"
$ApiBase = "https://skzyxapvleyktmgshvfp.supabase.co/functions/v1/agent-api"
$Root = Join-Path $env:ProgramData "Executador"
$ConfigPath = Join-Path $Root "agent.json"
$LogDir = Join-Path $Root "logs"
$LogPath = Join-Path $LogDir "agent.log"

New-Item -ItemType Directory -Force -Path $Root,$LogDir | Out-Null

function Write-Log {
  param([string]$Message,[string]$Level="INFO")
  try {
    if ((Test-Path $LogPath) -and (Get-Item $LogPath).Length -gt 5242880) {
      Move-Item $LogPath ($LogPath + ".1") -Force -ErrorAction SilentlyContinue
    }
    Add-Content -Path $LogPath -Value ("{0} [{1}] {2}" -f (Get-Date).ToString("s"),$Level,$Message)
  } catch {}
}

function Get-Sha256Text {
  param([string]$Text)
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes([string]$Text)
    return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-","").ToLowerInvariant()
  } finally { $sha.Dispose() }
}

function Protect-Text {
  param([string]$Text)
  Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue
  $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
  $enc = [Security.Cryptography.ProtectedData]::Protect($bytes,$null,[Security.Cryptography.DataProtectionScope]::LocalMachine)
  return [Convert]::ToBase64String($enc)
}

function Unprotect-Text {
  param([string]$Text)
  Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue
  $enc = [Convert]::FromBase64String($Text)
  $bytes = [Security.Cryptography.ProtectedData]::Unprotect($enc,$null,[Security.Cryptography.DataProtectionScope]::LocalMachine)
  return [Text.Encoding]::UTF8.GetString($bytes)
}

function Save-Config {
  param([string]$Token,[string]$DeviceId)
  [pscustomobject]@{
    device_id = $DeviceId
    token_protected = (Protect-Text $Token)
    paired_at = (Get-Date).ToUniversalTime().ToString("o")
    agent_version = $AgentVersion
  } | ConvertTo-Json | Set-Content -Path $ConfigPath -Encoding UTF8
}

function Get-Config {
  if (!(Test-Path $ConfigPath)) { return $null }
  try {
    $c = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $c | Add-Member -NotePropertyName token -NotePropertyValue (Unprotect-Text $c.token_protected) -Force
    return $c
  } catch {
    Write-Log ("Config read failed: " + $_.Exception.Message) "ERROR"
    return $null
  }
}

function Invoke-AgentApi {
  param([string]$Path,[object]$Body,[switch]$NoToken)
  $headers = @{"Content-Type"="application/json"}
  if (!$NoToken) {
    $cfg = Get-Config
    if (!$cfg) { throw "PC not paired." }
    $headers["x-agent-token"] = $cfg.token
  }
  $json = $null
  if ($null -ne $Body) { $json = $Body | ConvertTo-Json -Depth 16 -Compress }
  return Invoke-RestMethod -Uri ($ApiBase + $Path) -Method Post -Headers $headers -Body $json -TimeoutSec 180
}

function Get-IdentityHash {
  $machine = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name MachineGuid -ErrorAction SilentlyContinue).MachineGuid
  $bios = (Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue).SerialNumber
  $board = (Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue).SerialNumber
  return Get-Sha256Text (($machine + "|" + $bios + "|" + $board).Trim())
}

function Get-DeviceInfo {
  $os = Get-CimInstance Win32_OperatingSystem
  $cs = Get-CimInstance Win32_ComputerSystem
  $kind = if ($cs.PCSystemType -eq 2) { "laptop" } else { "desktop" }
  [ordered]@{
    display_name = $env:COMPUTERNAME
    device_kind = $kind
    platform_version = $os.Caption
    platform_build = $os.BuildNumber
    architecture = $env:PROCESSOR_ARCHITECTURE
    manufacturer = $cs.Manufacturer
    model = $cs.Model
    identifier_hash = (Get-IdentityHash)
    capabilities = [ordered]@{
      admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
      winget = [bool](Get-Command winget.exe -ErrorAction SilentlyContinue)
      defender = [bool](Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue)
      bitlocker = [bool](Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue)
      appx = [bool](Get-Command Get-AppxPackage -ErrorAction SilentlyContinue)
      dism = $true
      sfc = $true
    }
  }
}

function New-AgentToken {
  $bytes = New-Object byte[] 32
  $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
  return ([Convert]::ToBase64String($bytes)).TrimEnd("=").Replace("+","-").Replace("/","_")
}

function Pair-ComputerFromPc {
  $token = New-AgentToken
  $tokenHash = Get-Sha256Text $token
  $device = Get-DeviceInfo

  $r = Invoke-AgentApi "/agent/pairing/create" ([ordered]@{
    agent_version = $AgentVersion
    token_hash = $tokenHash
    token_prefix = $token.Substring(0,8)
    device = $device
  }) -NoToken

  if(!$r.ok -or !$r.code -or !$r.pairing_id) {
    throw "Nao foi possivel gerar o codigo de conexao."
  }

  Clear-Host
  Write-Host ""
  Write-Host "============================================================" -ForegroundColor DarkCyan
  Write-Host "                    EXECUTADOR" -ForegroundColor Green
  Write-Host "============================================================" -ForegroundColor DarkCyan
  Write-Host ""
  Write-Host "CODIGO DE CONEXAO:" -ForegroundColor White
  Write-Host ""
  Write-Host ("        " + $r.code) -ForegroundColor Green
  Write-Host ""
  Write-Host "No celular:" -ForegroundColor Cyan
  Write-Host "1. Abra o Executador." -ForegroundColor Gray
  Write-Host "2. Toque em Conectar PC." -ForegroundColor Gray
  Write-Host "3. Cole/digite este codigo e toque em Vincular." -ForegroundColor Gray
  Write-Host ""
  Write-Host "Aguardando o celular..." -ForegroundColor Yellow

  $expires = [DateTime]::Parse([string]$r.expires_at).ToUniversalTime()

  while((Get-Date).ToUniversalTime() -lt $expires) {
    Start-Sleep -Seconds 2
    try {
      $s = Invoke-AgentApi "/agent/pairing/status" ([ordered]@{
        pairing_id = [string]$r.pairing_id
        token_hash = $tokenHash
      }) -NoToken

      if($s.status -eq "claimed" -and $s.device_id) {
        Save-Config -Token $token -DeviceId ([string]$s.device_id)
        Write-Log ("Paired by PC-generated code. Device " + $s.device_id)
        Write-Host ""
        Write-Host "PC VINCULADO COM SUCESSO!" -ForegroundColor Green
        Write-Host "O Executador ja pode diagnosticar este computador." -ForegroundColor Green
        Start-Sleep -Seconds 2
        return $s
      }

      if($s.status -in @("expired","cancelled")) {
        throw "O codigo expirou ou foi cancelado. Gere outro codigo."
      }
    } catch {
      if($_.Exception.Message -match "expirou|cancelado") { throw }
      Write-Log ("Pair status: " + $_.Exception.Message) "WARN"
    }
  }

  throw "O codigo expirou. Execute o pareador novamente para gerar outro."
}

function Pair-Computer {
  param([string]$Code)
  $body = [ordered]@{code=$Code;agent_version=$AgentVersion;device=(Get-DeviceInfo)}
  $r = Invoke-AgentApi "/agent/pair" $body -NoToken
  if (!$r.ok -or !$r.agent_token) { throw "Pairing failed." }
  Save-Config -Token $r.agent_token -DeviceId $r.device_id
  Write-Log ("Paired device " + $r.device_id)
  return $r
}

function Get-HardwareSnapshot {
  $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
  $os = Get-CimInstance Win32_OperatingSystem
  $gpu = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object {
    [ordered]@{name=$_.Name;driver_version=$_.DriverVersion;memory_bytes=[long]$_.AdapterRAM}
  })
  [ordered]@{
    cpu = [ordered]@{name=$cpu.Name;cores=$cpu.NumberOfCores;logical_processors=$cpu.NumberOfLogicalProcessors;max_mhz=$cpu.MaxClockSpeed}
    memory = [ordered]@{total_bytes=[long]$os.TotalVisibleMemorySize*1024;free_bytes=[long]$os.FreePhysicalMemory*1024}
    gpu = $gpu
    motherboard = [ordered]@{}
    firmware = [ordered]@{bios=(Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty SMBIOSBIOSVersion)}
    displays = @()
    audio_devices = @()
    cameras = @()
    radios = @()
    sensors = @()
    raw = [ordered]@{computer_name=$env:COMPUTERNAME}
  }
}

function Get-InstalledSoftware {
  $items = New-Object System.Collections.Generic.List[object]
  $paths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
  )
  foreach($p in $paths) {
    Get-ItemProperty $p -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName} | ForEach-Object {
      $child = [string]$_.PSChildName
      $identity = if ($child -match "^\{[0-9A-Fa-f-]{36}\}$") { "msi:" + $child } else { "reg:" + (Get-Sha256Text ($_.DisplayName+"|"+$_.Publisher+"|"+$_.DisplayVersion+"|"+$child)) }
      $items.Add([ordered]@{
        identity_key=$identity
        name=$_.DisplayName
        publisher=$_.Publisher
        version=$_.DisplayVersion
        install_source=$_.InstallSource
        package_type=$(if($identity.StartsWith("msi:")){"msi"}else{"registry"})
        path_hash=$(if($_.InstallLocation){Get-Sha256Text $_.InstallLocation}else{$null})
        architecture=$(if($p -like "*WOW6432Node*"){"x86"}else{$null})
        update_available=$null
        latest_version=$null
        vulnerability_summary=[ordered]@{}
        metadata=[ordered]@{uninstall_key=$child}
      })
    }
  }
  try {
    Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | ForEach-Object {
      $items.Add([ordered]@{
        identity_key=("appx:" + $_.PackageFamilyName)
        name=$_.Name
        publisher=$_.Publisher
        version=$_.Version.ToString()
        install_source="Microsoft Store / AppX"
        package_type="appx"
        path_hash=$null
        architecture=$_.Architecture.ToString()
        update_available=$null
        latest_version=$null
        vulnerability_summary=[ordered]@{}
        metadata=[ordered]@{package_family_name=$_.PackageFamilyName;package_full_name=$_.PackageFullName}
      })
    }
  } catch {}
  return @($items | Group-Object identity_key | ForEach-Object {$_.Group | Select-Object -First 1})
}

function Get-Drivers {
  @(Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue | Where-Object {$_.DeviceName} | Select-Object -First 700 | ForEach-Object {
    [ordered]@{
      identity_key=("drv:" + (Get-Sha256Text ($_.DeviceID+"|"+$_.DriverVersion)))
      device_name=$_.DeviceName
      provider=$_.DriverProviderName
      version=$_.DriverVersion
      date=$null
      signed=[bool]$_.IsSigned
      status=$null
      update_available=$null
      latest_version=$null
      hardware_ids_hash=@()
      metadata=[ordered]@{inf=$_.InfName}
    }
  })
}

function Get-StartupItems {
  @(Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | ForEach-Object {
    [ordered]@{
      identity_key=("startup:" + (Get-Sha256Text ($_.Name+"|"+$_.Location+"|"+$_.Command)))
      name=$_.Name
      source=$_.Location
      enabled=$true
      impact="unknown"
      publisher=$null
      path_hash=$(if($_.Command){Get-Sha256Text $_.Command}else{$null})
      metadata=[ordered]@{}
    }
  })
}

function Get-Volumes {
  @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue | ForEach-Object {
    $encrypted=$null
    if(Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue){
      try {$encrypted=((Get-BitLockerVolume -MountPoint $_.DeviceID -ErrorAction Stop).ProtectionStatus -eq "On")}catch{}
    }
    [ordered]@{
      volume_key=$_.DeviceID
      label=$_.VolumeName
      filesystem=$_.FileSystem
      total_bytes=[long]$_.Size
      free_bytes=[long]$_.FreeSpace
      used_bytes=[long]($_.Size-$_.FreeSpace)
      smart_status=$null
      wear_percent=$null
      encrypted=$encrypted
      system_volume=($_.DeviceID -eq $env:SystemDrive)
      health=[ordered]@{}
    }
  })
}

function Get-BatteryInfo {
  $bat=Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
  if(!$bat){return $null}
  [ordered]@{
    level_percent=[double]$bat.EstimatedChargeRemaining
    health_percent=$null
    design_capacity_mah=$null
    full_charge_capacity_mah=$null
    cycle_count=$null
    temperature_c=$null
    voltage_mv=$null
    current_ma=$null
    charging=($bat.BatteryStatus -eq 2)
    power_source=$null
    condition=$bat.Status
    raw=[ordered]@{}
  }
}

function Get-NetworkInfo {
  $adapter=Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq "Up"} | Sort-Object LinkSpeed -Descending | Select-Object -First 1
  $internet=$false;$lat=$null;$dns=$null
  try {$p=Test-Connection 1.1.1.1 -Count 1 -ErrorAction Stop;$internet=$true;$lat=[double]$p.ResponseTime}catch{}
  try {$sw=[Diagnostics.Stopwatch]::StartNew();Resolve-DnsName "www.microsoft.com" -ErrorAction Stop | Out-Null;$sw.Stop();$dns=[double]$sw.ElapsedMilliseconds}catch{}
  [ordered]@{
    interface_type=$(if($adapter){$adapter.MediaType}else{$null})
    interface_name=$(if($adapter){$adapter.Name}else{$null})
    connected=[bool]$adapter
    wifi_signal_percent=$null
    mobile_signal_dbm=$null
    download_mbps=$null
    upload_mbps=$null
    latency_ms=$lat
    jitter_ms=$null
    packet_loss_percent=$null
    dns_ms=$dns
    gateway_reachable=$null
    internet_reachable=$internet
    captive_portal=$false
    details=[ordered]@{link_speed=$(if($adapter){$adapter.LinkSpeed}else{$null})}
  }
}

function Get-CrashReports {
  $events=Get-WinEvent -FilterHashtable @{LogName="Application";Id=1000;StartTime=(Get-Date).AddHours(-24)} -MaxEvents 80 -ErrorAction SilentlyContinue
  @($events | ForEach-Object {
    $msg=[string]$_.Message;$app=$null
    if($msg -match "(?im)Faulting application name:\s*([^,\r\n]+)"){$app=$matches[1]}
    if(!$app -and $msg -match "(?im)Nome do aplicativo com falha:\s*([^,\r\n]+)"){$app=$matches[1]}
    [ordered]@{
      app_name=$app
      package_name=$null
      process_name=$app
      occurred_at=$_.TimeCreated.ToUniversalTime().ToString("o")
      crash_type="application_error"
      exception_name=$null
      signature_hash=(Get-Sha256Text ($_.ProviderName+"|"+$_.Id+"|"+$msg.Substring(0,[Math]::Min(400,$msg.Length))))
      stack_hash=$null
      os_component=$false
      frequency_24h=1
      metadata=[ordered]@{event_id=$_.Id;provider=$_.ProviderName}
    }
  })
}

function Send-Inventory {
  $body=[ordered]@{
    device=(Get-DeviceInfo)
    hardware=(Get-HardwareSnapshot)
    software=(Get-InstalledSoftware)
    drivers=(Get-Drivers)
    startup_items=(Get-StartupItems)
    storage_volumes=(Get-Volumes)
    battery=(Get-BatteryInfo)
    network=(Get-NetworkInfo)
    crash_reports=(Get-CrashReports)
    full_software_inventory=$true
  }
  Invoke-AgentApi "/agent/inventory" $body
}

function Send-Heartbeat {
  try {Invoke-AgentApi "/agent/heartbeat" ([ordered]@{status="online";agent_version=$AgentVersion;capabilities=(Get-DeviceInfo).capabilities}) | Out-Null}
  catch {Write-Log ("Heartbeat failed: "+$_.Exception.Message) "WARN"}
}

function New-Result {
  param($Def,[string]$Status,[string]$Title,[string]$Summary,[object]$Values,[string[]]$Actions)
  [ordered]@{
    check_id=$Def.id
    status=$Status
    severity=$(if($Status -in @("warning","fail","error")){$Def.default_severity}else{"info"})
    title=$Title
    summary=$Summary
    measured_values=$(if($Values){$Values}else{[ordered]@{}})
    evidence=[ordered]@{}
    recommended_action_keys=$(if($Actions){@($Actions)}else{@()})
    completed_at=(Get-Date).ToUniversalTime().ToString("o")
  }
}

function Get-ActionList {
  param($Def,[string]$Status)
  if($Status -notin @("warning","fail","error")){return @()}
  if(!$Def.default_action_key){return @()}
  if($Def.handler_key -in @("software.install_integrity","software.msi_health","software.msix_appx_health")){return @()}
  return @([string]$Def.default_action_key)
}

function Run-Check {
  param($Def)
  $h=[string]$Def.handler_key
  try {
    switch($h) {
      "system.os_version" {
        $os=Get-CimInstance Win32_OperatingSystem
        return New-Result $Def "pass" "Windows detectado" ($os.Caption+" build "+$os.BuildNumber) @{build=$os.BuildNumber;version=$os.Version} @()
      }
      "system.uptime" {
        $os=Get-CimInstance Win32_OperatingSystem;$hours=[math]::Round(((Get-Date)-$os.LastBootUpTime).TotalHours,1);$s=if($hours -gt 168){"warning"}else{"pass"}
        return New-Result $Def $s "Tempo ligado" ($hours.ToString()+" horas") @{hours=$hours} (Get-ActionList $Def $s)
      }
      "performance.cpu_load" {
        $v=[double](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime;$s=if($v -ge 95){"fail"}elseif($v -ge 85){"warning"}else{"pass"}
        return New-Result $Def $s "Uso de CPU" ($v.ToString("0")+"%") @{percent=$v} @()
      }
      "performance.memory_pressure" {
        $os=Get-CimInstance Win32_OperatingSystem;$v=[math]::Round((1-($os.FreePhysicalMemory/$os.TotalVisibleMemorySize))*100,1);$s=if($v -ge 95){"fail"}elseif($v -ge 85){"warning"}else{"pass"}
        return New-Result $Def $s "Uso de memória" ($v.ToString()+"%") @{percent=$v} (Get-ActionList $Def $s)
      }
      "storage.free_space" {
        $min=100.0;foreach($v in @(Get-Volumes)){if($v.total_bytes -gt 0){$p=($v.free_bytes/$v.total_bytes)*100;if($p -lt $min){$min=$p}}};$min=[math]::Round($min,1);$s=if($min -lt 5){"fail"}elseif($min -lt 15){"warning"}else{"pass"}
        return New-Result $Def $s "Espaço livre" ("Menor volume com "+$min+"% livre") @{min_free_percent=$min} (Get-ActionList $Def $s)
      }
      "network.internet" {
        $ok=$false;$ms=$null;try{$p=Test-Connection 1.1.1.1 -Count 1 -ErrorAction Stop;$ok=$true;$ms=[double]$p.ResponseTime}catch{};$s=if($ok){"pass"}else{"fail"}
        return New-Result $Def $s "Internet" $(if($ok){"Conectado • "+$ms+" ms"}else{"Sem resposta externa"}) @{reachable=$ok;latency_ms=$ms} (Get-ActionList $Def $s)
      }
      "network.dns" {
        $ok=$false;$ms=$null;try{$sw=[Diagnostics.Stopwatch]::StartNew();Resolve-DnsName "www.microsoft.com" -ErrorAction Stop|Out-Null;$sw.Stop();$ok=$true;$ms=$sw.ElapsedMilliseconds}catch{};$s=if(!$ok){"fail"}elseif($ms -gt 250){"warning"}else{"pass"}
        return New-Result $Def $s "DNS" $(if($ok){$ms.ToString()+" ms"}else{"Falha de resolução"}) @{latency_ms=$ms} (Get-ActionList $Def $s)
      }
      "security.firewall" {
        $bad=@(Get-NetFirewallProfile -ErrorAction SilentlyContinue | Where-Object {!$_.Enabled});$s=if($bad.Count){"fail"}else{"pass"}
        return New-Result $Def $s "Firewall" $(if($bad.Count){$bad.Count.ToString()+" perfil(is) desativado(s)"}else{"Todos os perfis ativos"}) @{disabled=@($bad.Name)} (Get-ActionList $Def $s)
      }
      "security.antimalware" {
        if(!(Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue)){return New-Result $Def "skipped" "Antimalware" "Status indisponível" @{} @()}
        $m=Get-MpComputerStatus;$ok=$m.AntivirusEnabled -and $m.RealTimeProtectionEnabled;$s=if($ok){"pass"}else{"fail"}
        return New-Result $Def $s "Proteção antimalware" $(if($ok){"Proteção ativa"}else{"Proteção incompleta"}) @{antivirus=$m.AntivirusEnabled;realtime=$m.RealTimeProtectionEnabled} (Get-ActionList $Def $s)
      }
      "drivers.health" {
        $bad=@(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object {$_.ConfigManagerErrorCode -ne 0});$s=if($bad.Count){"warning"}else{"pass"}
        return New-Result $Def $s "Drivers e dispositivos" ($bad.Count.ToString()+" dispositivo(s) com erro") @{count=$bad.Count;devices=@($bad.Name|Select-Object -First 30)} (Get-ActionList $Def $s)
      }
      "windows.application_events" {
        $ev=@(Get-WinEvent -FilterHashtable @{LogName="Application";Level=2;StartTime=(Get-Date).AddHours(-24)} -MaxEvents 100 -ErrorAction SilentlyContinue);$s=if($ev.Count -gt 10){"warning"}else{"pass"}
        return New-Result $Def $s "Erros de aplicativos" ($ev.Count.ToString()+" erro(s) nas últimas 24h") @{errors_24h=$ev.Count} @()
      }
      "performance.app_hangs" {
        $ev=@(Get-WinEvent -FilterHashtable @{LogName="Application";Id=1002;StartTime=(Get-Date).AddHours(-24)} -MaxEvents 80 -ErrorAction SilentlyContinue);$s=if($ev.Count -gt 3){"warning"}else{"pass"}
        return New-Result $Def $s "Aplicativos travando" ($ev.Count.ToString()+" travamento(s) em 24h") @{hangs=$ev.Count} @()
      }
      "software.install_integrity" {
        $cr=@(Get-CrashReports);$bad=@($cr|Where-Object {$_.app_name}|Group-Object app_name|Where-Object {$_.Count -ge 3});$s=if($bad.Count){"warning"}else{"pass"}
        return New-Result $Def $s "Integridade de aplicativos" $(if($bad.Count){$bad.Count.ToString()+" aplicativo(s) com falhas recorrentes"}else{"Sem falhas recorrentes detectadas"}) @{problem_apps=@($bad|ForEach-Object {[ordered]@{name=$_.Name;crashes=$_.Count}})} @()
      }
      "software.msi_health" {
        $ev=@(Get-WinEvent -FilterHashtable @{LogName="Application";ProviderName="MsiInstaller";Level=2;StartTime=(Get-Date).AddDays(-7)} -MaxEvents 80 -ErrorAction SilentlyContinue);$s=if($ev.Count){"warning"}else{"pass"}
        return New-Result $Def $s "Instaladores MSI" ($ev.Count.ToString()+" erro(s) MSI em 7 dias") @{errors=$ev.Count} @()
      }
      "software.msix_appx_health" {
        $bad=@(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object {[string]$_.Status -and [string]$_.Status -ne "Ok"});$s=if($bad.Count){"warning"}else{"pass"}
        return New-Result $Def $s "Pacotes MSIX/AppX" ($bad.Count.ToString()+" pacote(s) anormal(is)") @{count=$bad.Count} @()
      }
      "windows.component_store" {
        if(!(Get-Command Repair-WindowsImage -ErrorAction SilentlyContinue)){return New-Result $Def "skipped" "Component Store" "DISM PowerShell indisponível" @{} @()}
        $r=Repair-WindowsImage -Online -CheckHealth -NoRestart -ErrorAction Stop;$state=[string]$r.ImageHealthState;$s=if($state -match "Healthy"){"pass"}else{"fail"}
        return New-Result $Def $s "Component Store" $state @{health_state=$state} (Get-ActionList $Def $s)
      }
      "windows.package_manager_health" {
        $w=Get-Command winget.exe -ErrorAction SilentlyContinue
        if(!$w){return New-Result $Def "fail" "WinGet" "Windows Package Manager não encontrado" @{} @()}
        $v=& winget.exe --version 2>&1 | Out-String
        return New-Result $Def "pass" "WinGet" $v.Trim() @{version=$v.Trim()} @()
      }
      default { return New-Result $Def "skipped" $Def.name "Check ainda não implementado neste agente." @{handler=$h} @() }
    }
  } catch {
    return New-Result $Def "error" $Def.name $_.Exception.Message @{handler=$h} @()
  }
}

function Run-ScanTask {
  param($Scan,$Definitions)
  $defs=@($Definitions|Where-Object {$_.template_id -eq $Scan.template_id}|Sort-Object position)
  $results=New-Object System.Collections.Generic.List[object]
  foreach($link in $defs){if($link.diagnostic_checks){$results.Add((Run-Check $link.diagnostic_checks))}}
  Invoke-AgentApi "/agent/scan/results" ([ordered]@{scan_run_id=$Scan.id;results=@($results);complete=$true}) | Out-Null
  Write-Log ("Scan complete " + $Scan.id + " checks=" + $results.Count)
}

function Invoke-ProcessChecked {
  param([string]$File,[string[]]$Args,[int]$TimeoutSec=1800)
  $p=Start-Process -FilePath $File -ArgumentList $Args -PassThru -WindowStyle Hidden
  if(!$p.WaitForExit($TimeoutSec*1000)){try{$p.Kill()}catch{};throw "Process timeout."}
  if($p.ExitCode -ne 0){throw ($File+" exit code "+$p.ExitCode)}
}

function Run-Repair {
  param($Job,$Action)
  $h=[string]$Action.handler_key
  $p=$Job.parameters
  switch($h) {
    "cleanup.temp_files" {
      foreach($t in @($env:TEMP,(Join-Path $env:windir "Temp"))){if(Test-Path $t){Get-ChildItem $t -Force -ErrorAction SilentlyContinue|Where-Object {$_.LastWriteTime -lt (Get-Date).AddHours(-12)}|Remove-Item -Force -Recurse -ErrorAction SilentlyContinue}}
      return @{message="Arquivos temporários elegíveis removidos."}
    }
    "network.flush_dns" {Invoke-ProcessChecked "ipconfig.exe" @("/flushdns") 60;return @{message="Cache DNS limpo."}}
    "network.renew_address" {Invoke-ProcessChecked "ipconfig.exe" @("/renew") 180;return @{message="DHCP renovado."}}
    "network.reset_stack" {Invoke-ProcessChecked "netsh.exe" @("winsock","reset") 120;Invoke-ProcessChecked "netsh.exe" @("int","ip","reset") 120;return @{message="Pilha de rede redefinida.";reboot_recommended=$true}}
    "windows.restart_explorer" {Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue;Start-Process explorer.exe;return @{message="Explorer reiniciado."}}
    "windows.repair_system_files" {Repair-WindowsImage -Online -RestoreHealth -NoRestart -ErrorAction Stop|Out-Null;Invoke-ProcessChecked "sfc.exe" @("/scannow") 3600;return @{message="DISM e SFC concluídos."}}
    "windows.repair_component_store" {Repair-WindowsImage -Online -RestoreHealth -NoRestart -ErrorAction Stop|Out-Null;return @{message="Component Store reparado."}}
    "windows.reset_update_components" {Stop-Service wuauserv,bits,cryptsvc -Force -ErrorAction SilentlyContinue;Remove-Item (Join-Path $env:windir "SoftwareDistribution\Download\*") -Recurse -Force -ErrorAction SilentlyContinue;Start-Service cryptsvc,bits,wuauserv -ErrorAction SilentlyContinue;return @{message="Windows Update redefinido."}}
    "windows.create_restore_point" {Enable-ComputerRestore -Drive ($env:SystemDrive+"\") -ErrorAction SilentlyContinue;Checkpoint-Computer -Description "Executador" -RestorePointType "MODIFY_SETTINGS";return @{message="Ponto de restauração criado."}}
    "windows.reset_store_cache" {Invoke-ProcessChecked "wsreset.exe" @() 300;return @{message="Cache da Microsoft Store redefinido."}}
    "security.refresh_protection" {Update-MpSignature -ErrorAction Stop;return @{message="Microsoft Defender atualizado."}}
    "security.enable_firewall" {Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True;return @{message="Firewall ativado."}}
    "software.update_apps" {
      if(!(Get-Command winget.exe -ErrorAction SilentlyContinue)){throw "WinGet unavailable."}
      & winget.exe upgrade --all --silent --disable-interactivity --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
      if($LASTEXITCODE -ne 0){throw "WinGet exit code "+$LASTEXITCODE}
      return @{message="Atualização de aplicativos concluída."}
    }
    "software.repair_app" {
      $id=[string]$p.identity_key
      if($id -like "msi:*"){
        $product=$id.Substring(4)
        if(Get-Command winget.exe -ErrorAction SilentlyContinue){
          & winget.exe repair --product-code $product --silent --disable-interactivity --accept-package-agreements 2>&1 | Out-Null
          if($LASTEXITCODE -eq 0){return @{message="Aplicativo reparado pelo WinGet.";product_code=$product}}
        }
        Invoke-ProcessChecked "msiexec.exe" @("/fa",$product,"/qn","/norestart") 1800
        return @{message="Aplicativo MSI reparado.";product_code=$product}
      }
      throw "Este aplicativo não possui identidade MSI segura para reparo automático."
    }
    "windows.reregister_store_app" {
      $family=[string]$p.package_family_name;if(!$family){throw "package_family_name required."}
      $pkg=Get-AppxPackage -AllUsers|Where-Object {$_.PackageFamilyName -eq $family}|Select-Object -First 1
      if(!$pkg){throw "Package not found."}
      Add-AppxPackage -DisableDevelopmentMode -Register (Join-Path $pkg.InstallLocation "AppXManifest.xml") -ErrorAction Stop
      return @{message="Pacote registrado novamente."}
    }
    "system.reboot" {& shutdown.exe /r /t 60 /c "Reinicialização solicitada pelo Executador" | Out-Null;return @{message="Reinicialização agendada em 60 segundos."}}
    default {throw ("Repair handler not implemented: " + $h)}
  }
}

function Process-Tasks {
  try {
    $tasks=Invoke-AgentApi "/agent/tasks/claim" ([ordered]@{scan_limit=2;repair_limit=8})
    foreach($scan in @($tasks.scans)){Run-ScanTask $scan @($tasks.scan_definitions)}
    foreach($job in @($tasks.repairs)){
      $action=@($tasks.actions|Where-Object {$_.id -eq $job.action_id})|Select-Object -First 1
      if(!$action){
        Invoke-AgentApi "/agent/repair/finish" @{job_id=$job.id;status="failed";error_code="ACTION_MISSING";error_message="Ação não encontrada.";result=@{}} | Out-Null
        continue
      }
      try {
        $result=Run-Repair $job $action
        Invoke-AgentApi "/agent/repair/finish" @{job_id=$job.id;status="succeeded";result=$result} | Out-Null
      } catch {
        Invoke-AgentApi "/agent/repair/finish" @{job_id=$job.id;status="failed";error_code="HANDLER_FAILED";error_message=$_.Exception.Message;result=@{handler=$action.handler_key}} | Out-Null
        Write-Log ("Repair failed: "+$_.Exception.Message) "ERROR"
      }
    }
  } catch {Write-Log ("Task polling failed: "+$_.Exception.Message) "WARN"}
}

try {
  if($PairFromPc){
    $r=Pair-ComputerFromPc
    Send-Heartbeat
    Send-Inventory | Out-Null
    Write-Host ""
    Write-Host "Sessao ativa. Mantenha esta janela aberta." -ForegroundColor Cyan
    $Daemon=$true
  }

  if($PairCode){
    $r=Pair-Computer $PairCode
    Send-Heartbeat
    Send-Inventory | Out-Null
    Write-Output ("PAIR_OK " + $r.device_id)
    exit 0
  }

  if($InventoryNow){
    if(!(Get-Config)){throw "PC not paired."}
    Send-Inventory | ConvertTo-Json -Depth 5
    exit 0
  }

  if($Daemon){
    if(!(Get-Config)){throw "PC not paired."}
    Write-Log "Daemon started"
    $lastInventory=[datetime]::MinValue
    while($true){
      Send-Heartbeat
      if(((Get-Date)-$lastInventory).TotalMinutes -ge 10){
        try{Send-Inventory|Out-Null;$lastInventory=Get-Date}catch{Write-Log ("Inventory failed: "+$_.Exception.Message) "WARN"}
      }
      Process-Tasks
      Start-Sleep -Seconds 12
    }
  }

  Write-Output ("Executador Agent " + $AgentVersion)
  Write-Output "Use -PairFromPc para gerar codigo, -InventoryNow ou -Daemon."
} catch {
  Write-Log $_.Exception.Message "ERROR"
  Write-Error $_.Exception.Message
  exit 1
}