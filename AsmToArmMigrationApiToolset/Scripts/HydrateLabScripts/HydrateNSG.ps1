<#
Purpose: Recreate the associated NSGs and rules in a simulated lab virtual network that matches the production virtual network. The vNet is built from the exported network configuration file, and this scripts add NSGs and rules to the vNet. 
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $SubscriptionID,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $VirtualNetworkName,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $SubnetName,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $Region,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $NSG_Name,

    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $FilePath
)

Select-AzureSubscription -SubscriptionId $SubscriptionID

Write-Host "Creating $NSG_Name ...." 
$nsg = New-AzureNetworkSecurityGroup -Name $NSG_Name -Location $Region
$nsg | Set-AzureNetworkSecurityGroupToSubnet -VirtualNetworkName $VirtualNetworkName -SubnetName $SubnetName
Write-Host "NSG: $NSG_Name created and associated to subnet: $SubnetName." -ForeGroundColor Green

Write-Host "Attempting to open $FilePath ." 
$rules = Import-Csv $FilePath
Write-Host "Success: Imported $FilePath . Begin creating rules." -ForeGroundColor Green

foreach($rule in $rules)
{
    if ($rule.Priority -gt 4096) { continue }

    Write-Host "adding a rule to the NSG"
    $nsg | Set-AzureNetworkSecurityRule -Name $rule.Name -Type $rule.Type -Priority $rule.Priority -Action $rule.Action -SourceAddressPrefix $rule.SourceAddressPrefix  -SourcePortRange $rule.SourcePortRange -DestinationAddressPrefix $rule.DestinationAddressPrefix -DestinationPortRange $rule.DestinationPortRange -Protocol $rule.Protocol 
    Write-Host "Successfully added rule $($rule.Name)" -ForeGroundColor Green
}

Write-Host "Done. Success adding NSG rules" -ForeGroundColor Green


