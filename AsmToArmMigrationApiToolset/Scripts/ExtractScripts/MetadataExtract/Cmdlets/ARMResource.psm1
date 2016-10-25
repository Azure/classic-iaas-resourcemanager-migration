function Get-ARMResource() {
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$true,HelpMessage="ID or displayName of the Azure subscription.")]    
    [string]$Subscription, 
    
    [parameter(Mandatory=$false,HelpMessage="Name of the resource group if you wish to limit the search to one.")]    
    [string]$ResourceGroup = $null, 
    
    [parameter(Mandatory=$true,HelpMessage="Name of the Azure resource provider. For instance 'Microsoft.Sql'.")]    
    [string]$ResourceProvider, 
    
    [parameter(Mandatory=$true,HelpMessage="Type of object that you wish to retrieve. For instance 'servers/databases'.")]    
    [string]$ResourceType, 

    [parameter(Mandatory=$false,HelpMessage="Identifier of a specific resource that you wish to retrieve.")]    
    [string]$ResourceIdentifier, 
    
    [parameter(Mandatory=$true,HelpMessage="API version of the ARM resource provider API")]    
    [string]$APIVersion, 
    
    [parameter(Mandatory=$false,HelpMessage="The base of the route if you wish to fetch a specific instance or a child object.")]    
    [string]$Base = $null, 
    
    [parameter(Mandatory=$false,HelpMessage="Additional query parameters")]    
    [string]$Query = $null, 
        
    [parameter(Mandatory=$false,HelpMessage="Silent mode")]    
    [switch] $Silent
  )
  PROCESS {
    $return = $null
    if($global:ARMTenantAccessTokensARM -ne $null) {
      if($global:ARMSubscriptions.Contains($Subscription)){
        $subscriptionObject = $global:ARMSubscriptions[$subscription]
        $subscriptionId = $subscriptionObject.subscriptionId

        $header = "Bearer " + $global:ARMTenantAccessTokensARM[$subscriptionObject.TenantId]
        $headers = @{"Authorization"=$header;"Accept"="application/json"}
              
        $queryBase = $subscriptionObject.id
        if(-not [string]::IsNullOrEmpty($ResourceGroup)) {$queryBase += ("/resourceGroups/" + $ResourceGroup)}
        $queryBase += "/providers/" + $ResourceProvider + "/" + $ResourceType 
        if(-not [string]::IsNullOrEmpty($ResourceIdentifier)) {$queryBase += ("/" + $ResourceIdentifier)}
        if(-not [string]::IsNullOrEmpty($Base)) {$queryBase += ("/" + $Base)}
        
        $uri = [string]::Format("{0}{1}?api-version={2}{3}",$global:ARMUrl, $queryBase, $APIVersion, $Query)
        if(-not $Silent){
          Write-Host HTTP GET $uri -ForegroundColor Cyan
          Write-Host
        }
        $headers.GetEnumerator() | % {
          if(-not $Silent){
            if(-not $_.Key.Equals("Authorization")){
              Write-Host $_.Key: $_.Value -ForegroundColor Cyan
            }
            else{
              $value = [string]::Format("{0}--snip--{1}", $_.Value.SubString(0,20), $_.Value.SubString($_.Value.Length - 20,20))
              Write-Host $_.Key: $value -ForegroundColor Cyan
            }
          }
        }
        if($data -ne $null){
          if(-not $Silent){
            Write-Host
            Write-Host $body -ForegroundColor Cyan
          }
        }
        $result = Invoke-WebRequest -Method GET -Uri $uri -Headers $headers
        if($result.StatusCode -ge 200 -and $result.StatusCode -le 399){
          if(-not $Silent){
            Write-Host
            Write-Host "Query successfully executed." -ForegroundColor Cyan
          }
          if($result.Content -ne $null){
            $json = (ConvertFrom-Json $result.Content)
            if($json -ne $null){
              $return = $json
              if($json.value -ne $null){$return = $json.value}
            }
          }
        }
      }
      else{
        Write-Host "Either you don't have access to that Azure subscription or it doesn't exist." -ForegroundColor Yellow
      }
    }
    else{
      Write-Host "Not connected to Azure. First run Connect-ARM." -ForegroundColor Yellow
    }
    return $return
  }
}  

function Operate-ARMResource() {
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$true,HelpMessage="ID or displayName of the Azure subscription.")]    
    [string]$Subscription, 
    
    [parameter(Mandatory=$true,HelpMessage="Name of the resource group if you wish to limit the search to one.")]    
    [string]$ResourceGroup = $null, 
    
    [parameter(Mandatory=$true,HelpMessage="Name of the provider. For instance 'Microsoft.Sql'.")]    
    [string]$ResourceProvider, 
    
    [parameter(Mandatory=$true,HelpMessage="Type of the resource that you wish to operate. For instance 'servers/databases'.")]    
    [string]$ResourceType, 

    [parameter(Mandatory=$true,HelpMessage="Identifier of a specific object that you wish to retrieve.")]    
    [string]$ResourceIdentifier, 
    
    [parameter(Mandatory=$true,HelpMessage="API version of the ARM resource provider API")]    
    [string]$APIVersion, 
        
    [parameter(Mandatory=$false,HelpMessage="The base of the route if you wish to operate a specific instance or a child object.")]    
    [string]$Base = $null, 
    
    [parameter(Mandatory=$true,HelpMessage="Name of the action that you wish yo execute on the ARM Object. For instance 'restart'.")]    
    [string]$Action = $null, 
    
    [ValidateSet("Default","Status","File")] 
    [parameter(Mandatory=$false,HelpMessage="Kind of result the action produces.")]    
    [string]$ActionResult = "Default", 
    
    [parameter(Mandatory=$false,HelpMessage="Extension type of returned file.")]    
    [string]$ActionResultExtension = $null,    
        
    [parameter(Mandatory=$false,HelpMessage="Object to be posted with the request as json.")]    
    [object]$Data = $null,    
        
    [parameter(Mandatory=$false,HelpMessage="Silent mode")]    
    [switch] $Silent
  )
  PROCESS {
    $return = $null
    if($global:ARMTenantAccessTokensARM -ne $null) {
      if($global:ARMSubscriptions.Contains($Subscription)){
        $subscriptionObject = $global:ARMSubscriptions[$subscription]
        $subscriptionId = $subscriptionObject.subscriptionId

        $header = "Bearer " + $global:ARMTenantAccessTokensARM[$subscriptionObject.TenantId]
        $headers = @{"Authorization"=$header;"Accept"="application/json"}
              
        $queryBase = $subscriptionObject.id
        if(-not [string]::IsNullOrEmpty($ResourceGroup)) {$queryBase += ("/resourceGroups/" + $ResourceGroup)}
        $queryBase += "/providers/" + $ResourceProvider + "/" + $ResourceType 
        if(-not [string]::IsNullOrEmpty($ResourceIdentifier)) {$queryBase += ("/" + $ResourceIdentifier)}
        if(-not [string]::IsNullOrEmpty($Base)) {$queryBase += ("/" + $Base)}
        $queryBase += ("/" + $Action)
        
        $uri = [string]::Format("{0}{1}?api-version={2}{3}",$global:ARMUrl, $queryBase, $APIVersion, $Query)
        if($Data -ne $null){
          $enc = New-Object "System.Text.ASCIIEncoding"
          $body = ConvertTo-Json -InputObject $Data
          $byteArray = $enc.GetBytes($body)
          $contentLength = $byteArray.Length
          $headers.Add("Content-Type","application/json")
          $headers.Add("Content-Length",$contentLength)
        }
        if(-not $Silent){
          Write-Host HTTP POST $uri -ForegroundColor Cyan
          Write-Host
        }
        $headers.GetEnumerator() | % {
          if(-not $Silent){
            if(-not $_.Key.Equals("Authorization")){
              Write-Host $_.Key: $_.Value -ForegroundColor Cyan
            }
            else{
              $value = [string]::Format("{0}--snip--{1}", $_.Value.SubString(0,20), $_.Value.SubString($_.Value.Length - 20,20))
              Write-Host $_.Key: $value -ForegroundColor Cyan
            }
          }
        }
        if($data -ne $null){
          if(-not $Silent){
            Write-Host
            Write-Host $body -ForegroundColor Cyan
          }
        }
        $result = Invoke-WebRequest -Method POST -Uri $uri -Headers $headers -Body $body
        if($result.StatusCode -ge 200 -and $result.StatusCode -le 399){
          if(-not $Silent){
            Write-Host
            Write-Host "Query successfully executed." -ForegroundColor Cyan
          }
          if($ActionResult.Equals("default",[StringComparison]::InvariantCultureIgnoreCase)){
            if($result.Content -ne $null){
              $json = (ConvertFrom-Json $result.Content)
              if($json -ne $null){
                $return = $json
                if($json.value -ne $null){$return = $json.value}
              }
            }
          }
          elseif($ActionResult.Equals("status",[StringComparison]::InvariantCultureIgnoreCase)){
            if($result.StatusCode -eq 202){
              Write-Host "Action submitted." -ForegroundColor Yellow
              $statusUri = $result.Headers["Location"]
              $operationComplete = $false
              $tries = 0
              $operationTimeoutTries = 60
              $header = "Bearer " + $global:ARMTenantAccessTokensARM[$subscriptionObject.TenantId]
              $headers = @{"Authorization"=$header;"Accept"="application/json"}
              do{
                $statusResult = Invoke-WebRequest -Method GET -Uri $statusUri -Headers $headers
                Write-Host "Action status: " $statusResult.StatusCode"-"$statusResult.StatusDescription -ForegroundColor Yellow
                if($statusResult.StatusCode -eq 200){$operationComplete = $true}
                else{sleep 5}
                $tries++
              }
              while((-not $operationComplete) -and ($tries -lt $operationTimeoutTries))
            }
            else{
              Write-Host "Didn't get back an operation status." -ForegroundColor Yellow
            }
          }
          elseif($ActionResult.Equals("file",[StringComparison]::InvariantCultureIgnoreCase)){
            if($result.Content -ne $null){
              $fileName = $env:temp + "\" + $ResourceIdentifier + $ActionResultExtension
              [System.IO.File]::WriteAllBytes($fileName,$result.Content)
              Write-Host "Saved the file: "$fileName -ForegroundColor Yellow
            }
            else{
              Write-Host "Didn't get back anything." -ForegroundColor Yellow
            }
          }
        }
      }
      else{
        Write-Host "Either you don't have access to that Azure subscription or it doesn't exist." -ForegroundColor Yellow
      }
    }
    else{
      Write-Host "Not connected to Azure. First run Connect-ARM." -ForegroundColor Yellow
    }
    return $return
  }
}
  
#Operate-ARMResource -Subscription production -ResourceProvider microsoft.classiccompute -ResourceGroup PROD-Service -ResourceType virtualMachines -ResourceIdentifier prodsvcuseast -Action restart -ActionResult Status -APIVersion 2014-06-01 -Silent

#Operate-ARMResource -Subscription production -ResourceProvider microsoft.classiccompute -ResourceGroup PROD-Service -ResourceType virtualMachines -ResourceIdentifier prodsvcuseast -Action downloadRemoteDesktopConnectionFile -ActionResult file -ActionResultExtension .rdp -APIVersion 2014-06-01 -Silent