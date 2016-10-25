<#
Purpose: Will quickly walk through and remove all of the migrated test lab vhds from the storage accounts in the lab subscription.  WARNING. Be careful to not remove items from storage accounts that you want to retain.
#>

Param(
	[string]$SubscriptionId, 
	[string]$storageAccountName = $null
)

$ErrorActionPreference = "stop"

function Write-Log
{
	param(
    [string]$logMessage,
	[string]$color="White"
    )

    $timestamp = ('[' + (Get-Date -Format hh:mm:ss.ff) + '] ')
	$message = $timestamp + $logMessage
    Write-Host $message -ForeGroundColor $color
}

Write-Log "Running: Selecting Subscription $SubscriptionId."
Select-AzureSubscription -SubscriptionId $SubscriptionId -Default | Out-Null

if($storageAccountName -eq $null -or $storageAccountName.Length -eq 0)
{
	$storageAccounts = Get-AzureStorageAccount
}
else
{
	$storageAccounts = Get-AzureStorageAccount -StorageAccountName $storageAccountName
}

$disks = Get-AzureDisk

$finalResult = @()

foreach($stgAccount in $storageAccounts)
{
	Write-Log "Running: Storage Account: $($stgAccount.StorageAccountName)."
	
	try {
		$container = Get-AzureStorageContainer -Context $stgAccount.Context -Name vhds
	}
	catch
	{
		Write-Log "Error  : Fetching vhds from the StorageAccount." -color "Red"
		continue
	}
	
	$blobs = $container.CloudBlobContainer.ListBlobs()
	
	foreach($blob in $blobs)
	{
		if (($blob.Name.Contains(".vhd")) -and ($blob.Name.Contains("Image")))
        {
            continue;
        }
        elseif ($blob.Name.Contains(".vhd"))
		{
			Write-Log "Blob: $($blob.Name)"
			# Check if there is a Disk Resource created out of this blob. Delete the disk resource before deleting the blob. 
			$disk = $disks.Where({$_.MediaLink -eq $blob.Uri.AbsoluteUri})
			if($disk -ne $null)
			{
				#Check if the disk is attached to a VM, if yes, we cannot delete this disk.
				if($disk.AttachedTo -eq $null)
				{
					Write-Log "Running : Remove-AzureDisk $($disk.DiskName) for Blob $($($blob.Uri).AbsoluteUri)"
					Remove-AzureDisk -DiskName $disk.DiskName -DeleteVHD
					Write-Log "Success : Remove-AzureDisk $($disk.DiskName) for Blob $($($blob.Uri).AbsoluteUri)"
				}
				else
				{
					$obj = New-Object System.Object;
					$obj | Add-Member -type NoteProperty -name SubscriptionId -value $SubscriptionId -Force;
					$obj | Add-Member -type NoteProperty -name StorageAccountName -value $stgAccount.StorageAccountName -Force;
					$obj | Add-Member -type NoteProperty -name BlobUri -value $blob.Uri.AbsoluteUri -Force;
					$obj | Add-Member -type NoteProperty -name DiskName -value $disk.DiskName -Force;
					$obj | Add-Member -type NoteProperty -name AttachedTo -value $disk.AttachedTo.RoleName -Force;
					
					$finalResult += $obj;
				}
			}
			else
			{
				Write-Log "Running : Delete Blob $($($blob.Uri).AbsoluteUri)"
				$blob.Delete()
				Write-Log "Success : Delete Blob $($($blob.Uri).AbsoluteUri)"
			}
		}
		else
		{
			Write-Log "Running : Delete Blob $($($blob.Uri).AbsoluteUri)"
			$blob.Delete()
			Write-Log "Success : Delete Blob $($($blob.Uri).AbsoluteUri)"
		}
	}
	
	Write-Log "Success: Storage Account: $($stgAccount.StorageAccountName)."
}

$finalResult | Export-Csv -Path "RemainingBlobs.csv";
Invoke-Item "RemainingBlobs.csv"
Write-Log "Output : RemainingBlobs.csv"
