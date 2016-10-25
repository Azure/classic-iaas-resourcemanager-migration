# Purpose:
#   This script will migrate an ExpressRoute connected v1 virtual network to ARM using the ARM migration api, and reconnect the circuit(s) after migration is completed.
#   Well tested script to do the actual migration of an Express Route connected vnet to ARM.  The script disconnects the vnet from ER, removes the gateway, prepares the migration, commits the migration, then reconnects to the ER circuit. Designed to handle more than one linked ER circuit. Script will also handle expected migration api transient errors that can be safely retried. Lots of error handling and logging.
#
# Version: 1.6  2016/09/23
#
# Assumption1: The ER circuits have been moved to ARM and configured for coexistence with ASM -- see article
#    https://azure.microsoft.com/en-us/documentation/articles/expressroute-howto-move-arm/
#
# Assumption2: Must be logged into both classic and ARM with Add-AzureAccount and Add-AzureRmAccount
#
# Assumption3: The script will only migrate a vnet connected to 1 or 2 circuits. If more circuits, modify the script.
#
#
# Example invoke of the cmdlet
#   .\MoveErConnectedVnet.ps1 -SubscriptionId "132fb7b3-f10c-4a20-a84f-a0081215007a" -VNetName AcnErTest -ErServiceKey1 "30db8742-114c-47d6-bd1f-49572fd78041" -VNetGatewaySubnetName "GatewaySubnet" -AzureRegion "Central US" -ErCircuitName1 "AcnTestCircuit" -ErCircuitRG1 "ERCircuit"
#


Param
(
    [Parameter(Mandatory=$true)]
	[string]$SubscriptionId,         # subscription ID
    [Parameter(Mandatory=$true)]
	[string]$VNetName,               # V1 vnet name (connected to ER) to be migrated to ARM
    [Parameter(Mandatory=$true)]
    [string]$VNetGatewaySubnetName,  # V1 vnet gateway subnet -- likely called "GatewaySubnet"
    [Parameter(Mandatory=$true)]
	[string]$ErServiceKey1,          # ER circuit service key 1 (all ER params can be retrieved from the new Azure portal)
    [Parameter(Mandatory=$true)]
	[string]$ErCircuitName1,         # V2 ER circuit 1 name
    [Parameter(Mandatory=$true)]
	[string]$ErCircuitRG1,           # V2 ER circuit 1 resource group name
    [Parameter(Mandatory=$false)]
	[string]$ErServiceKey2,          # ER circuit service key 2 (optional)
    [Parameter(Mandatory=$false)]
	[string]$ErCircuitName2,         # V2 ER circuit 2 name  (optional)
    [Parameter(Mandatory=$false)]
	[string]$ErCircuitRG2            # V2 ER circuit 2 resource group name (optional)
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
    Write-Log "Starting Classic to ARM Migration w/ER circuit for the vNet: $VNetName"
    Write-Log "Importing ER modules"
    Import-Module -Name "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Azure.psd1" -ErrorAction Stop 
    Import-Module -Name "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\ExpressRoute\ExpressRoute.psd1" -ErrorAction Stop 

    Select-AzureSubscription -SubscriptionId $SubscriptionId
    Select-AzureRmSubscription -SubscriptionId $SubscriptionId

    $oldgw = Get-AzureVNetGateway -VNetName $VNetName -ErrorAction Stop
    $sku = $oldgw.GatewaySKU 
    Write-Log "Classic gateway sku: $sku"
    if ($sku -eq "Default") {$sku = "Basic"}

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
    Write-Log "Success" -color "Green"

    Write-Log "Pausing 5 minutes to ensure all the ER gateway resources are cleaned up"
    Start-Sleep 300

    while ($TRUE)
    {
        try
        {
            Write-Log "Beginning the migration to ARM for the vNet: $VNetName. Prepare phase started."
            Move-AzureVirtualNetwork -VirtualNetworkName $VNetName -Prepare -ErrorAction Stop
            break
        }
        catch
        {
            Write-Log "Error in Prepare phase. Retry is an option. Please inspect error : $($_.Exception.Message)" -color Yellow
            $errmsg = "Error preparing the vnet move to ARMn. Following exception was caught:`n`n$($_.Exception.Message)"
            $out = [System.Windows.Forms.MessageBox]::Show($errmsg, "Yes-Retry or No-ExitScript?" , 4) 
            if ($out -eq "No" ) 
            {
                Exit 
            }
        }
    }    
    
    Write-Log "Success with Prepare phase" -color "Green"
  
    # stop and validate prepare
    $out = [System.Windows.Forms.MessageBox]::Show("Prepare has completed. Validate ARM metadata. Press Yes to continue and remove ExpressRoute circuit and commit the migration." , "Continue with Commit - YES, ExitScript - NO?" , 4) 
    if ($out -eq "No" ) 
    {
        Exit 
    }

    while ($TRUE)
    {
        try
        {
            Write-Log "Completing the migration to ARM for the vNet: $VNetName. Commit phase started."
            Move-AzureVirtualNetwork -VirtualNetworkName $VNetName -Commit -ErrorAction Stop
            break
        }
        catch
        {
            Write-Log "Error in Commit phase. Retry is an option. Please inspect error : $($_.Exception.Message)" -color Yellow
            $errmsg = "Error committing the vnet move to ARM. Following exception was caught:`n`n$($_.Exception.Message)"
            $out = [System.Windows.Forms.MessageBox]::Show($errmsg, "Yes-Retry or No-ExitScript?" , 4) 
            if ($out -eq "No" ) 
            {
                Exit 
            }
        }
    }    

    Write-Log "Success with Commit phase -- the vNet has been migrated to ARM" -color Green
    Write-Log ""

    Write-Log "Pausing 60 seconds to ensure all operations are complete"
    Start-Sleep 60

    Write-Log "Beginning the process to rebind the migrated ARM vNet: $VNetName-Migrated to the ExpressRoute circuit" 
    Write-Log "Retrieve the v2 primary circuit and v2 vNet"
    $circuit1 = Get-AzureRmExpressRouteCircuit -Name $ErCircuitName1 -ResourceGroupName $ErCircuitRG1 -ErrorAction Stop
    $vnet = Get-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $($VNetName + "-Migrated") -ErrorAction Stop
    
    Write-Log "Success" -color Green

    Write-Log "Create a public IP and gateway config"
    $gwpip= New-AzureRmPublicIpAddress -Name $($VNetName + "-GwPubIp") -ResourceGroupName $($VNetName + "-Migrated") -Location $vnet.Location -AllocationMethod Dynamic -ErrorAction Stop
    # The migration api will make the v2 gateway subnet
    $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $VNetGatewaySubnetName -VirtualNetwork $vnet -ErrorAction Stop
    $gwipconfig = New-AzureRmVirtualNetworkGatewayIpConfig -Name $($VNetName + "-GwPubIpConfig") -SubnetId $subnet.Id -PublicIpAddressId $gwpip.Id -ErrorAction Stop
    Write-Log "Success setting up ER dependent resources." -color "Green"

    Write-Log "Create the v2 vNet Gateway...this can take a number of minutes"
    $gw = New-AzureRmVirtualNetworkGateway -Name $($VNetName + "-Gw") -ResourceGroupName $($VNetName + "-Migrated") -Location $vnet.Location -IpConfigurations $gwipconfig -GatewayType ExpressRoute -GatewaySku $sku -ErrorAction Stop
    Write-Log "Success creating the v2 gateway" -color "Green"

    Write-Log "Finally, create a connection between the vNet and ER circuit"
    New-AzureRmVirtualNetworkGatewayConnection -Name $($VNetName + "-GwConn") -ResourceGroupName $($VNetName + "-Migrated")  -Location $vnet.Location -VirtualNetworkGateway1 $gw -PeerId $circuit1.Id -ConnectionType ExpressRoute -ErrorAction Stop
    Write-Log "Success creating the connection. ER primary circuit is now connected to the vnet" -color "Green"

    if ($ErCircuitName2 -ne "")
    {
        Write-Log "A secondary circuit exists. Retrieve the v2 secondary circuit"
        $circuit2 = Get-AzureRmExpressRouteCircuit -Name $ErCircuitName2 -ResourceGroupName $ErCircuitRG2 -ErrorAction Stop
        Write-Log "Retrieved secondary circuit. Now link the circuit to the vnet." -color "Green"

        Write-Log "Create a connection between the vNet and the secondary ER circuit"
        New-AzureRmVirtualNetworkGatewayConnection -Name $($VNetName + "-GwConn2") -ResourceGroupName $($VNetName + "-Migrated")  -Location $vnet.Location -VirtualNetworkGateway1 $gw -PeerId $circuit2.Id -ConnectionType ExpressRoute -ErrorAction Stop
        Write-Log "Success creating the connection. ER secondary circuit is now connected to the vnet" -color "Green"
    }

    Write-Log "Success. Script Completed. Ready for testing." -color Green
}
catch
{
    Write-Log "Error moving ER connected vnet to ARM. Following exception was caught $($_.Exception.Message)" -color "Red"
}


