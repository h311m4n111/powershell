# This script detects several events that tie into user addition into tier 0 security groups such as BUILTIN\Administators or Domain Admins. 
# As soon as an event is detected that concerns on of the tier 0 group, a warning e-mail is sent out to the specified e-mail address.
# The monitored events are:
#	- 4728
#	- 4732
#	- 4756

# A "Tier 0" group is any group that if owned by an attacker essentially puts you in a check-mate situation.

# The script runs as a scheduled task that executes this script when one of the above events is detected and passes the event ID to the script. 

# Please also change the variables in the e-mail section at the bottom of this script to reflect your environment.

param(
    [int32]$eventid
)

$srchost = $env:COMPUTERNAME
$Report = "$PSScriptroot\report.htm"  # Report file name

#Once an event is detected, its index is added to this text file.
$eventlist = "$PSScriptroot\pastEvents.txt"

# Detect the last event 
$event = get-eventlog -LogName Security -InstanceId $eventid -Newest 1
$timeobj = $event | select TimeGenerated
$time = $timeobj.TimeGenerated
$idxObj = $event | select Index
$eventIdx = $idxObj.Index

# Array that contains all tier 0 group. In its infinite wisdom, Microsoft, for some reason, decided to change the name of the groups depending on your language. This is only the case for certain groups.
# For instance, in english you have "Domain Admins" and in French you have "Admins du domaine". However some groups are named in english regardless.
# In any case, you will have to go through the list below and change the name of the groups according to your own language

$tier0groups = @(
"Admins du domaine",
"Administrateurs du schéma",
"Administrateurs de l'entreprise",
"Enterprise Read-only Domain Controllers",
"Contrôleurs de domaine",
"Éditeurs de certificats",
"Key Admins",
"Propriétaires créateurs de la stratégie de groupe",
"Read-only Domain Controllers",
"Enterprise Key Admins",
"Administrateurs",
"Opérateurs de compte",
"Opérateurs de sauvegarde",
"Opérateurs de serveur",
"Opérateurs d'impression",
"Incoming Forest Trust Builders",
"DnsAdmins",
"Exchange Windows Permissions")


# Pass the content of the message of the event to a variable
$msg = $event.message

$account = ''
$grp = ''
$acc_regex = ''
$grp_regex = ''

# Regex pour extraire le nom du compte ajouté au groupe
# Regex pour extraire le nom du groupe cible
# Next we use a bit of regex to extract account name that was added and group name that was targeted
if(($eventid -eq 4728) -or ($eventid -eq 4732)){
	$acc_regex = 'Account Name:\s+(CN.*)'
    $grp_regex =  'Group Name:\s+(.*)'
}
if($eventid -eq 4756){
	$acc_regex = 'Account Name:\s+(CN.*)'
    $grp_regex = 'Account Name:\s+(Admin.*)'
}

if($msg -match $acc_regex){
    $account = $matches[1].TrimEnd()
}

if($msg -match $grp_regex){
    $grp = $matches[1].TrimEnd()
}

# If the Group name is contained in the tier0groups array, an alert is sent out
if($tier0groups -contains $grp){
@"
<html>
    <head>
        <meta http-equiv='Content-Type' content='text/html; charset=iso-8859-1'>
        <title>SPN Report</title>
        <STYLE TYPE='text/css'>
            <!--
            td {font-family: Arial; font-size: 12px; border: 0px; padding-top: 5px; padding-right: 5px; padding-bottom: 5px; padding-left: 5px;} 
            body { margin-left: 5px; margin-top: 5px; margin-right: 5px; margin-bottom: 5px; table {border: thin solid #000000;}
            --> 
        </style> 
    </head>
        <body>
        <p>Bonjour</p>
        <p>Un ajout d'utilisateur dans un groupe Tier 0 (admins du domaine / entreprise / schema) à été détecté. Assurez-vous que cela soit intentionel!</p>
        <p>DC Source: <strong>$srchost</strong> 
		<p>Date     : <strong>$time</strong></p> 
        <p>Compte   : <strong>$account</strong></p>
        <p>Groupe   : <strong>$grp</strong></p>
    </body>
</html>
"@ | out-file -FilePath $report -Force
    
    $eventExists = select-string -path C:\scripts\Monitoring\detectEvent\pastEvents.txt -Pattern $eventIdx

        if($eventExists -eq $null){

            $eventIdx | out-file -FilePath $eventlist -Append

            $subject = "Ajout d'un utilisateur dans un groupe Tier 0 détecté"
			$subject = "[Warn] - Tier 0 group addition detected!"
            $EmailFrom = "domain@yourdomain.com" 
            $Smtpserver = "smtp.yourdomain.com"
            $File1 = Get-Content "$PSScriptRoot\report.htm"

            $message = New-Object System.Net.Mail.MailMessage 
            $message.from = $EmailFrom
            $message.to.add("email@yourdomain.com")
            $message.Subject = $subject
            $message.IsBodyHTML = $true
            $message.Body = $File1
            $smtp = New-Object Net.Mail.SmtpClient($smtpServer)
            $smtp.Send($message)
        }
}
