try {
    Add-PSSnapin VMware.VimAutomation.Core
}
catch {
}
$VCServerName = "chidebvc01"
$VC = Connect-VIServer $VCServerName
$ExportFilePath = "C:\scripts\vm_mapping\prod_debesys.csv"
 
$Report = @()
$VMs = Get-VM 
$Datastores = Get-Datastore | select Name, Id 

$VMHosts = Get-VMHost | select Name, Parent
 
ForEach ($VM in $VMs) {
      $VMView = $VM | Get-View
      $VMInfo = {} | Select VMName,Powerstate,Host,Cluster,Datastore
      $VMInfo.VMName = $vm.name
      $VMInfo.Powerstate = $vm.Powerstate
      $VMInfo.Host = $vm.vmhost.name
      $VMInfo.Cluster = $vm.host.Parent.Name
      $VMInfo.Datastore = (($Datastores | where {$_.ID -match (($vmview.Datastore | Select -First 1) | Select Value).Value} | Select Name ).Name  | Where { $_ -NotLike 'datastore*' }).Split(" ") | select -First 1
      $Report += $VMInfo
}
$Report = $Report | Sort-Object VMName
IF ($Report -ne "") {
$report | Export-Csv $ExportFilePath -NoTypeInformation
}

$VC = Disconnect-VIServer -Confirm:$False

