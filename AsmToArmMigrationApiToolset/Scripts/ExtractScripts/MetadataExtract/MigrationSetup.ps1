# Please run Get-Help MigrationSetup.ps1 to learn about how to use this script.

<#
 
.SYNOPSIS
This is a helper Script that sets up the cmdlets for working withe Classic to ARM Migration 

[Script Files Path] - Location of the scripts folder

Sample Command:

.\MigrationSetup.ps1 -scriptFilesPath 'C:\scripts' 
 
#>

[CmdletBinding()]
param(

    [Parameter(Mandatory=$True,ParameterSetName = "Set1")]
    [ValidateNotNullOrEmpty()]
    $scriptFilesPath
)

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

cd $scriptFilesPath
& .\Install-ARMModule.ps1