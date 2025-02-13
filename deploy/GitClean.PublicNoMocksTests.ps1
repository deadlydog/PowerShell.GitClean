# These tests are in their own file so they can be easily dot-sourced into the local development tests
# and the smoke tests without duplicating all of the code.
# Because these are called by the smoke tests, make sure they only call public module functions and do not use mocks.
# These are integration tests that assume git.exe is installed and available in the PATH environment variable.

Describe 'Invoke-GitClean' {
	BeforeAll {
		[string] $UntrackedFileName = 'UntrackedFile.txt'
		[int] $UntrackedFileSizeInBytes = 1MB

		function NewRandomRootDirectoryPath() {
			[string] $rootDirectoryPath = "$TestDrive\" + ([System.IO.Path]::GetRandomFileName().Split('.')[0])
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

		It 'Should report the correct disk space reclaimed when the switch is provided' {
			# Arrange.
			CreateGitRepository -directoryPath $Repo1Path -hasUntrackedFile

			# Act.
			# Use -Force to ensure the untracked files are deleted and reported on.
			$result = Invoke-GitClean -RootDirectoryPath $RootDirectoryPath -Force -CalculateDiskSpaceReclaimed

			# Assert.
			$result.DiskSpaceReclaimedInMb | Should -Be ($UntrackedFileSizeInBytes / 1MB)
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
			$untrackedFileExists1 = Test-Path -Path $Repo1UntrackedFilePath
			$untrackedFileExists2 = Test-Path -Path $Repo2UntrackedFilePath
			$untrackedFileExists3 = Test-Path -Path $Repo3UntrackedFilePath
			$untrackedFileExists1 | Should -Be $false
			$untrackedFileExists2 | Should -Be $true
			$untrackedFileExists3 | Should -Be $false
		}
	}
}
