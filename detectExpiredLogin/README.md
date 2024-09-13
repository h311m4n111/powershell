# SYNOPSIS

Using this script, you can create a scheduled task that triggers whenever event 4776 is logged in the security log. 
The script will parse the event's message and look for a specific status to alert.

# DESCRIPTION
The goal of this script is simple: detect logon attempts with expired accounts. Expired accounts can typically be used as honeypots because they appear valid since they are not disabled.
		
This script is intended to run on your domain controller(s) as a scheduled task triggered on the occurence of event 4776. Each time this event is detected, this script will be fired. Using some basic regex, we then filter the event's message to determine whether 
it concerns an expired account. The specific status that let's us know this is 0xc0000193.

You can place this script in your SYSVOL to make it accessible to all domain controlers. This makes it easy to then deploy a GPO to your domain controlers so they all have the scheduled task deployed.
	
For example, a scheduled task for event 4776 is configurer like this:
1. Triggers : 
   - On an event
   - Log : security
   - Source : Microsoft Windows security auditing
   - Event ID : 4776
2. Actions : 
   - Start a program
   - Program / script : powershell
   - Add arguments (optional) : -Exec Bypass -nop -Command C:\Windows\SYSVOL\domain\scripts\detectExpiredLogin\detectExpiredLogin.ps1 4776
			
** /!\ Please adjust your e-mail settings at the bottom of the script. **

The alert will tell you the name of the expired account, the source workstation that made the request, the date and time and finally the domain controler that logged the event. This should make it pretty easy to take action rapidly.
	
# EXAMPLE
N/A
# INPUTS
N/A
# OUTPUTS
NA