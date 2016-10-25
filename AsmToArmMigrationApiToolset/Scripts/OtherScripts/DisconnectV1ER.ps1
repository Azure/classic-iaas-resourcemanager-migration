<#
Purpose: Script to disconnect a V1 ER circuit from the vnet, and reconnect the vnet back to ER. Useful scripts if there’s a desire to separate the ExpressRoute functionality from the actual ARM migration.
#>


Param
(
    [Parameter(Mandatory=$true)]
	[string]$SubscriptionId,         # subscription ID
    [Parameter(Mandatory=$true)]
	[string]$VNetName,               # V1 vnet name (connected to ER) to be migrated to ARM
    [Parameter(Mandatory=$true)]
	[string]$ErServiceKey1,          # ER circuit service key 1 (all ER params can be retrieved from the new Azure portal)
    [Parameter(Mandatory=$false)]
	[string]$ErServiceKey2           # ER circuit service key 2 (optional)
    
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
    Write-Log "Starting Disconnect Vnet with w/ER circuit for the vNet: $VNetName"

    Write-Log "Importing ER modules"
    Import-Module -Name "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Azure.psd1" -ErrorAction Stop 
    Import-Module -Name "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\ExpressRoute\ExpressRoute.psd1" -ErrorAction Stop 

    Select-AzureSubscription -SubscriptionId $SubscriptionId
    
    Get-AzureVNetGateway -VNetName $VNetName -ErrorAction Stop
    
    Write-Log "Removing the ExpressRoute circuit 1 link for the classic vNet: $VNetName"
    Remove-AzureDedicatedCircuitLink -VNetName $VNetName -ServiceKey $ErServiceKey1 -Force -ErrorAction Stop
    Write-Log "Success" -color "Green"

    if ($ErServiceKey2 -ne "")
    {
        Write-Log "Removing the ExpressRoute circuit 2 link for the classic vNet: $VNetName"
        Remove-AzureDedicatedCircuitLink -VNetName $VNetName -ServiceKey $ErServiceKey2 -Force -ErrorAction Stop
        Write-Log "Success" -color "Green"
    }

    Write-Log "Removing the classic ER gateway for the vNet: $VNetName"
    Remove-AzureVNetGateway -VNetName $VNetName -ErrorAction Stop
    Write-Log "Success. Script Completed. Ready for testing." -color Green
}
catch
{
    Write-Log "Error Following exception was caught $($_.Exception.Message)" -color "Red"
}


