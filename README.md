# CIDisk #
PowerShell module to manage independent disks in vCloud Director

This module provides 5 functions to allow manipulation of Independent Disks in a VMware vCloud Director environment. The minimum supported release of vCloud Director for these functions is v5.1, all later releases should work (tested mainly against a v8.10.1 deployment).

The exported cmdlet functions are:

Function | Description
-------- | -----------
Get-CIDisk | Returns details of any Independent Disk objects in accessible VDCs
New-CIDisk | Creates a new Independent Disk object
Remove-CIDisk | Removes/Permanently deletes and Independent Disk object
Mount-CIDisk | Attaches an Independent Disk to a Virtual Machine
Dismount-CIDisk | Detaches an Independent Disk from a Virtual Machine

Note that error checking is reasonably basic, so attempting to attach the same disk simulateously to two different VMs (for example) will likely generate an API error.

Parameters for each cmdlet are detailed below.

## Get-CIDisk ##

Returns details of any Independent Disk objects in accessible VDCs.

Parameter | Type | Required? | Default | Description
--------- | ---- | --------- | --------| -----------
VDCName | String | False | - | The name of the VDC to search for independent disks, if no name is specified and multiple VDCs are available the first accessible VDC will be used.
DiskName | String | False | - | The name of the disk to search for, if multiple disks have common name attributes they will all be returned. Note that the match on DiskName is case-sensitive.
DiskHref | String | False | - | The unique cloud URI for the independent disk, can be used to ensure that the correct specific disk is returned.

Returns:
Null (if no disks found) or an array of disk objects if one or more disks are found sorted by disk name. Returned disk objects have the following members:

Member | Description
------ | -----------
Name | The disk name
Href | The cloud URI for the disk object
Description | Any description entered when the disk was created
Size | The disk size, large sizes are adjusted and use the 'KB', 'MB' and 'GB' suffix
BusType | The vCloud Storage Bus Type for the disk
Storage | The name of the storage profile on which the disk is located
AttachedTo | The name of the virtual machine to which the disk is currently attached, or 'Not Attached' if no current attachment

## New-CIDisk ##

Allows creation of a new Independent Disk object.

Parameters:

Parameter | Type | Required? | Default | Description
--------- | ---- | --------- | --------| -----------
DiskName | String | True | - | The name for this disk
DiskSize | String | True | - | The size of the disk to be created in bytes. The suffix 'K', 'M' or 'G' can be used to easily express larger sizes (e.g. 100G)
VDCName | String | False | - | The name of the VDC in which the disk should be created. If not specified the first accessible VDC will be used
StorageProfileHref | String | False | - | The URI of a VDC storage profile to be used for the creation of the disk. If not specified the default storage profile for the VDC will be used
DiskDescription | String | False | - | A text description of this disk
BusSubType | String | False | lsilogicsas | The vCloud Director storage bus type for this disk
BusType | String | False | 6 | The vCloud Director storage bus type for this disk
WaitforTask | Boolean | False | True | Whether to wait for the creation operation to complete or return immediately while the disk may still be being created




