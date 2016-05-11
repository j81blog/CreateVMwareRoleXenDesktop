<#
.SYNOPSIS  
	Configures a Security Role in VMware vSphere for XenDesktop
.DESCRIPTION  
	Configures a Security Role in VMware vSphere for XenDesktop
.NOTES  
	File Name  : CreateVMwareRoleXenDesktop.ps1
	Author     : John Billekens - john@j81.nl
	Requires   : Powershell
	             .\CreateVMwareRoleXenDesktop.ps1
.LINK
	http://blog.j81.nl
.PARAMETER vCenterServer
	Specify the vCenter Server FQDN
	
	.\CtxVdContinuousShutdown.ps1 -vCenterServer "vCenter01.domain.local"
	Default: "localhost"
.PARAMETER XenDesktopRoleName
	Specify name of the new role in vCenter
	
	.\CtxVdContinuousShutdown.ps1 -XenDesktopRoleName "XenDesktop Service"
	Default: "XenDesktop Service"
.PARAMETER AssignServiceAccount
	Assign a Service Account (must be specified seperately) to the newly created Role.
	
	.\CtxVdContinuousShutdown.ps1 -AssignServiceAccount
	Default: $True (Will be set to false if no Service Account is specified)
.PARAMETER XDServiceAccount
	Specify the ServiceAccount "DOMAIN\ServiceAccount"
    If this account must me assigned to the newly created group, specify the -AssignServiceAccount option
	
	.\CtxVdContinuousShutdown.ps1 -XDServiceAccount "DOMAIN\ServiceAccount" -AssignServiceAccount
	Default: -empty-
.EXAMPLE
	.\CreateVMwareRoleXenDesktop.ps1 -vCenterServer "vCenter01.domain.local" -XDServiceAccount "DOMAIN\ServiceAccount" -AssignServiceAccount
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory=$false)][string]$vCenterServer = "localhost",
	[Parameter(Mandatory=$false)][string]$XDServiceAccount = $null,
	[Parameter(Mandatory=$false)][switch]$AssignServiceAccount = $true,
	[Parameter(Mandatory=$false)][string]$XenDesktopRoleName = "XenDesktop Service"
)

# Script

if ($XDServiceAccount -eq $null) {
    $AssignServiceAccount = $false
}

#Add VMware PowerCLI Snapin
Write-Host "Try connecting to vCenter Server `"$vCenterServer`"..."
if (-not (Get-PSSnapin VMware.* -ErrorAction SilentlyContinue)) {
	Add-PSSnapin VMware.*
}
 
#Ignore vCenter certificate error and connect to single vCenter Instance
Set-PowerCLIConfiguration -InvalidCertificateAction "Ignore" -DefaultVIServerMode "single" -Scope User -ErrorAction SilentlyContinue -Confirm:$false | Out-Null

$oConnect = Connect-VIServer -Server $vCenterServer
If ($oConnect.IsConnected) {
    Write-Host -ForegroundColor Green "Connected!"
} else {
    Write-Host -ForegroundColor Red "Error, not connected!"
    Exit(1)
}

Write-Host -NoNewLine "Gathering Privileges... "

$oVIPrivilege = Get-VIPrivilege -ID `
	Datastore.AllocateSpace,`
	Datastore.Browse,`
	Datastore.FileManagement,`
	Global.ManageCustomFields,`
	Global.SetCustomField,`
	Network.Assign,`
	Resource.AssignVMToPool,`
	System.Anonymous,`
	System.Read,`
	System.View,`
	Task.Create,`
	VirtualMachine.Config.AddExistingDisk,`
	VirtualMachine.Config.AddNewDisk,`
	VirtualMachine.Config.AddRemoveDevice,`
	VirtualMachine.Config.AdvancedConfig,`
	VirtualMachine.Config.CPUCount,`
	VirtualMachine.Config.Memory,`
	VirtualMachine.Config.RemoveDisk,`
	VirtualMachine.Config.Resource,`
	VirtualMachine.Config.Settings,`
	VirtualMachine.Interact.PowerOff,`
	VirtualMachine.Interact.PowerOn,`
	VirtualMachine.Interact.Reset,`
	VirtualMachine.Interact.Suspend,`
	VirtualMachine.Inventory.Create,`
	VirtualMachine.Inventory.CreateFromExisting,`
	VirtualMachine.Inventory.Delete,`
	VirtualMachine.Inventory.Register,`
	VirtualMachine.Provisioning.Clone,`
	VirtualMachine.Provisioning.DeployTemplate,`
	VirtualMachine.Provisioning.DiskRandomAccess,`
	VirtualMachine.Provisioning.GetVmFiles,`
	VirtualMachine.Provisioning.MarkAsVM,`
	VirtualMachine.Provisioning.PutVmFiles,`
	VirtualMachine.State.CreateSnapshot,`
	VirtualMachine.State.RemoveSnapshot,`
	VirtualMachine.State.RevertToSnapshot

Write-Host -ForegroundColor Green "Done!"

Write-Host -NoNewline "Creating new Role `"$XenDesktopRoleName`"... "
try {
    $oNewRole = New-VIRole -Name "$XenDesktopRoleName" -Privilege $oVIPrivilege
} catch {
    Write-Host -ForegroundColor Red "Error!"
    Exit(1)
}finally {
    Write-Host -ForegroundColor Green "Done!"
}

if ($AssignServiceAccount) {
    Write-Host -NoNewline "Assigning permissions to `"$XDServiceAccount`"... "
    try {
	    $oRootFolder = Get-Folder -NoRecursion
    	$oPermission = New-VIPermission -Entity $oRootFolder -Principal "$XDServiceAccount" -Role "XenDesktop Service" -Propagate:$true
    } catch {
        Write-Host -ForegroundColor Red "Error!"
        Exit(1)
    }finally {
        Write-Host -ForegroundColor Green "Finished!"
    }

	$oRootFolder = $null
	$oPermission = $null
}
" "
$oVIPrivilege = $null
Write-Host -ForegroundColor Green "Finished!"
