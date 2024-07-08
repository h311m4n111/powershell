# This script will ad the specified local user with the specified password to the local administrators and remote desktop users. The account will expire at the set date.

#List of machines where the account should be added to
$machines = get-content -Path "path_to_file"

foreach($machine in $machines){

    invoke-command -ComputerName $machine -scriptblock{
		#Name of the local user to add
		$localUsr = ""
        $pwd = ConvertTo-SecureString "*Gonet*1845*" -AsPlainText -Force
        $expire = Get-Date -Year 2024 -Month 03 -Day 15
        
        
        New-LocalUser -Name $localUsr -Password $pwd -PasswordNeverExpires -FullName $localUsr -Description "This is a new user" -AccountExpires $expire 
        Add-LocalGroupMember -Group "Administrators" -Member $localUsr
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $localUsr
        
    }
}
