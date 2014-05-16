function global:Deploy-DSPSolution() {
	[CmdletBinding(DefaultParameterSetName="FileOrDirectory")]
	param (
		[Parameter(Mandatory=$true, Position=0, ParameterSetName="Xml")]
		[ValidateNotNullOrEmpty()]
		[xml]$Config,

		[Parameter(Mandatory=$true, Position=0, ParameterSetName="FileOrDirectory")]
		[ValidateNotNullOrEmpty()]
		[string]$Identity,

		[Parameter(Mandatory=$false, Position=1, ParameterSetName="FileOrDirectory")]
		[switch]$UpgradeExisting,

		[Parameter(Mandatory=$false, Position=2, ParameterSetName="FileOrDirectory")]
		[switch]$AllWebApplications,

		[Parameter(Mandatory=$false, Position=3, ParameterSetName="FileOrDirectory")]
		[Microsoft.SharePoint.PowerShell.SPWebApplicationPipeBind[]]$WebApplication,
		
		[Parameter(Mandatory=$false, Position=4, ParameterSetName="FileOrDirectory")]
		[switch]$Force=$false
	)
	
	function script:Get-QueueSolutionDefinition {
		Param (
			[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
			[ValidateScript({$_.Name.ToLower().EndsWith(".wsp")})]
			[System.IO.FileInfo]$WSPFile,
			
			[switch]$UpgradeExisting = $false,
			
			[Microsoft.SharePoint.PowerShell.SPWebApplicationPipeBind[]]$WebApplications,
			
			[switch]$Force = $false
		)
		
		Write-Output @{
			WSPFile = $WSPFile
			UpgradeExisting = $UpgradeExisting
			WebApplications = $WebApplications
			Force = $Force
		}
	}
	
	function script:Parse-XmlConfiguration {
		Param(
			[xml]$Config
		)
		$solutionQueue = @()
		$Config.Solutions.Solution | foreach {
			if (![string]::IsNullOrEmpty($_.UpgradeExisting)) {
				$upgrade = [bool]::Parse($_.UpgradeExisting)
			} else {
				$upgrade = $false
			}
			
			if (![string]::IsNullOrEmpty($_.Force)) {
				$force = [bool]::Parse($_.Force)
			} else {
				$force = $false
			}
			
			$WSPFile = Get-Item $_.Path -ErrorAction SilentlyContinue
			if($WSPFile -ne $null) {
				$solutionQueue += Get-QueueSolutionDefinition -WSPFile $WSPFile -UpgradeExisting:$upgrade -WebApplications $_.WebApplications.WebApplication -Force:$force
			} else {
				Write-Host "Unable to find file '$($_.Path)'." -ForegroundColor Red
			}
		}
		
		Write-Output $solutionQueue
	}
	
	function script:Block-SPDeployment {
		Param (
			[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
			[Microsoft.SharePoint.PowerShell.SPSolutionPipeBind]$Solution,
			[bool]$Deploying,
			[Parameter(Mandatory=$false)]
			[Microsoft.SharePoint.PowerShell.SPWebApplicationPipeBind[]]$WebApplications
		)
		
		$prevJobStatus = $null
		$prevOppDetails = $null
		$timeAsleep = 0
		
		$spSolution = $Solution.Read()
		
		Write-Host $(if($Deploying){"Deploying"} else {"Retracting"}) " solution with name '$($spSolution.Name)'."

		do {
			Start-Sleep 2
			$timeAsleep += 2
			$spSolution = Get-SPSolution $spSolution
			
			if($spSolution.JobExists -and ($spSolution.JobStatus -ne $prevJobStatus)) {
				$prevJobStatus = $spSolution.JobStatus
				Write-Host "Current Job Status: $prevJobStatus"
			}
			
			if($spSolution.LastOperationDetails -ne "" -and ($spSolution.LastOperationDetails -ne $prevOppDetails)) {
				$prevOppDetails = $spSolution.LastOperationDetails
				
				if($spSolution.LastOperationResult -like "*Failed*") {
					Write-Host "Operation Details: $prevOppDetails" -ForegroundColor Red
				} else {
					Write-Host "Operation Details: $prevOppDetails"
				}
			}
			
			if($spSolution.LastOperationDetails -like "*Use the force*"){
				Write-Host "Attempting to deploy with the force attribute." -ForegroundColor Yellow
				Deploy-WSPSolution -Solution $spSolution -WebApplications $WebApplications -Force:$true
				break
			}
			
			if ($spSolution.LastOperationResult -like "*Failed*") {
				throw "An error occurred during the solution retraction, deployment, or update."
			}
			
			# if the job is finished and either finished deploying or retracting the solution then break
			if (!$spSolution.JobExists -and (($Deploying -and $spSolution.Deployed) -or (!$Deploying -and !$spSolution.Deployed))) {
				Write-Host "Finished " $(if($Deploying){"deploying"} else {"retracting"}) " solution with name '$($spSolution.Name)'."
				break
			} elseif ($timeAsleep -ge 90){
				Write-Host "We have been waiting for $([Math]::Round($($timeAsleep/60), 2)) minutes... Go check the Central admin to see whats happening..." -ForegroundColor Yellow
				sleep 10
				$timeAsleep += 10
			}
		} while ($true)
		sleep 5 
	}
	
	function script:Remove-WSPSolution {
		Param (
			[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
			[Microsoft.SharePoint.PowerShell.SPSolutionPipeBind]$Solution
		)
		$spSolution = $Solution.Read()
		if($spSolution.Deployed) {
			if ($spSolution.ContainsWebApplicationResource) {
				Write-Host "The solution contains web app resources, retracting from all web apps."
				$spSolution | Uninstall-SPSolution -AllWebApplications -Confirm:$false
			} else {
				$spSolution | Uninstall-SPSolution -Confirm:$false
			}
			
			Block-SPDeployment -Solution $spSolution -Deploying $false		
		} else {
			Write-Host "The solution '$($spSolution.Name)' is not currently deployed." -ForegroundColor Yellow
		}		
		
		Write-Host "Removing solution '$($spSolution.name)'..." -NoNewline
		$spSolution | Remove-SPSolution -Confirm:$false
		Write-Host "Removed!" -ForegroundColor Green
	}
	
	function script:Remove-WSPSolutionsInQueue {
		Param (
			[Array]$SolutionQueue
		)
		
		$SolutionQueue | foreach {
			Write-Host "`n$("-" * 50)" -ForegroundColor Green
			Write-Host "Working on removing '$($_.WSPFile.Name)'..." -ForegroundColor Cyan
			Write-Host "$("-" * 50)`n" -ForegroundColor Green
			
			if($_.UpgradeExisting) {
				Write-Host "Skipping the removal of the solution '$($_.WSPFile.Name)' because it will be upgraded instead."
			} else {
				$solution = Get-SPSolution $_.WSPFile.Name -ErrorAction SilentlyContinue
				if ($solution -ne $null) {
					Remove-WSPSolution -Solution $solution
				} else {
					Write-Host "No solution found in SharePoint with name '$($_.WSPFile.Name)'." -ForegroundColor Yellow
				}
			}
		}
	}
	
	function script:Deploy-WSPSolution {
		Param (
			[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
			[Microsoft.SharePoint.PowerShell.SPSolutionPipeBind]$Solution,
			[Microsoft.SharePoint.PowerShell.SPWebApplicationPipeBind[]]$WebApplications,
			[switch]$Force=$false
		)
		
		$spSolution = $Solution.Read()
		
		if (!$spSolution.ContainsWebApplicationResource) {
			Write-Host "Installing '$($spSolution.name)' globally."
			$spSolution | Install-SPSolution -GACDeployment:$($spSolution.ContainsGlobalAssembly) -CASPolicies:$($spSolution.ContainsCasPolicy) -Confirm:$false -Force:$force
			Block-SPDeployment -Solution $spSolution -Deploying $true
		} else {
			if ($WebApplications -eq $null -or $WebApplications.Length -eq 0) {
				Write-Host "Installing '$($spSolution.name)' to all Web Applications."
				$spSolution | Install-SPSolution -GACDeployment:$($spSolution.ContainsGlobalAssembly) -CASPolicies:$($spSolution.ContainsCasPolicy) -AllWebApplications -Confirm:$false -Force:$force
				Block-SPDeployment -Solution $spSolution -Deploying $true
			} else {
				$WebApplications | foreach {
					$webApp = $_.Read()
					Write-Host "Installing '$($spSolution.name)' to $($webApp.Url)"
					$spSolution | Install-SPSolution -GACDeployment:$gac -CASPolicies:$($spSolution.ContainsCasPolicy) -WebApplication $webApp -Confirm:$false -Force:$force
					Block-SPDeployment -Solution $spSolution -Deploying $true -WebApplications $WebApplications
				}
			}
		}

        # Restart OWSTIMER to clear DLL cache
        # Mandatory if you have Feature Receivers
        Restart-SPTimer
	}
	
	function script:Deploy-WSPSolutionsInQueue {
		Param (
			[Array]$SolutionQueue
		)
		
		$SolutionQueue | foreach {
			Write-Host "`n$("-" * 50)" -ForegroundColor Green
			Write-Host "Working on deploying '$($_.WSPFile.Name)'..." -ForegroundColor Cyan
			Write-Host "$("-" * 50)`n" -ForegroundColor Green
			
			$solution = Get-SPSolution $_.WSPFile.Name -ErrorAction SilentlyContinue
			if($solution -eq $null)	{
				$solution = Add-SPSolution $_.WSPFile.FullName
				Deploy-WSPSolution -Solution $solution -WebApplications $_.WebApplications -Force:$_.Force
			} elseif($_.UpgradeExisting) {
				Update-SPSolution -Identity $solution -CASPolicies:$($solution.ContainsCasPolicy) -GACDeployment:$($solution.ContainsGlobalAssembly) -LiteralPath $path -Force:$_.Force
				Block-SPDeployment -Solution $solution -Deploying $true
			} else {
				Write-Host "Please remove the solution '$($solution.name)' before deploying it."
			}
		}
	}
	
	function script:Process-SolutionQueue {
		Param (
			[Array]$SolutionQueue
		)
		
		Remove-WSPSolutionsInQueue -SolutionQueue $SolutionQueue
		Deploy-WSPSolutionsInQueue -SolutionQueue $SolutionQueue
	}
	
	switch ($PsCmdlet.ParameterSetName) { 
		"Xml" {
			# An XML document was provided so iterate through all the defined solutions and call the other parameter set version of the function
			$solutionQueue = Parse-XmlConfiguration -Config $Config
			Process-SolutionQueue -SolutionQueue $solutionQueue
			break
		}
		"FileOrDirectory" {
			$item = Get-Item (Resolve-Path $Identity)
			if ($item -is [System.IO.DirectoryInfo]) {
				# A directory was provided so iterate through all files in the directory and deploy if the file is a WSP (based on the extension)
				$solutionQueue = @()
				
				Get-ChildItem $item | ForEach-Object {
					if ($_.Name.ToLower().EndsWith(".wsp")) {
						$solutionQueue += Get-QueueSolutionDefinition -WSPFile $_ -UpgradeExisting:$UpgradeExisting -WebApplication:$WebApplication -Force:$Force
						Process-SolutionQueue -SolutionQueue $solutionQueue
					}
				}
			} elseif ($item -is [System.IO.FileInfo]) {
				# A specific file was provided so assume that the file is a WSP if it does not have an XML extension.
				[string]$name = $item.Name

				if ($name.ToLower().EndsWith(".xml")) {
					# Deploy the Solutions defined in XML file.
					$solutionQueue = Parse-XmlConfiguration -Config ([xml](Get-Content $item.FullName))
					Process-SolutionQueue -SolutionQueue $solutionQueue
				} else {
					$solutionQueue = @()
					$solutionQueue += Get-QueueSolutionDefinition -WSPFile $item -UpgradeExisting:$UpgradeExisting -WebApplication:$WebApplication -Force:$Force
					Process-SolutionQueue -SolutionQueue $solutionQueue
				}
			}
			break
		}
	}
  
 	Write-Host "`n$("-" * 50)" -ForegroundColor Green
	Write-Host "Finished deploying SharePoint Solutions Packages!" -ForegroundColor Cyan
	Write-Host "$("-" * 50)`n" -ForegroundColor Green
}