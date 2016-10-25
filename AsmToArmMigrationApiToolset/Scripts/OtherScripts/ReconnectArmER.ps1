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
    [string]$VNetGatewaySubnetName,  # V1 vnet gateway subnet -- likely called "GatewaySubnet"
    [Parameter(Mandatory=$true)]
	[string]$AzureRegion,            # Azure region that contains the vnet (i.e. "East US", "East US 2", "Southeast Asia", etc)
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
    Write-Log "Starting ReconnectArmER script vNet: $VNetName"

    Write-Log "Importing ER modules"
    Import-Module -Name "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Azure.psd1" -ErrorAction Stop 
    Import-Module -Name "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\ExpressRoute\ExpressRoute.psd1" -ErrorAction Stop 

    Select-AzureRmSubscription -SubscriptionId $SubscriptionId

    $sku = "Standard"

    Write-Log "Beginning the process to rebind the migrated ARM vNet: $VNetName-Migrated to the ExpressRoute circuit" 

    Write-Log "Retrieve the v2 primary circuit and v2 vNet"
    $circuit1 = Get-AzureRmExpressRouteCircuit -Name $ErCircuitName1 -ResourceGroupName $ErCircuitRG1 -ErrorAction Stop
    $vnet = Get-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $($VNetName + "-Migrated") -ErrorAction Stop
    Write-Log "Success" -color Green

    Write-Log "Create a public IP and gateway config"
    $gwpip= New-AzureRmPublicIpAddress -Name $($VNetName + "-GwPubIp") -ResourceGroupName $($VNetName + "-Migrated") -Location $AzureRegion -AllocationMethod Dynamic -ErrorAction Stop
    # The migration api will make the v2 gateway subnet
    $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $VNetGatewaySubnetName -VirtualNetwork $vnet -ErrorAction Stop
    $gwipconfig = New-AzureRmVirtualNetworkGatewayIpConfig -Name $($VNetName + "-GwPubIpConfig") -SubnetId $subnet.Id -PublicIpAddressId $gwpip.Id -ErrorAction Stop
    Write-Log "Success" -color "Green"

    Write-Log "Create the v2 vNet Gateway...this can take a number of minutes"
    $gw = New-AzureRmVirtualNetworkGateway -Name $($VNetName + "-Gw") -ResourceGroupName $($VNetName + "-Migrated") -Location $AzureRegion -IpConfigurations $gwipconfig -GatewayType ExpressRoute -GatewaySku $sku -ErrorAction Stop
    Write-Log "Success creating the v2 gateway" -color "Green"

    Write-Log "Finally, create a connection between the vNet and ER circuit"
    New-AzureRmVirtualNetworkGatewayConnection -Name $($VNetName + "-GwConn") -ResourceGroupName $($VNetName + "-Migrated")  -Location $AzureRegion -VirtualNetworkGateway1 $gw -PeerId $circuit1.Id -ConnectionType ExpressRoute -ErrorAction Stop
    Write-Log "Success creating the connection. ER primary circuit is now connected to the vnet" -color "Green"

    if ($ErCircuitName2 -ne "")
    {
        Write-Log "A secondary circuit exists. Retrieve the v2 secondary circuit"
        $circuit2 = Get-AzureRmExpressRouteCircuit -Name $ErCircuitName2 -ResourceGroupName $ErCircuitRG2 -ErrorAction Stop
        Write-Log "Retrieved secondary circuit. Now link the circuit to the vnet." -color "Green"

        Write-Log "Create a connection between the vNet and the secondary ER circuit"
        New-AzureRmVirtualNetworkGatewayConnection -Name $($VNetName + "-GwConn2") -ResourceGroupName $($VNetName + "-Migrated")  -Location $AzureRegion -VirtualNetworkGateway1 $gw -PeerId $circuit2.Id -ConnectionType ExpressRoute -ErrorAction Stop
        Write-Log "Success creating the connection. ER secondary circuit is now connected to the vnet" -color "Green"
    }

    Write-Log "Success. Script Completed. Ready for testing." -color Green
    Get-Date
}
catch
{
    Write-Log "Error moving ER connected vnet to ARM. Following exception was caught $($_.Exception.Message)" -color "Red"
}


