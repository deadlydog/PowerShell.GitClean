# Changelog

This page is a list of _notable_ changes made in each version.

## v1.0.0 - Feb 17, 2015

- Initial stable release of the module.

## v0.3.0 - Feb 16, 2015

BREAKING CHANGES:

- Removed the `-CalculateDiskSpaceReclaimed` switch, as the time it actually added to the total operation was very minimal, so we just always do it.

## v0.2.0 - Feb 13, 2015

Features:

- Added the `-CalculateDiskSpaceReclaimed` switch to show how much disk space was reclaimed in the output.

BREAKING CHANGES:

- Renamed the `Clean-GitRepositories` cmdlet to `Invoke-GitClean`.

## v0.1.0 - Feb 12, 2015

- Initial release of beta module.
