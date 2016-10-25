<#
Purpose: Core script to hydrate a test environment from the ASM/Classic metadata extract. Use the CSV to hydrate a simulated ASM environment with the same metadata for running/testing the ARM Migration API.
#>

Param
(
    [Parameter(Mandatory=$true)]
	[string]$SubscriptionId,             # subscriptionID for the test lab to hydrate the test environment
    [Parameter(Mandatory=$true)]
	[string]$VirtualNetworkName,         # virtual network in the test lab (should be already setup) to place the VMs
    [Parameter(Mandatory=$true)]
	[string]$StandardStorageAccountName, # standard storage account to place the hydrated VMs needing standard storage
    [Parameter(Mandatory=$false)]   
    [string]$PremiumStorageAccountName,  # premium storage account to place the hydrated VMs requiring XIO storage
    [Parameter(Mandatory=$true)]   
	[string]$AzureRegion,                # region to build out hybrid environment. The virtual network above must already be setup in this region.
    [Parameter(Mandatory=$true)]  
	[string]$ImportCsvFileName,          # csv file name containing all the VMs and metadata generated from AsmMetadataParser utility
    [Parameter(Mandatory=$true)]  
	[string]$CloudServicePrefixLetter,   # letter to place infront of the new cloud service name to ensure a unique internet domain name. This should be one character.
    [Parameter(Mandatory=$false)]  
	[string]$WindowsCustomImageName      # custom image name for Windows VMs built from a custom image.  TODO: add linux or other needed support here.
    
)

$ErrorActionPreference = "stop"

$global:ScriptStartTime = (Get-Date -Format hh-mm-ss.ff)
$global:CreatedVMLog = "Output\CreatedVM.log"
$global:FailedVMLog = "Output\FailedVM.log"
$global:ExistsVMLog = "Output\ExistsVM.log"


if((Test-Path "Output") -eq $false)
{
	md "Output" | Out-Null
}
	
function Write-Log
{
	param(
    [string]$logMessage,
	[string]$color="White"
    )

    $timestamp = ('[' + (Get-Date -Format hh:mm:ss.ff) + '] ')
	$message = $timestamp + $logMessage
    Write-Host $message -ForeGroundColor $color
	$fileName = "Output\Log-" + $global:ScriptStartTime + ".log"
	Add-Content $fileName $message
}

function Create-VM
{
    param(
        [string]$vhdStorageAccount,
        [string]$customImageName,
        [string]$vmName,
        [string]$serviceName,
        [string]$instanceSize,
        [string]$secondaryNICSubnetName,
        [string]$secondaryNICs,
        [string]$primaryNICSubnetName,
        [string]$primaryNICIP,
        [string]$running,
        [string]$datadisks,
        [string]$availset,
        [switch]$agent,
        [string]$adminUsername,
        [string]$adminPwd,
        [string]$vnetName,
        [string]$deploymentLocation,
        [string]$os,
        [string]$lbendpointname,
        [string]$lbport,
        [string]$lbvip,
        [string]$lbtype
    )

    # vmname,csname,size,agent,running,lbendpointname,lbport,lbvip,lbtype,osdisktype,os,ip,datadisks,subnet,secondarynics,availset

    try
    {
        Set-AzureSubscription -SubscriptionId $SubscriptionId -CurrentStorageAccountName $vhdStorageAccount

        Write-Host "setting os image"        
        if ($os -eq "Windows")
        {
            if ($customImageName -ne "")
            {
                $customImage = Get-AzureVMImage $customImageName
                $azureImageName = $customImage.ImageName
            }
            else
            {
                $family="Windows Server 2012 R2 Datacenter"
                $azureImageName = Get-AzureVMImage | where { $_.ImageFamily -eq $family } | sort PublishedDate -Descending | select -ExpandProperty ImageName -First 1
            }
        }
        else
        {
            $family="Ubuntu Server"
            $azureImageName = Get-AzureVMImage | where { $_.ImageFamily -eq $family } | sort PublishedDate -Descending | select -ExpandProperty ImageName -First 1
        }  

        $VMConfig = $null
        Write-Host "Creating VM Config"
        $VMConfig = New-AzureVMConfig -Name $vmName -InstanceSize $instanceSize -ImageName $azureImageName

        if ($os -eq "Windows")
        {
            #if ($agent)
            #{
                Add-AzureProvisioningConfig -VM $VMConfig -Windows -Password $adminPwd -AdminUsername $adminUsername
            #}
            #else
            #{
            #    Add-AzureProvisioningConfig -VM $VMConfig -Windows -Password $adminPwd -AdminUsername $adminUsername -NoRDPEndpoint -NoWinRMEndpoint -DisableGuestAgent
            #}
        }
        else
        {
            #if ($agent)
            #{
                Add-AzureProvisioningConfig -VM $VMConfig -Linux -Password $adminPwd -LinuxUser $adminUsername
            #}
            #else
            #{
            #    Add-AzureProvisioningConfig -VM $VMConfig -Linux -Password $adminPwd -LinuxUser $adminUsername -NoSSHEndpoint -DisableGuestAgent
            #}
        }
    
        Write-Host "Setting subnets"
        if (($primaryNICSubnetName -ne $secondaryNICSubnetName) -and ($secondaryNICSubnetName -ne ""))
        {
            Set-AzureSubnet -SubnetNames $primaryNICSubnetName,$secondaryNICSubnetName  -VM $VMConfig
        }
        else 
        {
            Set-AzureSubnet -SubnetNames $primaryNICSubnetName -VM $VMConfig
        }
    
        Write-Host "building networking config"
        $secondaryNicArray = @();
        if ($secondaryNICs -ne "")
        {
            $secondaryNicArray = $secondaryNICs.Split('|')
            $i = 2;
            foreach ($nic in $secondaryNicArray)
            {
                Add-AzureNetworkInterfaceConfig -Name $("Ethernet" + $i) -SubnetName $secondaryNICSubnetName -VM $VMConfig
				# UNCOMMENT below for static IPs
				#Add-AzureNetworkInterfaceConfig -Name $("Ethernet" + $i) -SubnetName $secondaryNICSubnetName -StaticVNetIPAddress $nic -VM $VMConfig
                $i = $i + 1
            }
        }

        # UNCOMMENT below if you want static IPs
        # Default NIC
		<#
	    if ($primaryNICIP -ne "")
	    {
	        Set-AzureStaticVNetIP -IPAddress $primaryNICIP -VM $VMConfig
	    }#>
       
	   
        #Write-Host "Adding custom extensions"
        #if (($secondaryNICs -ne "") -and ($os -eq "Windows"))
        #{
        #    $VMConfig = Set-AzureVMCustomScriptExtension -VM $VMConfig -ContainerName 'scripts' -FileName 'DefaultRouteAdd.ps1' -StorageAccountName "aclimages"
        #}

        Write-Host "adding data disks"
        if ($datadisks -ne "")
        {
            $i = 0;
            
            Write-Host "Number of data disks to create: $datadisks"
            while ($i -lt [int]$datadisks)
            {
                Write-Host "Creating data disk: $i"
                Add-AzureDataDisk -CreateNew -DiskSizeInGB 100 -DiskLabel $("DataDisk" + $i) -LUN $i -VM $VMConfig
                $i = $i + 1
            }     
        }

        Write-Host "adding availability sets"
        if ($availset -ne "")
        {
            Set-AzureAvailabilitySet -AvailabilitySetName $availset -VM $VMConfig
        }

        #Write-Host "Disabling boot diagnostics"
        #Set-AzureBootDiagnostics -Disable -VM $VMConfig

        Write-Host "Creating VM"
        $AzureVM = New-AzureVM -ServiceName $serviceName -VM $VMConfig -VNetName $vnetName -Location $deploymentLocation -WaitForBoot
        Write-Host "New-AzureVM completed"

        $retry = 1
		while($retry -le 4) {
			try {
				$vm = Get-AzureVM -Name $vmName -ServiceName $serviceName
                Write-Host "waiting....Get-AzureVM"
				break
			}
			catch
			{
				Write-Log "Failed $retry/4. Exception in Get-AzureVM. ServiceName $ServiceName vmName $vmName : Message: $_.Exception.Message." -color "Yellow" 
				$retry = $retry + 1
				Start-Sleep 10
			}
		}

        $secondsToWait = 5*60
		$startTime = Get-Date
		Write-Log "Running: Waiting for the VM to boot up. Checking the GuestAgentStatus of the VM; giving about $secondsToWait seconds time maximum." 

		# Check if the GuestAgentStatus is available for the VM, if yes, let's use that to check if the VM is accessible or not.	
		if($vm.GuestAgentStatus -ne $null)
		{
			Write-Log "Running: Check for the GuestAgentStatus." 
            # query the agent status every 5 seconds for up to $secondsToWait 
			while($vm.GuestAgentStatus.Status -ne "Ready" -and ((Get-Date) - $startTime).TotalSeconds -lt $secondsToWait) 
			{
				Start-Sleep 5
				$retry = 1
				while($retry -lt 4) {
					try 
                    {
                        $vm = Get-AzureVM -Name $vmName -ServiceName $serviceName
						break
					}
					catch
					{
						Write-Log "Failed $retry/4. Exception in Get-AzureVM. ServiceName $ServiceName vmName $vmName : Message: $_.Exception.Message." -color "Yellow" 
				        $retry = $retry + 1
						Start-Sleep 5
					}
				}
			}

			if($vm.GuestAgentStatus.Status -eq "Ready")
			{
				Write-Log "VM Guest Agent Status is 'Ready': ServiceName $ServiceName vmName $vmName ." -color "Green" 
			}
			else
			{
				Write-Log "VM Guest Agent Status is not Ready: ServiceName $ServiceName vmName $vmName . Continue anyway." -color "Yellow" 
            }
        }
        else
        {
            Write-Log "No agent. Sleep $secondsToWait seconds." 
            Start-Sleep $secondsToWait
        }	

        Add-Content $global:CreatedVMLog "Added new VM $vmName Service $ServiceName." 


        # configure load balancing
        # if the VM is in a load balancer -- add it
        if ($lbendpointname -ne "")
        {
            if ($lbtype -eq "internal")
            {
                Write-Log "Internal load balancer required: $lbendpointname"  
                $ilb = Get-AzureInternalLoadBalancer -ServiceName $serviceName
                if ($ilb -eq $null)
                {
                    Write-Log "Internal load balancer not found for $serviceName. Creating"
                    Add-AzureInternalLoadBalancer -ServiceName $serviceName -InternalLoadBalancerName "ilb1" –SubnetName $primaryNICSubnetName -StaticVNetIPAddress $lbvip  
                }

                Write-Log "Adding VM to ILB"  
                Get-AzureVM -ServiceName $serviceName -Name $vmName | Add-AzureEndpoint -Name "ilbendpoint1" -Protocol "tcp" -LocalPort $lbport -PublicPort $lbport -DefaultProbe -InternalLoadBalancerName "ilb1" -LBSetName $lbendpointname | Update-AzureVM
                Write-Log "ILB endpoint added successfully" -color Green
            }
            else # external
            {
                Write-Log "External load balancer required: $lbendpointname" 
                Get-AzureVM -ServiceName $serviceName -Name $vmName | Add-AzureEndpoint -Name "elbendpoint1" -Protocol "tcp" -LocalPort $lbport -PublicPort $lbport -LBSetName $lbendpointname -DefaultProbe | Update-AzureVM
                #Set-AzureLoadBalancedEndpoint -ServiceName $serviceName -LBSetName $lbendpointname -Protocol tcp -LocalPort $lbport            
                Write-Log "External loadbalanced endpoint added successfully" -color Green
            }
        }

        if ($running -eq "Stopped")
        {
            Write-Log "VM is in a stopped state, so shutdown/deallocate"  
            Stop-AzureVM -ServiceName $ServiceName -Name $vmName -Force
            Write-Log "shutdown complete" 
        }

        Write-Log "Success creating $vmName" -color Green
    }
    catch
    {
        Write-Log "Error creating new VM $vmName Service $ServiceName. Following exception was caught $($_.Exception.Message)" -color "Red"
        Add-Content $global:FailedVMLog "Error creating new VM $vmName Service $ServiceName. Following exception was caught $($_.Exception.Message)"
    }
}

Select-AzureSubscription -SubscriptionId $SubscriptionId -Default | Out-Null
Write-Log "Success: Added the Azure Account. Selected the Subscription with Id $SubscriptionId as the default one." 

$vms = Import-Csv $ImportCsvFileName
Write-Log "Success: Imported $ImportCsvFileName . Begin creating VMs." -color Green

foreach($vm in $vms)
{
    # vmname,csname,size,agent,running,lbendpointname,lbport,lbvip,lbtype,osdisktype,os,ip,datadisks,subnet,secondarynics,availset

    $f = $vm.csname
    if ($f.Length -gt 14)
    {
        $vm.csname = $CloudServicePrefixLetter + $f.Substring(1, $f.Length-1)
    }
    else
    {
        $vm.csname = $CloudServicePrefixLetter + $f
    }

    $ret = Get-AzureVM -ServiceName $vm.csname -Name $vm.vmname
    if ($ret -eq $null)
    {
        Write-Log "-vhdStorageAccount $($StandardStorageAccountName) -vmName $($vm.vmname) -serviceName $($vm.csname) -customImageName $($WindowsCustomImageName) -instanceSize $($vm.size) -secondaryNICSubnetName $($vm.secondarysubnet) -secondaryNICs $($vm.secondarynics) -primaryNICIP $($vm.ip) -primaryNICSubnetName $($vm.subnet) -running $($vm.running) -datadisks $($vm.datadisks) -agent $($vm.agent) -availset $($vm.avilset) -vnetName $($VirtualNetworkName) -deploymentLocation $($AzureRegion) -os $($vm.os) -lbendpointname $($vm.lbendpointname) -lbport $($vm.lbport) -lbvip $($vm.lbvip) -lbtype $($vm.lbtype)" -color "Yellow"
        Create-VM -vhdStorageAccount $StandardStorageAccountName -customImageName $WindowsCustomImageName -vmName $vm.vmname -serviceName $vm.csname -instanceSize $vm.size -secondaryNICSubnetName $vm.secondarysubnet -secondaryNICs $vm.secondarynics -primaryNICIP $vm.ip -primaryNICSubnetName $vm.subnet -running $vm.running -datadisks $vm.datadisks -agent $vm.agent -availset $vm.availset -adminUsername "ops" -adminPwd "pass@word2" -vnetName $VirtualNetworkName -deploymentLocation $AzureRegion -os $vm.os -lbendpointname $vm.lbendpointname -lbport $vm.lbport -lbvip $vm.lbvip -lbtype $vm.lbtype
    }
    else
    {
        Add-Content $global:ExistsVMLog "$vmName Service $ServiceName already exists." 
    }
}

Write-Log "Done" -color "Green"

