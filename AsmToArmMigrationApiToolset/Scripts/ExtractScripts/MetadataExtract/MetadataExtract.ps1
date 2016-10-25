<#
 
Purpose: Extract the deployment metadata from a production Azure subscription running ASM virtual networks. Output is a single XML file.
This is a helper Script that can make REST API calls for and pull back metadata for all production deployments in a subscription

One parameter -- subscription ID

Sample Command:

.\MetadataExtract.ps1 -subscriptionID 98f9a3cd-a241-4ad0-9057-8d8cff55ca1f -cloudServiceName mycloudservice
 
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $subscriptionID
)

Select-AzureSubscription -SubscriptionId $subscriptionID
$subscription = Get-AzureSubscription -SubscriptionId $subscriptionID
Write-Host "Selecting the cloud services within the subscription" 
$services = Get-AzureService

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
        $uri = "https://management.core.windows.net/" + $subscription.SubscriptionId +"/services/hostedservices/" + $services[0].ServiceName + "/deploymentslots/Production"
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
$deployments = "<deployments>"

Write-Host "Now walking through each cloud service deployment and retrieving its metadata"

foreach ($svc in $services)
{
    Write-Host ("Pulling metadata for " + $svc.ServiceName) 
    $uri = "https://management.core.windows.net/" + $subscription.SubscriptionId +"/services/hostedservices/" + $svc.ServiceName + "/deploymentslots/Production"
    $header = @{"x-ms-version" = "2015-10-01";"Authorization" = $token}

    $xml = try {Invoke-RestMethod -Uri $uri -Method Get -Headers $header} catch {$_.exception.response}

    if($xml.StatusCode -eq 'NotFound') 
    {
        write-host -ForegroundColor Yellow ("Status Code for GET Cloud Service: " + $svc.ServiceName + " : Status :" +  $xml.StatusCode)
    }
    else
    {
        $deployments = $deployments + $xml.InnerXml
    }
}

$deployments = $deployments + "</deployments>"
$deployments | Out-File (".\metadata_" + $subscription.SubscriptionId + ".xml")
Write-Host ("Completed. Metadata saved to file metadata_" + $subscription.SubscriptionId + ".xml") -ForegroundColor Green


