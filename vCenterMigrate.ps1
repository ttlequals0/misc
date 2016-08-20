$ErrorActionPreference = "Stop"
$SourcevCenter = "119.0.0.0"
$DestinationvCenter = "120.0.0.0"
#escape password
$Datacenter = "New York"
$Cluster1 = "SL-Cluster-MAR"
$Cluster2 = ""
$Cluster3 = ""
$HostPassword = "password"
$VmIfoCsv = "MAR_VM_Network_Info.csv"
$VmNamePattern = "*ar*"
$DatastoreClusterName = "MOCK-Aurora-Debesys-3PAR"
$DatastoreNamePattern = "MTN-AR-3PAR-1:mar*"

##OLD VCENTER
Connect-VIServer $SourcevCenter 
#export VM Information
If ((Test-Path ./$SourcevCenter/$Datacenter/Cluster1) -eq 0) {mkdir ./$SourcevCenter/$Datacenter/Cluster1 | Out-Null}
Get-VM -name $VmNamePattern | Get-NetworkAdapter | Select Parent, Name, NetworkName, MacAddress | Export-CSV .\$SourcevCenter\$Datacenter\$VmIfoCsv
Get-Cluster -name $Cluster1 | Get-VMHost | select Name | `
Export-Csv -NoTypeInformation -UseCulture -Path .\$SourcevCenter\$Datacenter\Cluster1\VMHost.csv

if($Cluster2) {     
    If ((Test-Path ./$SourcevCenter/$Datacenter/Cluster2) -eq 0) {mkdir ./$SourcevCenter/$Datacenter/Cluster2 | Out-Null}       
    Get-Cluster -name $Cluster2 | Get-VMHost | select Name | `
    Export-Csv -NoTypeInformation -UseCulture -Path .\$SourcevCenter\$Datacenter\Cluster2\VMHost.csv          
} else {            
    Write-Host "no second cluster"            
}
if($Cluster3) {            
    If ((Test-Path ./$SourcevCenter/$Datacenter/Cluster3) -eq 0) {mkdir ./$SourcevCenter/$Datacenter/Cluster3 | Out-Null}       
    Get-Cluster -name $Cluster3 | Get-VMHost | select Name | `
    Export-Csv -NoTypeInformation -UseCulture -Path .\$SourcevCenter\$Datacenter\Cluster3\VMHost.csv          
} else {            
    Write-Host "no third cluster"            
}

Disconnect-VIServer $SourcevCenter -confirm:$false


#Export VDS and verify
Write-Host "Verify all VDS port connectivity"
Write-Host "Export all vDS using web interface. Press any key once done."
$UserInput = Read-Host


##NEW VCENTER

Connect-VIServer $DestinationvCenter

#create Datacenters
New-Datacenter -Location (Get-Folder -NoRecursion) -Name "$Datacenter"

#read in CSV files and create clusters
$CSVhosts1 = Import-Csv .\$SourcevCenter\$Datacenter\Cluster1\VMHost.csv
New-Cluster -Location "$Datacenter" -Name "$Cluster1"

if($Cluster2) {   
    $CSVhosts2 = Import-Csv .\$SourcevCenter\$Datacenter\Cluster2\VMHost.csv          
    New-Cluster -Location "$Datacenter" -Name "$Cluster2"            
} else {            
    Write-Host "no second cluster"            
}
if($Cluster3) {     
    $CSVhosts3 = Import-Csv .\$SourcevCenter\$Datacenter\Cluster3\VMHost.csv       
    New-Cluster -Location "$Datacenter" -Name "$Cluster3"
} else {            
    Write-Host "no third cluster"            
}

#add Hosts
foreach ($vmhost in $CSVhosts1) {Add-VMHost $vmhost.name -Location $Cluster1 -User root -Password $HostPassword -confirm:$false -Force -RunAsync}
if($cluster2) {   
    foreach ($vmhost in $CSVhosts2) {Add-VMHost $vmhost.name -Location $Cluster2 -User root -Password $HostPassword -confirm:$false -Force -RunAsync}            
} else {            
    Write-Host "no second cluster"            
}
if($cluster3) {     
    foreach ($vmhost in $CSVhosts3) {Add-VMHost $vmhost.name -Location $Cluster3 -User root -Password $HostPassword -confirm:$false -Force -RunAsync}  
} else {            
    Write-Host "no third cluster"            
}
#Waiting for hosts to be added 
$x = 1*35
$length = $x / 100
while($x -gt 0) {
  $min = [int](([string]($x/60)).split('.')[0])
  $text = " " + $min + " minutes " + ($x % 60) + " seconds left"
  Write-Progress "Waiting to allow hosts to connect" -status $text -perc ($x/$length)
  start-sleep -s 1
  $x--
}

#check host connection status
foreach ($vmhost in $CSVhosts1) {
    Do {
        [string]$status = (get-vmhost -Name $vmhost.name | select ConnectionState)
        Write-Host "Connection state of " $vmhost.name " = " $status " - Process will proceed when host status is connected"
        Start-Sleep -Seconds 1
        }
        While ($status -ne "@{ConnectionState=Connected}")
    }
if($cluster2) {   
    foreach ($vmhost in $CSVhosts2) {
    Do {
        [string]$status = (get-vmhost -Name $vmhost.name | select ConnectionState)
        Write-Host "Connection state of " $vmhost.name " = " $status " - Process will proceed when host status is connected"
        Start-Sleep -Seconds 1
        }
        While ($status -ne "@{ConnectionState=Connected}")
    }
} else {            
    Write-Host "no second cluster"            
}
if($cluster3) {     
    foreach ($vmhost in $CSVhosts2) {
    Do {
        [string]$status = (get-vmhost -Name $vmhost.name | select ConnectionState)
        Write-Host "Connection state of " $vmhost.name " = " $status " - Process will proceed when host status is connected"
        Start-Sleep -Seconds 1
        }
        While ($status -ne "@{ConnectionState=Connected}")
    }
} else {            
    Write-Host "no third cluster"            
}


#Import VDS
Write-Host "Import all vDS using web interface. Press any key once done."
$UserInput = Read-Host

#read in NIC information
get-vm -name $VmNamePattern |  get-networkadapter -name "Network adapter 1" | set-networkadapter -confirm:$false

#cluster datastores
New-DatastoreCluster -Name "$DatastoreClusterName" -Location "$Datacenter"
Get-Datastore -Name $DatastoreNamePattern | Move-Datastore -Destination (Get-DatastoreCluster -Name "$DatastoreClusterName")
Set-DatastoreCluster -DatastoreCluster "$DatastoreClusterName" -SdrsAutomationLevel FullyAutomated

#configure esx and datastore clusters
$TotalVMHosts = Get-Cluster -Name "$Cluster1" |Get-VMHost
[int]$TotalVMHostsCount = $TotalVMHosts.count
[int]$haPercent= 100 / $TotalVMHostsCount
Set-Cluster -Cluster $Cluster1 -DrsAutomationLevel FullyAutomated -DrsEnabled:$true -HAEnabled:$true -HAIsolationResponse DoNothing -HAAdmissionControlEnable:$true  -Confirm:$false 
#DRS
$clus = Get-Cluster -Name $Cluster1 | Get-View
$clusSpec = New-Object VMware.Vim.ClusterConfigSpecEx
$clusSpec.drsConfig = New-Object VMware.Vim.ClusterDrsConfigInfo
$clusSPec.drsConfig.vmotionRate = 1
$clus.ReconfigureComputeResource_Task($clusSpec, $true)
#HA
$spec = New-Object VMware.Vim.ClusterConfigSpecEx
$spec.dasConfig = New-Object VMware.Vim.ClusterDasConfigInfo
$spec.dasConfig.admissionControlPolicy = New-Object VMware.Vim.ClusterFailoverResourcesAdmissionControlPolicy
$spec.dasConfig.admissionControlPolicy.cpuFailoverResourcesPercent = $haPercent
$spec.dasConfig.admissionControlPolicy.memoryFailoverResourcesPercent = $haPercent
$clus.ReconfigureComputeResource_Task($spec, $true)

if($cluster2) {   
    $TotalVMHosts = Get-Cluster -Name "$Cluster2" |Get-VMHost
    [int]$TotalVMHostsCount = $TotalVMHosts.count
    [int]$haPercent= 100 / $TotalVMHostsCount
    Set-Cluster -Cluster $Cluster2 -DrsAutomationLevel FullyAutomated -DrsEnabled:$true -HAEnabled:$true -HAIsolationResponse DoNothing -HAAdmissionControlEnable:$true  -Confirm:$false 
    #DRS
    $clus = Get-Cluster -Name $Cluster2 | Get-View
    $clusSpec = New-Object VMware.Vim.ClusterConfigSpecEx
    $clusSpec.drsConfig = New-Object VMware.Vim.ClusterDrsConfigInfo
    $clusSPec.drsConfig.vmotionRate = 1
    $clus.ReconfigureComputeResource_Task($clusSpec, $true)
    #HA
    $spec = New-Object VMware.Vim.ClusterConfigSpecEx
    $spec.dasConfig = New-Object VMware.Vim.ClusterDasConfigInfo
    $spec.dasConfig.admissionControlPolicy = New-Object VMware.Vim.ClusterFailoverResourcesAdmissionControlPolicy
    $spec.dasConfig.admissionControlPolicy.cpuFailoverResourcesPercent = $haPercent
    $spec.dasConfig.admissionControlPolicy.memoryFailoverResourcesPercent = $haPercent
    $clus.ReconfigureComputeResource_Task($spec, $true)
} else {            
    Write-Host "no second cluster"            
}
if($cluster3) {     
    $TotalVMHosts = Get-Cluster -Name "$Cluster3" |Get-VMHost
    [int]$TotalVMHostsCount = $TotalVMHosts.count
    [int]$haPercent= 100 / $TotalVMHostsCount
    Set-Cluster -Cluster $Cluster3 -DrsAutomationLevel FullyAutomated -DrsEnabled:$true -HAEnabled:$true -HAIsolationResponse DoNothing -HAAdmissionControlEnable:$true  -Confirm:$false 
    #DRS
    $clus = Get-Cluster -Name $Cluster3 | Get-View
    $clusSpec = New-Object VMware.Vim.ClusterConfigSpecEx
    $clusSpec.drsConfig = New-Object VMware.Vim.ClusterDrsConfigInfo
    $clusSPec.drsConfig.vmotionRate = 1
    $clus.ReconfigureComputeResource_Task($clusSpec, $true)
    #HA
    $spec = New-Object VMware.Vim.ClusterConfigSpecEx
    $spec.dasConfig = New-Object VMware.Vim.ClusterDasConfigInfo
    $spec.dasConfig.admissionControlPolicy = New-Object VMware.Vim.ClusterFailoverResourcesAdmissionControlPolicy
    $spec.dasConfig.admissionControlPolicy.cpuFailoverResourcesPercent = $haPercent
    $spec.dasConfig.admissionControlPolicy.memoryFailoverResourcesPercent = $haPercent
    $clus.ReconfigureComputeResource_Task($spec, $true)
} else {            
    Write-Host "no third cluster"            
}

$ErrorActionPreference = "Continue"
Get-VMHost -name "$HostNamePattern" | %{  $esxcli = Get-EsxCli -VMHost $_ ; Write-Host "$_" ; $esxcli.software.vib.list() | Where { $_.Name -like "*net-mlx4-en*"} | %{ $esxcli.software.vib.remove($null, $false, $false, $true, @($_.Name)) } }
Get-VM -Name $VmNamePattern | Where-Object  {$_.PowerState -eq "PoweredOn"} | Get-CDDrive | Set-CDDrive -Connected $false -Confirm:$false 
Write-Host "Create DRS Schedule "  
disconnect-viserver * -confirm:$false

