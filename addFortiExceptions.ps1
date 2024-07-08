# Run as administrator, followed by "add" or "remove" e.g. .\addFortiExceptions add
# Modify the $machines to point to a list of machines. You must generate that list yourself.
# You need to populate the $admins array.
# Example to add exceptions:
# .\addFortiExceptions add

#Example to remove exceptions:
# .\addFortiExceptions remove

param(
    [string]$action
)

#$machines = get-content -Path "$PSScriptRoot\servers.txt"
$machines = get-content -Path "$PSScriptRoot\servers.txt"

if($action -eq "add"){
    foreach($machine in $machines){
        write-host "Processing $machine..." -ForegroundColor Yellow
        invoke-command -ComputerName $machine -scriptblock{
			
			# Comma separated list of users or groups e.g. @("domain\user1","domain\user2")
            $admins = @()    
			
            $currentExceptions = @(Get-ItemProperty -Path "HKLM:\SOFTWARE\Fortinet\FAC_Agent_v1.0\Plugins\27c65014-b660-4141-b9c4-9d35cfe99ae5" | select -expandproperty EU_UserList)
            write-host "Current exceptions: $currentExceptions" -ForegroundColor Cyan
            $newExceptions = $currentExceptions + $admins
            write-host "$machine New exceptions: $newExceptions" -ForegroundColor Green
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Fortinet\FAC_Agent_v1.0\Plugins\27c65014-b660-4141-b9c4-9d35cfe99ae5" -Name "EU_UserList" -Value $newExceptions -Type "Multistring"
        }
    }

}

if($action -eq "remove"){

    foreach($machine in $machines){
    
        write-host "Processing $machine..." -ForegroundColor Yellow
        invoke-command -ComputerName $machine -scriptblock{
			# Comma separated list of users or groups e.g. @("domain\user1","domain\user2")
            $admins = @()    
			
            $currentExceptions = @(Get-ItemProperty -Path "HKLM:\SOFTWARE\Fortinet\FAC_Agent_v1.0\Plugins\27c65014-b660-4141-b9c4-9d35cfe99ae5" | select -expandproperty EU_UserList)
            write-host "Current exceptions: $currentExceptions" -ForegroundColor Cyan
            $newExceptions = @()
            foreach($dude in $currentExceptions){
                if(-not($admins -contains $dude)){
                    $newExceptions+=$dude
                }
            }
            write-host "New exceptions: $newExceptions" -ForegroundColor Green
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Fortinet\FAC_Agent_v1.0\Plugins\27c65014-b660-4141-b9c4-9d35cfe99ae5" -Name "EU_UserList" -Value $newExceptions -Type "Multistring"
        }
    }
}
