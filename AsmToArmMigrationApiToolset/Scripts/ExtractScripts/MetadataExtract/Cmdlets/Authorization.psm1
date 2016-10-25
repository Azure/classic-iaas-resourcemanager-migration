function Get-ARMAccessChangeHistory () {
  [CmdletBinding()]
  param (
    [ValidateRange(1,90)] 
    [parameter(Mandatory=$false,HelpMessage="Fetch access change events for the past n days. Default = 30")]
    [Int]$Days = 30
  )
  PROCESS {
    $output = @()
    #For each subscription that the signed in user has some kind of access in
    if($global:ARMSubscriptions -ne $null){
      $global:ARMSubscriptions.GetEnumerator() | % {
        $startEvents = @{}
        $endEvents = @{}
        $offlineEvents = @()
        $subscription = $_.Value
        #query the Microsoft.Insights Resource Provider - for Events, for the subscription created by the Microsoft.Authorization Rsource Provider
        $base = "/subscriptions/" + $subscription.subscriptionId + "/providers/microsoft.insights/eventtypes/management/values"
        $query = "&`$filter=resourceProvider eq 'Microsoft.Authorization' and "
        $query = $query + "&eventTimestamp le '" + [System.Web.HttpUtility]::UrlEncode(([DateTime]::UTCNow).ToString("o")) + "' and ";
        $query = $query + "&eventTimestamp ge '" + [System.Web.HttpUtility]::UrlEncode(([DateTime]::UTCNow - [TimeSpan]::FromDays($Days)).ToString("o")) + "'";
        
        $events = try {Execute-ARMQuery -HTTPVerb GET -SubscriptionId $subscription.subscriptionId -Base $base -Query $query -APIVersion "2014-04-01" -Silent} catch{}
        
        $events | % {
          if($_.httpRequest -ne $null){
            if($_.status.value -eq "Started"){
              $startEvents.Add($_.operationId, $_) 
            }
            else{
              $endEvents.Add($_.operationId, $_)
            }
          }
          else{
            $offlineEvents += $_
          }
        }
        
        $startEvents.GetEnumerator() | % {
          # confirm that the startEvent resulted in an endEvent that succeeded
          if($endEvents[$_.Value.operationId] -ne $null -and $endEvents[$_.Value.operationId].status.value.ToLower() -eq "succeeded"){
            # instantiate an output event object 
            $out = "" | select Date,Action,DirectoryName,SubscriptionName,SubscriptionId,User,RoleId,RoleName,SubjectId,SubjectType,SubjectName,Scope,ScopeType,ScopeName
            $out.Date = [DateTime]::Parse($_.Value.eventTimestamp)
            $out.DirectoryName = $subscription.tenantName
            $out.SubscriptionName = $subscription.displayName
            $out.SubscriptionId = $subscription.subscriptionId
            #the claims property of events contains the bag of claims from the token of the user that made the change that resulted in the event
            $out.User = $_.Value.claims."http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"
            $messageBody = $null
            
            if($_.value.httpRequest.method.ToUpper() -eq "PUT"){
              $out.Action = "Granted"
              #Microsoft.Authorization PUT RoleAssignment start events log the request body that contains the information about the role and the subject of the role assignment
              if($_.Value.properties.requestbody -ne $null){
                $messageBody = ConvertFrom-Json $_.Value.properties.requestbody
              }
            }
            elseif ($_.value.httpRequest.method.ToUpper() -eq "DELETE"){
              $out.Action = "Revoked"
              #Microsoft.Authorization DELETE RoleAssignment end events log the response body that contains the information about the role and the subject of the role assignment
              if($endEvents[$_.Value.operationId].properties.responseBody -ne $null){
                $messageBody = ConvertFrom-Json $endEvents[$_.Value.operationId].properties.responseBody
              }
            }
            if($messageBody -ne $null){
              #get the role id from the request body
              $out.RoleId = $messageBody.properties.roleDefinitionId
              #convert the role id to role name by querying the Microsoft.Authorization resource provider
              $role = try{Execute-ARMQuery -HTTPVerb GET -SubscriptionId $subscription.subscriptionId -Base $out.RoleId -APIVersion "2014-07-01-preview" -Silent} catch{}
              if($role -ne $null){$out.RoleName = $role.properties.roleName}
              
              #from the request body, get the objectid of the user or group to whom role was assigned
              $out.SubjectId = $messageBody.properties.principalId
              #covert the object id of the subject to name and type by querying the Azure AD Graph API
              $subject = try{Get-ARMDirectoryObject -SubscriptionId $subscription.subscriptionId -ObjectId $out.SubjectId -Silent $true} catch{}
              if($subject -ne $null){
                $out.SubjectType = $subject.objectType
                $out.SubjectName = $subject.displayName
              }
            }
            
            $out.scope = $_.Value.resourceUri
            #authorization events are created under the URI or the subscription/resource group/resource URI on which access is granted/revoked.
            #get the subscription or the resourcegroup or the resource URI on which access was granted revoked 
            if($out.scope.ToLower().Contains("/providers/microsoft.authorization")){
              $out.scope = $out.Scope.ToLower().Remove($out.Scope.ToLower().IndexOf("/providers/microsoft.authorization"))
            }
            
            #determine whether the role assignment was added/deleted on subscription or resourcegroup or the resource
            if($out.scope.ToLower().Contains("subscription") -and $out.scope.Split('/').Length -lt 4){
              $out.ScopeType = "Subscription"
              $scope = try{Execute-ARMQuery -HTTPVerb GET -SubscriptionId $subscription.subscriptionId -Base $out.scope  -APIVersion "2014-04-01-preview" -Silent} catch{}
              if($scope -ne $null){$out.ScopeName = $scope.displayName + " (Id: " + $scope.subscriptionId + ")"}
            }
            elseif($out.scope.ToLower().Contains("resourcegroups") -and $out.scope.Split('/').Length -lt 6){
              $out.ScopeType = "Resource Group"
              $scope = try{Execute-ARMQuery -HTTPVerb GET -SubscriptionId $subscription.subscriptionId -Base $out.scope  -APIVersion "2014-04-01-preview" -Silent} catch{}
              if($scope -ne $null){$out.ScopeName = $scope.name + " (Region: " + $scope.location + ")"}
            }
            elseif($out.scope.ToLower().Contains("providers") -and $out.scope.Split('/').Length -gt 7){
              $out.ScopeType = "Resource"
              $scopeName = $out.scope.Split("/")[$out.scope.Split("/").Length - 1]
              $out.ScopeName = $scopeName + " (Under: " + $out.scope.ToLower().SubString($out.scope.LastIndexOf("providers")).Trim($scopeName.ToLower()).Trim("providers").Trim("/") + ")"
            }
            $output += $out
          }
        }
        
        $offlineEvents | % {
          if($_.status -ne $null -and $_.status.value.ToLower() -eq "succeeded" -and $_.operationName -ne $null -and $_.operationName.value -ne $null -and $_.operationName.value.ToLower().StartsWith("microsoft.authorization/classicadministrators")){
            $out = "" | select Date,Action,DirectoryName,SubscriptionName,SubscriptionId,User,RoleId,RoleName,SubjectId,SubjectType,SubjectName,Scope,ScopeType,ScopeName
            $out.User = "Subscription Admin"
            $out.RoleId = $null
            $out.SubjectId = $null
            $out.SubjectType = "User"
            $out.Scope = "/subscriptions/" + $out.SubscriptionId
            $out.ScopeType = "Subscription"
            $out.ScopeName = $subscription.displayName
            
            $out.Date = [DateTime]::Parse($_.eventTimestamp)
            $out.DirectoryName = $subscription.tenantName
            $out.SubscriptionName = $subscription.displayName
            $out.SubscriptionId = $subscription.subscriptionId
            
            if($_.operationName.value.ToLower() -eq "microsoft.authorization/classicadministrators/write"){
              $out.Action = "Granted"
            }
            elseif($_.operationName.value.ToLower() -eq "microsoft.authorization/classicadministrators/delete"){
              $out.Action = "Revoked"
            }
            
            if($_.properties -ne $null){
              $out.SubjectName = $_.properties.adminEmail
              $out.RoleName = "Classic " + $_.properties.adminType
            }         
            $output += $out
          }
        }
      }
    }
    else{
      Write-Host "Didn't find any subscriptions. Make sure you've run the Connect-ARM command."
    }
    $output | Sort Date
  }
}

function Get-ARMAccessAssignments () {
  [CmdletBinding(DefaultParameterSetName = "All")]
  param (
    [parameter(Mandatory=$false,HelpMessage="Get access assignments applicable to a user, by specifying the User Principal Name or Email of the User.")]
    [string]$User
  )
  PROCESS {
    $output = @()
    
    $filterByPrincipal = $false
    $principalObjectIdAndGroupsObjectIds = @()
    $principalEmailOrUPN = $null
    
    if($global:ARMSubscriptions -ne $null){
      $global:ARMSubscriptions.GetEnumerator() | % {
        $subscription = $_.Value

        $principal = $null
        $principalType = $null
        
        if(-not [string]::IsNullOrEmpty($User) -or -not [string]::IsNullOrEmpty($Group) -or -not [string]::IsNullOrEmpty($ServicePrincipal)){
          if(-not [string]::IsNullOrEmpty($User)){
            $principalType = "users"
            $principal = try{Resolve-ARMDirectoryPrincipal -SubscriptionId $subscription.subscriptionId -PrincipalType $principalType -DisplayNameOrUPNOrEmail $User -Silent $true} catch{}
          }
          elseif(-not [string]::IsNullOrEmpty($Group)){
            $principalType = "groups"        
            $principal = try{Resolve-ARMDirectoryPrincipal -SubscriptionId $subscription.subscriptionId -PrincipalType $principalType -DisplayNameOrUPNOrEmail $Group -Silent $true} catch{}
          }
          elseif(-not [string]::IsNullOrEmpty($ServicePrincipal)){
            $principalType = "servicePrincipals"
            $principal = try{Resolve-ARMDirectoryPrincipal -SubscriptionId $subscription.subscriptionId -PrincipalType $principalType -DisplayNameOrUPNOrEmail $ServicePrincipal -Silent $true} catch{}
          }
        }
        
        if($principal -ne $null){
          $filterByPrincipal = $true
          $principalObjectIdAndGroupsObjectIds += $principal.ObjectId
          $principalGroupMembership = try{Get-ARMDirectoryPrincipalGroupMembership -SubscriptionId $subscription.subscriptionId -PrincipalType $principalType -ObjectId $principal.objectId -Silent $true} catch{}
          if($principalGroupMembership -ne $null){$principalGroupMembership | % {$principalObjectIdAndGroupsObjectIds += $_}}
          if($principal.UPNOrEmail -ne $null){$principalEmailOrUPN = $principal.UPNOrEmail}
        }

        $base = "/subscriptions/" + $subscription.subscriptionId + "/providers/Microsoft.Authorization/roleAssignments"
        $roleAssignments = try{Execute-ARMQuery -HTTPVerb GET -SubscriptionId $subscription.subscriptionId -Base $base -APIVersion "2014-10-01-preview" -Silent} catch{}
              
        $roleAssignments | % {
          if($_.id -ne $null){
            $out = "" | select DirectoryName,SubscriptionName,SubscriptionId,RoleId,RoleName,SubjectId,SubjectType,SubjectName,Scope,ScopeType,ScopeName
            $out.DirectoryName = $subscription.tenantName
            $out.SubscriptionName = $subscription.displayName
            $out.SubscriptionId = $subscription.subscriptionId
            
            $out.RoleId = $_.properties.roleDefinitionId
            $role = try{Execute-ARMQuery -HTTPVerb GET -SubscriptionId $subscription.subscriptionId -Base $out.RoleId -APIVersion "2014-07-01-preview" -Silent} catch{}
            if($role -ne $null){$out.RoleName = $role.properties.roleName}
            
            $out.SubjectId = $_.properties.principalId
            #covert the object id of the subject to name and type by querying the Azure AD Graph API
            $subject = Get-ARMDirectoryObject -SubscriptionId $subscription.subscriptionId -ObjectId $out.SubjectId -Silent $true
            if($subject -ne $null){
              $out.SubjectType = $subject.objectType
              $out.SubjectName = $subject.displayName
            }
            
            $out.Scope = $_.properties.scope

            #determine whether the role assignment was added/deleted on subscription or resourcegroup or the resource
            if($out.scope.ToLower().Contains("subscription") -and $out.scope.Split('/').Length -lt 4){
              $out.ScopeType = "Subscription"
              $scope = try{Execute-ARMQuery -HTTPVerb GET -SubscriptionId $subscription.subscriptionId -Base $out.scope  -APIVersion "2014-04-01-preview" -Silent} catch{}
              if($scope -ne $null){$out.ScopeName = $scope.displayName + " (Id: " + $scope.subscriptionId + ")"}
            }
            elseif($out.scope.ToLower().Contains("resourcegroups") -and $out.scope.Split('/').Length -lt 6){
              $out.ScopeType = "Resource Group"
              $scope = try{Execute-ARMQuery -HTTPVerb GET -SubscriptionId $subscription.subscriptionId -Base $out.scope  -APIVersion "2014-04-01-preview" -Silent} catch{}
              if($scope -ne $null){$out.ScopeName = $scope.name + " (Region: " + $scope.location + ")"}
            }
            elseif($out.scope.ToLower().Contains("providers") -and $out.scope.Split('/').Length -gt 7){
              $out.ScopeType = "Resource"
              $scopeName = $out.scope.Split("/")[$out.scope.Split("/").Length - 1]
              $out.ScopeName = $scopeName + " (Under: " + $out.scope.ToLower().SubString($out.scope.LastIndexOf("providers")).Trim($scopeName.ToLower()).Trim("providers").Trim("/") + ")"
            }
            $output += $out
          }
        }
        $base = "/subscriptions/" + $subscription.subscriptionId + "/providers/Microsoft.Authorization/classicAdministrators"
        $classicAdmins = Execute-ARMQuery -HTTPVerb GET -SubscriptionId $subscription.subscriptionId -Base $base -APIVersion "2014-10-01-preview" -Silent
        $classicAdmins | % {
          $out = "" | select DirectoryName,SubscriptionName,SubscriptionId,RoleId,RoleName,SubjectId,SubjectType,SubjectName,Scope,ScopeType,ScopeName
          $out.DirectoryName = $subscription.tenantName
          $out.SubscriptionName = $subscription.displayName
          $out.SubscriptionId = $subscription.subscriptionId
          
          $out.RoleId = $null
          $out.RoleName = $_.properties.role
          
          $out.SubjectId = $null
          $out.SubjectType = "User"
          $out.SubjectName = $_.properties.emailAddress
          
          $out.Scope = "/subscriptions/" + $out.SubscriptionId
          $out.ScopeType = "Subscription"
          $out.ScopeName = $subscription.displayName
          
          $output += $out
        }
      }
      
      if(-not [string]::IsNullOrEmpty($User) -or -not [string]::IsNullOrEmpty($Group) -or -not [string]::IsNullOrEmpty($ServicePrincipal)){
        if($filterByPrincipal){
          $filteredOutput = @()
          $output | % {
            if(($_.SubjectId -ne $null -and $principalObjectIdAndGroupsObjectIds.Contains($_.SubjectId)) -or ($_.SubjectName -ne $null -and $principalEmailOrUPN.ToLower().Equals($_.SubjectName.ToLower()))){
              $filteredOutput += $_
            }
          }
          $output = $filteredOutput
        }
        else{
          Write-Host "Sorry - couldn't find this principal in any of the tenants" -ForegroundColor Yellow
          $output = $null
        }
      }
    }
    else{
      Write-Host "Didn't find any subscriptions. Make sure you've run the Connect-ARM command."
    }
    $output | Sort DirectoryName,SubscriptionId
  }
}