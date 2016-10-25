<#
 Purpose: Scripts to help validate the metadata post ARM migration. These scripts will use the metadata captured in the ASM CSV and compare it to the post migration ARM metadata.
#>

Param
(
    [Parameter(Mandatory=$true)]         # subscription id
    [string]$SubscriptionID,
    [Parameter(Mandatory=$true)]          # csv containing two columns, vmname and newstorageaccount. This will map the vm to it's new storage account for balancing disks
    [string]$VmMappingCsv  
)

Select-AzureRmSubscription -SubscriptionId $SubscriptionID

$csvItems = Import-Csv $VmMappingCsv
Write-Host "Success: Imported $VmMappingCsv . Build vm to SA mapping." -BackgroundColor Green

foreach($csvItem in $csvItems)
{
    $rgname = $csvItem.csname + "-Migrated"
    $vm1 = Get-AzureRmVM -ResourceGroupName $rgname -Name $csvItem.vmname
    $vm2 = Get-AzureRmVM -ResourceGroupName $rgname -Name $csvItem.vmname -Status

  <#  $ex = ""
    if ($vm2.VMAgent -ne $null)
    {
        foreach ($extension in $vm2.VMAgent.ExtensionHandlers)
        {
            if ($extension.Type -ne "Microsoft.Compute.BGInfo")
            {
                $ex = $ex + $extension.Type
            }
        }
    }#>

    Write-Host ""
    Write-Host "$($csvItem.vmname) --------------------------------------------------------------------------"
    Write-Host "Status: $($csvItem.status + "," + $csvItem.running) | $($vm2.Statuses[1].Code)"
    Write-Host "Agent: $($csvItem.agent) | $($vm2.VMAgent.Statuses[0].DisplayStatus)"
    Write-Host "Data Disk Count: $($csvItem.datadisks) | $($vm1.DataDiskNames.Count)"
    #Write-Host "Extensions: $($csvItem.extensions) | $ex"
}

Write-Host ""
Write-Host "Completed" -BackgroundColor Green