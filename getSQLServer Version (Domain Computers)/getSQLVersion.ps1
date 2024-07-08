<#
.SYNOPSIS
    Get the version of SQL Server that is installed on remote computers (typically servers)
.DESCRIPTION
    Get the version of SQL Server that is installed on remote computers (typically servers)
.EXAMPLE
    N/A
.INPUTS
    List of servers in a text file
.OUTPUTS
    CSV File. Sample output:
	"machine","Status","SQLVersion","SQLEdition"
	"server1","Online","Microsoft SQL Server 2019 (RTM-CU18) (KB5017593) - 15.0.4261.1 (X64) Copyright (C) 2019 Microsoft Corporation Standard Edition (64-bit) on Windows Server 2019 Standard 10.0 <X64> (Build 17763: ) (Hypervisor)","Standard Edition (64-bit)"
.NOTES
    N/A
#>

$machines = get-content $PSScriptRoot\adservers.txt

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
			$sqlv = invoke-command -computername $machine -scriptblock{invoke-sqlcmd -query "select @@version" -serverinstance "localhost" | select-object column1}
			
			$sqled = invoke-command -computername $machine -scriptblock{invoke-sqlcmd -query "select serverproperty('edition')" -serverinstance "localhost" | select-object column1}
			
			#Add an entry in the hashtable for the computer
			$computers += [pscustomobject]@{
				machine=$machine
				Status="Online"
				SQLVersion=$sqlv.column1
				SQLEdition=$sqled.column1
			}
		}	
		else{
			#If the computer is not available (unable to open a PS Session) because for example WinRM service isn't started or configured, set the status to unavailable and all the rest to null
			$computers += [pscustomobject]@{
				machine=$machine
				Status="Unavailable"
				SQLVersion="NA"
				SQLEdition="NA"
			}
        }
	}
	else{
		#If the computer does not respond to ping, set the status to offline and everything else to null
		$computers += [pscustomobject]@{
			machine=$machine
			Status="Offline"
			SQLVersion="NA"
			SQLEdition="NA"
		}
	}
}

$headers = $computers | ForEach-Object {($_.PSObject.Properties).Name} | Select-Object -Unique

$headers | Where-Object { ($computers[0].PSObject.Properties).Name -notcontains $_ } | ForEach-Object {
    $computers[0] | Add-Member -MemberType NoteProperty -Name $_ -Value $null
}

# output on console
#$computers

# output to csv file
$computers | Export-Csv -Path '$PSScriptRoot\servers_SQL_version.csv' -NoTypeInformation


