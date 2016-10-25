<#
Purpose: Extract the Network Security Groups and rules for an ASM virtual network.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $subscriptionID,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $virtualNetworkName
)

Select-AzureSubscription -SubscriptionId $subscriptionID

$groups = Get-AzureNetworkSecurityGroup

# First dump out all the NSG's defined for the subscription -- and each NSG's rules. One csv for each NSG.

foreach ($group in $groups)
{
   (Get-AzureNetworkSecurityGroup -Name $group.Name -Detailed).Rules | Export-csv -path (".\" + $group.Name + "_" + $subscriptionID + ".csv") 
}

# Now go through all subnets in the vnet, and show which NSG is associated to each subnet. Send this to a txt file.
# Edit this section. Follow the pattern. List the subnets in the vnet to be migrated as below.

"Subnets on vnet: " + $virtualNetworkName | Out-File (".\nsg_" + $subscriptionID + ".txt")
"" | Out-File -Append (".\nsg_" + $subscriptionID + ".txt")
"Subnet-1" | Out-File -Append (".\nsg_" + $subscriptionID + ".txt")
Get-AzureNetworkSecurityGroupAssociation -VirtualNetworkName $virtualNetworkName -SubnetName "Subnet-1" | Out-File -Append (".\nsg_" + $subscriptionID + ".txt")
"Subnet-2" | Out-File -Append (".\nsg_" + $subscriptionID + ".txt")
Get-AzureNetworkSecurityGroupAssociation -VirtualNetworkName $virtualNetworkName -SubnetName "Subnet-2" | Out-File -Append (".\nsg_" + $subscriptionID + ".txt")
