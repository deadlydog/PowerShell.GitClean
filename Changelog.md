# Changelog

This page is a list of _notable_ changes made in each version.

## v1.1.0 - Feb 28, 2025

Features:

- Added the following aliases for the `Invoke-GitClean` cmdlet:
  - `Clean-GitRepositories`
  - `Git-Clean`

## v1.0.0 - Feb 17, 2025

- Initial stable release of the module.

## v0.3.0 - Feb 16, 2025

BREAKING CHANGES:

- Removed the `-CalculateDiskSpaceReclaimed` switch, as the time it actually added to the total operation was very minimal, so we just always do it.

## v0.2.0 - Feb 13, 2025

Features:

- Added the `-CalculateDiskSpaceReclaimed` switch to show how much disk space was reclaimed in the output.

BREAKING CHANGES:

- Renamed the `Clean-GitRepositories` cmdlet to `Invoke-GitClean`.

## v0.1.0 - Feb 12, 2025

- Initial release of beta module.
