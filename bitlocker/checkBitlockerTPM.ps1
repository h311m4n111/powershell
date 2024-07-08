# The goal of this script is to check if a domain computer has TPM enabled and if Bitlocker is activated with the TPM and RecoveryPassword key protectors. Ideally you'll want to store the recovery key in Active Directory. 
# If TPM is enabled but bitlocker is not, it will add the computer to the AD group "S_C_TPM_Enabled", clear the PC's kerberos ticket and force a gpupdate
# Assumptions:
# 	1. You have created a security group like S_C_TPM_Enabled for computers of your domain that have not bitlocker enabled
#	2. You have a GPO that applies only to this group. This GPO creates a scheduled task on the comput

# Pass computer name through the CLI
param(
    [string]$PC
)

#Get the TPM status
$tpm = invoke-command -computername $PC -ScriptBlock{Get-TPM | Select TPMPresent,TPMReady,TPMEnabled,TPMActivated}

write-host "Checking TPM pre-requisites..."

if(($TPM.TpmActivated -eq $true) -and ($TPM.TpmEnabled -eq $true) -and ($TPM.TpmPresent -eq $true) -and ($tpm.TpmReady -eq $true)){

    write-host -ForegroundColor Green "All TPM parameters are set to true :-)"
    write-host "Verifying if the disk is encrypted..."
    write-host "Verifying if $PC is an S_C_TPM_Enabled group member..."

    # Get members of the AD group to check if the computer is in there or not
    $GroupMembers = Get-ADGroupMember -identity "S_C_TPM_Enabled" | select -expandproperty name

    # If the computer is not a member, add it
    if(-not($GroupMembers -contains $PC)){
        write-host -ForegroundColor Red "$PC is not an S_C_TPM_Enabled group member!"
        write-host "Adding $PC to S_C_TPM_Enabled..."
        Add-ADGroupMember -Identity "S_C_TPM_Enabled" -Members "$PC`$"
        $GroupMembers = Get-ADGroupMember -identity "S_C_TPM_Enabled" | select -expandproperty name
        if(-not($GroupMembers -contains $PC)){
            write-host -ForegroundColor Red "/!\ There was a problem adding $PC to S_C_TPM_Enabled!"
            Exit 1
        }
        else{
            write-host -ForegroundColor Green "$PC is now a member of S_C_TPM_Enabled!"
        }
    }

    # If the computer is already a member of the group
    else{
        write-host -ForegroundColor Green "$PC is already an S_C_TPM_Enabled group member."
		
        # Get the status of Bitlocker
        $bitlocker = invoke-command -ComputerName $PC -ScriptBlock{get-bitlockervolume | select-object VolumeStatus,keyprotector}

        if(-not($bitlocker.VolumeStatus -like "FullyEncrypted")){
            write-host -ForegroundColor Red "/!\ The volume on $PC is not encrypted!"
        }
        if($bitlocker.VolumeStatus -like "EncryptionInProgress"){
            write-host -ForegroundColor Yellow "Encryption on $PC is already in progress. Quitting Script."
            Exit 0
        }
        if($bitlocker.VolumeStatus -like "FullyEncrypted"){
            write-host -ForegroundColor Green "Bitlocker is already enabled and the volume in encrypted. Checking key protectors..."
			
			# If bitlocker was enabled without keyprotectors, it means we have no way of accessing the key. The volume should be decrypted and re-encrypted.
            if($bitlocker.keyprotector -eq $null){
                write-host -ForegroundColor Red "/!\ No key protectors are enabled! Please use the disable-bitlocker powershell command on $PC to decrypt the drive and re-run this script."
                Exit 0
            }
            else{
                $kp = $bitlocker.keyprotector
                write-host -ForegroundColor Green "The following Key Protectors are enabled on $PC : $kp. Nothing to do."
                Exit 0
            }
        }
		
		# If bitlocker is enabled but the drive is seen as not encrypted and the computer has been added to the security group above, we need to purge the krb ticket and force a gpupdate. Type "y" or "n" at the prompt
        write-host -ForegroundColor Yellow "$PC is in the correct group, but the drive is not encrypted. Do you want to purge the kerberos ticket now and force a gpupdate?"
        $hold = 1
        $choice = ''

        while($hold -eq 1){
            $choice = read-host "Type y or n"
            if(($choice -eq "y") -or ($choice -eq "n")){
                $hold = 0
                Switch($choice){          
                    "y"{
                        write-host "Purging kerberos ticket for $PC..."
                        & psexec -s \\$PC klist.exe -li 0x3e7 purge
                        write-host "Wait 5 seconds..."
                        start-sleep 5
                        write-host "Forcing gpupdate"
                        invoke-command -ComputerName $PC -ScriptBlock{gpupdate /force}
                        write-host -ForegroundColor Yellow "Bitlocker should now be encrypting the drive with TPM and RecoveryPassword as KeyProtectors. Use get-bitlockervolume on the remote machine to check."
                        exit 0
                   }
                    "n"{
                        write-host -ForegroundColor Yellow "OK. Please either purge the ticket and force a gpupdate manually or reboot the remote computer!"
                    }
                }
            }    
            else{
                write-host "Invalid choide. Type y or n!!"
            }
        }
    }
}

else{
    write-host -ForegroundColor Red "TPM settings do not meet requirements for $PC : $tpm"
}