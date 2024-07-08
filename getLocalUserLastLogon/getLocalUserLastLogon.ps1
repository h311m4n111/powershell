# Generate a list of servers and put them into servers.txt

$servers = get-content -path $PSScriptRoot\servers.txt
$arr = @()

foreach ($server in $servers){
    $localusers = invoke-command -computername $server -ScriptBlock{get-localUser | select Name,LastLogon}

    foreach($user in $localusers){
        $username = $user.Name
        $userlastlogon = $user.LastLogon
        $result = @{
            server = $server
            username = $username
            LastLogon = $userlastlogon
        }
        $arr += New-Object psobject -Property $result
    }

}

$arr | Export-csv -path $PSScriptRoot\result.csv -NoTypeInformation