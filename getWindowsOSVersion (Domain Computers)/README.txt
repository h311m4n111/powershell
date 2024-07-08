This script will generate a CSV file with the Windows version of all computers in adservers.txt.

Pre-requisits:
- Run script as administrator
- Extract all computers from AD into a text file (adservers.txt). Or use get-adcomputer to do a live query and adapt this script
- WinRM needs to be activated on the remote computers