#
# Module manifest for module 'Azure Resource Manager'
#
# Generated by: Dushyant Gill
#
# Generated on: 1/5/2014
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'ARM.psm1'

# Version number of this module.
ModuleVersion = '1.0'

# ID used to uniquely identify this module
GUID = 'f3a04d92-43e2-4dc3-96bf-67ac223628c7'

# Author of this module
Author = 'Dushyant Gill'

# Company or vendor of this module
CompanyName = 'dushyantgill.com'

# Copyright statement for this module
Copyright = '(c) 2014 Dushyant Gill. All rights reserved.'

# Description of the functionality provided by this module
Description = 'A PowerShell Client for the Azure Resource Manager REST APIs.'

# Minimum version of the Windows PowerShell engine required by this module
# PowerShellVersion = ''

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
NestedModules = @('Cmdlets\Authorization.psm1','Cmdlets\ARMResource.psm1','Cmdlets\ARMClassicCompute.psm1')

# Functions to export from this module
FunctionsToExport = 'Connect-ARM', 'Execute-ARMQuery', 'Get-ARMDirectories', 'Get-ARMSubscriptions', 'Get-ARMDirectoryInfo', 'Get-ARMDirectoryObject', 'Resolve-ARMDirectoryPrincipal', 'Get-ARMDirectoryPrincipalGroupMembership', 'Get-ARMAccessChangeHistory', 'Get-ARMAccessAssignments', 'Get-ARMResource', 'Operate-ARMResource', 'Get-ARMClassicVM', 'Start-ARMClassicVM', 'Restart-ARMClassicVM', 'Stop-ARMClassicVM', 'Shutdown-ARMClassicVM', 'RDP-ARMClassicVM', 'Get-ARMClassicVMDisk', 'Attach-ARMClassicVMDisk', 'Detach-ARMClassicVMDisk' 

# Cmdlets to export from this module
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module
AliasesToExport = '*'

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess
# PrivateData = ''

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}