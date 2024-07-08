Create a new Security goup and name it using your own standards. In our case, we named it S_C_TPM_Enabled:
- S > Security Group (what kind of group)
- C > Computers (what it applies to)
- TPM_Enabled (what it does)

Next

1. Create a GPO in your domain for your workstations
2. Change the delegation to apply this GPO only to this group: S_C_TPM_Enabled
3. The GPO needs to:
	- Copy the script enableBL.ps1 from sysvol to C:\windows
	- Create a scheduled that that runs the above script once

Then, whenever a computer is added to the S_C_TPM_Enabled group, it will automatically apply the above GPO and enable Bitlocker.