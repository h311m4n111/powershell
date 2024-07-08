<#
.SYNOPSIS
    Detect malicious activity on critical domain groups
.DESCRIPTION
    The goal of this script is simple: detect additions of users to Tier 0 groups e.g. administration groups that if compromised would equate to a check-mate. Every time a user is added to a group, events for this are generated in the eventlog, specifically events:
		- 4728 for global security groups
		- 4732 for local security groups
		- 4756 for universal security groups
		
	This script is intended to run on your domain controller(s) as a scheduled task triggered on the occurence of any of the above events. Each time event 4728, 4732 or 4756 is detected, this script will be fired. Using some basic regex, we then filter the event's message to
	determine whether the targeted group is part of the Tier 0 list. If it is, an e-mail alert is immediatly sent out. When this script is in production, the delay between group addition and alert is roughly 5-10 seconds. There is one scheduled task per event. 
	
	For example, a scheduled task for event 4728 is configurer like this:
		o Triggers : 
			- On an event
			- Log : security
			- Source : Microsoft Windows security auditing
			- Event ID : 4728
		o Actions : 
			- Start a program
			- Program / script : powershell
			- Add arguments (optional) : -Exec Bypass -nop -Command C:\scripts\Monitoring\detectEvent\detectEvent.ps1 4728
			
	Each detected event is added to a text file "pastevents.txt" as to not alert on the same event multiple times.
	
	/!\ Please adjust the Tier0groups array to reflect your windows language. In its infinite wisdom, Microsoft, for some reason, does not name some of the groups the same way in every language.

	/!\ Please adjust your e-mail settings at the bottom of the script.
	
.EXAMPLE
    N/A
.INPUTS
    List of servers in a text file
.OUTPUTS
    E-mail sample (HTML format):
	
	<html>
    <head>
        <meta http-equiv='Content-Type' content='text/html; charset=iso-8859-1'>
        <title>Tier 0 detection</title>
        <STYLE TYPE='text/css'>
            <!--
            td {font-family: Arial; font-size: 12px; border: 0px; padding-top: 5px; padding-right: 5px; padding-bottom: 5px; padding-left: 5px;} 
            body { margin-left: 5px; margin-top: 5px; margin-right: 5px; margin-bottom: 5px; table {border: thin solid #000000;}
            --> 
        </style> 
    </head>
        <body>
        <p>Hello,</p>
        <p>A user has been added to a Tier 0 group (e.g. domain / entreprise / schema admins). Ensure that this modification was intentional!</p>
        <p>Source DC: <strong>DC1</strong> 
		<p>Date     : <strong>06/26/2024 16:55:36</strong></p> 
        <p>Account   : <strong>CN=Doe John,OU=X,OU=Y,OU=Users,OU=company,DC=company,DC=local</strong></p>
        <p>Group   : <strong>Domain admins</strong></p>
    </body>
</html>
	
.NOTES
    N/A
#>

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

# Array that contains all tier 0 group. 

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
        <title>Tier 0 detection</title>
        <STYLE TYPE='text/css'>
            <!--
            td {font-family: Arial; font-size: 12px; border: 0px; padding-top: 5px; padding-right: 5px; padding-bottom: 5px; padding-left: 5px;} 
            body { margin-left: 5px; margin-top: 5px; margin-right: 5px; margin-bottom: 5px; table {border: thin solid #000000;}
            --> 
        </style> 
    </head>
        <body>
        <p>Hello, </p>
        <p>A user has been added to a Tier 0 group (e.g. domain / entreprise / schema admins). Ensure that this modification was intentional!</p>
        <p>Source DC: <strong>$srchost</strong> 
		<p>Date     : <strong>$time</strong></p> 
        <p>Account   : <strong>$account</strong></p>
        <p>Group   : <strong>$grp</strong></p>
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
