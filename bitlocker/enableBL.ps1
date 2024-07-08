# This script is used by the GPO (view readme). Place it in SYSVOL\scripts and get the GPO to copy it locally to C:\windows

$bl_status = get-bitlockervolume | select ProtectionStatus,VolumeStatus

if(($bl_status.ProtectionStatus -notmatch "On") -and ($bl_status.VolumeStatus -notmatch "FullyEncrypted")){
	enable-bitlocker -mountpoint C: -RecoveryPasswordProtector -SkipHardwareTest
}