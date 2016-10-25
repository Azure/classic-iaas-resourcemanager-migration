<#
Purpose: Script to add the extensions back after migrating to ARM. Additions will need to be made to this script for extensions to be added back.
#>

Param
(
    [Parameter(Mandatory=$true)]         # subscription id
    [string]$SubscriptionID,
    [Parameter(Mandatory=$true)]          # csv containing two columns, vmname and newstorageaccount. This will map the vm to it's new storage account for balancing disks
    [string]$Csv,
    [Parameter(Mandatory=$true)]          # name of the v2 storage account containing the vm extension script
    [string]$ScriptStorageAccount,
    [Parameter(Mandatory=$true)]         # resource group that holds the storage account
    [string]$StorageAccountRG      
)

$global:ScriptStartTime = (Get-Date -Format hh-mm-ss.ff)

if((Test-Path "Output") -eq $false)
{
	md "Output" | Out-Null
}

function Write-Log
{
	param(
        [string]$logMessage,
	    [string]$color="White"
    )

    $timestamp = ('[' + (Get-Date -Format hh:mm:ss.ff) + '] ')
	$message = $timestamp + $logMessage
    Write-Host $message -ForeGroundColor $color
	$fileName = "Output\Log-" + $global:ScriptStartTime + ".log"
	Add-Content $fileName $message
}


try
{
    Select-AzureRmSubscription -SubscriptionId $SubscriptionID

    $key = Get-AzureRmStorageAccountKey -ResourceGroupName $StorageAccountRG -Name $ScriptStorageAccount -ErrorAction Stop
    
    $csvItems = Import-Csv $Csv -ErrorAction Stop
    Write-Log "Success: Imported $Csv with all ASM metadata." -color Green

    foreach($csvItem in $csvItems)
    {
        #if (($csvItem.extensions -ne $null) -and ($csvItem.extensions -ne "") -and ($csvItem.extensions.Contains("Microsoft.Compute.CustomScriptExtension")))
        if ($csvItem.secondarynics.Trim() -ne "")
        {
            Write-Log "Set-AzureRmVMCustomScriptExtension for VM: $($csvItem.vmname)"
            $rg = Get-AzureRmResourceGroup -Name ($csvItem.csname + "-Migrated")
            Set-AzureRmVMCustomScriptExtension -VMName $csvItem.vmname -ResourceGroupName ($csvItem.csname + "-Migrated") -Location $rg.Location -ContainerName 'scripts' -Run 'DefaultRouteAdd.ps1' -FileName 'DefaultRouteAdd.ps1' -Name "CustomScriptExtension" -StorageAccountName $ScriptStorageAccount -StorageAccountKey $key[0].Value
            Write-Log "Success adding CustomScriptExtension to $($csvItem.vmname)" -color "Green"
        }
    }

    Write-Log "Success: Script Completed" -color "Green"
}
catch
{
    Write-Log "ERROR adding extensions. Following exception was caught $($_.Exception.Message)" -color "Red"
}



