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
Write-Host "Success: Imported $VmMappingCsv . Build vm to SA mapping." -ForegroundColor Green

foreach($csvItem in $csvItems)
{
    Write-Host "checking $($csvItem.csname + "-Migrated") : $($csvItem.vmname)"
  
    $vm = Get-AzureRmVm -Name $csvItem.vmname  -ResourceGroupName $($csvItem.csname + "-Migrated")
    if ($vm -eq $null)
    {
        Write-Host "$($csvItem.csname + "-Migrated") not found" -ForegroundColor Magenta
        continue
    }
    $vm2 = Get-AzureRmVM -Name $csvItem.vmname  -ResourceGroupName $($csvItem.csname + "-Migrated") -Status
    if ($vm2.Statuses[1].Code -ne "PowerState/running")
    {
        continue
    }

    foreach ($n in $vm.NetworkInterfaceIDs)
    {
        $r = Get-AzureRmResource -ResourceId $n
        $ni = Get-AzureRmNetworkInterface -ResourceGroupName $r.ResourceGroupName -Name $r.ResourceName
        
        if ($ni.Primary)
        {
            if ($csvItem.ip -ne $ni.IpConfigurations[0].PrivateIpAddress)
            {
                Write-Host "$($csvItem.csname + "-Migrated") : $($csvItem.vmname) : ARM IP: $($ni.IpConfigurations[0].PrivateIpAddress) doesn't match former classic primary IP" -ForegroundColor Magenta
            }
        }
        else
        {
            if ($csvItem.secondarynics.Contains($ni.IpConfigurations[0].PrivateIpAddress)) {}
            else
            {
                Write-Host "$($csvItem.csname + "-Migrated") : $($csvItem.vmname) : ARM IP: $($ni.IpConfigurations[0].PrivateIpAddress) doesn't match former classic secondary IP" -ForegroundColor Magenta
            }
        }
    }
}

Write-Host "Script completed" -ForegroundColor Green