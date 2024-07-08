#####################################################################
# Script Computer inventory
# Version : 1.0
# Scope : this script is targeted at phyical PCs in your environment and will generate a CSV file containing, for each machine:
# 	- OS name
# 	- OS Installation Date
# 	- OS Locale
# 	- OS Language
# 	- Keyboard Layout
# 	- Device Manufacturer (Dell, HP...)
# 	- Device Model
# 	- CPU Model
# 	- CPU Cores
# 	- CPU Threads
# 	- Size of ram
# 	- System Disk
# 	- System Disk bus type (SSD, nVME...)
# 	- System Disk Media type (SSD, HDD...)
# 	- System Disk Size in GB
# 	- System Disk Free Space in Gb
#
# Pre-requisits: 
# 	- Text file computers.txt containing all domain computers you want to be part of your inventory. 
#	- Script must be run as administrator with the appopriate rights to query devices
#	- WinRM must be enabled
#####################################################################

#Le fichier contenant les machines à scanner
$machines = get-content $PSScriptRoot\computers.txt

$computers = @()

foreach($machine in $machines){
	write-host "processing $machine"
    if(test-connection -computername $machine -count 1 -ErrorAction SilentlyContinue){
        write-host "Ping $machine OK" -ForegroundColor green
            
		#Try a simple query to ensure we can query the device
		write-host "Try remote authentication..." -ForegroundColor yellow
		#$test = invoke-command -computername $machine -scriptblock{get-computerinfo | select-object WindowsProductName}

		if(New-PSSession -Computername $machine -ErrorAction SilentlyContinue){

			write-host "Remote authentication succeeded, querying..." -ForegroundColor magenta
			#Get ram information
			$ram = Get-CimInstance -Class CIM_PhysicalMemory -ComputerName $machine -ErrorAction SilentlyContinue | Select-Object banklabel,capacity | measure-object -property capacity -sum

			#Get disk volume information for "C" Drive
			$volume = invoke-command -computername $machine -ScriptBlock{get-volume | where-object -Property driveletter -eq "C" | select sizeremaining,path}
			
			#Find on which physical disk the C: drive is installed by using the volume path			
			$sysdisk = invoke-command -computername $machine -scriptblock{Get-Volume -Path $Using:volume.Path | Get-Partition | Get-Disk | select Size,FriendlyName}
			
			#Get physical disk information for the C: drive by using the friendly name
			$phydisk = invoke-command -computername $machine -scriptblock{get-physicaldisk -FriendlyName $using:sysdisk.FriendlyName | select BusType,MediaType,Size}			
			
			#Get CPU information
			$cpu = Get-CimInstance -ComputerName $machine -Class CIM_Processor -ErrorAction Stop | Select-Object Name,NumberOfCores,ThreadCount

			#Get general device information
			$device = invoke-command -computername $machine -scriptblock{get-computerinfo | select-object WindowsProductName,WindowsInstallDateFromRegistry,CsDNSHostName,OsLocale,OsLanguage,KeyboardLayout,CsManufacturer,CsModel}
    
			#Add an entry in the hashtable for the computer
			$computers += [pscustomobject]@{
				DNSHostName=$device.CsDNSHostName
				Status="Online"
				OsProductName=$device.WindowsProductName
				WindowsInstallDate=$device.WindowsInstallDateFromRegistry
				OSLocale=$device.OsLocale
				OSLanguage=$device.OsLanguage
				KeyboardLayout=$device.KeyboardLayout
				Manufacturer=$device.CsManufacturer
				Model=$device.CsModel
				CPUModel=$cpu.Name
				CPUCores=$cpu.NumberOfCores
				CPUThreads=$cpu.ThreadCount
				RamSizeGB=$ram.sum/1073741824
				DiskFriendlyName=$sysdisk.FriendlyName
				DiskBusType=$phydisk.BusType
				DiskMediaType=$phydisk.MediaType
				DiskSizeGB=([Math]::Round($phydisk.Size/1073741824,2))
				Disk_C_FreeSpaceGB=([Math]::Round($volume.sizeremaining/1073741824,2))
			}
		}	
		else{
			#If the computer is not available (unable to open a PS Session) because for example WinRM service isn't started or configured, set the status to unavailable and all the rest to null
			$computers += [pscustomobject]@{
				DNSHostName=$machine
				Status="Unavailable"
				OsProductName=$null
				WindowsInstallDate=$null
				OSLocale=$null
				OSLanguage=$null
				KeyboardLayout=$null
				Manufacturer=$null
				Model=$null
				CPUModel=$null
				CPUCores=$null
				CPUThreads=$null
				RamSizeGB=$null
				DiskFriendlyName=$null
				DiskBusType=$null
				DiskMediaType=$null
				DiskSizeGB=$null
				Disk_C_FreeSpaceGB=$null
			}
        }
	}
	else{
		#If the computer does not respond to ping, set the status to offline and everything else to null
		$computers += [pscustomobject]@{
			DNSHostName=$machine
			Status="Offline"
			OsProductName=$null
			WindowsInstallDate=$null
			OSLocale=$null
			OSLanguage=$null
			KeyboardLayout=$null
			Manufacturer=$null
			Model=$null
			CPUModel=$null
			CPUCores=$null
			CPUThreads=$null
			RamSizeGB=$null
			DiskFriendlyName=$null
			DiskBusType=$null
			DiskMediaType=$null
			DiskSizeGB=$null
			Disk_C_FreeSpaceGB=$null
		}
	}
}

 # Try and find all headers by looping over all items.
# You could change this to loop up to a maximum number of items if you like.
# The headers will be captured in the order in which they are found. 
$headers = $computers | ForEach-Object {($_.PSObject.Properties).Name} | Select-Object -Unique

# Find the missing headers in the first item of the collection
# and add those with value $null to it.
$headers | Where-Object { ($computers[0].PSObject.Properties).Name -notcontains $_ } | ForEach-Object {
    $computers[0] | Add-Member -MemberType NoteProperty -Name $_ -Value $null
}

# output on console
#$computers

# output to csv file
$computers | Export-Csv -Path '$PSSCriptRoot\workstations.csv' -NoTypeInformation


