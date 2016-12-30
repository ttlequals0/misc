
##ON OLD VCENTER

#In PowerCLI run the following command:
Get-VM -name *sy* | Get-NetworkAdapter | Select Parent, Name, NetworkName, MacAddress | Export-CSV C:\backups\SY_VM_Network_Info.csv

#verify vds port connectivity

#with the web client: export vds's

##ON NEW VCENTER

#create datacenter
New-Datacenter -Location (Get-Folder -NoRecursion) -Name "$Datacenter"

#create cluster
New-Cluster -Location "$Datacenter" -Name "$cluster1"

#connect esxi hosts 
Get-Content hosts.txt | Foreach-Object { Add-VMHost $_ -Location (Get-Datacenter "$Datacenter") -User root -Password $Password -RunAsync -force:$true; Move-VMHost $_ -Location (Get-Cluster "SL-Cluster-MFR") -RunAsync}
#import vds's

get-vm -name *sy* |  get-networkadapter -name "Network adapter 1" | set-networkadapter -confirm:$false

#remove old drivers
Get-VMHost -name *sy* | %{  $esxcli = Get-EsxCli -VMHost $_ ; Write-Host "$_" ; $esxcli.software.vib.list() | Where { $_.Name -like "*net-mlx4-en*"} | %{ $esxcli.software.vib.remove($null, $false, $false, $true, @($_.Name)) } }

#cluster datastores
New-DatastoreCluster -Name "MOCK-Frankfurt-Debesys-3PAR" -Location "MOCK-Frankfurt-Debesys"
Get-Datastore -Name MTN-FR-3PAR* | Move-Datastore -Destination (Get-DatastoreCluster -Name "MOCK-Frankfurt-Debesys-3PAR")
Set-DatastoreCluster -DatastoreCluster "MOCK-Chicago-Debesys-3PAR" -SdrsAutomationLevel FullyAutomated

#copy profile
#configure esx and datastore clusters

$clusName = "SL-Cluster-MAR"
[int]$haPercent="50"
Set-Cluster -Cluster $clusName -DrsAutomationLevel FullyAutomated -DrsEnabled:$true -HAEnabled:$true -HAIsolationResponse DoNothing -HAAdmissionControlEnable:$true  -Confirm:$false -WhatIf
#DRS
$clus = Get-Cluster -Name $clusName | Get-View
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

#create drs schedules

#restart vcenter




 
Get-VMHost -name mtn-ch-esx-132* | %{ 
    $esxcli = Get-EsxCli -VMHost $_
    Write-Host "$_"
    $esxcli.software.vib.list() | Where { $_.Name -like "*net-mlx4-en*"} | %{
        $esxcli.software.vib.remove($null, $false, $false, $true, @($_.Name))
    }
}
 