## CIDisk.psm1 - PowerCLI Manipulation of Independent Disks for vCloud-based Clouds
##
## Requires:
##   - PowerCLI 6.x+ (Tested with 6.5 Realease 1 Build 4624819)
##   - vCloud API 5.1+ (Tested with vCloud Director 8.10.1)
##   - PowerCLI session connected to Cloud (Connect-CIServer)
##
## Provides:
##   - Get-CIDisk      - Retrieves information about existing Independent Disks
##   - New-CIDisk      - Allows creation of new Independent Disks
##   - Remove-CIDisk   - Deletes Independent Disks
##   - Mount-CIDisk    - Attaches an Independent Disk to a VM
##   - Dismount-CIDisk - Detaches an Independent Disk from a VM
## 
## Copyright 2017, Jon Waite
##
## Permission is hereby granted, free of charge, to any person obtaining a copy
## of this software and associated documentation files (the "Software"), to deal
## in the Software without restriction, including without limitation the rights
## to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
## copies of the Software, and to permit persons to whom the Software is
## furnished to do so, subject to the following conditions:
##
## The above copyright notice and this permission notice shall be included in
## all copies or substantial portions of the Software.
##
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
## EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
## OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
## IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
## CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
## TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
## OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
##

# Function to test for number:
function Is-Numeric ($Value) {
    return $Value -match "^[\d\.]+$"
}

# Function to turn value in bytes to nice display value (10.0 GB, 100 MB etc.)
Function Nice-Number ([Long]$size) 
{
    if ($size -lt 1024) {                 return [String]$size }
    if ($size -lt (1024 * 1024)) {        return [String]($size/1024) + ' KB' }
    if ($size -lt (1024 * 1024 * 1024)) { return [String]($size/1024/1024) + ' MB' }
    return [String]($size/1024/1024/1024) + ' GB'
}

# Function to build XML for attaching/detaching disks to/from VMs
Function Build-DiskXML(
    [Parameter(Mandatory=$true)][string]$DiskHref
)
{
    $xmlresp  = '<?xml version="1.0" encoding="UTF-8"?>'
    $xmlresp += '<DiskAttachOrDetachParams'
    $xmlresp += '   xmlns="http://www.vmware.com/vcloud/v1.5">'
    $xmlresp += '   <Disk'
    $xmlresp += '      type="application/vnd.vmware.vcloud.disk+xml"'
    $xmlresp += '      href="' + $DiskHref + '" />'
    $xmlresp += '</DiskAttachOrDetachParams>'
    return $xmlresp
} # End Function Build-DiskXML

# Wrapper function for Invoke-RestMethod which handles errors and optionally waits for API
# interactions that generate a task which takes time to complete.
Function vCloud-REST(
    [Parameter(Mandatory=$true)][string]$URI,
    [string]$ContentType,
    [string]$Method = 'Get',
    [string]$ApiVersion = '5.1',
    [string]$Body,
    [boolean]$WaitForTask = $false,
    [int]$Timeout = 40
)
{
    $Headers = @{"x-vcloud-authorization" = ($global:DefaultCIServers.SessionId); "Accept" = 'application/*+xml;version=' + $ApiVersion}
    if (!$ContentType) { Remove-Variable ContentType }
    if (!$Body)        { Remove-Variable Body }
    Try
    {
        [xml]$response = Invoke-RestMethod -Method $Method -Uri $URI -Headers $headers -Body $Body -ContentType $ContentType -TimeoutSec $Timeout
    }
    Catch
    {
        Write-Host "Exception: " $_.Exception.Message
        if ( $_.Exception.ItemName ) { Write-Host "Failed Item: " $_.Exception.ItemName }
        Write-Host "Exiting."
        Return
    }
    if ($WaitForTask) {
        Write-Host "Request submitted, waiting for task to complete..."
        $taskuri = $response.Disk.Tasks.task.href
        if (!$taskuri) {
            $taskuri = $response.Task.href
        }
        if ($taskuri) {
            $status = WaitVC-Task -TaskURI $taskuri -Timeout $Timeout -ApiVersion '5.1'
            if ($status) {
                Write-Host "Task completed successfully."
            } else {
                Write-Host "Task ended abnormally."
            }
        } else {
            write-Host "No task found - completed already?"
        }
    }
    return $response
} # Function vCloud-REST End

# Function to wait for a vCloud Task to complete and return $true (suceeded) or $false (error):
Function WaitVC-Task(
    [Parameter(Mandatory=$true)][String]$TaskURI,
    [Int]$Timeout = 40,
    [String]$ApiVersion = '5.1'
) 
{
    $Headers = @{"x-vcloud-authorization" = ($global:DefaultCIServers.SessionId); "Accept" = 'application/*+xml;version=' + $ApiVersion}
    Do {
        Try
        {
            [xml]$taskstatus = Invoke-RestMethod -Method Get -Uri $TaskURI -Headers $Headers -TimeoutSec $Timeout
        }
        Catch
        {
            Write-Host "Exception: " $_.Exception.Message
            if ( $_.Exception.ItemName ) { Write-Host "Failed Item: " $_.Exception.ItemName }
            Write-Host "Exiting with 'false'"
            Return $false
        }
        if ($taskstatus.Task.status -eq 'success') {
            return $true
        }
        Start-Sleep -Seconds 1    # Pause 1 second between API checks on task status.
        $Timeout -= 1
    } Until ($Timeout -le 0) # Timeout 'Do' loop
    Write-Host "Timeout reached, exiting."
    return $false   
} # End Function WaitVC-Task

## Return a list of Independent Disks in all or specific VDC(s)
function Get-CIDisk(
    [String]$VDCName,
    [String]$DiskHref,
    [String]$DiskName
)
{
<#
.SYNOPSIS
Retrieves Independent Disk information from one or more VDCs.

.DESCRIPTION
Get-CIDisk uses the vCloud REST API to return all Indpendent Disks found in
accessible Virtual Datacenters (VDCs). VDC Name can be provided by pipeline
input.

.PARAMETER VDCName
A specific VDC to search for Independent Disks, if the VDC cannot be located an
error will be returned.

.PARAMETER DiskName
An Independent Disk name to search for, if matched disk details will be returned
for disk(s) with this name only.

.PARAMETER DiskHref
A cloud URI uniquely identifying a specific independent disk. Unlike the
DiskName parameter, specifying the DiskHref guarantees that only a single
matching disk will be returned.

.OUTPUTS
Details of each Indpendent Disk found matching the input criteria.

.NOTES
You must have an existing vCloud session (Connect-CIServer) for this function
to work and must pass the session ID to this function. 
#>
    if (!$VDCName) {
        $vdcs = Get-OrgVdc
    } else {
        $vdcs = Get-OrgVdc -Name $VDCName
    }
    
    if ($vdcs) {
    
        $disks = $vdcs.ExtensionData.ResourceEntities.ResourceEntity | Where { $_.Type -eq 'application/vnd.vmware.vcloud.disk+xml' } | Sort-Object $_.Name
        if ($DiskName) {
            $disks = $disks | Where { $_.Name -eq $DiskName }
        }

        if ($DiskHref) {
            $disks = $disks | Where { $_.Href -eq $DiskHref }
        }

        $numdisks = ($disks | Measure-Object).Count
        $disks = $disks | Sort-Object('Name')
        
        if ($numdisks -gt 0) {
            $diskobjs = @()
            foreach ($disk in $disks) {
                [xml]$diskxml = vCloud-REST -URI $disk.href -Method 'Get'
                [xml]$attached = vCloud-REST -URI ($disk.Href + '/attachedVms') -Method 'Get'
                $diskobj = New-Object -TypeName PSObject
                $diskobj | Add-Member -Type NoteProperty -Name "Name"        -Value ([string]$disk.Name)
                $diskobj | Add-Member -Type NoteProperty -Name "Href"        -Value ([string]$disk.Href)
                $diskobj | Add-Member -Type NoteProperty -Name "Description" -Value ([string]$diskxml.Disk.Description)
                $diskobj | Add-Member -Type NoteProperty -Name "Size"        -Value ([string](Nice-Number($diskxml.Disk.size)))
                $diskobj | Add-Member -Type NoteProperty -Name "BusType"     -Value ([string]$diskxml.Disk.busSubType)
                $diskobj | Add-Member -Type NoteProperty -Name "Storage"     -Value ([string]$diskxml.Disk.StorageProfile.name)
                if ($attached.Vms.VmReference.name) {
                    $diskobj | Add-Member -Type NoteProperty -Name "AttachedTo"  -Value ([string]$attached.Vms.VmReference.name)
                } else {
                    $diskobj | Add-Member -Type NoteProperty -Name "AttachedTo"  -Value ([string]'Not Attached')
                }
                $diskobjs += $diskobj
            } # Foreach disk
        } # Numdsisks > 0
        return $diskobjs
    } else {
        Write-Host "No matching VDC found."
    }
} # End of Function

## Create a new Independent Disk
function New-CIDisk(
    [Parameter(Mandatory=$true)][string]$DiskName,
    [Parameter(Mandatory=$true)][string]$DiskSize,
    $VDCName,
    [string]$StorageProfileHref,
    [string]$DiskDescription,
    [string]$BusSubType = 'lsilogicsas',
    [string]$BusType = '6',
    [boolean]$WaitforTask = $true
)
<#
.SYNOPSIS
Creates Independent Disk based on input parameters.

.DESCRIPTION
New-CIDisk uses the vCloud REST API to create an Indpendent Disk object and
returns an object containing the specifications of the newly created disk.

.PARAMETER DiskName
The name to assign to the new disk object.

.PARAMETER DiskSize
The size (in bytes) for the new disk object, the suffixes 'K', 'M' and 'G'
are recognised to allow for easy calculation of larger disk sizes (e.g. 10G).

.PARAMETER VDCName
Optional - The name of the virtual Datacenter (VDC) to create the disk in (if
multiple VDCs are accessible to the current session it is suggested to specify
this).

.PARAMETER StorageProfileHref
Optional - The cloud URI of the storage profile in which to create this disk
if multiple storage profiles are available. By default the VDC's default
storage profile will be used.

.PARAMETER Disk Description
Optional - A text description of the disk being created.

.PARAMETER BusSubType
Optional - The vSphere Bus Sub Type for this disk, defaults to 'lsilogicsas'
which should be the most universally compatible type. Note that 'lsilogic'
results in a 'LSI Logic Parallel' disk which has no drivers available for
several guest Operating Systems including Windows Server 2012/2012R2.

.PARAMETER BusType
Optional - The vSphere Bus Type for the disk - safest to leave at the default
value of '6'.

.PARAMETER WaitforTask
Optional - A boolean value indicating whether New-CIDisk should wait until the
disk has been fully created before returning (default = $true).

.OUTPUTS
A disk object for the newly created disk in a format compatible with the
Get-CIDisk cmdlet.

.NOTES
You must have an existing vCloud session (Connect-CIServer) for this function
to work. 
#>
{
    if (!$VDCName) {
        $vdc = Get-OrgVdc
    } else {
        $vdc = Get-OrgVdc -Name $VDCName
    }
    [string]$VDCHref = $vdc[0].Href
    $VDCHref += '/disk'

    # Build XML String to add a disk:
    if (Is-Numeric $DiskSize) {
        [long]$DiskBytes = $DiskSize
    } else {
        $SizeMult = $DiskSize.Substring($DiskSize.Length - 1, 1)
        $BaseSize = [double]($DiskSize.Substring(0, $DiskSize.Length -1))
        switch ($SizeMult) {
            K { [long]$DiskBytes = ($BaseSize * 1024) }
            M { [long]$DiskBytes = ($BaseSize * 1024 * 1024) }
            G { [long]$DiskBytes = ($BaseSize * 1024 * 1024 * 1024) }
            default { $DiskBytes = $BaseSize }
        }
    }
    $diskxml  = '<?xml version="1.0" encoding="UTF-8"?>'
    $diskxml += '<DiskCreateParams xmlns="http://www.vmware.com/vcloud/v1.5"><Disk'
    $diskxml += ' name="' + $DiskName + '"'
    $diskxml += ' busSubType="' + $BusSubType + '"'
    $diskxml += ' busType="' + $BusType + '"'
    $diskxml += ' size="' + $DiskBytes + '">'
    if ($DiskDescription) { $diskxml += '<Description>' + $DiskDescription + '</Description>' }
    if ($StorageProfileHref) { $diskxml += '<StorageProfile href="' + $StorageProfileHref + '"/>' }
    $diskxml += '</Disk></DiskCreateParams>'
    
    $headers = @{"x-vcloud-authorization" = ($global:DefaultCIServers.SessionId); "Accept" = 'application/*+xml;version=5.1'}

    [xml]$response = vCloud-REST -Method 'Post' -Body $diskxml -URI $VDCHref -ContentType 'application/vnd.vmware.vcloud.diskCreateParams+xml' -WaitForTask $WaitforTask
    $newdisk = Get-CIDisk -DiskHref $response.Disk.Href
    return $newdisk
}

## Remove/Delete an Independent Disk
function Remove-CIDisk(
    [Parameter(Mandatory=$true)][string]$DiskHref
)
<#
.SYNOPSIS
Removes and permanently deletes an Independent Disk based on input parameters.

.DESCRIPTION
Remove-CIDisk uses the vCloud REST API to delete an Indpendent Disk object.

.PARAMETER DiskHref
The cloud URI of the disk to be removed/deleted. Note that if the disk is
currently attached to a VM this will be detected and the disk cannot be
deleted until it is detached from any VM (Dismount-CIDisk).

.OUTPUTS
Success / failure messages on host console.

.NOTES
You must have an existing vCloud session (Connect-CIServer) for this function
to work. 
#>
{
    # CAUTION! - Minimal error checking, this will permanently delete the disk passed by reference!!!
    [xml]$attached = vCloud-REST -URI ($DiskHref + '/attachedVms') -Method 'Get'
    if ($attached.Vms.VmReference.name) {
        Write-Host ("Cannot remove this disk as it is attached to VM '"+($attached.Vms.VmReference.name)+"' and must be detached first.")
        return
    }
    [xml]$response = vCloud-REST -Method 'Delete' -URI $DiskHref -WaitForTask $true
} # End of Remove-CIDisk Function

## Attach an Independent Disk to a VM
function Mount-CIDisk(
    [Parameter(Mandatory=$true)][string]$VMHref,
    [Parameter(Mandatory=$true)][string]$DiskHref
)
<#
.SYNOPSIS
Attaches an independent disk to a specific VM based on input parameters.

.DESCRIPTION
Mount-CIDisk uses the vCloud REST API to mount a specific Indpendent Disk to
a virtual machine.

.PARAMETER DiskHref
The cloud URI of the disk to be mounted.

.PARAMETER VMHref
The cloud URI of the virtual machine on which the disk is to be mounted.

.OUTPUTS
Success / failure messages on host console.

.NOTES
You must have an existing vCloud session (Connect-CIServer) for this function
to work. 
#>
{
    $VMHref += '/disk/action/attach'
    $xml = Build-DiskXML -DiskHref $DiskHref
    [xml]$response = vCloud-REST -Method 'Post' -Body $xml -URI $VMHref -ContentType 'application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml' -WaitForTask $true
}

## Detach an Independent Disk from a VM
function Dismount-CIDisk(
    [Parameter(Mandatory=$true)][string]$VMHref,
    [Parameter(Mandatory=$true)][string]$DiskHref
)
<#
.SYNOPSIS
Detaches an independent disk from a specific VM based on input parameters.

.DESCRIPTION
Dismount-CIDisk uses the vCloud REST API to dismount a specific Indpendent Disk
from a virtual machine.

.PARAMETER DiskHref
The cloud URI of the disk to be dismounted.

.PARAMETER VMHref
The cloud URI of the virtual machine from which the disk is to be dismounted.

.OUTPUTS
Success / failure messages on host console.

.NOTES
You must have an existing vCloud session (Connect-CIServer) for this function
to work. 
#>
{
    $VMHref += '/disk/action/detach'
    $xml = Build-DiskXML -DiskHref $DiskHref
    [xml]$response = vCloud-REST -Method 'Post' -Body $xml -URI $VMHref -ContentType 'application/vnd.vmware.vcloud.diskAttachOrDetachParams+xml' -WaitForTask $true
}

## Export Functions for Module:
Export-ModuleMember -Function 'Get-CIDisk'
Export-ModuleMember -Function 'New-CIDisk'
Export-ModuleMember -Function 'Remove-CIDisk'
Export-ModuleMember -Function 'Mount-CIDisk'
Export-ModuleMember -Function 'Dismount-CIDisk'
