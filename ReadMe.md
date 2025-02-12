# GitClean PowerShell Module

## 💬 Description

The GitClean PowerShell module provides a `Clean-GitRepositories` cmdlet that can be used to easily perform a `git clean -xfd` on all git repositories under a specified directory.

## ❓ Why this exists

Developers often have 10s or 100s of git repositories cloned on their local machine.
We don't always remember to clean up build artifacts and temporary files, such as NuGet packages and node_modules, when we are done.
These files can take up a lot of space on your hard drive.
This module provides a simple way to clean up all of these git repositories at once.

## 🖼️ Screenshots

Coming soon...

## 🚀 Quick start

To install the module from the PowerShell Gallery, run the following command:

```powershell
Install-Module -Name GitClean -Scope CurrentUser
```

To clean all git repositories under a specified directory, run the following command:

```powershell
Clean-GitRepositories -RootDirectoryPath 'C:\path\to\repositories'
```

This assumes that there are multiple git repositories under the specified root directory.

__Safety first__: To avoid accidentally deleting files that have not yet been committed to git, this cmdlet will only clean repositories that have no untracked files.
This ensures you don't lose any work that you haven't committed yet.

## 📖 Documentation

This module only provides one cmdlet: `Clean-GitRepositories`

It accepts the following parameters:

- `RootDirectoryPath` (required): The root directory where all of your git repositories are located. Alias: `Path`
- `DirectorySearchDepth`: The depth to search for git repositories under the RootDirectoryPath. A large value may increase the time it takes to discover git repositories. Default is 4. Alias: `Depth`
- `Force`: If specified, the cmdlet will clean all repositories, even if they have untracked files. __Be careful with this option!__
- `WhatIf`: If specified, the cmdlet will not actually delete any files. It will only show you which repos would be cleaned, even if `-Force` is specified.

### Examples

Clean all git repositories under the current directory:

```powershell
Clean-GitRepositories -RootDirectoryPath (Get-Location)
```

---

Do not clean any repositories, but show which ones would be cleaned:

```powershell
Clean-GitRepositories -Path 'C:\path\to\repositories' -WhatIf
```

---

Clean all repositories, even if they have untracked files:

```powershell
Clean-GitRepositories -Path 'C:\path\to\repositories' -Force
```

---

With repositories at the following paths:

- `C:\path\to\repositories\repo1`
- `C:\path\to\repositories\repo2`
- `C:\path\to\repositories\OtherRepos\repo3`
- `C:\path\to\repositories\OtherRepos\repo4`
- `C:\path\to\repositories\OtherRepos\MoreRepos\repo5`

Only clean `repo1` and `repo2`:

```powershell
Clean-GitRepositories -Path 'C:\path\to\repositories' -Depth 0
```

And to only clean `repo1`, `repo2`, `repo3`, and `repo4`:

```powershell
Clean-GitRepositories -Path 'C:\path\to\repositories' -Depth 1
```

## ➕ How to contribute

Issues and Pull Requests are welcome.
See [the Contributing page](docs/Contributing.md) for more details.

## 📃 Changelog

See what's changed in the application over time by viewing [the changelog](Changelog.md).

## ❤️ Donate to support this project

Buy me a milkshake for providing this PowerShell module open source and for free 🙂

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=VTQ5C7APCHN3E)
