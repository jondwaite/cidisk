# CIDisk.psm1 #
CIDIsk.psm1 is a PowerShell module to manage the lifecycle of independent disks in vCloud Director.

This module provides 5 functions to allow manipulation of Independent Disks in a VMware vCloud Director environment. The minimum supported release of vCloud Director for these functions is v5.1, all later releases should work (tested mainly against a v8.10.1 deployment).

The exported functions are:

Function | Description
-------- | -----------
Get-CIDisk | Returns details of any Independent Disk objects in accessible VDCs
New-CIDisk | Creates a new Independent Disk object
Remove-CIDisk | Removes/Permanently deletes and Independent Disk object
Mount-CIDisk | Attaches an Independent Disk to a Virtual Machine
Dismount-CIDisk | Detaches an Independent Disk from a Virtual Machine

## Installation ##

To make these functions available, save the CIDisk.psm1 file somewhere convenient and use PowerShell's Import-Module command:

e.g. `Import-Module "C:\PowerShellModules\CIDisk.psm1"`

## Usage ##

The module relies on an existing PowerCLI connection to a vCloud infrastructure (`Connect-CIServer`) to function, it will not function without a current session. It will also stop working if a cloud session expires (timeout).

If you are connected to multiple vCloud sessions it will only operate against the first vCloud session it finds so it's best/safest to only be connected to a single vCloud session to avoid confusion.

## Notes ##

Note that error checking is reasonably (very) basic, so attempting to attach the same disk simulateously to two different VMs (for example) will likely generate an API error.

This module works well for me, but (as always) please test carefully before using/relying on it in any sort of production scenario.

Note that independent disks are **NOT** included in VM snapshots, so any backups taken using snapshots will **NOT** include the contents of these disks.

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
BusSubType | String | False | lsilogicsas | The vCloud Director storage bus subtype for this disk
BusType | String | False | 6 | The vCloud Director storage bus type for this disk
WaitforTask | Boolean | False | True | Whether to wait for the creation operation to complete or return immediately while the disk may still be being created

Returns:
Null if disk creation fails, or a disk object in Get-CIDisk format (see above) for the newly created disk if successful.

## Remove-CIDisk ##

Permanently deletes the specified Independent Disk object. Note that no confirmation is prompted for or required so use with care. If the disk is currently attached to a VM it cannot be deleted and this will generate an error (use Dismount-CIDisk first - see below)

Parameters:

Parameter | Type | Required? | Default | Description
--------- | ---- | --------- | --------| -----------
DiskHref | String | True | - | The cloud URI of the disk object to be removed. Since disk names are not guaranteed to be unique this is the only way to guarantee a specific disk. The href parameter of the Get-CIDisk cmdlet (see above) can be used to find this URI

Returns:
Nothing, an error message will be written to console if the remove fails.

## Mount-CIDisk ##

Attaches the specified Independent Disk to a Virtual Machine. The Get-CIVM cmdlet (VMware PowerCLI) can be used to find the Href of the VM object. The Get-CIDisk cmdlet (see above) can be used to find the Href of the Independent Disk object. The cmdlet will block (halt script execution) until the operation has either completed or failed with an error.

Parameters:

Parameter | Type | Required? | Default | Description
--------- | ---- | --------- | --------| -----------
VMHref | String | True | - | The cloud URI of the VM to which the disk is to be attached
DiskHref | String | True | - | The cloud URI of the Independent Disk object which is being attached to the VM

Returns:
Nothing, an error message will be written to console if the operation fails.

## Dismount-CIDisk ##

Detaches the specified Independent Disk from a Virtual Machine. The Get-CIVM cmdlet (VMware PowerCLI) can be used to find the Href of the VM object. The Get-CIDisk cmdlet (see above) can be used to find the Href of the Independent Disk object. The cmdlet will block (halt script execution) until the operation has either completed or failed with an error.

Parameters:

Parameter | Type | Required? | Default | Description
--------- | ---- | --------- | --------| -----------
VMHref | String | True | - | The cloud URI of the VM to which the disk is to be detached
DiskHref | String | True | - | The cloud URI of the Independent Disk object which is being attached to the VM

Returns:
Nothing, an error message will be written to console if the operation fails.

## Examples ##

Below are some usage examples, these flow on from each other and show the lifecycle of creating, viewing, attaching, detaching, and deleting some Independent disks from a VM.

### Example 1 ###

Create 2 new independent disks of size 5G on the default VDC with default VDC storage profile named 'disk01' and 'disk02':

```
New-CIDisk -DiskName 'disk01' -DiskSize 5G -DiskDescription 'Disk 01'

Request submitted, waiting for task to complete...
Task completed successfully.

Name        : disk01
Href        : https://my.cloud.com/api/disk/8af07fc1-b6ab-40ae-aa46-fbcdac05f193
Description : Disk 01
Size        : 5 GB
BusType     : lsilogicsas
Storage     : Bronze Storage Profile
AttachedTo  : Not Attached

New-CIDisk -DiskName 'disk02' -DiskSize 5G -DiskDescription 'Disk 02'

Request submitted, waiting for task to complete...
Task completed successfully.

Name        : disk02
Href        : https://my.cloud.com/api/disk/3c274b3e-eb78-4fa2-8983-70f41858466b
Description : Disk 02
Size        : 5 GB
BusType     : lsilogicsas
Storage     : Bronze Storage Profile
AttachedTo  : Not Attached
```

### Example 2 ###

View details of currently defined independent disk objects:

```
Get-CIDisk

Name        : disk01
Href        : https://my.cloud.com/api/disk/8af07fc1-b6ab-40ae-aa46-fbcdac05f193
Description : Disk 01
Size        : 5 GB
BusType     : lsilogicsas
Storage     : Bronze Storage Profile
AttachedTo  : Not Attached

Name        : disk02
Href        : https://my.cloud.com/api/disk/3c274b3e-eb78-4fa2-8983-70f41858466b
Description : Disk 02
Size        : 5 GB
BusType     : lsilogicsas
Storage     : Bronze Storage Profile
AttachedTo  : Not Attached
```

View independent disk details as formatted table:

```
Get-CIDisk | ft -Autosize
Name   Href                                                               Description Size BusType     Storage                AttachedTo
----   ----                                                               ----------- ---- -------     -------                ----------
disk01 https://my.cloud.com/api/disk/8af07fc1-b6ab-40ae-aa46-fbcdac05f193 Disk 01     5 GB lsilogicsas Bronze Storage Profile Not Attached
disk02 https://my.cloud.com/api/disk/3c274b3e-eb78-4fa2-8983-70f41858466b Disk 02     5 GB lsilogicsas Bronze Storage Profile Not Attached
```

### Example 3 ###

Get references to both disks and to a VM named 'vm01' in the vApp 'testvApp':

```
$vm01 = Get-CIVM -Name 'vm01' -vApp 'testvApp'
$vm01.href
https://my.cloud.com/api/vApp/vm-18595e04-8625-43c5-b4f4-d9d5e1094345

$disk01 = Get-CIDisk -DiskName 'disk01'
$disk01.href
https://my.cloud.com/api/disk/8af07fc1-b6ab-40ae-aa46-fbcdac05f193
$disk02 = Get-CIDisk -DiskName 'disk02'
$disk02.href
https://my.cloud.com/api/disk/3c274b3e-eb78-4fa2-8983-70f41858466b`
```

### Example 4 ###

Attach both disks to the vm01 VM using Mount-CIDisk:

```
Mount-CIDisk -VMHref $vm01.href -DiskHref $disk01.Href
Request submitted, waiting for task to complete...
Task completed successfully.

Mount-CIDisk -VMHref $vm01.href -DiskHref $disk02.Href
Request submitted, waiting for task to complete...
Task completed successfully.
```

### Example 5 ###

View details of independent disks showing the attachment to vm01:

```
Get-CIDisk | ft -AutoSize
Name   Href                                                               Description Size BusType     Storage                AttachedTo
----   ----                                                               ----------- ---- -------     -------                ----------
disk01 https://my.cloud.com/api/disk/8af07fc1-b6ab-40ae-aa46-fbcdac05f193 Disk 01     5 GB lsilogicsas Bronze Storage Profile vm01
disk02 https://my.cloud.com/api/disk/3c274b3e-eb78-4fa2-8983-70f41858466b Disk 02     5 GB lsilogicsas Bronze Storage Profile vm01
```

### Example 6 ###

Detach both disks from vm01:

```
Dismount-CIDisk -VMHref $vm01.href -DiskHref $disk01.Href
Request submitted, waiting for task to complete...
Task completed successfully.

Dismount-CIDisk -VMHref $vm01.href -DiskHref $disk02.Href
Request submitted, waiting for task to complete...
Task completed successfully.
```

### Example 7 ###

Check the disk details in Get-CIDisk again to confirm the detachment from vm01:

```
Get-CIDisk | ft -AutoSize
Name   Href                                                               Description Size BusType     Storage                AttachedTo
----   ----                                                               ----------- ---- -------     -------                ----------
disk01 https://my.cloud.com/api/disk/8af07fc1-b6ab-40ae-aa46-fbcdac05f193 Disk 01     5 GB lsilogicsas Bronze Storage Profile Not Attached
disk02 https://my.cloud.com/api/disk/3c274b3e-eb78-4fa2-8983-70f41858466b Disk 02     5 GB lsilogicsas Bronze Storage Profile Not Attached
```

### Example 8 ###

Remove and permanently delete the independent disks:

```
Remove-CIDisk -DiskHref $disk01.Href
Request submitted, waiting for task to complete...
Task completed successfully.

Remove-CIDisk -DiskHref $disk02.Href
Request submitted, waiting for task to complete...
Task completed successfully.
```
