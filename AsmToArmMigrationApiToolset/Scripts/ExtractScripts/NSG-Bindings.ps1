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
$vnetConfig = [xml](Get-AzureVNetConfig).XMLConfiguration
$virtualNetworkSubnets = $vnetConfig | Select-Xml "//Any:VirtualNetworkSite[@name='$virtualNetworkName']/Any:Subnets/*" -Namespace @{ Any = $vnetConfig.DocumentElement.Attributes["xmlns"].Value }

if(-not $virtualNetworkSubnets) {
  Write-Warning 'Could not find configuration for virtual network'
  exit -1
}

$title = "$virtualNetworkName subnets migration"
$yesOption = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Include subnet in migration."
$noOption = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Exclude subnet from migration."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yesOption, $noOption)


"Subnets on vnet: " + $virtualNetworkName | Out-File (".\nsg_" + $subscriptionID + ".txt")
"" | Out-File -Append (".\nsg_" + $subscriptionID + ".txt")

$virtualNetworkSubnets.Node | % {
  $subnetName = $_.name

  $message = "Do you want to include subnet '$subnetName' in migration ?"
  $result = $host.ui.PromptForChoice($title, $message, $options, 0) 

  switch ($result)
  {
    0 {
      $subnetName | Out-File -Append (".\nsg_" + $subscriptionID + ".txt")
      Get-AzureNetworkSecurityGroupAssociation -VirtualNetworkName $virtualNetworkName -SubnetName $subnetName -ErrorAction Continue | Out-File -Append (".\nsg_" + $subscriptionID + ".txt")
      Write-Host "'$subnetName' have been included in migration"
    }
    1 { Write-Host "'$subnetName' have been excluded from migration" }
  }  
}