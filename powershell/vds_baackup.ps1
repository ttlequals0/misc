
Add-PSSnapin VMware.VimAutomation.Core
Import-Module VMware.VimAutomation.Vds

Connect-VIServer 10.200.203.62
Get-VDSwitch -Name *  | Foreach { Export-VDSwitch -VDSwitch $_ -Description “Backup of $($_.Name) VDS” -Destination “c:\VDS\MOCK_7x\$($_.Datacenter.Name)-$($_.Name).Zip” -Force}
Disconnect-VIServer * -confirm:$false
