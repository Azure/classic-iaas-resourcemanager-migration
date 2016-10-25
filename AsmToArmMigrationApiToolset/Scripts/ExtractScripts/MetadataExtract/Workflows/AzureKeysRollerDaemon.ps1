<#
.SYNOPSIS
  Connects to Azure using the security context of an Azure AD application. Regenrates keys 
  of all storage accounts in the subscription. Writes the new primary keys to a Key Vault.

.DESCRIPTION
  Connects to Azure using the security context of an Azure AD application. Regenrates keys 
  of all storage accounts in the subscription. Writes the new primary keys to a Key Vault.
  http://www.dushyantgill.com

.NOTES
  Author: Dushyant Gill
  Last Updated: 4/27
#>

workflow AzureKeysRollerDaemon
{   
  # By default, errors in PowerShell do not cause workflows to suspend, like exceptions do.
  # This means a runbook can still reach 'completed' state, even if it encounters errors
  # during execution. The below command will cause all errors in the runbook to be thrown as
  # exceptions, therefore causing the runbook to suspend when an error is hit.
  $ErrorActionPreference = "Stop"
  $clientId = Get-AutomationVariable -Name "AzureKeysRollerDaemon-ClientId"
  $clientSecret = Get-AutomationVariable -Name "AzureKeysRollerDaemon-ClientSecret"
  $directory = Get-AutomationVariable -Name "DirectoryDomainName"
  $subscriptionId = Get-AutomationVariable -Name "SubscriptionId"
  $storageAccountKeyVaultMapping = Get-AutomationVariable -Name "AzureKeysRollerDaemon-StorageAccountKeyVaultMapping"
  InlineScript {
    #######################################################
    #acquire token from Azure AD for Azure Resource Manager
    #######################################################
    $armAccessToken = $null
    $uri = "https://login.windows.net/" + $using:directory + "/oauth2/token"
    $body = "grant_type=client_credentials"
    $body += "&client_id=" + $using:clientId
    $body += "&client_secret=" + [Uri]::EscapeDataString($using:clientSecret)
    $body += "&resource=" + [Uri]::EscapeDataString("https://management.core.windows.net/")
    $headers = @{"Accept"="application/json"}
    $enc = New-Object "System.Text.ASCIIEncoding"
    $byteArray = $enc.GetBytes($body)
    $contentLength = $byteArray.Length
    $headers.Add("Content-Type","application/x-www-form-urlencoded")
    $headers.Add("Content-Length",$contentLength)
    $result = try { Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -Body $body } catch { $_.Exception.Response } 
    $armAccessToken = $result.access_token

    ################################################
    #acquire token from Azure AD for Azure Key Vault
    ################################################
    $kvAccessToken = $null
    $uri = "https://login.windows.net/" + $using:directory + "/oauth2/token"
    $body = "grant_type=client_credentials"
    $body += "&client_id=" + $using:clientId
    $body += "&client_secret=" + [Uri]::EscapeDataString($using:clientSecret)
    $body += "&resource=" + [Uri]::EscapeDataString("https://vault.azure.net")
    $headers = @{"Accept"="application/json"}
    $enc = New-Object "System.Text.ASCIIEncoding"
    $byteArray = $enc.GetBytes($body)
    $contentLength = $byteArray.Length
    $headers.Add("Content-Type","application/x-www-form-urlencoded")
    $headers.Add("Content-Length",$contentLength)
    $result = try { Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -Body $body } catch { $_.Exception.Response }
    $kvAccessToken = $result.access_token

    ###########################
    #Get Storage Accounts
    ###########################
    
    #First, parse the storageAccountKeyVaultMapping variable into something we can work with (a hashtable of storage account names and keyvault names)
    $storageAccountKeyVaultAssoc = @{}
    $storageAccounts = @()
    $sakvMapping = $using:storageAccountKeyVaultMapping
    $sakvMaps = $sakvMapping.Split(';')
    $sakvMaps | % {
      $sas = $_.Split(':')[0]
      $kv = $_.Split(':')[1]
      $sas.Split(',') | % {
        $storageAccountKeyVaultAssoc.Add($_.ToLower() , $kv)
        $storageAccounts += $_.ToLower()
      }
    }
    
    #Next, query Azure Resource Manager reosurces API to get the storage accounts. Query both, Microsoft.ClassicStorage as well as Microsoft.Storage namespaces
    $storageAccountObjects = $null
    $storageAccountsSearchSubFilter = ""
    $count = 0
    $storageAccounts | % {
      $storageAccountsSearchSubFilter += [string]::Format("substringof('{0}', name)", $_)
      if($count -lt $storageAccounts.Length - 1) {$storageAccountsSearchSubFilter += " or "}
      $count++
    }
    $uri = [string]::Format("https://management.azure.com/subscriptions/{0}/resources?api-version=2015-01-01&`$filter=(resourceType eq 'Microsoft.ClassicStorage/storageAccounts' or resourceType eq 'Microsoft.Storage/storageAccounts') and ({1})", $using:subscriptionId, $storageAccountsSearchSubFilter)
    $header = "Bearer " + $armAccessToken
    $headers = @{"Authorization"=$header;"Content-Type"="application/json"}
    $result = try { Invoke-RestMethod -Method GET -Uri $uri -Headers $headers } catch { $_.Exception.Response }
    $storageAccountObjects = $result.value
    
    if($storageAccountObjects -ne $null){
      $storageAccountObjects | % {
        if($storageAccounts.Contains($_.name)){                
          $newKey = $null
          
          #######################
          #regenerate Primary Key or key1
          #######################
          if($_.type.Equals("microsoft.storage/storageAccounts",[StringComparison]::InvariantCultureIgnoreCase)){
            $apiVer = "2015-05-01-preview"
            $postData1 = "" | select KeyName
            $postData1.KeyName = "key1"
            $postData2 = "" | select KeyName
            $postData2.Keyname = "key2"
          }
          else{
            $apiVer = "2014-06-01"
            $postData1 = "" | select KeyType
            $postData1.KeyType = "Primary"
            $postData2 = "" | select KeyType
            $postData2.KeyType = "Secondary"
          }
         
          $uri = [string]::Format("https://management.azure.com{0}/regenerateKey?api-version={1}", $_.id, $apiVer)
          $header = "Bearer " + $armAccessToken
          $headers = @{"Authorization"=$header;"Content-Type"="application/json"}
          $enc = New-Object "System.Text.ASCIIEncoding"
          $body = ConvertTo-Json $postData1
          $byteArray = $enc.GetBytes($body)
          $contentLength = $byteArray.Length
          $headers.Add("Content-Length",$contentLength)
          $result = try { Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -Body $body } catch { $_.Exception.Response }
                    
          if($result.key1 -ne $null -or $result.primaryKey -ne $null){
            #######################
            #regenerate Secondary Key or key2
            #######################
            $header = "Bearer " + $armAccessToken
            $headers = @{"Authorization"=$header;"Content-Type"="application/json"}
            $body = ConvertTo-Json $postData2
            $byteArray = $enc.GetBytes($body)
            $contentLength = $byteArray.Length
            $headers.Add("Content-Length",$contentLength)
            $result = try { Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -Body $body } catch { $_.Exception.Response }
                        
            if($_.type.Equals("microsoft.storage/storageAccounts",[StringComparison]::InvariantCultureIgnoreCase)){
              $newKey = $result.key1
            }
            else{
              $newKey = $result.primaryKey
            }
          }
          
          ####################################
          # Write new key to the Key Vault
          ####################################
          if($newKey -ne $null){
            $uri = [string]::Format("https://{0}.vault.azure.net/secrets/{1}?api-version=2014-12-08-preview", $storageAccountKeyVaultAssoc[$_.name], $_.name)
            $postData = "" | select value
            $postData.value = $newKey
            $header = "Bearer " + $kvAccessToken
            $headers = @{"Authorization"=$header;"Content-Type"="application/json"}
            $enc = New-Object "System.Text.ASCIIEncoding"
            $body = ConvertTo-Json $postData
            $byteArray = $enc.GetBytes($body)
            $contentLength = $byteArray.Length
            $headers.Add("Content-Length",$contentLength)
            $result = try { Invoke-RestMethod -Method PUT -Uri $uri -Headers $headers -Body $body } catch { $_.Exception.Response }
            
            if($result.value -ne $null) {
              [string]::Format("Regenerated key for Storage Account {0} and saved it in Key Vault {1} as Secret {2}", $_.name, $storageAccountKeyVaultAssoc[$_.name], $result.id)
            }
            else {
              [string]::Format("Error while regenerating key for Storage Account {0} and saving it in Key Vault {1}", $_.name, $storageAccountKeyVaultAssoc[$_.name])
            }
          }
        }
      }
    }
  }
}