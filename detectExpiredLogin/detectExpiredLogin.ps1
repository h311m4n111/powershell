<#

.SYNOPSIS
    Detect when an expired account is used to log on to detect potential fraudulent activity
.DESCRIPTION
	This script looks for the event 4776 with the specific status 0xc0000193 which indicates that the account that is used has expired.
	You can use disabled accounts as honeypots to detect unusal behaviour.
.PREREQUISTS
	- An expired account
#>

param(
	[int32]$eventid
)

$Report = "$PSScriptRoot\mail.html"

# Remonter le DC source ou l'évennement à été loggé
$srchost = $env:COMPUTERNAME

$events = get-eventlog -LogName Security -InstanceID $eventid -Newest 1

# The code that has to appear in the event's message
$code_regex = '(0xc0000193)'

# The logon account is specified after the string 'Logon Account: '
$account_regex = 'Logon Account:\s+(\S+)'

# The host name that made the request is after the string 'Source Workstation: '
$srchst_regex = 'Source Workstation:\s+(\S+)'

# Get the event's generated time
$timeobj = $event | select TimeGenerated
$time = $timeobj.TimeGenerated

foreach($event in $events){

	#Put the content of the message of the event in a variable
	$msg = $event.message
	
	#If the code 0xc0000193 is found
	if($msg -match $code_regex){
		
		#Check if the account that has been used is the one we target
		if($msg -match $account_regex){
			
			$account = $matches[1]
			
			$var = $msg -match $srchst_regex
			$hostname = $matches[1]
			
		# Get the event's generated time
		$timeobj = $event | select TimeGenerated
		$time = $timeobj.TimeGenerated
			
@"
<html>
    <head>
        <meta http-equiv='Content-Type' content='text/html; charset=utf-8'>
        <STYLE TYPE='text/css'>
            <!--
            td {font-family: Arial; font-size: 12px; border: 0px; padding-top: 5px; padding-right: 5px; padding-bottom: 5px; padding-left: 5px;} 
            body { margin-left: 5px; margin-top: 5px; margin-right: 5px; margin-bottom: 5px; table {border: thin solid #000000;}
            --> 
        </style> 
    </head>
        <body>
        <p>Hello,</p>
        <p>Someone has attempted to use an expired account to connect. The expired account is <b><u>$account</u></b></p>
		 <p> The connection was made from <b><u>$hostname</u></b> at $time. The DC that logged the event was $srchost.</p>
    </body>
</html>
"@ | out-file -FilePath $report -Force

#Envoyer le mail avec le résultat
            $subject = "/!\ warn: an expired account was used in a logon attempt."
            $EmailFrom = "domain@mydomain.com" 
            $Smtpserver = "smtp.mydomain.com"
            $File1 = Get-Content "$PSScriptRoot\mail.html"

            $message = New-Object System.Net.Mail.MailMessage 
            $message.from = $EmailFrom
            $message.to.add("myadmins@mydomain.com")
            $message.Subject = $subject
            $message.IsBodyHTML = $true
            $message.Body = $File1
            $smtp = New-Object Net.Mail.SmtpClient($smtpServer)
            $smtp.Send($message)
		}
	}
}
