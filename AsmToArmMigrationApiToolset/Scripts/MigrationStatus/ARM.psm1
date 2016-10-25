function Load-ActiveDirectoryAuthenticationLibrary(){
  $moduleDirPath = [Environment]::GetFolderPath("MyDocuments") + "\WindowsPowerShell\Modules"
  $modulePath = $moduleDirPath + "\ARM"
  if(-not (Test-Path ($modulePath+"\Nugets"))) {New-Item -Path ($modulePath+"\Nugets") -ItemType "Directory" | out-null}
  $adalPackageDirectories = (Get-ChildItem -Path ($modulePath+"\Nugets") -Filter "Microsoft.IdentityModel.Clients.ActiveDirectory*" -Directory)
  if($adalPackageDirectories.Length -eq 0){
    Write-Host "Active Directory Authentication Library Nuget doesn't exist. Downloading now ..." -ForegroundColor Yellow
    if(-not(Test-Path ($modulePath + "\Nugets\nuget.exe")))
    {
      Write-Host "nuget.exe not found. Downloading from http://www.nuget.org/nuget.exe ..." -ForegroundColor Yellow
      $wc = New-Object System.Net.WebClient
      $wc.DownloadFile("http://www.nuget.org/nuget.exe",$modulePath + "\Nugets\nuget.exe");
    }
    $nugetDownloadExpression = $modulePath + "\Nugets\nuget.exe install Microsoft.IdentityModel.Clients.ActiveDirectory -Version 2.14.201151115 -OutputDirectory " + $modulePath + "\Nugets | out-null"
    Invoke-Expression $nugetDownloadExpression
  }
  $adalPackageDirectories = (Get-ChildItem -Path ($modulePath+"\Nugets") -Filter "Microsoft.IdentityModel.Clients.ActiveDirectory*" -Directory)
  $ADAL_Assembly = (Get-ChildItem "Microsoft.IdentityModel.Clients.ActiveDirectory.dll" -Path $adalPackageDirectories[$adalPackageDirectories.length-1].FullName -Recurse)
  $ADAL_WindowsForms_Assembly = (Get-ChildItem "Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll" -Path $adalPackageDirectories[$adalPackageDirectories.length-1].FullName -Recurse)
  if($ADAL_Assembly.Length -gt 0 -and $ADAL_WindowsForms_Assembly.Length -gt 0){
    Write-Host "Loading ADAL Assemblies ..." -ForegroundColor Green
    [System.Reflection.Assembly]::LoadFrom($ADAL_Assembly[0].FullName) | out-null
    [System.Reflection.Assembly]::LoadFrom($ADAL_WindowsForms_Assembly.FullName) | out-null
    return $true
  }
  else{
    Write-Host "Fixing Active Directory Authentication Library package directories ..." -ForegroundColor Yellow
    $adalPackageDirectories | Remove-Item -Recurse -Force | Out-Null
    Write-Host "Not able to load ADAL assembly. Delete the Nugets folder under" $modulePath ", restart PowerShell session and try again ..."
    return $false
  }
}

function Get-AuthenticationResult($tenant = "common", $prompt=$true, $resourceAppIdURI = "https://graph.windows.net/"){
  $clientId = "1950a258-227b-4e31-a9cf-717495945fc2"
  $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
  $authority = "https://login.windows.net/" + $tenant
  $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority,$false
  if($prompt){$authResult = $authContext.AcquireToken($resourceAppIdURI, $clientId, $redirectUri, [Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Always)}
  else{
      try{
        $authResult = $authContext.AcquireToken($resourceAppIdURI, $clientId, $redirectUri, [Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Never)
      }
      catch{}
      if ($authResult -eq $null){
        $authResult = $authContext.AcquireToken($resourceAppIdURI, $clientId, $redirectUri, [Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Auto)      
      }
    }
  return $authResult
}

function Get-ARMDirectories($Silent=$false){
  $return = $null
  if($global:ARMCommonARMAccessToken -ne $null) {
    $header = "Bearer " + $global:ARMCommonARMAccessToken
    $headers = @{"Authorization"=$header;"Content-Type"="application/json"}
    $uri = [string]::Format("{0}/tenants?api-version={1}",$global:ARMUrl,$global:ARMAPIVersion)
    $result = Invoke-WebRequest -Method GET -Uri $uri -Headers $headers
    if($result.StatusCode -ge 200 -and $result.StatusCode -le 399){
      if(-not $Silent){
        Write-Host
        Write-Host "Queried tenants successfully." -ForegroundColor Cyan
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
    Write-Host "Not connected to an ARM. First run Connect-ARM." -ForegroundColor Yellow
  }
  return $return
}

function Get-ARMSubscriptions($AccessToken=$global:ARMCommonARMAccessToken, $Silent=$false){
  $return = $null
  if($AccessToken -ne $null) {
    $header = "Bearer " + $AccessToken
    $headers = @{"Authorization"=$header;"Content-Type"="application/json"}
    $uri = [string]::Format("{0}/subscriptions?api-version={1}",$global:ARMUrl,$global:ARMAPIVersion)
    $result = Invoke-WebRequest -Method GET -Uri $uri -Headers $headers
    if($result.StatusCode -ge 200 -and $result.StatusCode -le 399){
      if(-not $Silent){
        Write-Host
        Write-Host "Queried subscriptions successfully." -ForegroundColor Cyan
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
    Write-Host "Not connected to an ARM. First run Connect-ARM." -ForegroundColor Yellow
  }
  return $return
}

function Get-ARMDirectoryInfo($TenantId, $AccessToken, $Silent=$false){
  $return = $null
  if($AccessToken -ne $null) {
    $header = "Bearer " + $AccessToken
    $headers = @{"Authorization"=$header;"Content-Type"="application/json"}
    $uri = [string]::Format("{0}/{1}/tenantDetails?api-version={2}",$global:ARMGraphUrl,$TenantId,$global:ARMGraphAPIVersion)
    $result = Invoke-WebRequest -Method GET -Uri $uri -Headers $headers
    if($result.StatusCode -ge 200 -and $result.StatusCode -le 399){
      if(-not $Silent){
        Write-Host
        Write-Host "Queried tenant info successfully." -ForegroundColor Cyan
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
  return $return
}

function Get-ARMDirectoryObject($SubscriptionId, $ObjectId, $Silent=$false){
  $return = $null
  if($global:ARMTenantAccessTokensGraph -ne $null) {
    $tenantId = $global:ARMSubscriptions[$SubscriptionId].TenantId
    $acessToken = $global:ARMTenantAccessTokensGraph[$tenantId]
    $header = "Bearer " + $acessToken
    $headers = @{"Authorization"=$header;"Content-Type"="application/json"}
    $uri = [string]::Format("{0}/{1}/directoryObjects/{2}?api-version={3}",$global:ARMGraphUrl,$tenantId,$ObjectId,$global:ARMGraphAPIVersion)
    $result = Invoke-WebRequest -Method GET -Uri $uri -Headers $headers
    if($result.StatusCode -ge 200 -and $result.StatusCode -le 399){
      if(-not $Silent){
        Write-Host
        Write-Host "Queried directory object successfully." -ForegroundColor Cyan
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
    Write-Host "Not connected to an ARM. First run Connect-ARM." -ForegroundColor Yellow
  }
  return $return
}

function Resolve-ARMDirectoryPrincipal($SubscriptionId, $PrincipalType, $DisplayNameOrUPNOrEmail, $Silent=$false){
  $return = $null
  if($global:ARMTenantAccessTokensGraph -ne $null) {
    $tenantId = $global:ARMSubscriptions[$SubscriptionId].TenantId
    $acessToken = $global:ARMTenantAccessTokensGraph[$tenantId]
    $header = "Bearer " + $acessToken
    $headers = @{"Authorization"=$header;"Content-Type"="application/json"}
    if($PrincipalType.ToLower() -eq "users"){
      $uri = [string]::Format("{0}/{1}/users?api-version={2}&`$filter=userPrincipalName eq '{3}' or startswith(userPrincipalName,'{4}')", $global:ARMGraphUrl, $tenantId, $global:ARMGraphAPIVersion, $DisplayNameOrUPNOrEmail, $DisplayNameOrUPNOrEmail.Replace('@','_'))
    }
    else{
      $uri = [string]::Format("{0}/{1}/{2}?api-version={3}&`$filter=displayName eq'{4}'", $global:ARMGraphUrl, $tenantId, $PrincipalType, $global:ARMGraphAPIVersion, $DisplayNameOrUPNOrEmail)
    }
        
    $result = Invoke-WebRequest -Method GET -Uri $uri -Headers $headers
    
    if($result.StatusCode -ge 200 -and $result.StatusCode -le 399 -and $result.Content -ne $null){
      $json = (ConvertFrom-Json $result.Content)
      if($json -ne $null -and $json.value -ne $null){
        if($json.value.Length -eq 1){
          $return = "" | select DisplayName,ObjectId,UPNOrEmail
          $return.DisplayName = $json.value.displayName
          $return.ObjectId = $json.value.objectId
          
          if($json.value.userPrincipalName -ne $null){
            if($json.value.userPrincipalName.ToLower() -eq $DisplayNameOrUPNOrEmail.ToLower()){
              $return.UPNOrEmail = $json.value.userPrincipalName
            }
            elseif($json.value.userPrincipalName.ToLower().StartsWith($DisplayNameOrUPNOrEmail.ToLower().Replace('@','_')) -and $json.value.otherMails -ne $null -and $json.value.otherMails.Count -eq 1){
              $return.UPNOrEmail = $json.value.otherMails
            }
            else{
              $return = $null
            }
          }
        }
        else{
          $return = $false
        }
      }
    }
  }
  else{
    Write-Host "Not connected to an ARM. First run Connect-ARM." -ForegroundColor Yellow
  }
  return $return
}

function Get-ARMDirectoryPrincipalGroupMembership($SubscriptionId, $PrincipalType, $ObjectId, $Silent=$false){
  $return = $null
  if($global:ARMTenantAccessTokensGraph -ne $null) {
    $tenantId = $global:ARMSubscriptions[$SubscriptionId].TenantId
    $acessToken = $global:ARMTenantAccessTokensGraph[$tenantId]
    $header = "Bearer " + $acessToken
    $headers = @{"Authorization"=$header;"Content-Type"="application/json"}
    $uri = [string]::Format("{0}/{1}/{2}/{3}/getMemberObjects?api-version={4}", $global:ARMGraphUrl, $tenantId, $PrincipalType, $ObjectId, $global:ARMGraphAPIVersion)
    $data = "" | Select securityEnabledOnly
    $data.securityEnabledOnly = $true    
    $enc = New-Object "System.Text.ASCIIEncoding"
    $body = ConvertTo-Json -InputObject $data
    $byteArray = $enc.GetBytes($body)
    $contentLength = $byteArray.Length
    $headers.Add("Content-Length",$contentLength)
        
    $result = Invoke-WebRequest -Method POST -Uri $uri -Headers $headers -Body $body
    
    if($result.StatusCode -ge 200 -and $result.StatusCode -le 399 -and $result.Content -ne $null){
      $json = (ConvertFrom-Json $result.Content)
      if($json -ne $null -and $json.value -ne $null){
        $json.value
      }
    }
  }
  else{
    Write-Host "Not connected to an ARM. First run Connect-ARM." -ForegroundColor Yellow
  }
  return $return
}

function Connect-ARM ($ARMAPIVersion="2014-04-01-preview", $GraphAPIVersion="1.5") {
  PROCESS {
    $global:ARMUrl = "https://management.azure.com"
    $global:ARMGraphUrl = "https://graph.windows.net"
    $global:ARMAPIVersion = $ARMAPIVersion
    $global:ARMGraphAPIVersion = $GraphAPIVersion
    $global:ARMCommonARMAccessToken = (Get-AuthenticationResult -ResourceAppIdURI "https://management.core.windows.net/").AccessToken
    $global:ARMTenants = @()
    $global:ARMTenantAccessTokensARM = @{}
    $global:ARMTenantAccessTokensGraph = @{}
    $global:ARMSubscriptions = @{}
    $directories = Get-ARMDirectories -Silent $true 
    $directories | % {
      $tenant = $_
      $global:ARMTenants = $global:ARMTenants + $tenant.tenantId; 
      $tenantAccessTokenARM = (Get-AuthenticationResult -Tenant $tenant.tenantId -Prompt $false -ResourceAppIdURI "https://management.core.windows.net/").AccessToken
      $global:ARMTenantAccessTokensARM.Add($tenant.tenantId, $tenantAccessTokenARM);
      $tenantAccessTokenGraph = (Get-AuthenticationResult -Tenant $tenant.tenantId -Prompt $false -ResourceAppIdURI "https://graph.windows.net/").AccessToken
      $global:ARMTenantAccessTokensGraph.Add($tenant.tenantId, $tenantAccessTokenGraph);

      $tenantName = ""
      $tenantInfo = Get-ARMDirectoryInfo -TenantId $tenant.tenantId -AccessToken $tenantAccessTokenGraph -Silent $true
      if($tenantInfo.verifiedDomains -ne $null){$tenantInfo.verifiedDomains | % {if ($_.default){ $tenantName = $_.name;}}}
      
      Get-ARMSubscriptions -AccessToken $tenantAccessTokenARM -Silent $true | % {
        if($_.subscriptionId -ne $null){
          $subscription = "" | Select-Object subscriptionId, displayName, state, id, tenantId, tenantName
          $subscription.subscriptionId = $_.subscriptionId
          $subscription.displayName = $_.displayName
          $subscription.state = $_.state
          $subscription.id = $_.id
          $subscription.tenantId = $tenant.tenantId
          $subscription.tenantName = $tenantName 
          $global:ARMSubscriptions.Add($subscription.subscriptionId, $subscription)
          if(-not $global:ARMSubscriptions.Contains($subscription.displayName)){$global:ARMSubscriptions.Add($subscription.displayName, $subscription)}
        }
      }
    }
  }
}

function Execute-ARMQuery ($HTTPVerb, $SubscriptionId, $Base, $Query, $Data, $APIVersion=$global:ARMAPIVersion, [switch] $Silent) {
  $return = $null
  if($global:ARMTenantAccessTokensARM -ne $null) {
    $header = "Bearer " + $global:ARMTenantAccessTokensARM[$global:ARMSubscriptions[$SubscriptionId].TenantId]
    $headers = @{"Authorization"=$header;"Accept"="application/json"}
    $uri = [string]::Format("{0}{1}?api-version={2}{3}",$global:ARMUrl, $Base, $APIVersion, $Query)
    if($data -ne $null){
      $enc = New-Object "System.Text.ASCIIEncoding"
      $body = ConvertTo-Json -InputObject $Data
      $byteArray = $enc.GetBytes($body)
      $contentLength = $byteArray.Length
      $headers.Add("Content-Type","application/json")
      $headers.Add("Content-Length",$contentLength)
    }
    if(-not $Silent){
      Write-Host HTTP $HTTPVerb $uri -ForegroundColor Cyan
      Write-Host
    }
    
    $headers.GetEnumerator() | % {
      if(-not $Silent){
        Write-Host $_.Key: $_.Value -ForegroundColor Cyan
        }
      }
    if($data -ne $null){
      if(-not $Silent){
        Write-Host
        Write-Host $body -ForegroundColor Cyan
      }
    }
    $result = Invoke-WebRequest -Method $HTTPVerb -Uri $uri -Headers $headers -Body $body
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
    Write-Host "Not connected to an ARM. First run Connect-ARM." -ForegroundColor Yellow
  }
  return $return
}

Load-ActiveDirectoryAuthenticationLibrary