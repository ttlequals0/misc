#Connect to DC02
$session = New-PSSession -ComputerName dc02

Invoke-Command -Session $session -ScriptBlock {

Param(
	[string]$DHCPServer = "192.168.101.191",
	[string]$DHCPscope = "192.168.100.0",
	[string]$Date = (Get-Date -F yyyy-MM-dd),
	[string]$InputCSV = "C:\share\dhcp\DHCP_Reservations_$($Date).csv",
	[string]$log_file = "C:\share\dhcp\DHCPReservations.txt"
)

function Write-Log
(
	[string]$log,
	[string]$message,
	[string]$delimeter,
	[int]$count
)
{
	if ($delimeter -and $count -gt 0)
	{	Add-Content -Path $log -Value ($delimeter*$count); return
	}
	Add-Content -Path $log -Value ((get-date -format G) + "`t" + $message)
}

#check for new DHCP reservations.
$strFileName="\\util01\dhcp\DHCP_Reservations_$($Date).csv"
If (Test-Path $strFileName){
cp \\util01\dhcp\DHCP_Reservations_$($Date).csv C:\share\dhcp\

#Log sepertator 
Write-Log $log_file -Delimeter "-" -Count 100

### Check if 'DHCP Server' role is installed.
Try { Import-Module ServerManager -ErrorAction Stop }
Catch
{
	Write-Host "Unable to load Active Directory module, is RSAT installed?"
	Write-Log $log_file "Tried to load the ServerManager Module, but failed. Is RSAT installed?"; Break
}

Write-Log $log_file "Loaded ServerManager Module."
Write-Log $log_file "Checking if `'DHCP Server`' role is installed on this server."

if (-not (Get-WindowsFeature | Where-Object { $_.DisplayName -eq "DHCP Server" -and $_.Installed -eq $True }))
{
	Write-Log $log_file "The `'DHCP Server`' role is not installed on this server. Please make sure this script is being run from a server with the `'DHCP Server`' role installed."
	Exit
}
else
{
	Write-Log $log_file "Found the `'DHCP Server`' role is installed on this server."
}

# CSV with three columns, IP,MAC,NAME.
Write-Log $log_file "CSV file exists for import, File Location: $($InputCSV)"
if (-not (Test-Path $InputCSV))
{
	Write-Warning "CSV File not found"
	Write-Log $log_file "CSV File not found."
	Start-Sleep -Seconds 10
	Exit
}
else
{
	Write-Log $log_file "CSV File found."
	$Computers = Import-CSV $InputCSV
	
	ForEach ($Computer in $Computers)
	{
		Write-Host "Adding reservation for Computer: $($Computer.NAME), with a MAC address: $($Computer.MAC) to DHCP Server: $DHCPServer" -ForegroundColor Yellow -BackgroundColor Black
		Try
		{
			Write-Log $log_file "Adding reservation for Computer: $($Computer.NAME), with a MAC address: $($Computer.MAC) to DHCP Server: $DHCPServer"
			netsh Dhcp Server $DHCPServer Scope $DHCPScope Add reservedip $($Computer.IP) $($Computer.MAC) $($Computer.NAME) $($Computer.NAME) "BOTH"
			Write-Log $log_file "Succeeded in adding a reservation for Computer: $($Computer.NAME), with a MAC address: $($Computer.MAC) to DHCP Server: $DHCPServer"
		}
		Catch
		{
			Write-Log $log_file "Failed to add reservation for Computer: $($Computer.NAME), with a MAC address: $($Computer.MAC) to DHCP Server: $DHCPServer with error: $(error[0])"
		}
	} 
  }
  }Else{
  #Log sepertator 
  Write-Log $log_file -Delimeter "-" -Count 100
  Write-Log $log_file "No new reservations to be created"
  }
}

#close session to DC02
Remove-PSSession -Session $session

