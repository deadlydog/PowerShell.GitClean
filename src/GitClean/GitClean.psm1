function Clean-GitRepositories {
	<#
	.SYNOPSIS
		Cleans all git repositories under a directory.

	.DESCRIPTION
		This cmdlet will search for all git repositories in a directory and it's children and clean them using 'git clean -xfd'.
		By default, it will only clean repositories that do not have untracked files. If the -Force switch is provided,
		it will clean all repositories, even if they have untracked files. If the -WhatIf switch is provided, it will
		only show which repositories would be cleaned, but will not actually clean them. The -Confirm switch can be used
		to prompt the user to confirm before cleaning each repository.

	.PARAMETER RootDirectoryPath
		The root directory to search for git repositories under. Alias: Path.

	.PARAMETER DirectorySearchDepth
		The max depth from the root directory to search for git repositories in. Default is 4. Alias: Depth.

	.PARAMETER Force
		If provided, all git repositories will be cleaned, even if they have untracked files. Be careful with this switch!

	.PARAMETER WhatIf
		If provided, no git repositories will be cleaned; it will just show which repos would be cleaned, even if -Force is provided.

	.PARAMETER Confirm
		Prompts the user to confirm before cleaning each git repository.

	.EXAMPLE
		PS> Clean-GitRepositories -RootDirectoryPath 'C:\GitRepos'

		Cleans all git repositories under 'C:\GitRepos' that do not have untracked files.

	.EXAMPLE
		PS> Clean-GitRepositories -RootDirectoryPath 'C:\GitRepos' -Force

		Cleans all git repositories under 'C:\GitRepos', even if they have untracked files.

	.EXAMPLE
		PS> Clean-GitRepositories -RootDirectoryPath 'C:\GitRepos' -WhatIf

		Shows which git repositories under 'C:\GitRepos' would be cleaned, but does not actually clean them.

	.EXAMPLE
		PS> Clean-GitRepositories -RootDirectoryPath 'C:\GitRepos' -Confirm

		Prompts the user to confirm before cleaning each git repository.

	.EXAMPLE
		PS> Clean-GitRepositories -RootDirectoryPath 'C:\GitRepos' -DirectorySearchDepth 2

		Cleans all git repositories under 'C:\GitRepos' that do not have untracked files, searching up to 2 child directories deep.

	.LINK
		https://github.com/deadlydog/PowerShell.GitClean
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Justification = 'Using Git terminology')]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Using Git terminology')]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Force', Justification = 'Used in a child scope')]
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory = $true, HelpMessage = 'The root directory to search for git repositories in.')]
		[Alias('Path')]
		[string] $RootDirectoryPath,

		[Parameter(Mandatory = $false, HelpMessage = 'The max depth from the root directory to search for git repositories in.')]
		[Alias('Depth')]
		[int] $DirectorySearchDepth = 4,

		[Parameter(Mandatory = $false, HelpMessage = 'If provided all git repositories will be cleaned, even if they have untracked files.')]
		[switch] $Force = $false
	)

	Write-Information "Searching for git repositories in '$RootDirectoryPath'..."
	[string[]] $gitRepositoryDirectoryPaths = GetGitRepositoryDirectoryPaths -rootDirectory $RootDirectoryPath -depth $DirectorySearchDepth

	Write-Information "Testing git repositories to see which ones can be safely cleaned..."
	$gitRepositoryDirectoryPathsWithUntrackedFiles = [System.Collections.ArrayList]::new()
	$gitRepositoryDirectoryPathsThatAreSafeToClean = [System.Collections.ArrayList]::new()
	ForEachWithProgress -collection $gitRepositoryDirectoryPaths -scriptBlock {
		param([string] $gitRepoDirectoryPath)

		[bool] $gitRepoHasUntrackedFiles = TestGitRepositoryHasUntrackedFile -gitRepositoryDirectoryPath $gitRepoDirectoryPath
		if ($gitRepoHasUntrackedFiles -and -not $Force) {
			$gitRepositoryDirectoryPathsWithUntrackedFiles.Add($gitRepoDirectoryPath) > $null
		} else {
			$gitRepositoryDirectoryPathsThatAreSafeToClean.Add($gitRepoDirectoryPath) > $null
		}
	} -activity "Checking for untracked files" -status "Checking git repo '{0}'"

	Write-Information "Cleaning git repositories..."
	ForEachWithProgress -collection $gitRepositoryDirectoryPathsThatAreSafeToClean -scriptBlock {
		param([string] $gitRepoDirectoryPath)

		CleanGitRepository -gitRepositoryDirectoryPath $gitRepoDirectoryPath
	} -activity "Cleaning git repositories" -status "Cleaning git repo '{0}'"

	if ($gitRepositoryDirectoryPathsWithUntrackedFiles.Count -gt 0) {
		Write-Information "The following git repo directories have untracked files, so they were not cleaned: " +
			($gitRepositoryDirectoryPathsWithUntrackedFiles -join [System.Environment]::NewLine)
	}
}

function GetGitRepositoryDirectoryPaths([string] $rootDirectory, [int] $depth) {
	[string[]] $gitRepoPaths =
	Get-ChildItem -Path $rootDirectory -Include '.git' -Recurse -Depth $depth -Force -Directory |
		ForEach-Object {
			$gitDirectoryPath = $_.FullName
			$gitRepositoryDirectoryPath = Split-Path -Path $gitDirectoryPath -Parent
			return $gitRepositoryDirectoryPath
		}
	return $gitRepoPaths
}

function TestGitRepositoryHasUntrackedFile([string] $gitRepositoryDirectoryPath) {
	$gitOutput = (& git -C "$gitRepositoryDirectoryPath" status) | Out-String

	[bool] $gitRepoHasUntrackedFiles = $gitOutput.Contains('Untracked files')
	return $gitRepoHasUntrackedFiles
}

function CleanGitRepository {
	[CmdletBinding(SupportsShouldProcess)]
	param([string] $gitRepositoryDirectoryPath)

	if ($PSCmdlet.ShouldProcess($gitRepositoryDirectoryPath, 'git clean -xfd')) {
		Write-Verbose "Cleaning git repository at '$gitRepositoryDirectoryPath' using 'git clean -xfd'."
		& git -C "$gitRepositoryDirectoryPath" clean -xdf > $null
	}
}

# Adding all the code inline to support Write-Progress made things feel very messy.
# This function helps clean that up, but does add some complexity to the script, especially because
# you cannot assign a variable in the script block a new value and have it persist outside the script block.
function ForEachWithProgress([object[]] $collection, [scriptblock] $scriptBlock, [string] $activity, [string] $status) {
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
