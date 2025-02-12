function Clean-GitRepositories {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, HelpMessage = 'The root directory to search for git repositories in.')]
		[Alias('Path')]
		[string] $RootDirectoryPath,

		[Parameter(Mandatory = $false, HelpMessage = 'The max depth from the root directory to search for git repositories in.')]
		[Alias('Depth')]
		[int] $DirectorySearchDepth = 4,

		[Parameter(Mandatory = $false, HelpMessage = 'If provided all git repositories will be cleaned, even if they have untracked files.')]
		[switch] $Force = $false,

		[Parameter(Mandatory = $false, HelpMessage = 'If provided no git repositories will be cleaned; it will just show which repos would be cleaned.')]
		[switch] $WhatIf = $false
	)

	Write-Information "Searching for git repositories in '$RootDirectoryPath'..."
	[string[]] $gitRepositoryDirectoryPaths = Get-GitRepositoryDirectoryPaths -rootDirectory $RootDirectoryPath -depth $DirectorySearchDepth

	Write-Information "Testing git repositories to see which ones can be safely cleaned..."
	$gitRepositoryDirectoryPathsWithUntrackedFiles = [System.Collections.ArrayList]::new()
	$gitRepositoryDirectoryPathsThatAreSafeToClean = [System.Collections.ArrayList]::new()
	ForEach-WithProgress -collection $gitRepositoryDirectoryPaths -scriptBlock {
		param([string] $gitRepoDirectoryPath)

		[bool] $gitRepoHasUntrackedFiles = Test-GitRepositoryHasUntrackedFiles -gitRepositoryDirectoryPath $gitRepoDirectoryPath
		if ($gitRepoHasUntrackedFiles -and -not $Force) {
			$gitRepositoryDirectoryPathsWithUntrackedFiles.Add($gitRepoDirectoryPath) > $null
		} else {
			$gitRepositoryDirectoryPathsThatAreSafeToClean.Add($gitRepoDirectoryPath) > $null
		}
	} -activity "Checking for untracked files" -status "Checking git repo '{0}'"

	Write-Information "Cleaning git repositories..."
	ForEach-WithProgress -collection $gitRepositoryDirectoryPathsThatAreSafeToClean -scriptBlock {
		param([string] $gitRepoDirectoryPath)

		Clean-GitRepository -gitRepositoryDirectoryPath $gitRepoDirectoryPath -WhatIf $WhatIf
	} -activity "Cleaning git repositories" -status "Cleaning git repo '{0}'"

	if ($gitRepositoryDirectoryPathsWithUntrackedFiles.Count -gt 0) {
		Write-Information "The following git repo directories have untracked files, so they were not cleaned: " +
			($gitRepositoryDirectoryPathsWithUntrackedFiles -join [System.Environment]::NewLine)
	}
}

function Get-GitRepositoryDirectoryPaths([string] $rootDirectory, [int] $depth) {
	[string[]] $gitRepoPaths =
	Get-ChildItem -Path $rootDirectory -Include '.git' -Recurse -Depth $depth -Force -Directory |
		ForEach-Object {
			$gitDirectoryPath = $_.FullName
			$gitRepositoryDirectoryPath = Split-Path -Path $gitDirectoryPath -Parent
			return $gitRepositoryDirectoryPath
		}
	return $gitRepoPaths
}

function Test-GitRepositoryHasUntrackedFiles([string] $gitRepositoryDirectoryPath) {
	Set-Location -Path $gitRepositoryDirectoryPath
	$gitOutput = Invoke-Expression "git -C ""$gitRepositoryDirectoryPath"" status" | Out-String

	[bool] $gitRepoHasUntrackedFiles = $gitOutput.Contains('Untracked files')
	return $gitRepoHasUntrackedFiles
}

function Clean-GitRepository([string] $gitRepositoryDirectoryPath, [bool] $whatIf) {
	Write-Verbose "Cleaning git repository at '$gitRepositoryDirectoryPath' using 'git clean -xfd'."
	Set-Location -Path $gitRepositoryDirectoryPath

	if ($whatIf) {
		Write-Host "What If is enabled, so not cleaning git repository at '$gitRepositoryDirectoryPath'."
	} else {
		Invoke-Expression "git -C ""$gitRepositoryDirectoryPath"" clean -xdf" > $null
	}
}

# Adding all the code inline to support Write-Progress made things feel very messy.
# This function helps clean that up, but does add some complexity to the script, especially because
# you cannot assign a variable in the script block a new value and have it persist outside the script block.
function ForEach-WithProgress([object[]] $collection, [scriptblock] $scriptBlock, [string] $activity, [string] $status) {
	[int] $numberOfItems = $collection.Count
	[int] $numberOfItemsProcessed = 0
	$collection | ForEach-Object {
		$numberOfItemsProcessed++

		$splat = @{
			Activity = $activity
			Status = "'$numberOfItemsProcessed' of '$numberOfItems' : $($status -f $_)"
			PercentComplete = (($numberOfItemsProcessed / $numberOfItems) * 100)
		}
		Write-Progress @splat

		& $scriptBlock $_
	}
	Write-Progress -Activity $activity -Completed # Hide the progress bar.
}
