.SYNOPSIS
    Get the version of SQL Server that is installed on remote computers (typically servers)
.DESCRIPTION
    Get the version of SQL Server that is installed on remote computers (typically servers)
.EXAMPLE
    N/A
.INPUTS
    List of servers in a text file
.OUTPUTS
    CSV File. Sample output:
	"machine","Status","SQLVersion","SQLEdition"
	"server1","Online","Microsoft SQL Server 2019 (RTM-CU18) (KB5017593) - 15.0.4261.1 (X64) Copyright (C) 2019 Microsoft Corporation Standard Edition (64-bit) on Windows Server 2019 Standard 10.0 <X64> (Build 17763: ) (Hypervisor)","Standard Edition (64-bit)"
.NOTES
    N/A