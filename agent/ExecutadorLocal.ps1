param(
  [Parameter(Mandatory=$true)][string]$AgentPath,
  [switch]$SelfTest
)

Set-StrictMode -Version 2
$ErrorActionPreference="Stop"

if(!(Test-Path -LiteralPath $AgentPath)){throw "ExecutadorAgent.ps1 não encontrado."}
$RequestedSelfTest=[bool]$SelfTest
. $AgentPath | Out-Null

function Get-LocalDiagnosticDefinitions {
  @(
    [pscustomobject]@{id="local.os";handler_key="system.os_version";name="Windows";default_severity="medium";default_action_key=$null}
    [pscustomobject]@{id="local.uptime";handler_key="system.uptime";name="Tempo ligado";default_severity="low";default_action_key=$null}
    [pscustomobject]@{id="local.cpu";handler_key="performance.cpu_load";name="CPU";default_severity="medium";default_action_key=$null}
    [pscustomobject]@{id="local.memory";handler_key="performance.memory_pressure";name="Memória";default_severity="medium";default_action_key=$null}
    [pscustomobject]@{id="local.storage";handler_key="storage.free_space";name="Armazenamento";default_severity="high";default_action_key="cleanup.temp_files"}
    [pscustomobject]@{id="local.internet";handler_key="network.internet";name="Internet";default_severity="high";default_action_key="network.renew_address"}
    [pscustomobject]@{id="local.dns";handler_key="network.dns";name="DNS";default_severity="medium";default_action_key="network.flush_dns"}
    [pscustomobject]@{id="local.firewall";handler_key="security.firewall";name="Firewall";default_severity="high";default_action_key="security.enable_firewall"}
    [pscustomobject]@{id="local.antimalware";handler_key="security.antimalware";name="Microsoft Defender";default_severity="high";default_action_key="security.refresh_protection"}
    [pscustomobject]@{id="local.drivers";handler_key="drivers.health";name="Drivers";default_severity="medium";default_action_key=$null}
    [pscustomobject]@{id="local.apperrors";handler_key="windows.application_events";name="Erros de aplicativos";default_severity="medium";default_action_key=$null}
    [pscustomobject]@{id="local.hangs";handler_key="performance.app_hangs";name="Aplicativos travando";default_severity="medium";default_action_key=$null}
    [pscustomobject]@{id="local.software";handler_key="software.install_integrity";name="Integridade de aplicativos";default_severity="medium";default_action_key=$null}
    [pscustomobject]@{id="local.msi";handler_key="software.msi_health";name="MSI";default_severity="medium";default_action_key=$null}
    [pscustomobject]@{id="local.appx";handler_key="software.msix_appx_health";name="Microsoft Store / AppX";default_severity="medium";default_action_key=$null}
    [pscustomobject]@{id="local.componentstore";handler_key="windows.component_store";name="Component Store";default_severity="high";default_action_key="windows.repair_component_store"}
    [pscustomobject]@{id="local.winget";handler_key="windows.package_manager_health";name="WinGet";default_severity="medium";default_action_key=$null}
  )
}

function Invoke-LocalRepair {
  param([string]$Handler,[hashtable]$Parameters)
  $job=[pscustomobject]@{parameters=$(if($Parameters){$Parameters}else{@{}})}
  $action=[pscustomobject]@{handler_key=$Handler}
  Write-Log ("Local repair requested: "+$Handler)
  $result=Run-Repair $job $action
  Write-Log ("Local repair completed: "+$Handler)
  return $result
}

if($RequestedSelfTest){
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  if(!(Get-Command Run-Repair -ErrorAction SilentlyContinue)){throw "Motor de reparo não carregado."}
  if(!(Get-Command Run-Check -ErrorAction SilentlyContinue)){throw "Motor de diagnóstico não carregado."}
  if(!(Get-Command Get-InstalledSoftware -ErrorAction SilentlyContinue)){throw "Inventário não carregado."}
  if(-not [type]::GetType("System.Windows.Forms.Form, System.Windows.Forms", $false)){throw "WinForms indisponível."}
  if(-not [type]::GetType("System.Drawing.Color, System.Drawing", $false)){throw "System.Drawing indisponível."}
  Write-Output "LOCAL_SELFTEST_OK"
  exit 0
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

$bg=[Drawing.Color]::FromArgb(5,9,8)
$card=[Drawing.Color]::FromArgb(11,21,18)
$line=[Drawing.Color]::FromArgb(24,49,40)
$fg=[Drawing.Color]::FromArgb(238,250,245)
$mut=[Drawing.Color]::FromArgb(139,161,152)
$green=[Drawing.Color]::FromArgb(79,247,173)
$red=[Drawing.Color]::FromArgb(255,101,119)

$form=New-Object Windows.Forms.Form
$form.Text="Executador — PC"
$form.StartPosition="CenterScreen"
$form.Size=New-Object Drawing.Size(1180,780)
$form.MinimumSize=New-Object Drawing.Size(980,680)
$form.BackColor=$bg
$form.ForeColor=$fg
$form.Font=New-Object Drawing.Font("Segoe UI",10)

$header=New-Object Windows.Forms.Panel
$header.Dock="Top"
$header.Height=78
$header.BackColor=$card
$form.Controls.Add($header)

$title=New-Object Windows.Forms.Label
$title.Text="EXECUTADOR"
$title.Font=New-Object Drawing.Font("Segoe UI Semibold",22)
$title.ForeColor=$green
$title.AutoSize=$true
$title.Location=New-Object Drawing.Point(24,12)
$header.Controls.Add($title)

$sub=New-Object Windows.Forms.Label
$sub.Text="Modo PC direto • local • sem celular • sem pareamento"
$sub.ForeColor=$mut
$sub.AutoSize=$true
$sub.Location=New-Object Drawing.Point(28,49)
$header.Controls.Add($sub)

$status=New-Object Windows.Forms.Label
$status.Text="Pronto"
$status.ForeColor=$green
$status.AutoSize=$true
$status.Anchor="Top,Right"
$status.Location=New-Object Drawing.Point(1010,31)
$header.Controls.Add($status)

$tabs=New-Object Windows.Forms.TabControl
$tabs.Dock="Fill"
$form.Controls.Add($tabs)

function New-Tab([string]$Name){
  $t=New-Object Windows.Forms.TabPage
  $t.Text=$Name
  $t.BackColor=$bg
  $t.ForeColor=$fg
  [void]$tabs.TabPages.Add($t)
  return $t
}

$tabOverview=New-Tab "Visão geral"
$tabDiag=New-Tab "Diagnóstico"
$tabApps=New-Tab "Aplicativos"
$tabRepair=New-Tab "Reparos"
$tabLogs=New-Tab "Logs"

$overview=New-Object Windows.Forms.RichTextBox
$overview.Dock="Fill"
$overview.ReadOnly=$true
$overview.BorderStyle="None"
$overview.BackColor=$bg
$overview.ForeColor=$fg
$overview.Font=New-Object Drawing.Font("Consolas",11)
$tabOverview.Controls.Add($overview)

$diagPanel=New-Object Windows.Forms.Panel
$diagPanel.Dock="Top"
$diagPanel.Height=54
$tabDiag.Controls.Add($diagPanel)

$btnDiag=New-Object Windows.Forms.Button
$btnDiag.Text="Executar diagnóstico"
$btnDiag.Width=210
$btnDiag.Height=36
$btnDiag.Location=New-Object Drawing.Point(10,9)
$btnDiag.BackColor=$green
$btnDiag.ForeColor=[Drawing.Color]::Black
$btnDiag.FlatStyle="Flat"
$btnDiag.FlatAppearance.BorderSize=0
$diagPanel.Controls.Add($btnDiag)

$diagList=New-Object Windows.Forms.ListView
$diagList.Dock="Fill"
$diagList.View="Details"
$diagList.FullRowSelect=$true
$diagList.GridLines=$true
$diagList.BackColor=$card
$diagList.ForeColor=$fg
[void]$diagList.Columns.Add("Status",100)
[void]$diagList.Columns.Add("Verificação",250)
[void]$diagList.Columns.Add("Detalhes",560)
[void]$diagList.Columns.Add("Ação",170)
$tabDiag.Controls.Add($diagList)
$diagList.BringToFront()

$appTop=New-Object Windows.Forms.Panel
$appTop.Dock="Top"
$appTop.Height=54
$tabApps.Controls.Add($appTop)

$btnApps=New-Object Windows.Forms.Button
$btnApps.Text="Atualizar lista"
$btnApps.Width=140
$btnApps.Height=36
$btnApps.Location=New-Object Drawing.Point(10,9)
$appTop.Controls.Add($btnApps)

$btnRepairApp=New-Object Windows.Forms.Button
$btnRepairApp.Text="Reparar selecionado"
$btnRepairApp.Width=180
$btnRepairApp.Height=36
$btnRepairApp.Location=New-Object Drawing.Point(160,9)
$appTop.Controls.Add($btnRepairApp)

$appsGrid=New-Object Windows.Forms.DataGridView
$appsGrid.Dock="Fill"
$appsGrid.ReadOnly=$true
$appsGrid.AllowUserToAddRows=$false
$appsGrid.AllowUserToDeleteRows=$false
$appsGrid.SelectionMode="FullRowSelect"
$appsGrid.MultiSelect=$false
$appsGrid.AutoSizeColumnsMode="Fill"
$appsGrid.BackgroundColor=$card
$tabApps.Controls.Add($appsGrid)
$appsGrid.BringToFront()

$repairFlow=New-Object Windows.Forms.FlowLayoutPanel
$repairFlow.Dock="Fill"
$repairFlow.AutoScroll=$true
$repairFlow.Padding=New-Object Windows.Forms.Padding(14)
$repairFlow.BackColor=$bg
$tabRepair.Controls.Add($repairFlow)

$logTop=New-Object Windows.Forms.Panel
$logTop.Dock="Top"
$logTop.Height=54
$tabLogs.Controls.Add($logTop)

$btnLogs=New-Object Windows.Forms.Button
$btnLogs.Text="Atualizar logs"
$btnLogs.Width=140
$btnLogs.Height=36
$btnLogs.Location=New-Object Drawing.Point(10,9)
$logTop.Controls.Add($btnLogs)

$logs=New-Object Windows.Forms.RichTextBox
$logs.Dock="Fill"
$logs.ReadOnly=$true
$logs.BackColor=$card
$logs.ForeColor=$fg
$logs.Font=New-Object Drawing.Font("Consolas",9)
$tabLogs.Controls.Add($logs)
$logs.BringToFront()

function Set-LocalStatus([string]$Text,[Drawing.Color]$Color){
  $status.Text=$Text
  $status.ForeColor=$Color
  [Windows.Forms.Application]::DoEvents()
}

function Refresh-Overview {
  try{
    $d=Get-DeviceInfo
    $h=Get-HardwareSnapshot
    $n=Get-NetworkInfo
    $vol=@(Get-Volumes)
    $lines=New-Object System.Collections.Generic.List[string]
    $lines.Add("EXECUTADOR "+$AgentVersion)
    $lines.Add("")
    $lines.Add("Computador: "+$d.display_name)
    $lines.Add("Windows:    "+$d.platform_version+" (build "+$d.platform_build+")")
    $lines.Add("Modelo:     "+$d.manufacturer+" "+$d.model)
    $lines.Add("CPU:        "+$h.cpu.name)
    $lines.Add("RAM:        "+([math]::Round($h.memory.total_bytes/1GB,1))+" GB total")
    $lines.Add("Internet:   "+$(if($n.internet_reachable){"OK"}else{"Sem resposta"}))
    $lines.Add("DNS:        "+$(if($null -ne $n.dns_ms){$n.dns_ms.ToString()+" ms"}else{"indisponível"}))
    $lines.Add("")
    $lines.Add("Discos:")
    foreach($v in $vol){
      $lines.Add("  "+$v.volume_key+"  "+([math]::Round($v.free_bytes/1GB,1))+" GB livres / "+([math]::Round($v.total_bytes/1GB,1))+" GB")
    }
    $lines.Add("")
    $lines.Add("Administrador: "+$d.capabilities.admin)
    $lines.Add("WinGet:       "+$d.capabilities.winget)
    $lines.Add("Defender:     "+$d.capabilities.defender)
    $lines.Add("BitLocker:    "+$d.capabilities.bitlocker)
    $lines.Add("")
    $lines.Add("Tudo roda localmente neste computador.")
    $overview.Text=[string]::Join([Environment]::NewLine,$lines)
  }catch{
    $overview.Text="Falha ao carregar visão geral: "+$_.Exception.Message
  }
}

function Refresh-Apps {
  Set-LocalStatus "Lendo aplicativos..." $mut
  try{
    $data=@(Get-InstalledSoftware|Sort-Object name)
    $table=New-Object System.Data.DataTable
    [void]$table.Columns.Add("Nome")
    [void]$table.Columns.Add("Versão")
    [void]$table.Columns.Add("Tipo")
    [void]$table.Columns.Add("Editor")
    [void]$table.Columns.Add("Identity")
    [void]$table.Columns.Add("PackageFamily")
    foreach($a in $data){
      $row=$table.NewRow()
      $row["Nome"]=$a.name
      $row["Versão"]=[string]$a.version
      $row["Tipo"]=$a.package_type
      $row["Editor"]=[string]$a.publisher
      $row["Identity"]=$a.identity_key
      $row["PackageFamily"]=[string]$a.metadata.package_family_name
      $table.Rows.Add($row)
    }
    $appsGrid.DataSource=$table
    if($appsGrid.Columns["Identity"]){$appsGrid.Columns["Identity"].Visible=$false}
    if($appsGrid.Columns["PackageFamily"]){$appsGrid.Columns["PackageFamily"].Visible=$false}
    Set-LocalStatus ("Aplicativos: "+$data.Count) $green
  }catch{
    Set-LocalStatus "Falha ao listar aplicativos" $red
    [Windows.Forms.MessageBox]::Show($_.Exception.Message,"Executador")|Out-Null
  }
}

$btnDiag.Add_Click({
  $btnDiag.Enabled=$false
  $diagList.Items.Clear()
  Set-LocalStatus "Executando diagnóstico..." $mut
  try{
    foreach($def in @(Get-LocalDiagnosticDefinitions)){
      [Windows.Forms.Application]::DoEvents()
      $r=Run-Check $def
      $action=""
      if(@($r.recommended_action_keys).Count -gt 0){$action=[string]$r.recommended_action_keys[0]}
      $item=New-Object Windows.Forms.ListViewItem(([string]$r.status).ToUpperInvariant())
      [void]$item.SubItems.Add([string]$r.title)
      [void]$item.SubItems.Add([string]$r.summary)
      [void]$item.SubItems.Add($action)
      if($r.status -in @("fail","error")){$item.ForeColor=$red}
      elseif($r.status -eq "warning"){$item.ForeColor=[Drawing.Color]::Orange}
      else{$item.ForeColor=$fg}
      [void]$diagList.Items.Add($item)
    }
    Set-LocalStatus "Diagnóstico concluído" $green
  }catch{
    Set-LocalStatus "Erro no diagnóstico" $red
    [Windows.Forms.MessageBox]::Show($_.Exception.Message,"Executador")|Out-Null
  }finally{
    $btnDiag.Enabled=$true
  }
})

$btnApps.Add_Click({Refresh-Apps})

$btnRepairApp.Add_Click({
  if($appsGrid.SelectedRows.Count -eq 0){
    [Windows.Forms.MessageBox]::Show("Selecione um aplicativo primeiro.","Executador")|Out-Null
    return
  }
  $row=$appsGrid.SelectedRows[0]
  $name=[string]$row.Cells["Nome"].Value
  $type=[string]$row.Cells["Tipo"].Value
  $identity=[string]$row.Cells["Identity"].Value
  $family=[string]$row.Cells["PackageFamily"].Value
  if($type -notin @("msi","appx")){
    [Windows.Forms.MessageBox]::Show("Esse aplicativo não tem um reparo local seguro disponível.","Executador")|Out-Null
    return
  }
  $answer=[Windows.Forms.MessageBox]::Show("Reparar "+$name+"?","Confirmar",[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Question)
  if($answer -ne [Windows.Forms.DialogResult]::Yes){return}
  try{
    Set-LocalStatus ("Reparando "+$name+"...") $mut
    if($type -eq "msi"){$res=Invoke-LocalRepair "software.repair_app" @{identity_key=$identity}}
    else{$res=Invoke-LocalRepair "windows.reregister_store_app" @{package_family_name=$family}}
    Set-LocalStatus "Reparo concluído" $green
    [Windows.Forms.MessageBox]::Show([string]$res.message,"Executador")|Out-Null
  }catch{
    Set-LocalStatus "Reparo falhou" $red
    [Windows.Forms.MessageBox]::Show($_.Exception.Message,"Executador")|Out-Null
  }
})

$repairs=@(
  @{label="Limpar temporários";handler="cleanup.temp_files";confirm="Remover arquivos temporários antigos?";danger=$false}
  @{label="Limpar DNS";handler="network.flush_dns";confirm="Limpar o cache DNS?";danger=$false}
  @{label="Renovar IP";handler="network.renew_address";confirm="Renovar o endereço de rede via DHCP?";danger=$false}
  @{label="Resetar rede";handler="network.reset_stack";confirm="Redefinir Winsock e TCP/IP? Pode exigir reinicialização.";danger=$true}
  @{label="Reiniciar Explorer";handler="windows.restart_explorer";confirm="Reiniciar o Windows Explorer agora?";danger=$false}
  @{label="Reparar Windows (DISM + SFC)";handler="windows.repair_system_files";confirm="Executar DISM e SFC? Pode levar bastante tempo.";danger=$true}
  @{label="Reparar Component Store";handler="windows.repair_component_store";confirm="Executar reparo do Component Store?";danger=$true}
  @{label="Resetar Windows Update";handler="windows.reset_update_components";confirm="Redefinir componentes do Windows Update?";danger=$true}
  @{label="Criar ponto de restauração";handler="windows.create_restore_point";confirm="Criar um ponto de restauração agora?";danger=$false}
  @{label="Resetar Microsoft Store";handler="windows.reset_store_cache";confirm="Redefinir o cache da Microsoft Store?";danger=$false}
  @{label="Atualizar Defender";handler="security.refresh_protection";confirm="Atualizar assinaturas do Defender?";danger=$false}
  @{label="Ativar Firewall";handler="security.enable_firewall";confirm="Ativar o Firewall em todos os perfis?";danger=$false}
  @{label="Atualizar aplicativos";handler="software.update_apps";confirm="Atualizar aplicativos compatíveis pelo WinGet?";danger=$true}
  @{label="Reiniciar PC em 60s";handler="system.reboot";confirm="Agendar a reinicialização do PC em 60 segundos?";danger=$true}
)

foreach($spec in $repairs){
  $button=New-Object Windows.Forms.Button
  $button.Text=$spec.label
  $button.Width=250
  $button.Height=58
  $button.Margin=New-Object Windows.Forms.Padding(8)
  $button.FlatStyle="Flat"
  $button.FlatAppearance.BorderColor=$line
  $button.BackColor=$(if($spec.danger){[Drawing.Color]::FromArgb(55,20,24)}else{$card})
  $button.ForeColor=$(if($spec.danger){$red}else{$fg})
  $handler=[string]$spec.handler
  $label=[string]$spec.label
  $confirm=[string]$spec.confirm
  $button.Add_Click({
    $answer=[Windows.Forms.MessageBox]::Show($confirm,$label,[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Question)
    if($answer -ne [Windows.Forms.DialogResult]::Yes){return}
    try{
      Set-LocalStatus ($label+"...") $mut
      $res=Invoke-LocalRepair $handler @{}
      Set-LocalStatus "Concluído" $green
      [Windows.Forms.MessageBox]::Show([string]$res.message,"Executador")|Out-Null
      Refresh-Overview
    }catch{
      Set-LocalStatus "Falhou" $red
      [Windows.Forms.MessageBox]::Show($_.Exception.Message,"Executador")|Out-Null
    }
  }.GetNewClosure())
  [void]$repairFlow.Controls.Add($button)
}

$btnLogs.Add_Click({
  if(Test-Path $LogPath){$logs.Text=(Get-Content $LogPath -Tail 1000 -ErrorAction SilentlyContinue|Out-String)}
  else{$logs.Text="Nenhum log ainda."}
})

$form.Add_Shown({
  Refresh-Overview
  Refresh-Apps
  if(Test-Path $LogPath){$logs.Text=(Get-Content $LogPath -Tail 300 -ErrorAction SilentlyContinue|Out-String)}
})

[void]$form.ShowDialog()
