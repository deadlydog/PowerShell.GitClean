function Invoke-GitClean {
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
		The root directory to search for git repositories in. If not provided, the current directory will be used. Alias: Path.

	.PARAMETER DirectorySearchDepth
		The max depth from the root directory to search for git repositories in. A large value may increase the time it takes to discover git repositories. Default is 3. Alias: Depth.

	.PARAMETER Force
		If provided, all git repositories will be cleaned, even if they have untracked files. Be careful with this switch!

	.PARAMETER WhatIf
		If provided, no git repositories will be cleaned; it will just show which repos would be cleaned, even if -Force is provided.

	.PARAMETER Confirm
		Prompts the user to confirm before cleaning each git repository.

	.OUTPUTS
		[PSCustomObject] The cmdlet returns an object containing the following properties:
			- RootDirectoryPath: The root directory that was searched for git repositories.
			- DirectorySearchDepth: The max depth from the root directory to search for git repositories.
			- NumberOfGitRepositoriesFound: The number of git repositories found.
			- GitRepositoriesCleaned: The git repositories that were cleaned.
			- GitRepositoriesWithUntrackedFiles: The git repositories that were not cleaned because they had untracked files.
			- Duration: The duration of the operation.
			- DiskSpaceReclaimedInMb: The amount of disk space reclaimed by the git clean operations, in megabytes.

	.EXAMPLE
		PS> Invoke-GitClean -RootDirectoryPath 'C:\GitRepos'

		Cleans all git repositories under 'C:\GitRepos' that do not have untracked files.

	.EXAMPLE
		PS> Invoke-GitClean -RootDirectoryPath 'C:\GitRepos' -Force

		Cleans all git repositories under 'C:\GitRepos', even if they have untracked files.

	.EXAMPLE
		PS> Invoke-GitClean -RootDirectoryPath 'C:\GitRepos' -WhatIf

		Shows which git repositories under 'C:\GitRepos' would be cleaned, but does not actually clean them.

	.EXAMPLE
		PS> Invoke-GitClean -RootDirectoryPath 'C:\GitRepos' -Confirm

		Prompt the user for confirmation before cleaning each repository.

	.EXAMPLE
		PS> Invoke-GitClean -Path 'C:\GitRepos' -DirectorySearchDepth 2

		Cleans all git repositories under 'C:\GitRepos' that do not have untracked files, searching up to 2 child directories deep.

	.EXAMPLE

		PS> $result = Invoke-GitClean -Path 'C:\path\to\repositories'
		PS> $result.GitRepositoriesWithUntrackedFiles

		List all git repositories that were not cleaned because they have untracked files.

	.EXAMPLE
		PS> Invoke-GitClean -Path 'C:\GitRepos' -InformationAction Continue -Verbose

		Cleans all git repositories under 'C:\GitRepos' that do not have untracked files, showing information messages and verbose output.

	.LINK
		https://github.com/deadlydog/PowerShell.GitClean
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Force', Justification = 'Used in a child scope')]
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory = $false, HelpMessage = 'The root directory to search for git repositories in. If not provided, the current directory will be used.')]
		[Alias('Path')]
		[string] $RootDirectoryPath = [string]::Empty,

		[Parameter(Mandatory = $false, HelpMessage = 'The max depth from the root directory to search for git repositories in.')]
		[Alias('Depth')]
		[UInt32] $DirectorySearchDepth = 3,

		[Parameter(Mandatory = $false, HelpMessage = 'If provided, all git repositories will be cleaned, even if they have untracked files.')]
		[switch] $Force = $false
	)

	[DateTime] $startTime = Get-Date

	WriteVerbose "Validating the root directory path..."
	if ([string]::IsNullOrWhiteSpace($RootDirectoryPath)) {
		$RootDirectoryPath = Get-Location
	}
	if (-not (Test-Path -Path $RootDirectoryPath -PathType Container)) {
		Write-Error "The specified RootDirectoryPath '$RootDirectoryPath' does not exist or is not a directory."
		return
	}
	$RootDirectoryPath = Resolve-Path -Path $RootDirectoryPath

	Write-Information "Searching for git repositories in '$RootDirectoryPath'..."
	[string[]] $gitRepositoryDirectoryPaths = GetGitRepositoryDirectoryPaths -rootDirectory $RootDirectoryPath -depth $DirectorySearchDepth

	Write-Information "Testing git repositories to see which ones can be safely cleaned..."
	$gitRepositoryDirectoryPathsWithUntrackedFiles = [System.Collections.ArrayList]::new()
	$gitRepositoryDirectoryPathsToClean = [System.Collections.ArrayList]::new()
	ForEachWithProgress -collection $gitRepositoryDirectoryPaths -scriptBlock {
		param([string] $gitRepoDirectoryPath)

		# If the -Force switch was provided, don't bother checking for untracked files; just add it to the list of repos to clean.
		if ($Force) {
			$gitRepositoryDirectoryPathsToClean.Add($gitRepoDirectoryPath) > $null
			return
		}

		[bool] $gitRepoHasUntrackedFiles = TestGitRepositoryHasUntrackedFile -gitRepositoryDirectoryPath $gitRepoDirectoryPath
		if ($gitRepoHasUntrackedFiles) {
			$gitRepositoryDirectoryPathsWithUntrackedFiles.Add($gitRepoDirectoryPath) > $null
		} else {
			$gitRepositoryDirectoryPathsToClean.Add($gitRepoDirectoryPath) > $null
		}
	} -activity "Checking for untracked files" -status "Git repo '{0}'"

	Write-Information "Cleaning git repositories..."
	$diskSpaceReclaimedDictionary = [System.Collections.Generic.Dictionary[string, long]]::new()
	ForEachWithProgress -collection $gitRepositoryDirectoryPathsToClean -scriptBlock {
		param([string] $gitRepoDirectoryPath)

		[long] $diskSpaceReclaimed = CleanGitRepository -gitRepositoryDirectoryPath $gitRepoDirectoryPath
		$diskSpaceReclaimedDictionary.Add($gitRepoDirectoryPath, $diskSpaceReclaimed)
	} -activity "Cleaning git repositories" -status "Git repo '{0}'"

	if ($gitRepositoryDirectoryPathsWithUntrackedFiles.Count -gt 0) {
		Write-Information ("The following git repo directories have untracked files, so they were not cleaned: " +
			[System.Environment]::NewLine + ($gitRepositoryDirectoryPathsWithUntrackedFiles -join [System.Environment]::NewLine))
	}

	[int] $totalDiskSpaceReclaimedInMb = 0
	WriteVerbose "Calculating disk space reclaimed..."
	$totalDiskSpaceReclaimedInMb = ($diskSpaceReclaimedDictionary.Values | Measure-Object -Sum | Select-Object -ExpandProperty Sum) / 1MB
	Write-Information "Total disk space reclaimed: $($totalDiskSpaceReclaimedInMb) MB"

	[DateTime] $finishTime = Get-Date
	[TimeSpan] $duration = $finishTime - $startTime

	# Build and write the result object.
	[PSCustomObject] $result = @{
		RootDirectoryPath = $RootDirectoryPath
		DirectorySearchDepth = $DirectorySearchDepth
		NumberOfGitRepositoriesFound = $gitRepositoryDirectoryPaths.Count
		GitRepositoriesCleaned = $gitRepositoryDirectoryPathsToClean
		GitRepositoriesWithUntrackedFiles = $gitRepositoryDirectoryPathsWithUntrackedFiles
		Duration = $duration
		DiskSpaceReclaimedInMb = $totalDiskSpaceReclaimedInMb
	}
	Write-Output $result
}

function GetGitRepositoryDirectoryPaths([string] $rootDirectory, [int] $depth) {
	[System.IO.DirectoryInfo[]] $gitDirectoryPaths = @()
	# If this is Windows PowerShell, we need to use the slower Get-ChildItem cmdlet.
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		$gitDirectoryPaths = Get-ChildItem -Path $rootDirectory -Filter '.git' -Recurse -Depth $depth -Force -Directory
	}
	# Else this is PowerShell Core, so we can use the faster System.IO.DirectoryInfo because it supports System.IO.EnumerationOptions.
	else {
		$searchOptions = [System.IO.EnumerationOptions]::new()
		$searchOptions.RecurseSubdirectories = $true
		$searchOptions.MaxRecursionDepth = $depth
		$searchOptions.MatchType = [System.IO.MatchType]::Simple
		$searchOptions.AttributesToSkip = [System.IO.FileAttributes]::None

		$gitDirectoryPaths = [System.IO.DirectoryInfo]::new($rootDirectory).GetDirectories('*.git', $searchOptions)
	}

	[string[]] $gitRepoPaths = $gitDirectoryPaths | Where-Object { $null -ne $_ } |
		ForEach-Object {
			$gitDirectoryPath = $_.FullName
			$gitRepositoryDirectoryPath = Split-Path -Path $gitDirectoryPath -Parent
			return $gitRepositoryDirectoryPath
		}
	return $gitRepoPaths
}

function TestGitRepositoryHasUntrackedFile([string] $gitRepositoryDirectoryPath) {
	WriteVerbose "Checking git repository for untracked files: '$gitRepositoryDirectoryPath'"
	[string] $gitOutput = (& git -C "$gitRepositoryDirectoryPath" status) | Out-String

	# NOTE: Git.exe currently only supports English output.
	# If that ever changes, we may need to allow the user to provide the 'Untracked files' string to look for.
	[bool] $gitRepoHasUntrackedFiles = $gitOutput.Contains('Untracked files')
	return $gitRepoHasUntrackedFiles
}

function CleanGitRepository {
	[CmdletBinding(SupportsShouldProcess)]
	param([string] $gitRepositoryDirectoryPath)

	[long] $diskSpaceReclaimed = 0
	if ($PSCmdlet.ShouldProcess($gitRepositoryDirectoryPath, 'git clean -xfd')) {
		# Use System.IO.DirectoryInfo instead of Get-ChildItem for performance reasons.
		WriteVerbose "Calculating size of directory before cleaning: '$gitRepositoryDirectoryPath'"
		[long] $repoSizeBeforeCleaning = [System.IO.DirectoryInfo]::new($gitRepositoryDirectoryPath).GetFiles('*', 'AllDirectories') |
			ForEach-Object { $_.Length } | Measure-Object -Sum | Select-Object -ExpandProperty Sum

		WriteVerbose "Cleaning git repository using 'git clean -xfd': '$gitRepositoryDirectoryPath'"
		[string] $gitCleanOutput = (& git -C "$gitRepositoryDirectoryPath" clean -xdf) | Out-String
		if (-not [string]::IsNullOrWhiteSpace($gitCleanOutput)) {
			WriteVerbose ("Git clean output:" + [System.Environment]::NewLine + $gitCleanOutput.Trim())
		}

		# Use System.IO.DirectoryInfo instead of Get-ChildItem for performance reasons.
		WriteVerbose "Calculating size of directory after cleaning: '$gitRepositoryDirectoryPath'"
		[long] $repoSizeAfterCleaning = [System.IO.DirectoryInfo]::new($gitRepositoryDirectoryPath).GetFiles('*', 'AllDirectories') |
			ForEach-Object { $_.Length } | Measure-Object -Sum | Select-Object -ExpandProperty Sum

		$diskSpaceReclaimed = $repoSizeBeforeCleaning - $repoSizeAfterCleaning
		WriteVerbose "Size before: '$repoSizeBeforeCleaning'. Size after: '$repoSizeAfterCleaning'. Disk space reclaimed: '$diskSpaceReclaimed' bytes."
		WriteVerbose '----------'
	}

	return $diskSpaceReclaimed
}

# This function performs a ForEach-Object loop with a progress bar to show the status and how many iterations are left.
# Adding all the code inline to support Write-Progress made things feel very messy.
# This function helps clean that up, but does add some complexity to the script, especially because
# you cannot assign a variable in the script block a new value and have it persist outside the script block.
function ForEachWithProgress([object[]] $collection, [scriptblock] $scriptBlock, [string] $activity, [string] $status) {
	# If there are no items to process, then just return.
	if ($null -eq $collection -or $collection.Count -eq 0) {
		return
	}

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

function WriteVerbose([string] $message) {
	if (-not [string]::IsNullOrWhiteSpace($message)) {
		$time = Get-Date -Format 'HH:mm:ss.fff'
		Write-Verbose "$time : $message"
	}
}
