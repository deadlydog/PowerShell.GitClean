using module '.\GitClean.psm1'

# Dot-source in the public tests that do not use mocks to run.
. "$PSScriptRoot\..\..\deploy\GitClean.PublicNoMocksTests.ps1"
