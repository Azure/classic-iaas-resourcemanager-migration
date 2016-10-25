
<#
 
Purpose: Retrieves the status of an actual ARM migration using the Migration API Move-AzureVirtualNetwork cmdlet.  This will show each cloud service as its being prepared and committed to ARM.
This is a helper Script that can make REST API calls for and pull back metadata for all production deployments in a subscription

Two parameters 
    -- subscription ID
    -- CSV from metadata extract

Sample Command:

.\MetadataExtract.ps1 -subscriptionID 98f9a3cd-a241-4ad0-9057-8d8cff55ca1f
 
#>

[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$true)]         # subscription id
    [string]$SubscriptionID,
    [Parameter(Mandatory=$true)]         # csv containing the services to check migration status
    [string]$Csv    
)

Select-AzureSubscription -SubscriptionId $subscriptionID
$subscription = Get-AzureSubscription -SubscriptionId $subscriptionID

Write-Host "Importing csv"
$csvItems = Import-Csv $Csv -ErrorAction Stop

$csList = @{}
foreach ($item in $csvItems)
{
    if (!$csList.ContainsKey($item.csname))
    {
        $csList.Add($item.csname, $item.csname)
    }
}

#Write-Host "Selecting the cloud services within the subscription" 
#$services = Get-AzureService  #| Where-Object {$_.ServiceName.StartsWith("b")}  


if ($subscription) {
    if($ARMTenantAccessTokensARM.count -eq 0) {
        Connect-ARM
    }
    else {        
        if ($subscription) {
            $ARMSubscriptions.Keys | % {if($_ -eq $subscription.SubscriptionName){$val = $ARMSubscriptions.Item($_);$global:tenantId = $val.tenantId}}
        }
        if($ARMTenantAccessTokensARM){
            $ARMTenantAccessTokensARM.Keys | %{if($_ -eq $global:tenantId){$Global:accessToken = $ARMTenantAccessTokensARM.Item($_)}} 
        }
        $token = ''
        $token = 'Bearer ' + $Global:accessToken
        $uri = "https://management.core.windows.net/" + $subscription.SubscriptionId +"/services/hostedservices/" + $csList[0] + "/deploymentslots/Production"
        $header = @{"x-ms-version" = "2015-10-01";"Authorization" = $token}
        $xml = try {Invoke-RestMethod -Uri $uri -Method Get -Headers $header} catch {$_.exception.response}
        if($xml.StatusCode -eq 'Unauthorized') {Connect-ARM}
   }
}
else {
    write-Host -ForegroundColor Yellow "Please set a default subscription using Select-AzureSubscription cmdlet"
}

if ($subscription) {
    $ARMSubscriptions.Keys | % {if($_ -eq "Cloudguy's World"){$val = $ARMSubscriptions.Item($_);$global:tenantId = $val.tenantId}}
}
else {
    write-Host -ForegroundColor Yellow "Please set a default subscription using Select-AzureSubscription cmdlet"
}

if($ARMTenantAccessTokensARM){
    $ARMTenantAccessTokensARM.Keys | %{if($_ -eq $global:tenantId){$Global:accessToken = $ARMTenantAccessTokensARM.Item($_)}} 
}
else {
    write-Host -ForegroundColor Yellow "Please Install the ARM Helper cmdlets using Install-ARMModule.ps1 and then run Conect-ARM cmdlet"
}

$token = ''
$token = 'Bearer ' + $Global:accessToken

Write-Host "Now walking through each cloud service deployment and retrieving its metadata"


foreach ($svc in $csList.Keys)
{
    $uri = "https://management.core.windows.net/" + $subscription.SubscriptionId +"/services/hostedservices/" + $svc + "/deploymentslots/Production"
    $header = @{"x-ms-version" = "2015-10-01";"Authorization" = $token}

    $xml = try {Invoke-RestMethod -Uri $uri -Method Get -Headers $header} catch {$_.exception.response}

    if($xml.StatusCode -eq 'NotFound') 
    {
        write-host -ForegroundColor Yellow ("Status Code for GET Cloud Service: " + $svc + "  Status: " +  $xml.StatusCode)
    }
    else
    {
        $deployments = $deployments + $xml.InnerXml
    }

    if($xml.StatusCode -ne 'NotFound') {
        if($xml.Deployment.RoleList.Role.MigrationState)
        {
            if ($xml.Deployment.RoleList.Role.MigrationState -eq "Prepared")
            {
                Write-Host -ForegroundColor Green "Migration State for" $svc ":" $xml.Deployment.RoleList.Role.MigrationState
            }
            elseif ($xml.Deployment.RoleList.Role.MigrationState -eq "Preparing")
            {
                Write-Host -ForegroundColor Yellow "Migration State for" $svc ":" $xml.Deployment.RoleList.Role.MigrationState
            }
            elseif ($xml.Deployment.RoleList.Role.MigrationState -eq "Committing")
            {
                Write-Host -ForegroundColor Magenta "Migration State for" $svc ":" $xml.Deployment.RoleList.Role.MigrationState
            }
            elseif ($xml.Deployment.RoleList.Role.MigrationState -eq "Committed")
            {
                Write-Host -ForegroundColor Cyan "Migration State for" $svc ":" $xml.Deployment.RoleList.Role.MigrationState
            }
            else
            {
                Write-Host -ForegroundColor Red "Migration State for" $svc ":" $xml.Deployment.RoleList.Role.MigrationState
            }
        }
        else{
            Write-Host -ForegroundColor Yellow "Migration State for" $svc ": NotPrepared"
        }
    }
    else
    {
        write-host -ForegroundColor Green "Status Code for GET Cloud Service: " $xml.StatusCode
    }
}

Write-Host "Completed" -ForegroundColor Green



