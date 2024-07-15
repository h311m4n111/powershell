<#

.SYNOPSIS
    Detect potential malicious network scanning on your network
.DESCRIPTION
	The idea behind this script is to use a honeypot fake SSH server on random windows machines in your subnet. For this purpose you can use something like sshesame
	which simulated an SSH server. Since there is no SSH on a windows machine, if someone is scanning your subnets for this specific ports and hits a windows machine
	it might indicate someone with malicious intent.
	
	The e-mail alert arrives within a couple second.
.PREREQUISTS
	- "Fake" SSH server for windows
	- A firewall rule on your windows server/machine that accepts SSH trafic on port 22
	- Enable firewall audit logs to generate 5156 events
	- A scheduled task that runs when an event is detected. You can use the content of the $FilterXml variable below to trigger the script
	- Replace bogus values in the variables below with your own
#>


$FilterXml = @"
<QueryList>
	<Query Id="0" Path="Security">
		<Select Path="Security">
			*[
				System[
					EventID=5156
				]
				and
				EventData[
					(
						  (Data[@Name='DestPort']='22')
					)
				]
			]
		</Select>
	</Query>
</QueryList>
"@

Get-WinEvent -FilterXml $FilterXml -MaxEvents 10 -ErrorAction Stop | %{
	$ret = $_ | Select SourceAddress
	([xml]$_.Toxml()).Event.EventData.Data | ?{ $_.Name -eq 'SourceAddress'} | ForEach-Object {
		$ret."$($_.Name)" = $_.'#text'
	}
}

#If you have legitimate scanning trafic like a vulnerability scanner, ignore the events. Put the hosts that do the network scanning in this array
$ignore = @('10.20.30.40')

#return $ret.SourceAddress
$srcip = $ret.SourceAddress

$emailParams = @{
	From    = 'domain@yourdomain.com'
	To     = 'mynetworkadmin@yourdomain.com'
	Subject  = '[warn] Unusual network scan detected (SSH honeypot)'
	Body    = "Hello,<br/>
				Windows firewall on $($env:COMPUTERNAME) has detected a possible abnormal network scan.<br/>
				Windows firewall has blocked a request on port 22 (SSH) where a honeypot is running.<br/>
				The source IP that made the connection was $srcip .
				SSH service does not exist on Windows...! Please investigate."
	SmtpServer = 'yourexchange.yourdomain.com'
	Port    = 25
	BodyAsHtml = $true
	UseSsl   = $false
}

# If the IP address is in the ignore variable, don't notify.
if(-not($ignore -contains $srcip)){
	Send-MailMessage @emailParams -Encoding UTF8
}