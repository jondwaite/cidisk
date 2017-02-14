# CIDisk #
PowerShell module to manage independent disks in vCloud Director

This module provides 5 functions to allow manipulation of Independent Disks in a VMware vCloud Director environment. The minimum supported release of vCloud Director for these functions is v5.1, all later releases should work (tested mainly against a v8.10.1 deployment).

The exported cmdlet functions are:

Function|Description
Get-CIDisk|Returns details of any Independent Disk objects in accessible VDCs
New-CIDisk|Creates a new Independent Disk object
Remove-CIDisk|Removes/Permanently deletes and Independent Disk object
Mount-CIDisk|Attaches an Independent Disk to a Virtual Machine
Dismount-CIDisk|Detaches an Independent Disk from a Virtual Machine

Note that error checking is reasonably basic, so attempting to attach the same disk simulateously to two different VMs (for example) will likely generate an API error.

Parameters for each cmdlet are detailed below.

## Get-CIDisk ##

Required Parameters: None
