<#
    © 2015 Microsoft Corporation. All rights reserved. This sample code is not supported under any Microsoft standard support program or service. 
    This sample code is provided AS IS without warranty of any kind. Microsoft disclaims all implied warranties including, without limitation, 
    any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance 
    of the sample code and documentation remains with you. In no event shall Microsoft, its authors, or anyone else involved in the creation, 
    production, or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of business 
    profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the 
    sample scripts or documentation, even if Microsoft has been advised of the possibility of such damages.
#>


function New-VirtualNetworkResource
{
    Param
    (
        $Name,
        $Location,
        [string[]]
        $AddressSpacePrefixes,
        $Subnets
    )

    $addressSpace = @{'addressPrefixes' = $AddressSpacePrefixes;}

    $createProperties = @{"addressSpace" = $addressSpace; 'subnets'= $subnets;}

    $resource = New-ResourceTemplate -Type "Microsoft.Network/virtualNetworks" -Name $Name `
        -Location $Location -ApiVersion $Global:apiVersion -Properties $createProperties

    return $resource
}


function New-VirtualNetworkSubnet
{
    Param
    (
        $Name,
        $AddressPrefix,
        $NetworkSecurityGroup
    )

    $properties = @{'addressPrefix' = $addressPrefix}
    if ($networkSecurityGroup)
    {
        $properties.Add('networkSecurityGroup', @{'id' = $networkSecurityGroup})
    }

    $subnet = @{'name' = $Name; 'properties' = $properties}
    
    return $subnet
}

function New-NetworkSecurityGroupResource
{
    Param
    (
        $Name,
        $Location,
        [Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVMRoleContext]
		$VM
    )

    # Report all load balanced endpoints to the user so that they know that we do not currently handle these endpoints
    $VM | Get-AzureEndpoint | Where-Object {$_.LBSetName -ne $null} | ForEach-Object { Write-Warning $("Endpoint {0} is skipped as load balanced endpoints are NOT currently supported by this cmdlet. You can still manually recreate this endpoint in ARM using the following details: {1}" -f $_.Name, $(ConvertTo-Json $_)) }

    # Walk through all endpoints and filter those that are assigned to a load balancer set (we do not currently handle these endpoints)
    $endpoints =  $VM | Get-AzureEndpoint | Where-Object {$_.LBSetName -eq $null}
    
    # Start translating endpoints to NSG security rules
    $securityRules = @()
    $priority = 1000

    foreach ($endpoint in $endpoints)
    {
        $securityRules += @{'name' = $endpoint.Name; 
                            'properties' = @{ 'priority'= $priority;
                                              'sourceAddressPrefix' = '*';
                                              'protocol' = $endpoint.Protocol;
                                              'destinationPortRange' = $endpoint.LocalPort;
                                              'access' = 'Allow';
                                              'direction' = 'inbound';
                                              'sourcePortRange' = '*';
                                              'destinationAddressPrefix' = '*'
                                        }}
        $priority += 500
    }

    $createProperties = @{'securityRules' = $securityRules}
        
    $resource = New-ResourceTemplate -Type "Microsoft.Network/networkSecurityGroups" -Name $Name `
            -Location $Location -ApiVersion '2015-06-15' -Properties $createProperties

    return $resource
}


function New-NetworkInterfaceResource
{
    Param
    (
        $Name,
        $Location,
        [string]
        $SubnetReference,
        [string]
        $NsgReference,
        [string]
        $PrivateIpAddress,
        [string]
        $PublicIpAddressName,
        [string[]]
        $Dependencies
    )
    
    $subnet = @{'id' = $SubnetReference;}
    $ipConfigurations = @{ 'subnet' = $subnet;}

    if($PublicIpAddressName)
    {
        $publicIPAddress = @{'id' = '[resourceId(''Microsoft.Network/publicIPAddresses'',''{0}'')]' -f $PublicIpAddressName;}
        $ipConfigurations.Add('publicIPAddress', $publicIPAddress);
    }

    # Static and dynamic IPs will result in different property sets
    if($PrivateIpAddress)
    {
        $ipConfigurations.Add('privateIPAllocationMethod', 'Static');
        $ipConfigurations.Add('privateIPAddress', $PrivateIpAddress);
    }
    else
    {
        $ipConfigurations.Add('privateIPAllocationMethod', 'Dynamic');
    }

    $ipConfigName = "{0}_config1" -f $Name
    $createProperties = @{'ipConfigurations' =  @(@{'name' =  $ipConfigName; 'properties' = $ipConfigurations;}); 
                           'networkSecurityGroup' = @{'id' = $NsgReference}}
    
    $resource = New-ResourceTemplate -Type "Microsoft.Network/networkInterfaces" -Name $Name `
        -Location $Location -ApiVersion $Global:apiVersion -Properties $createProperties -DependsOn $Dependencies

    return $resource
}

function New-PublicIpAddressResource
{
    Param
    (
        $Name,
        $Location,
        [string]
        $AllocationMethod,
        [string]
        $DnsName
    )
    
    $dnsSettings = @{'domainNameLabel' = $DnsName}
    
    $createProperties = @{'publicIPAllocationMethod' = $AllocationMethod; 'dnsSettings' = $dnsSettings}

    $resource = New-ResourceTemplate -Type "Microsoft.Network/publicIPAddresses" -Name $Name `
        -Location $Location -ApiVersion $Global:apiVersion -Properties $createProperties

    return $resource
}

function Get-AvailableAddressSpace
{
    [OutputType([string])]
    Param
    (
        [string[]]
        $addressSpaces
    )

    if ($addressSpaces -eq $null -or $addressSpaces.Length -eq 0)
    {
        # Return default, 10.0.0.1/16 network
        return "10.0.0.0/16"
    }

    $hostRanges = @()
    $addressSpaces | ForEach-Object {Get-HostRange $_} | Sort-Object -Property 'NetworkInt' | ForEach-Object {$hostRanges += $_}

    $minRange = [uint32]::MinValue
    $firstRangeNetwork = $hostRanges[0].Network.Split('.')
    if ($firstRangeNetwork[0] -eq 10)
    {
        $minRange = [uint32]([uint32]10 -shl 24) 
    } elseif ($firstRangeNetwork[0] -eq 172 -and $firstRangeNetwork[1] -eq 16)
    {
        $minRange = [uint32]([uint32]172 -shl 24) + [uint32]([uint32]16 -shl 16) 
    } elseif ($firstRangeNetwork[0] -eq 192 -and $firstRangeNetwork[1] -eq 168)
    {
        $minRange = [uint32]([uint32]192 -shl 24) + [uint32]([uint32]168 -shl 16) 
    } else
    {
        throw "Invalid IP range. Must conform rfc1918"
    }
     
    $networkRanges = @()
    $networkRanges += Get-FirstAvailableRange -Start $minRange -End ($hostRanges[0].NetworkInt - 1)

    for ($i = 0; $i -lt $hostRanges.Length - 1; $i++)
    { 
        $networkRanges += Get-FirstAvailableRange -Start ($hostRanges[$i].BroadcastInt + 1)  -End ($hostRanges[$i + 1].NetworkInt - 1)
    }

    $maxRange = [uint32]::MinValue
    $lastRangeNetwork = $hostRanges[$hostRanges.Length - 1].Network.Split('.')
    if ($lastRangeNetwork[0] -eq 10)
    {
        $maxRange = [uint32](([uint32]10 -shl 24) + ([uint32]255 -shl 16) + ([uint32]255 -shl 8) + [uint32]255) + 1        
    } elseif ($lastRangeNetwork[0] -eq 172 -and $lastRangeNetwork[1] -eq 16)
    {
        $maxRange = [uint32](([uint32]172 -shl 24) + ([uint32]31 -shl 16) + ([uint32]255 -shl 8) + [uint32]255) + 1
    } elseif ($lastRangeNetwork[0] -eq 192 -and $lastRangeNetwork[1] -eq 168)
    {
        $maxRange = [uint32](([uint32]192 -shl 24) + ([uint32]168 -shl 16) + ([uint32]255 -shl 8) + [uint32]255) + 1
    } else
    {
        throw "Invalid IP range. Must conform rfc1918"
    }

    $networkRanges += Get-FirstAvailableRange -Start ($hostRanges[$hostRanges.Length - 1].BroadcastInt + 1) -End $maxRange

    if (-not $networkRanges -or $networkRanges.Length -le 0)
    {
        return ""
    }

    $firstRange = $networkRanges[0]
    return "{0}/{1}" -f $firstRange.Network, $(Get-PrefixForNetwork $firstRange.Hosts)

}

function Get-HostRange
{
    [OutputType([PSCustomObject])]
    Param
    (
        [string]
        $cidrBlock
    )

    $network, [int]$cidrPrefix = $cidrBlock.Split('/')
    if ($cidrPrefix -eq 0)
    {
        throw "No network prefix is found"
    }

    [uint32] $uintNetwork = Get-IntIp $network
    
    $networkMask = (-bnot [uint32]0) -shl (32 - $cidrPrefix)
    $broadcast = $uintNetwork -bor ((-bnot $networkMask) -band [uint32]::MaxValue) 

    $networkRange = @{'Network' = Get-DecimalIp $uintNetwork; 'Broadcast' = Get-DecimalIp $broadcast; `
        'Hosts' = ($broadcast - $uintNetwork - 1); 'StartHost' = Get-DecimalIp ($uintNetwork + 1); 'EndHost' = Get-DecimalIp($broadcast - 1); `
        'BroadcastInt' = $broadcast; 'NetworkInt' = $uintNetwork}
    return [PSCustomObject] $networkRange
}

function Get-DecimalIp
{
    [OutputType([string])]
    Param
    (
        [uint32]
        $uintIp
    )

    return "{0}.{1}.{2}.{3}" -f [int]($uintIp -shr 24), [int](($uintIp -shr 16) -band 255), [int](($uintIp -shr 8) -band 255), [int]($uintIp -band 255)
}

function Get-IntIp
{
    [OutputType([uint32])]
    Param(
        [string]
        $ipString
    )

    $dottedDecimals = $ipString.Split('.')
    return [uint32]([uint32]$dottedDecimals[0] -shl 24) + [uint32]([uint32]$dottedDecimals[1] -shl 16) + [uint32]([uint32]$dottedDecimals[2] -shl 8) + [uint32]$dottedDecimals[3] 
}

function Get-FirstAvailableRange
{
    [OutputType([PSCustomObject])]
    Param
    (
        [uint32]
        $Start,
        [uint32] 
        $End
    ) 
    
    if ($Start -ge $End)
    {
        return @()
    }

    $blockSize = 512
    $rangesCount = [math]::Floor(($End - $Start) / $blockSize)
    $ranges = @()
    if ($rangesCount -gt 0) 
    {
        #for ($i = 0; $i -lt $rangesCount; $i++)
        # Just grab the first range, but leave the above for reference. The potential number of ranges can 
        # be quite large, so go for this optimization for the small block sizes.
        for ($i = 0; $i -lt 1; $i++)
        { 
            $uintNetwork = ($start + ($i * $blockSize))
            $broadcast = ($start + ($i + 1) * $blockSize -1)
            $networkRange = @{'Network' = Get-DecimalIp $uintNetwork; 'Broadcast' = Get-DecimalIp $broadcast; `
            'Hosts' = ($broadcast - $uintNetwork - 1); 'StartHost' = Get-DecimalIp ($uintNetwork + 1); 'EndHost' = Get-DecimalIp($broadcast - 1); `
            'BroadcastInt' = $broadcast; 'NetworkInt' = $uintNetwork}
            $ranges += $networkRange
        }
    }

    $remainingRange = ($End - $Start) % $blockSize

    if ($remainingRange -gt 0) {
        $uintNetwork = $start
        $broadcast = $start + $remainingRange
        $networkRange = @{'Network' = Get-DecimalIp $uintNetwork; 'Broadcast' = Get-DecimalIp $broadcast; `
        'Hosts' = ($broadcast - $uintNetwork - 1); 'StartHost' = Get-DecimalIp ($uintNetwork + 1); 'EndHost' = Get-DecimalIp($broadcast - 1); `
        'BroadcastInt' = $broadcast; 'NetworkInt' = $uintNetwork}
        $ranges += $networkRange
    }

    if($ranges.Count -gt 0)
    {
        return $ranges[0]
    }
}

function Get-PrefixForNetwork
{
    [OutputType([int])]
    Param
    (
        [uint32]
        $NetworkSize
    )

    $NetworkSize++
    
    $netPrefix = 0
    do
    {
        $NetworkSize = $NetworkSize -shr 1
        $netPrefix++
    }
    until ($NetworkSize -eq 0)

    return (32 - $netPrefix)
}

function Test-SubnetInAddressSpace
{
    [OutputType([boolean])]
    Param(
        $SubnetPrefix,
        $AddressSpace
    )

    $subnetIp, [int]$subnetBits = $SubnetPrefix.Split('/')
    $AddressSpaceIp, [int]$addressSpaceBits = $AddressSpace.Split('/')

    $subnetMask = (-bnot [uint32]0) -shl (32 - $subnetBits)
    $addressSpaceMask = (-bnot [uint32]0) -shl (32 - $addressSpaceBits)
    
    $intSubnet = Get-IntIp $subnetIp
    $intAddressSpace = Get-IntIp $AddressSpaceIp

    return (($intSubnet -band $addressSpaceMask) -eq $intAddressSpace)
}

