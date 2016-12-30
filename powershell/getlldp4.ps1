
&{foreach($esx in Get-VMHost -State Connected){
  $netSys =  Get-View -Id $esx.ExtensionData.ConfigManager.NetworkSystem
  $esxcli = Get-EsxCli -VMHost $esx
  foreach($vds in Get-VDSwitch -VMHost $esx){
    foreach($pnic in ($esxcli.network.vswitch.dvs.vmware.list($vds.Name) | Select -ExpandProperty Uplinks)){
      $netSys.QueryNetworkHint($pnic) |
      Select @{N='VMHost';E={$esx.Name}},
        @{N='VDS';E={$vds.Name}},
        @{n='pNIC';E={$pnic}},
        @{N='PortID';E={$_.LLDPInfo.portId}},
        @{N='MgmtIP';E={$_.LLDPInfo.Parameter | where{$_.Key -eq 'Management Address'} | Select -ExpandProperty Value}}
        #@{N='PortDesc';E={$_.LLDPInfo.Parameter | where{$_.Key -eq 'Port Description' } | Select -ExpandProperty Value}},
        #@{N='SysDesc';E={$_.LLDPInfo.Parameter | where{$_.Key -eq 'System Description' } | Select -ExpandProperty Value}},
        #@{N='SysName';E={$_.LLDPInfo.Parameter | where{$_.Key -eq 'System Name' } | Select -ExpandProperty Value}}
    }
  }
}} | Export-Csv c:\All_LLDP.csv -NoTypeInformation -UseCulture
 