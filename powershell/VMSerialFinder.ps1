New-VIProperty -Name BIOSNumber -ObjectType VirtualMachine -Value {
  param($vm)

  $s = ($vm.ExtensionData.Config.Uuid).Replace("-", "")
  $Uuid = "VMware-"
  for ($i = 0; $i -lt $s.Length; $i += 2)
  {
    $Uuid += ("{0:x2}" -f [byte]("0x" + $s.Substring($i, 2)))
    if ($Uuid.Length -eq 30) { $Uuid += "-" } else { $Uuid += " " }
  }
  $Uuid.TrimEnd()
} -Force | Out-Null

Get-VM DE-MPF-MEF*  | Select Name,BIOSNumber 