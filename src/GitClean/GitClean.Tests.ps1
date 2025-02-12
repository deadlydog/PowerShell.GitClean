using module '.\GitClean.psm1'

Describe 'Clean-GitRepositories' {
	BeforeAll {
		[string] $UntrackedFileName = 'UntrackedFile.txt'

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
				New-Item -Path (Join-Path -Path $directoryPath -ChildPath $UntrackedFileName) -ItemType File > $null
			}
		}
	}

	Context 'There is a single git repository' {
		BeforeEach {
			$RootDirectoryPath = NewRandomRootDirectoryPath
			$Repo1Path = NewRandomDirectoryPath -rootDirectoryPath $RootDirectoryPath

			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'It is used in the It block.')]
			$Repo1UntrackedFilePath = Join-Path -Path $Repo1Path -ChildPath $UntrackedFileName
		}

		It 'Should clean the git repository if there are no untracked files' {
			# Arrange.
			CreateGitRepository -directoryPath $Repo1Path

			# Act.
			Clean-GitRepositories -RootDirectoryPath $RootDirectoryPath

			# Assert.
			$untrackedFileExists = Test-Path -Path $Repo1UntrackedFilePath
			$untrackedFileExists | Should -Be $false
		}

		It 'Should not clean the git repository if there are untracked files' {
			# Arrange.
			CreateGitRepository -directoryPath $Repo1Path -hasUntrackedFile

			# Act.
			Clean-GitRepositories -RootDirectoryPath $RootDirectoryPath

			# Assert.
			$untrackedFileExists = Test-Path -Path $Repo1UntrackedFilePath
			$untrackedFileExists | Should -Be $true
		}

		It 'Should clean the git repository if there are untracked files and the Force switch was used' {
			# Arrange.
			CreateGitRepository -directoryPath $Repo1Path -hasUntrackedFile

			# Act.
			Clean-GitRepositories -RootDirectoryPath $RootDirectoryPath -Force

			# Assert.
			$untrackedFileExists = Test-Path -Path $Repo1UntrackedFilePath
			$untrackedFileExists | Should -Be $false
		}

		It 'Should not clean the git repository if the WhatIf switch is provided' {
			# Arrange.
			CreateGitRepository -directoryPath $Repo1Path -hasUntrackedFile

			# Act.
			Clean-GitRepositories -RootDirectoryPath $RootDirectoryPath -Force -WhatIf

			# Assert.
			$untrackedFileExists = Test-Path -Path $Repo1UntrackedFilePath
			$untrackedFileExists | Should -Be $true
		}
	}

	Context 'There are 3 git repositories' {
		BeforeEach {
			$RootDirectoryPath = NewRandomRootDirectoryPath
			$Repo1Path = NewRandomDirectoryPath -rootDirectoryPath $RootDirectoryPath
			$Repo2Path = NewRandomDirectoryPath -rootDirectoryPath $RootDirectoryPath
			$Repo3Path = NewRandomDirectoryPath -rootDirectoryPath $RootDirectoryPath

			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'It is used in the It block.')]
			$Repo1UntrackedFilePath = Join-Path -Path $Repo1Path -ChildPath $UntrackedFileName
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'It is used in the It block.')]
			$Repo2UntrackedFilePath = Join-Path -Path $Repo2Path -ChildPath $UntrackedFileName
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'It is used in the It block.')]
			$Repo3UntrackedFilePath = Join-Path -Path $Repo3Path -ChildPath $UntrackedFileName
		}

		It 'Should only clean the git repositories that have no untracked files' {
			# Arrange.
			CreateGitRepository -directoryPath $Repo1Path
			CreateGitRepository -directoryPath $Repo2Path -hasUntrackedFile
			CreateGitRepository -directoryPath $Repo3Path

			# Act.
			Clean-GitRepositories -RootDirectoryPath $RootDirectoryPath

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
