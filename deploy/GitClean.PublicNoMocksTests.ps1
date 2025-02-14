# These tests are in their own file so they can be easily dot-sourced into the local development tests
# and the smoke tests without duplicating all of the code.
# Because these are called by the smoke tests, make sure they only call public module functions and do not use mocks.
# These are integration tests that assume git.exe is installed and available in the PATH environment variable.

Describe 'Invoke-GitClean' {
	BeforeAll {
		[string] $UntrackedFileName = 'UntrackedFile.txt'
		[int] $UntrackedFileSizeInBytes = 1MB # Output is reported in MB, so 1MB is the minimum size to test with.

		function NewRandomRootDirectoryPath() {
			[string] $rootDirectoryPath = "$TestDrive/" + ([System.IO.Path]::GetRandomFileName().Split('.')[0])
			New-Item -Path $rootDirectoryPath -ItemType Directory -Force > $null
			return $rootDirectoryPath
		}

		function NewRandomDirectoryPath([string] $rootDirectoryPath) {
			[string] $directoryPath = Join-Path -Path $rootDirectoryPath -ChildPath ([System.IO.Path]::GetRandomFileName().Split('.')[0])
			New-Item -Path $directoryPath -ItemType Directory -Force > $null
			return $directoryPath
		}

		function CreateGitRepository([string] $directoryPath, [switch] $hasUntrackedFile) {
			New-Item -Path $directoryPath -ItemType Directory -Force > $null
			& git -C "$directoryPath" init > $null

			if ($hasUntrackedFile) {
				$untrackedFilePath = Join-Path -Path $directoryPath -ChildPath $UntrackedFileName

				$tempFile = [System.IO.FileStream]::new($untrackedFilePath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::ReadWrite)
				$tempFile.SetLength($UntrackedFileSizeInBytes)
				$tempFile.Close()
			}
		}
	}

	Context 'There are no git repositories' {
		BeforeEach {
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Used in the It blocks')]
			$RootDirectoryPath = NewRandomRootDirectoryPath
		}

		It 'Should not find any git repositories' {
			# Act.
			$result = Invoke-GitClean -RootDirectoryPath $RootDirectoryPath

			# Assert.
			$result.NumberOfGitRepositoriesFound | Should -Be 0
			$result.GitRepositoriesCleaned | Should -BeNullOrEmpty
			$result.GitRepositoriesWithUntrackedFiles | Should -BeNullOrEmpty
		}
	}

	Context 'There is a single git repository' {
		BeforeEach {
			$RootDirectoryPath = NewRandomRootDirectoryPath
			$Repo1Path = NewRandomDirectoryPath -rootDirectoryPath $RootDirectoryPath

			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Used in the It blocks')]
			$Repo1UntrackedFilePath = Join-Path -Path $Repo1Path -ChildPath $UntrackedFileName
		}

		It 'Should clean the git repository if there are no untracked files' {
			# Arrange.
			CreateGitRepository -directoryPath $Repo1Path

			# Act.
			Invoke-GitClean -RootDirectoryPath $RootDirectoryPath

			# Assert.
			$untrackedFileExists = Test-Path -Path $Repo1UntrackedFilePath
			$untrackedFileExists | Should -Be $false
		}

		It 'Should not clean the git repository if there are untracked files' {
			# Arrange.
			CreateGitRepository -directoryPath $Repo1Path -hasUntrackedFile

			# Act.
			Invoke-GitClean -RootDirectoryPath $RootDirectoryPath

			# Assert.
			$untrackedFileExists = Test-Path -Path $Repo1UntrackedFilePath
			$untrackedFileExists | Should -Be $true
		}

		It 'Should clean the git repository if there are untracked files and the Force switch was used' {
			# Arrange.
			CreateGitRepository -directoryPath $Repo1Path -hasUntrackedFile

			# Act.
			Invoke-GitClean -RootDirectoryPath $RootDirectoryPath -Force

			# Assert.
			$untrackedFileExists = Test-Path -Path $Repo1UntrackedFilePath
			$untrackedFileExists | Should -Be $false
		}

		It 'Should not clean the git repository if the WhatIf switch is provided' {
			# Arrange.
			CreateGitRepository -directoryPath $Repo1Path -hasUntrackedFile

			# Act.
			Invoke-GitClean -RootDirectoryPath $RootDirectoryPath -Force -WhatIf

			# Assert.
			$untrackedFileExists = Test-Path -Path $Repo1UntrackedFilePath
			$untrackedFileExists | Should -Be $true
		}

		It 'Should return that 1 git repository was cleaned when there are no untracked files' {
			# Arrange.
			CreateGitRepository -directoryPath $Repo1Path

			# Act.
			$result = Invoke-GitClean -RootDirectoryPath $RootDirectoryPath

			# Assert.
			$result.NumberOfGitRepositoriesFound | Should -Be 1
			$result.GitRepositoriesCleaned[0] | Should -Be $Repo1Path
			$result.GitRepositoriesWithUntrackedFiles | Should -BeNullOrEmpty
		}

		It 'Should return that 0 git repositories were cleaned when there are untracked files' {
			# Arrange.
			CreateGitRepository -directoryPath $Repo1Path -hasUntrackedFile

			# Act.
			$result = Invoke-GitClean -RootDirectoryPath $RootDirectoryPath

			# Assert.
			$result.NumberOfGitRepositoriesFound | Should -Be 1
			$result.GitRepositoriesCleaned | Should -BeNullOrEmpty
			$result.GitRepositoriesWithUntrackedFiles[0] | Should -Be $Repo1Path
		}

		It 'Should report the correct disk space reclaimed when the switch is provided and files were removed' {
			# Arrange.
			CreateGitRepository -directoryPath $Repo1Path -hasUntrackedFile

			# Act.
			# Use -Force to ensure the untracked files are deleted and reported on.
			$result = Invoke-GitClean -RootDirectoryPath $RootDirectoryPath -Force -CalculateDiskSpaceReclaimed

			# Assert.
			$result.DiskSpaceReclaimedInMb | Should -Be ($UntrackedFileSizeInBytes / 1MB)
		}

		It 'Should report that no disk space was reclaimed when the WhatIf switch is provided' {
			# Arrange.
			CreateGitRepository -directoryPath $Repo1Path -hasUntrackedFile

			# Act.
			$result = Invoke-GitClean -RootDirectoryPath $RootDirectoryPath -Force -CalculateDiskSpaceReclaimed -WhatIf

			# Assert.
			$result.DiskSpaceReclaimedInMb | Should -Be 0
		}
	}

	Context 'There are 3 git repositories' {
		BeforeEach {
			$RootDirectoryPath = NewRandomRootDirectoryPath
			$Repo1Path = NewRandomDirectoryPath -rootDirectoryPath $RootDirectoryPath
			$Repo2Path = NewRandomDirectoryPath -rootDirectoryPath $RootDirectoryPath
			$Repo3Path = NewRandomDirectoryPath -rootDirectoryPath $RootDirectoryPath

			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Used in the It blocks')]
			$Repo1UntrackedFilePath = Join-Path -Path $Repo1Path -ChildPath $UntrackedFileName
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Used in the It blocks')]
			$Repo2UntrackedFilePath = Join-Path -Path $Repo2Path -ChildPath $UntrackedFileName
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Used in the It blocks')]
			$Repo3UntrackedFilePath = Join-Path -Path $Repo3Path -ChildPath $UntrackedFileName
		}

		It 'Should only clean the git repositories that have no untracked files' {
			# Arrange.
			CreateGitRepository -directoryPath $Repo1Path
			CreateGitRepository -directoryPath $Repo2Path -hasUntrackedFile
			CreateGitRepository -directoryPath $Repo3Path

			# Act.
			Invoke-GitClean -RootDirectoryPath $RootDirectoryPath

			# Assert.
			$repo1UntrackedFileExists = Test-Path -Path $Repo1UntrackedFilePath
			$repo2UntrackedFileExists = Test-Path -Path $Repo2UntrackedFilePath
			$repo3UntrackedFileExists = Test-Path -Path $Repo3UntrackedFilePath
			$repo1UntrackedFileExists | Should -Be $false
			$repo2UntrackedFileExists | Should -Be $true
			$repo3UntrackedFileExists | Should -Be $false
		}
	}

	Context 'There are 5 git repositories, each one directory deeper than the previous' {
		BeforeEach {
			$RootDirectoryPath = NewRandomRootDirectoryPath
			$Repo1Path = NewRandomDirectoryPath -rootDirectoryPath "$RootDirectoryPath"
			$Repo2Path = NewRandomDirectoryPath -rootDirectoryPath "$RootDirectoryPath/Level2"
			$Repo3Path = NewRandomDirectoryPath -rootDirectoryPath "$RootDirectoryPath/Level2/Level3"
			$Repo4Path = NewRandomDirectoryPath -rootDirectoryPath "$RootDirectoryPath/Level2/Level3/Level4"
			$Repo5Path = NewRandomDirectoryPath -rootDirectoryPath "$RootDirectoryPath/Level2/Level3/Level4/Level5"

			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Used in the It blocks')]
			$Repo1UntrackedFilePath = Join-Path -Path $Repo1Path -ChildPath $UntrackedFileName
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Used in the It blocks')]
			$Repo2UntrackedFilePath = Join-Path -Path $Repo2Path -ChildPath $UntrackedFileName
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Used in the It blocks')]
			$Repo3UntrackedFilePath = Join-Path -Path $Repo3Path -ChildPath $UntrackedFileName
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Used in the It blocks')]
			$Repo4UntrackedFilePath = Join-Path -Path $Repo4Path -ChildPath $UntrackedFileName
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Used in the It blocks')]
			$Repo5UntrackedFilePath = Join-Path -Path $Repo5Path -ChildPath $UntrackedFileName
		}

		It 'Should only find and clean the git repositories up to the specified depth' {
			# Arrange.
			# We assume a depth of 2 for this test.
			CreateGitRepository -directoryPath $Repo1Path -hasUntrackedFile
			CreateGitRepository -directoryPath $Repo2Path -hasUntrackedFile
			CreateGitRepository -directoryPath $Repo3Path -hasUntrackedFile
			CreateGitRepository -directoryPath $Repo4Path -hasUntrackedFile
			CreateGitRepository -directoryPath $Repo5Path -hasUntrackedFile

			# Act.
			$result = Invoke-GitClean -RootDirectoryPath $RootDirectoryPath -Depth 2 -Force -CalculateDiskSpaceReclaimed

			# Assert.
			$repo1UntrackedFileExists = Test-Path -Path $Repo1UntrackedFilePath
			$repo2UntrackedFileExists = Test-Path -Path $Repo2UntrackedFilePath
			$repo3UntrackedFileExists = Test-Path -Path $Repo3UntrackedFilePath
			$repo4UntrackedFileExists = Test-Path -Path $Repo4UntrackedFilePath
			$repo5UntrackedFileExists = Test-Path -Path $Repo5UntrackedFilePath
			$repo1UntrackedFileExists | Should -Be $false
			$repo2UntrackedFileExists | Should -Be $false
			$repo3UntrackedFileExists | Should -Be $true
			$repo4UntrackedFileExists | Should -Be $true
			$repo5UntrackedFileExists | Should -Be $true

			$result.NumberOfGitRepositoriesFound | Should -Be 2
			$result.DiskSpaceReclaimedInMb | Should -Be (($UntrackedFileSizeInBytes / 1MB) * 2)
		}
	}
}
