#####################################################################
# Script OS Inventory
# Version : 1.0
# Scope : generate a Windows OS Version of your domain machines
# Pre-requisits:
# 	- Run script as administrator
# 	- Extract all computers from AD into a text file (adservers.txt). Or use get-adcomputer to do a live query and adapt this script
#	- WinRM needs to be activated on the remote computers
#####################################################################

# You will need to generate a text file with all the devices to scan
$machines = get-content $PSScriptroot\adservers.txt

#Commenter au dessus et décommenter ci-dessous pour debugger avec 1 ou 2 machines
#$machines = get-content c:\temp\scripts\powershell\computers_debug.txt

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

			#Get general device information
			$device = invoke-command -computername $machine -scriptblock{get-computerinfo | select-object WindowsProductName,WindowsInstallDateFromRegistry,CsDNSHostName,OsLocale,OsLanguage}
    
			#Add an entry in the hashtable for the computer
			$computers += [pscustomobject]@{
				DNSHostName=$device.CsDNSHostName
				Status="Online"
				OsProductName=$device.WindowsProductName
				WindowsInstallDate=$device.WindowsInstallDateFromRegistry
				OSLocale=$device.OsLocale
				OSLanguage=$device.OsLanguage
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
$computers | Export-Csv -Path '$PSScriptroot\windows_version.csv' -NoTypeInformation


