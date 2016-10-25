function Get-ARMClassicVM() {
  [CmdletBinding(DefaultParameterSetName="NoVMName")]            
  param (
    [parameter(Mandatory=$true,HelpMessage="ID or displayName of the Azure subscription.")]    
    [string]$Subscription, 
    
    [parameter(Mandatory=$false,ParameterSetName='NoVMName',HelpMessage="Name of the resource group if you wish to limit the search to one.")]    
    [parameter(Mandatory=$true,ParameterSetName='VMName',HelpMessage="Name of the resource group if you wish to limit the search to one.")]    
    [string]$ResourceGroup = $null, 

    [parameter(Mandatory=$false,ParameterSetName='VMName',HelpMessage="Name of a specific VM in a resource group that you wish to retrieve.")]    
    [string]$VMName, 
            
    [parameter(Mandatory=$false,HelpMessage="Silent mode")]    
    [switch] $Silent
  )
  PROCESS {
    $commandString = "Get-ARMResource -ResourceProvider microsoft.classiccompute -ResourceType virtualMachines -APIVersion 2014-06-01"
    $commandString += [string]::Format(" -Subscription {0}", $Subscription)
    if(-not [string]::IsNullOrEmpty($ResourceGroup)) {$commandString += [string]::Format(" -ResourceGroup {0}", $ResourceGroup)}
    if(-not [string]::IsNullOrEmpty($VMName)) {$commandString += [string]::Format(" -ResourceIdentifier {0}", $VMName)}
    if($Silent) {$commandString += " -Silent"}
    
    Invoke-Expression -Command $commandString
  }
}  

function Start-ARMClassicVM() {
  param (
    [parameter(Mandatory=$true,HelpMessage="ID or displayName of the Azure subscription.")]    
    [string]$Subscription, 
    
    [parameter(Mandatory=$true,HelpMessage="Name of the resource group that contains the VM that you wish to start.")]    
    [string]$ResourceGroup = $null, 

    [parameter(Mandatory=$true,HelpMessage="Name of the VM that you wish to start.")]    
    [string]$VMName, 
            
    [parameter(Mandatory=$false,HelpMessage="Silent mode")]    
    [switch] $Silent
  )
  PROCESS {
    $commandString = "Operate-ARMResource -ResourceProvider microsoft.classiccompute -ResourceType virtualMachines -APIVersion 2014-06-01 -Action start -ActionResult Status"
    $commandString += [string]::Format(" -Subscription {0}", $Subscription)
    $commandString += [string]::Format(" -ResourceGroup {0}", $ResourceGroup)
    $commandString += [string]::Format(" -ResourceIdentifier {0}", $VMName)
    if($Silent) {$commandString += " -Silent"}
    
    Invoke-Expression -Command $commandString
  }
} 

function Restart-ARMClassicVM() {
  param (
    [parameter(Mandatory=$true,HelpMessage="ID or displayName of the Azure subscription.")]    
    [string]$Subscription, 
    
    [parameter(Mandatory=$true,HelpMessage="Name of the resource group that contains the VM that you wish to restart.")]    
    [string]$ResourceGroup = $null, 

    [parameter(Mandatory=$true,HelpMessage="Name of the VM that you wish to restart.")]    
    [string]$VMName, 
            
    [parameter(Mandatory=$false,HelpMessage="Silent mode")]    
    [switch] $Silent
  )
  PROCESS {
    $commandString = "Operate-ARMResource -ResourceProvider microsoft.classiccompute -ResourceType virtualMachines -APIVersion 2014-06-01 -Action restart -ActionResult Status"
    $commandString += [string]::Format(" -Subscription {0}", $Subscription)
    $commandString += [string]::Format(" -ResourceGroup {0}", $ResourceGroup)
    $commandString += [string]::Format(" -ResourceIdentifier {0}", $VMName)
    if($Silent) {$commandString += " -Silent"}
    
    Invoke-Expression -Command $commandString
  }
}

function Stop-ARMClassicVM() {
  param (
    [parameter(Mandatory=$true,HelpMessage="ID or displayName of the Azure subscription.")]    
    [string]$Subscription, 
    
    [parameter(Mandatory=$true,HelpMessage="Name of the resource group that contains the VM that you wish to stop.")]    
    [string]$ResourceGroup = $null, 

    [parameter(Mandatory=$true,HelpMessage="Name of the VM that you wish to stop.")]    
    [string]$VMName, 
            
    [parameter(Mandatory=$false,HelpMessage="Silent mode")]    
    [switch] $Silent
  )
  PROCESS {
    $commandString = "Operate-ARMResource -ResourceProvider microsoft.classiccompute -ResourceType virtualMachines -APIVersion 2014-06-01 -Action stop -ActionResult Status"
    $commandString += [string]::Format(" -Subscription {0}", $Subscription)
    $commandString += [string]::Format(" -ResourceGroup {0}", $ResourceGroup)
    $commandString += [string]::Format(" -ResourceIdentifier {0}", $VMName)
    if($Silent) {$commandString += " -Silent"}
    
    Invoke-Expression -Command $commandString
  }
}

function Shutdown-ARMClassicVM() {
  param (
    [parameter(Mandatory=$true,HelpMessage="ID or displayName of the Azure subscription.")]    
    [string]$Subscription, 
    
    [parameter(Mandatory=$true,HelpMessage="Name of the resource group that contains the VM that you wish to shutdown.")]    
    [string]$ResourceGroup = $null, 

    [parameter(Mandatory=$true,HelpMessage="Name of the VM that you wish to shutdown.")]    
    [string]$VMName, 
            
    [parameter(Mandatory=$false,HelpMessage="Silent mode")]    
    [switch] $Silent
  )
  PROCESS {
    $commandString = "Operate-ARMResource -ResourceProvider microsoft.classiccompute -ResourceType virtualMachines -APIVersion 2014-06-01 -Action shutdown -ActionResult Status"
    $commandString += [string]::Format(" -Subscription {0}", $Subscription)
    $commandString += [string]::Format(" -ResourceGroup {0}", $ResourceGroup)
    $commandString += [string]::Format(" -ResourceIdentifier {0}", $VMName)
    if($Silent) {$commandString += " -Silent"}
    
    Invoke-Expression -Command $commandString
  }
}

function Restart-ARMClassicVM() {
  param (
    [parameter(Mandatory=$true,HelpMessage="ID or displayName of the Azure subscription.")]    
    [string]$Subscription, 
    
    [parameter(Mandatory=$true,HelpMessage="Name of the resource group that contains the VM that you wish to restart.")]    
    [string]$ResourceGroup = $null, 

    [parameter(Mandatory=$true,HelpMessage="Name of the VM that you wish to restart.")]    
    [string]$VMName, 
            
    [parameter(Mandatory=$false,HelpMessage="Silent mode")]    
    [switch] $Silent
  )
  PROCESS {
    $commandString = "Operate-ARMResource -ResourceProvider microsoft.classiccompute -ResourceType virtualMachines -APIVersion 2014-06-01 -Action restart -ActionResult Status"
    $commandString += [string]::Format(" -Subscription {0}", $Subscription)
    $commandString += [string]::Format(" -ResourceGroup {0}", $ResourceGroup)
    $commandString += [string]::Format(" -ResourceIdentifier {0}", $VMName)
    if($Silent) {$commandString += " -Silent"}
    
    Invoke-Expression -Command $commandString
  }
}

function RDP-ARMClassicVM() {
  param (
    [parameter(Mandatory=$true,HelpMessage="ID or displayName of the Azure subscription.")]    
    [string]$Subscription, 
    
    [parameter(Mandatory=$true,HelpMessage="Name of the resource group that contains the VM that you wish to RDP to.")]    
    [string]$ResourceGroup = $null, 

    [parameter(Mandatory=$true,HelpMessage="Name of the VM that you wish to RDP to.")]    
    [string]$VMName, 
            
    [parameter(Mandatory=$false,HelpMessage="Silent mode")]    
    [switch] $Silent
  )
  PROCESS {
    $commandString = "Operate-ARMResource -ResourceProvider microsoft.classiccompute -ResourceType virtualMachines -APIVersion 2014-06-01 -Action downloadRemoteDesktopConnectionFile -ActionResult file -ActionResultExtension .rdp"
    $commandString += [string]::Format(" -Subscription {0}", $Subscription)
    $commandString += [string]::Format(" -ResourceGroup {0}", $ResourceGroup)
    $commandString += [string]::Format(" -ResourceIdentifier {0}", $VMName)
    if($Silent) {$commandString += " -Silent"}
    
    Invoke-Expression -Command $commandString
  }
}

function Get-ARMClassicVMDisk() {
  param (
    [parameter(Mandatory=$true,HelpMessage="ID or displayName of the Azure subscription.")]    
    [string]$Subscription, 
    
    [parameter(Mandatory=$true,HelpMessage="Name of the resource group that contains the VM for which you wish to fetch disks.")]    
    [string]$ResourceGroup = $null, 

    [parameter(Mandatory=$true,HelpMessage="Name of the VM for which you wish to fetch disks.")]    
    [string]$VMName, 
            
    [parameter(Mandatory=$false,HelpMessage="Silent mode")]    
    [switch] $Silent
  )
  PROCESS {
    $commandString = "Get-ARMResource -ResourceProvider microsoft.classiccompute -ResourceType virtualMachines -APIVersion 2014-06-01 -Base disks"
    $commandString += [string]::Format(" -Subscription {0}", $Subscription)
    $commandString += [string]::Format(" -ResourceGroup {0}", $ResourceGroup)
    $commandString += [string]::Format(" -ResourceIdentifier {0}", $VMName)
    if($Silent) {$commandString += " -Silent"}
    
    Invoke-Expression -Command $commandString
  }
}

function Attach-ARMClassicVMDisk() {
  param (
    [parameter(Mandatory=$true,HelpMessage="ID or displayName of the Azure subscription.")]    
    [string]$Subscription, 
    
    [parameter(Mandatory=$true,HelpMessage="Name of the resource group that contains the VM to which you wish to attach a disk.")]    
    [string]$ResourceGroup = $null, 

    [parameter(Mandatory=$true,HelpMessage="Name of the VM to which you wish to attach a disk.")]    
    [string]$VMName, 
    
    [parameter(Mandatory=$false,HelpMessage="Name of the disk that you wish to attach.")]    
    [string]$DiskName, 

    [parameter(Mandatory=$true,HelpMessage="URI of the VHD of the disk that you wish to attach.")]    
    [string]$VHDURI, 
            
    [parameter(Mandatory=$false,HelpMessage="Caching of the disk that you wish to attach.")]    
    [string]$Caching, 
            
    [parameter(Mandatory=$false,HelpMessage="Source Image Name of the disk that you wish to attach.")]    
    [string]$SourceImageName, 
            
    [parameter(Mandatory=$false,HelpMessage="Operating System of the disk that you wish to attach.")]    
    [string]$OperatingSystem, 
            
    [parameter(Mandatory=$false,HelpMessage="Size of the disk that you wish to attach.")]    
    [Nullable[int]]$DiskSize, 
            
    [parameter(Mandatory=$true,HelpMessage="LUN of the disk that you wish to attach.")]    
    [int]$LUN, 
            
    [parameter(Mandatory=$false,HelpMessage="Silent mode")]    
    [switch] $Silent
  )
  PROCESS {
    $commandString = "Operate-ARMResource -ResourceProvider microsoft.classiccompute -ResourceType virtualMachines -APIVersion 2014-06-01 -Action attachDisk -ActionResult default -Data `$disk"
    $commandString += [string]::Format(" -Subscription {0}", $Subscription)
    $commandString += [string]::Format(" -ResourceGroup {0}", $ResourceGroup)
    $commandString += [string]::Format(" -ResourceIdentifier {0}", $VMName)
    if($Silent) {$commandString += " -Silent"}
    $disk = "" | select "DiskName", "VHDURI", "Caching", "SourceImageName", "OperatingSystem", "DiskSize", "LUN"
    $disk.VHDURI = $VHDURI
    $disk.LUN = $LUN
    if(-not [string]::IsNullOrEmpty($DiskName)){$disk.DiskName = $DiskName}
    if(-not [string]::IsNullOrEmpty($Caching)){$disk.Caching = $Caching}
    if(-not [string]::IsNullOrEmpty($SourceImageName)){$disk.SourceImageName = $SourceImageName}
    if(-not [string]::IsNullOrEmpty($OperatingSystem)){$disk.OperatingSystem = $OperatingSystem}
    if(-not [string]::IsNullOrEmpty($DiskSize)){$disk.DiskSize = $DiskSize}

    Invoke-Expression -Command $commandString
  }
}
#Attach-ARMClassicVMDisk -Subscription production -ResourceGroup prod-service -VMName prodsvcuswest -VHDURI "http://blob.core.windows.net/storage/datadisk.vhd" -LUN 1

function Detach-ARMClassicVMDisk() {
  param (
    [parameter(Mandatory=$true,HelpMessage="ID or displayName of the Azure subscription.")]    
    [string]$Subscription, 
    
    [parameter(Mandatory=$true,HelpMessage="Name of the resource group that contains the VM from which you wish to detach a disk.")]    
    [string]$ResourceGroup = $null, 

    [parameter(Mandatory=$true,HelpMessage="Name of the VM from which you wish to detach a disk.")]    
    [string]$VMName, 
                
    [parameter(Mandatory=$true,HelpMessage="LUN of the disk that you wish to detach.")]    
    [int]$LUN, 
            
    [parameter(Mandatory=$false,HelpMessage="Silent mode")]    
    [switch] $Silent
  )
  PROCESS {
    $commandString = "Operate-ARMResource -ResourceProvider microsoft.classiccompute -ResourceType virtualMachines -APIVersion 2014-06-01 -Action detachDisk -ActionResult default -Data `$disk"
    $commandString += [string]::Format(" -Subscription {0}", $Subscription)
    $commandString += [string]::Format(" -ResourceGroup {0}", $ResourceGroup)
    $commandString += [string]::Format(" -ResourceIdentifier {0}", $VMName)
    if($Silent) {$commandString += " -Silent"}
    $disk = "" | select "DiskName", "VHDURI", "Caching", "SourceImageName", "OperatingSystem", "DiskSize", "LUN"
    $disk.LUN = $LUN

    Invoke-Expression -Command $commandString
  }
}