<#
.SYNOPSIS  
	Configures a Security Role in VMware vSphere for XenDesktop/XenApp
.DESCRIPTION  
	Configures a Security Role in VMware vSphere for XenDesktop/XenApp and assign it to an (AD) user or group
.NOTES  
	File Name  : CreateVMwareRoleXenDesktop.ps1
	Author     : John Billekens
	Requires   : Powershell
	             Permissions on vCenter to create role and assign a user / group
	             .\CreateVMwareRoleXenDesktop.ps1
.LINK
	http://blog.j81.nl
.PARAMETER vCenterServer
	Specify the vCenter Server FQDN
 
	C:\ PS> .\CreateVMwareRoleXenDesktop.ps1 -vCenterServer "vCenter01.domain.local"
					 
.PARAMETER XenDesktopRoleName
	Specify name of the new role in vCenter
 
	C:\ PS> .\CreateVMwareRoleXenDesktop.ps1 -XenDesktopRoleName "Citrix Role"
.PARAMETER AssignXDServiceAccountOrGroupOrGroup
							   
	Assign a Service Account (must be specified seperately) to the newly created Role.
	C:\ PS> .\CreateVMwareRoleXenDesktop.ps1 -AssignXDServiceAccountOrGroupOrGroup
.PARAMETER XDServiceAccountOrGroup
																		 
						   
	Specify the ServiceAccount "DOMAIN\ServiceAccount"
    If this account must me assigned to the newly created group, specify the -AssignXDServiceAccountOrGroupOrGroup option
 
	C:\ PS> .\CreateVMwareRoleXenDesktop.ps1 -XDServiceAccountOrGroup "DOMAIN\ServiceAccount" -AssignXDServiceAccountOrGroupOrGroup
.EXAMPLE
	Create a Role with privileges and assign "DOMAIN\ServiceAccount" to that newly created role
	C:\ PS> .\CreateVMwareRoleXenDesktop.ps1 -vCenterServer "vCenter01.domain.local" -XDServiceAccountOrGroup "DOMAIN\ServiceAccount" -AssignXDServiceAccountOrGroupOrGroup
.EXAMPLE
	Use the aliasses to assign "DOMAIN\ADGroup" to the newly created Role
	C:\ PS> .\CreateVMwareRoleXenDesktop.ps1 -vCenterServer "vCenter01.domain.local" -Group "DOMAIN\ADGroup" -Assign
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory=$false)][string]$vCenterServer = "localhost",
	[Alias("Account","Group")][Parameter(Mandatory=$false)][string]$XDServiceAccountOrGroupOrGroup = $null,
	[Alias("Assign")][Parameter(Mandatory=$false)][switch]$AssignXDServiceAccountOrGroupOrGroup,
	[Alias("Role","Name")][Parameter(Mandatory=$false)][string]$XenDesktopRoleName = "Citrix Services"
)

# Script

if ($XDServiceAccountOrGroupOrGroup -eq $null) {
    $AssignXDServiceAccountOrGroupOrGroup = $false
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

if ($AssignXDServiceAccountOrGroupOrGroup) {
    Write-Host -NoNewline "Assigning permissions to `"$XDServiceAccountOrGroupOrGroup`"... "
    try {
	    $oRootFolder = Get-Folder -NoRecursion
    	$oPermission = New-VIPermission -Entity $oRootFolder -Principal "$XDServiceAccountOrGroupOrGroup" -Role "$XenDesktopRoleName" -Propagate:$true
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
