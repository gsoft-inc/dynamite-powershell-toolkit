#
# Module 'Dynamite.PowerShell.Toolkit'
# Generated by: GSoft, Team Dynamite.
# Generated on: 10/24/2013
# > GSoft & Dynamite : http://www.gsoft.com
# > Dynamite Github : https://github.com/GSoft-SharePoint/Dynamite-PowerShell-Toolkit
# > Documentation : https://github.com/GSoft-SharePoint/Dynamite-PowerShell-Toolkit/wiki
#

<#
	.Synopsis
		Use Get-DSPGroup to retrieve a SharePoint Group.
	.Description
		This function uses the SiteGroups collection property of an SPWeb object to return a specific group and its properties.
	.Example
		C:\PS>Get-DSPGroup -Web http://intranet -Group "Members"
		This example retrieves the properties of the "Members" group in the http://intranet site.
	.Notes
    Function taken from :
		Name: Get-SPGroup
		Author: Ryan Dennis
		Last Edit: July 18th 2011
		Keywords: Get-SPGroup
	.Link
		http://www.sharepointryan.com
	 	http://twitter.com/SharePointRyan
	.Inputs
		None
	.Outputs
		SPGroup(s)
	#Requires -Version 2.0
#>
function Get-DSPGroup {
	[CmdletBinding()]
	Param
	(
		[Parameter(Mandatory=$true)]
		[Microsoft.SharePoint.PowerShell.SPWebPipeBind]$Web,
		
		[string]$Group
	)
	
	$spWeb = $Web.Read()
	if (($Group -eq $null) -or ($Group.Length -eq 0))
	{
		$spGroup = $spWeb.SiteGroups
	}
	else
	{
		$spGroup = $spWeb.SiteGroups[$Group]
	}
	
	$spWeb.Dispose()
	return $spGroup
}

function Get-DSPGroupName {
	[CmdletBinding()]
	Param
	(
		[Parameter(Mandatory=$true)]
		[Microsoft.SharePoint.PowerShell.SPWebPipeBind]$Web,
		
		[string]$Group
	)

	return Get-DSPGroup -Web $Web -Group $Group | Select-Object Name
}

<#
	.Synopsis
		Use Remove-DSPGroup to delete a SharePoint Group.
	.Description
		This function uses the Remove() method of a SharePoint RoleAssignments property in an SPWeb to create a SharePoint Group.
	.Example
		C:\PS>Remove-DSPGroup -Web http://intranet -Group "Test Group"
		This example removes a group called "Test Group" in the http://intranet site.
	.Example
		C:\PS>$web = Get-SPWeb http://intranet
		C:\PS>$group = Get-DSPGroup -Web $web -Group "Test Group"
		C:\PS>Remove-DSPGroup $web $group
		This example also removes a group called "Test Group" from the http://intranet site, but this example uses $web and $group variables.
	.Notes
    Function taken from :
		Name: Remove-SPGroup
		Author: Ryan Dennis
		Last Edit: July 18th 2011
		Keywords: Remove-SPGroup
	.Link
		http://www.sharepointryan.com
	 	http://twitter.com/SharePointRyan
	.Inputs
		None
	.Outputs
		None
	#Requires -Version 2.0
#>
function Remove-DSPGroup {
	[CmdletBinding()]
	Param
  (
		[Microsoft.SharePoint.PowerShell.SPWebPipeBind]$Web,
		[string]$Group
	)
	$SPWeb = $Web.Read()

	# Prompting code
	$title = "Delete SharePoint Group $Group"
	$message = "Do you want to delete the SharePoint Group?"
	$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Deletes the SharePoint Group $Group."
	$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Cancels and keeps the SharePoint Group $Group."
	$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
	$result = $Host.UI.PromptForChoice($title, $message, $options, 0)
	
	switch ($result)
	{
		0 {"Deleting $($Group) Group."}
		1 {"Operation cancelled..."}
	}
	
	# End Prompting code
	if ($result -eq 0)
	{
		$SPWeb.SiteGroups.Remove($Group)
		$SPWeb.Dispose()
	}
	else 
	{
		return
	}
}

<#
	.Synopsis
		Use New-GSPGroup to create a SharePoint Group.
	.Description
		This function uses the Add() method of a SharePoint RoleAssignments property in an SPWeb to create a SharePoint Group.
	.Example
		C:\PS>New-GSPGroup -Web http://intranet -GroupName "Test Group" -OwnerName DOMAIN\User -MemberName DOMAIN\User2 -Description "My Group"
		This example creates a group called "Test Group" in the http://intranet site, with a description of "My Group".  The owner is DOMAIN\User and the first member of the group is DOMAIN\User2.
	.Notes
		Name: New-SPGroup
		Author: Ryan Dennis
		Last Edit: July 18th 2011
		Keywords: New-SPGroup
	.Link
		http://www.sharepointryan.com
	 	http://twitter.com/SharePointRyan
	.Inputs
		None
	.Outputs
		None
	#Requires -Version 2.0
#>
function New-DSPGroup {
	[CmdletBinding()]
	Param
  (
		[Parameter(Mandatory=$true)]
		[Microsoft.SharePoint.PowerShell.SPWebPipeBind]$Web,

		[Parameter(Mandatory=$true)]
		[string]$GroupName,
		
		[Parameter(Mandatory=$true)]
		[string]$OwnerName,

		[string]$MemberName,
		
		[string]$Description
	)
	
	$spWeb = $Web.Read()
	
	# Validate Group does not already exist.
	if ($spWeb.SiteGroups[$GroupName] -ne $null)
	{
		throw "Group $GroupName already exists!"	
	}
	
	# Check if specified owner is a sharepoint group.
	$owner = $spWeb.SiteGroups[$OwnerName]
	if($owner -eq $null)
	{
		$owner = Get-DSPUserFromLogin -Web $spWeb -UserLogin $OwnerName
		
		# Set member to owner if owner is not a sharepoint group and no member was specified.
		if(-not $MemberName)
		{
			$member = $owner
		}
	}
	
	if ($MemberName)
	{
		$member = Get-DSPUserFromLogin -Web $spWeb -UserLogin $MemberName
	}
	
	$spWeb.SiteGroups.Add($GroupName, $owner, $member, $Description)
	$spGroup = $spWeb.SiteGroups[$GroupName]
	$spWeb.RoleAssignments.Add($spGroup)
	$spWeb.Dispose()
	
	return $spGroup
}

function Set-DSPWebPermissionInheritance 
{
	[CmdletBinding()]
	Param
  (
		[Parameter(Mandatory=$true)]
		[Microsoft.SharePoint.PowerShell.SPWebPipeBind]$Web,
		[switch]$Break
	)
	
	if ($Break)
	{	
		$spWeb = $Web.Read()
		$spWeb.BreakRoleInheritance($true)
		Write-Verbose ([string]::Concat("Role Inheritance was broken for ", $spWeb.Url))
		$spWeb.Dispose()
	}
}

function Add-DSPUserToGroup
{
	[CmdletBinding()]
	Param 
  (
		[Parameter(Mandatory=$true)]
		[Microsoft.SharePoint.PowerShell.SPWebPipeBind]$Web,
		
		[Parameter(Mandatory=$true)]
		[string]$GroupName,
		
		[Parameter(Mandatory=$true)]
		[string]$User
	)
  
	$spWeb = $Web.Read()
	
	$group = Get-DSPGroup -Web $Web -Group $GroupName
	$userPrincipal = $spWeb.Site.RootWeb.EnsureUser($User)
	
	$group.AddUser($userPrincipal)
	
	Write-Verbose "The user $User was added to the group $Group"
	
	$spWeb.Dispose()
}

function Set-DSPPermission
{
	[CmdletBinding()]
	Param
  (
		[Parameter(Mandatory=$true)]
		[Microsoft.SharePoint.PowerShell.SPWebPipeBind]$Web,

		[Parameter(Mandatory=$true)]
		[string]$PermissionLevel,
		
		[Parameter(Mandatory=$true)]
		[string]$GroupName
	)
	
	$spWeb = $Web.Read()
	
	$group = Get-DSPGroup -Web $Web -Group $GroupName

	# Create a new assignment (group and permission level pair) which will be added to the web object
	$groupAssignment = new-object Microsoft.SharePoint.SPRoleAssignment($group)

	# Get the permission levels to apply to the new groups
	$roleDefinition = $spWeb.Site.RootWeb.RoleDefinitions[$PermissionLevel]

	if ($roleDefinition -ne $null)
	{
		# Assign the groups the appropriate permission level
		$groupAssignment.RoleDefinitionBindings.Add($roleDefinition)

		# Add the groups with the permission level to the site
		$spWeb.RoleAssignments.Add($groupAssignment)	
		
		Write-Verbose "The permission level $PermissionLevel was set to the group $GroupName"
	}
	else
	{
	  Write-Error ([string]::Concat("The permission level $PermissionLevel was not found in the root ", $spWeb.Site.RootWeb.Title))
		Write-Warning "Here is the list of the available permission levels :"
		(Get-GSPPermissionLevel -Web $Web -NameOnly) | foreach { Write-Warning ([string]::Concat(" ", $_.Name)) }
	}
	
	$spWeb.Update()
	$spWeb.Dispose()
}

# Not used
function Get-DSPPermissionLevel
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true)]
		[Microsoft.SharePoint.PowerShell.SPWebPipeBind]$Web,
		
		[switch]$NameOnly
	)
	
	$spWeb = $Web.Read()
	$permissionLevel = $spWeb.Site.RootWeb.RoleDefinitions
	$spWeb.Dispose()
	
	if ($NameOnly)
	{
		return $permissionLevel | Select-Object Name
	}
	else
	{
		return $permissionLevel 
	}
}

function Get-DSPUserFromLogin
{
	Param(
		[Parameter(Mandatory=$true)]
		[Microsoft.SharePoint.PowerShell.SPWebPipeBind]$Web,
		
		[Parameter(Mandatory=$true)]
		[string]$UserLogin
	)
	
  # Add the Claims Token
	if ($Web.Site.WebApplication.UseClaimsAuthentication)
	{
		$claimProviderManager = [Microsoft.SharePoint.Administration.Claims.SPClaimProviderManager]::Local
		$principal = New-SPClaimsPrincipal $UserLogin -IdentityType WindowsSamAccountName
		$UserLogin = $claimProviderManager.EncodeClaim($principal)
	}
	
	return Get-SPUser $UserLogin -Web $Web	
}