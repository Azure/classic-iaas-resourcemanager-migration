# Purpose: DRY RUN -- any enviornment. This script will prepare then abort a migration.
# Very useful script to dry run test an actual vnet that is planned for migration. No disconnection from ER or VPN is required. Simply prepare and abort a migration to flush out issues, as discussed above.
#
# Assumption 1: Logged into Azure with Add-AzureAccount
# Disconnection from an ER circuit is not required to run this script
#
# Please run Move-AzureVirtualNetwork -Validate before running this script, and ensure no errors.

Param
(
    [Parameter(Mandatory=$true)]         
    [string]$SubscriptionID,
    [Parameter(Mandatory=$true)]          
    [string]$VNetName  
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


Write-Log "Starting Classic to ARM Migration dry-run for the vNet: $VNetName"
Select-AzureSubscription -SubscriptionId $SubscriptionId

while ($TRUE)
{
    try
    {
        Write-Log "Starting Prepare...."
        Get-Date
        Move-AzureVirtualNetwork -VirtualNetworkName $VNetName -Prepare -ErrorAction Stop
        Get-Date
        break
    }
    catch
    {
        Write-Log "Error in Prepare phase. Retry is an option : $($_.Exception.Message)" -color Yellow
        $errmsg = "Error preparing the vnet move to ARM -- dry run. Following exception was caught:`n`n$($_.Exception.Message)"
        $out = [System.Windows.Forms.MessageBox]::Show($errmsg, "Yes-Retry or No-ExitScript?" , 4) 
        if ($out -eq "No" ) 
        {
            Exit 
        }
    }
}

Write-Log "Success with Prepare phase" -color "Green"

# pause and validate prepare
$out = [System.Windows.Forms.MessageBox]::Show("Prepare has completed. Validate ARM metadata. Press Yes to continue and abort/rollback." , "Continue with Abort - YES, or ExitScript - NO?" , 4) 
if ($out -eq "No" ) 
{
    Exit 
}

Write-Log "Completing the dry-run abort for the vNet: $VNetName. Abort phase."

while ($TRUE)
{
    try
    {
        Write-Log "Starting Abort...."
        Get-Date
        Move-AzureVirtualNetwork -VirtualNetworkName $VNetName -Abort -ErrorAction Stop
        Get-Date
        break
    }
    catch
    {
        Write-Log "Error in Abort phase. Retry is an option : $($_.Exception.Message)" -color Yellow
        $errmsg = "Error aborting the vnet move to ARM -- dry run. Following exception was caught:`n`n$($_.Exception.Message)" 
        $out = [System.Windows.Forms.MessageBox]::Show($errmsg, "Yes-Retry or No-ExitScript?" , 4) 
        if ($out -eq "No" ) 
        {
            Exit 
        }
    }
}

Write-Log "Success with Abort phase -- the vNet migration to ARM has been aborted" -color Green
Write-Log ""

Write-Log "Success. Script Completed. Ready for testing." -color Green
Get-Date