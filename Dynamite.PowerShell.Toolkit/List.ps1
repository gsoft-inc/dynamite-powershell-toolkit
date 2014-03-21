﻿#
# Module 'Dynamite.PowerShell.Toolkit'
# Generated by: GSoft, Team Dynamite.
# Generated on: 10/24/2013
# > GSoft & Dynamite : http://www.gsoft.com
# > Dynamite Github : https://github.com/GSoft-SharePoint/Dynamite-PowerShell-Toolkit
# > Documentation : https://github.com/GSoft-SharePoint/Dynamite-PowerShell-Toolkit/wiki
#

<#
	.SYNOPSIS
		Commandlet to add a file to a SharePoint library

	.DESCRIPTION
		Add a new file to a SharePoint library

    --------------------------------------------------------------------------------------
    Module 'Dynamite.PowerShell.Toolkit'
    by: GSoft, Team Dynamite.
    > GSoft & Dynamite : http://www.gsoft.com
    > Dynamite Github : https://github.com/GSoft-SharePoint/Dynamite-PowerShell-Toolkit
    > Documentation : https://github.com/GSoft-SharePoint/Dynamite-PowerShell-Toolkit/wiki
    --------------------------------------------------------------------------------------
   
	.PARAMETER  WebUrl
		Url of the SPweb that contains the library.
		
	.PARAMETER  DocLibName
		The library name.

	.PARAMETER  FilePath
		Physical file path to upload.

	.PARAMETER  Force
		If true, overwrite existing file. Otherwise, prompt for a confirmation.
		
		
	.EXAMPLE
		PS C:\> Add-DSPFile "http://mysite/sites/mysubsite" "Images" "C:\Photo.jpeg" $true

	.OUTPUTS
		The server relative url of the new added file.  
    
  .LINK
    GSoft, Team Dynamite on Github
    > https://github.com/GSoft-SharePoint
    
    Dynamite PowerShell Toolkit on Github
    > https://github.com/GSoft-SharePoint/Dynamite-PowerShell-Toolkit
    
    Documentation
    > https://github.com/GSoft-SharePoint/Dynamite-PowerShell-Toolkit/wiki
    
#>
function Add-DSPFile          
{            
    [CmdletBinding()]            
    Param(            
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]            
    [string]$WebUrl,            
    [Parameter(Mandatory=$true)]            
    [string]$DocLibName,            
    [Parameter(Mandatory=$true)]            
    [string]$FilePath,  
    [Parameter(Mandatory=$false)]            
    [string]$Force           
    )                 
                       
    $spWeb = Get-SPWeb -Identity $WebUrl             
    $spWeb.AllowUnsafeUpdates = $true;            
    $List = $spWeb.Lists[$DocLibName]            
    $folder = $List.RootFolder            
    $FileName = $FilePath.Substring($FilePath.LastIndexOf("\")+1)             
    $File= Get-ChildItem $FilePath            
    [Microsoft.SharePoint.SPFile]$spFile = $spWeb.GetFile($folder.Url + "/" + $File.Name)            
    $flagConfirm = 'y'            
    if($spFile.Exists -eq $true -and $Force -ne $true)            
    {            
        $flagConfirm = Read-Host "File $FileName already exists in library $DocLibName, do you  want to upload a new version(y/n)?"             
    }            
                
    if ($flagConfirm -eq 'y' -or $flagConfirm -eq 'Y')            
    {            
        $fileStream = ([System.IO.FileInfo] (Get-Item $File.FullName)).OpenRead()            
        #Add file            
        write-host -NoNewLine -f yellow "Copying file " $File.Name " to " $folder.ServerRelativeUrl "..."            
        [Microsoft.SharePoint.SPFile]$spFile = $folder.Files.Add($folder.Url + "/" + $File.Name, [System.IO.Stream]$fileStream, $true)            
        write-host -f Green "...Success!"            
        #Close file stream            
        $fileStream.Close()            
        write-host -NoNewLine -f yellow "Update file properties " $spFile.Name "..."            
        $spFile.Item["Title"] = "Document Metrics Report"            
        $spFile.Item.Update()            
        write-host -f Green "...Success!"            
    }               
    $spWeb.AllowUnsafeUpdates = $false;            
            
    return  $spFile.Item["ServerUrl"]        
}

#
# Module 'Dynamite.PowerShell.Toolkit'
# Generated by: GSoft, Team Dynamite.
# Generated on: 10/24/2013
# > GSoft & Dynamite : http://www.gsoft.com
# > Dynamite Github : https://github.com/GSoft-SharePoint/Dynamite-PowerShell-Toolkit
# > Documentation : https://github.com/GSoft-SharePoint/Dynamite-PowerShell-Toolkit/wiki
#

<#
	.SYNOPSIS
		Commandlet to set alerts configuration on SharePoint lists

	.DESCRIPTION
		Creates or deletes alerts for SharePoint Lists

    --------------------------------------------------------------------------------------
    Module 'Dynamite.PowerShell.Toolkit'
    by: GSoft, Team Dynamite.
    > GSoft & Dynamite : http://www.gsoft.com
    > Dynamite Github : https://github.com/GSoft-SharePoint/Dynamite-PowerShell-Toolkit
    > Documentation : https://github.com/GSoft-SharePoint/Dynamite-PowerShell-Toolkit/wiki
    --------------------------------------------------------------------------------------
   
    .NOTES
         Here is the Structure XML schema.

        <Configuration>
	        <Web Url="http://mysite">
		        <List Title="List Title">		
			        <!-- AlertType: http://msdn.microsoft.com/en-us/library/microsoft.sharepoint.spalerttype(v=office.15).aspx -->
			             DeliveryChannels: http://msdn.microsoft.com/en-us/library/microsoft.sharepoint.spalertdeliverychannels(v=office.15).aspx
			             EventType: http://msdn.microsoft.com/en-us/library/microsoft.sharepoint.speventtype(v=office.15).aspx 
			             AlertFrequency: http://msdn.microsoft.com/en-us/library/microsoft.sharepoint.spalertfrequency(v=office.15).aspx 

                         Users: Insert here all users separated by a semicolon ';'
                         Groups: Insert here all groups separated by a semicolon ';'. The cmdlet will process all users in this group.

                         CAUTION: Don't user empty "Users" or "Groups" XML atributes. If you don't need it, just delete the attribute in the schema but not leave it empty.
                    -->	
			        <Alert 	Title="My Alert" 
					        Users=""
					        Groups=""
					        AlertType="List"					
					        DeliveryChannels="Email"					
					        EventType="Add"				
					        AlertFrequency="Daily"
			        />
		        </List>
	        </Web>
        </Configuration>


	.PARAMETER  XmlPath (Mandatory)
		Physical path of the XML configuration file.
		
	.PARAMETER  Delete (Optionnal)
		If true, delete existing alerts in the list for users. Otherwise, create new alerts.

	.EXAMPLE
		PS C:\> Set-DSPAlerts "D:\Alerts.xml"
        PS C:\> Set-DSPAlerts "D:\Alerts.xml" -Delete 

	.OUTPUTS
		n/a. 
    
  .LINK
    GSoft, Team Dynamite on Github
    > https://github.com/GSoft-SharePoint
    
    Dynamite PowerShell Toolkit on Github
    > https://github.com/GSoft-SharePoint/Dynamite-PowerShell-Toolkit
    
    Documentation
    > https://github.com/GSoft-SharePoint/Dynamite-PowerShell-Toolkit/wiki
    
#>
function Set-DSPAlerts
{
	[CmdletBinding(DefaultParametersetName="Default")] 
	param
	(
		[Parameter(ParameterSetName="Default", Mandatory=$true, Position=0)]
		[string]$XmlPath,

        [Parameter(ParameterSetName="Default",Mandatory=$false, Position=1)]
		[switch]$Delete=$false
	)

    $Config = [xml](Get-Content $XmlPath)

    # Process all Webs
	$Config.Configuration.Web | ForEach-Object {
        
        $webUrl = $_.Url
        $web = Get-SPWeb -Identity $webUrl

        #Process all lists
        $_.List | ForEach-Object {
            
            $listTitle = $_.Title

            # Get the list
            $list = $web.Lists.TryGetList($listTitle)

            if ($list -ne $null)
            {
                Add-DSPAlert $list $_.Alert $Delete
            }
            else
            {
                Write-Warning "Unable to find the list with Title $listTitle on $webUrl"
            }
        }

    }
}

function Add-DSPAlert
{
    param
	(
        [Parameter(ParameterSetName="Default", Mandatory=$true, Position=0)]
		[Microsoft.SharePoint.SPList]$List,

        [Parameter(ParameterSetName="Default", Mandatory=$true, Position=1)]
		$Schema,

        [Parameter(ParameterSetName="Default",Mandatory=$false, Position=2)]
		[bool]$Delete=$false 
    )

    if ($Schema -ne $null -and $List -ne $null)
    {
        # Process All Alerts

        $Schema | ForEach-Object {
        
            $listName = $List.Title

            Write-Host "Creating alert for list: $listName" 

            # Get the web
            $web = $List.ParentWeb
            $spUsers= @()

            if ($Schema.Users -ne $null)
            {

                # Get single users
                $userList = $Schema.Users.Split(';');

                $userList | ForEach-Object {

                    # Ensure the user
                    $spUser = $web.EnsureUser($_)

                    if ($spUser -ne $null)
                    {
                        $spUsers += ,$spUser
                    }
                }
            }

            if ($Schema.Groups -ne $null)
            {

                # Get all groups
                $groupList = $Schema.Groups.Split(';');

                $groupList | ForEach-Object {

                    # Get all users in the group
                    $spGroup = $web.Groups[$_]

                    if ($spGroup -ne $null)
                    {
                         $spGroup.Users | ForEach-Object { $spUsers += ,$_ }
                    }
                }
            }

            $spUsers | ForEach-Object {
                
                $alertTitle = $Schema.Title

                $alert = $_.Alerts | Where-Object {$_.Title -eq $alertTitle}
                if ($alert -ne $null)
                {
                    $user = $_
                    Write-Warning "`tAlert with title $alertTitle for user: $_ already exists...Deleting..."

                    $alert | ForEach-Object {

                        $user.Alerts.Delete($_.ID)
                    }
                }

                if ($Delete -eq $false)
                {

                    Write-Host "`tCreating alert for user: $_" 

                    $alert = $_.Alerts.Add()
                    $alert.Title = $Schema.Title
                    $alert.AlertType = [Enum]::Parse([Microsoft.SharePoint.SPAlertType],$Schema.AlertType)
                    $alert.List = $List
                    $alert.DeliveryChannels = [Enum]::Parse([Microsoft.SharePoint.SPAlertDeliveryChannels],$Schema.DeliveryChannels)
                    $alert.EventType = [Enum]::Parse([Microsoft.SharePoint.SPEventType],$Schema.EventType)
                    $alert.AlertFrequency = [Enum]::Parse([Microsoft.SharePoint.SPAlertFrequency],$Schema.AlertFrequency)
                    $alert.Update($false)
                 }
            }    
        }
    }
}