<# ROLLBACK ASM TO ARM MIGRATION

 Purpose: After committing a migration to ARM, if applications fail and can’t be resolved, the ARM migration can be rolled back to ASM/classic with this script. Public VIPs will be lost but all other metadata will be brought back to ASM. Use this as a last resort risk mitigation contingency. 
 v 1.1

 Assumptions
 1. Right before migrating to ARM, run metadata extract (MetadataExtract.ps1) on the subscription containing the vnet to migrate. Save the xml.
 2. The rollback script should be run after first deleting all of the "-Migrated" resource groups.  Also delete the "-Migrated" RG containing the migrated vnet.
      Use a provided script called DeleteResourceGroups.ps1 to quickly delete the -migrated resource groups. The disk VHDs in storage will not be removed.
 3. Before running the rollback script, create the ASM vnet and NSGs. The VNET config should first be exported. The NSG part can be automated with HydrateNSG.ps1.
 4. The storage accounts should all be V1 storage accounts and have not been migrated to V2 storage accounts. 
      Rollback script assumes all of vhd's are still in their original v1 storage account container locations -- which should be true.
 
 Run the script after deleting all of the ARM resource groups, and after recreating the v1 vnet and NSGs.  The input to the script is a CSV file created by 
   AsmMetadataParser exe.  Example.  AsmMetadataParser.exe CIO_Network metadata.xml .  This will generate the CSV that Rollback.ps1 takes as an input.
#>

Param
(
    [Parameter(Mandatory=$true)]
	[string]$SubscriptionId,             # subscriptionID for the test lab to hydrate the test environment
    [Parameter(Mandatory=$true)]
	[string]$VirtualNetworkName,         # virtual network in the test lab (should be already setup) to place the VMs
    [Parameter(Mandatory=$true)]   
	[string]$AzureRegion,                # region to build out hybrid environment. The virtual network above must already be setup in this region.
    [Parameter(Mandatory=$true)]  
	[string]$ImportCsvFileName           # file generated from MetadataExtract.ps1 that contains all of the ASM metadata before ARM migration.
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
        [string]$lbtype,
        [string]$osDiskName,
        [string]$dataDiskNames,
        [string]$osdiskstorageaccount,
        [string]$osDiskVhd,
        [string]$dataDiskVhds,
        [string]$endpoints,
        [string]$reservedip
    )

    try
    {
        Set-AzureSubscription -SubscriptionId $SubscriptionId -CurrentStorageAccountName $osdiskstorageaccount

        Add-AzureDisk -DiskName $osDiskName -MediaLocation $osDiskVhd -OS $os
        $VMConfig = $null
        $VMConfig = New-AzureVMConfig -Name $vmName -InstanceSize $instanceSize -DiskName $osDiskName

        if (($primaryNICSubnetName -ne $secondaryNICSubnetName) -and ($secondaryNICSubnetName -ne ""))
        {
            Set-AzureSubnet -SubnetNames $primaryNICSubnetName,$secondaryNICSubnetName  -VM $VMConfig
        }
        else 
        {
            Set-AzureSubnet -SubnetNames $primaryNICSubnetName -VM $VMConfig
        }
    
        $secondaryNicArray = @();
        if ($secondaryNICs -ne "")
        {
            $secondaryNicArray = $secondaryNICs.Split('|')
            $i = 2;
            foreach ($nic in $secondaryNicArray)
            {
                Add-AzureNetworkInterfaceConfig -Name $("Ethernet" + $i) -SubnetName $secondaryNICSubnetName -StaticVNetIPAddress $nic -VM $VMConfig
                $i = $i + 1
            }
        }

        # Default interface
        if ($primaryNICIP -ne "")
        {
            Set-AzureStaticVNetIP -IPAddress $primaryNICIP -VM $VMConfig
        }
       
        $dataDisksArray = @()
        $dataDiskVhdsArray = @()

        if ($dataDiskNames -ne "")
        {
            $dataDisksArray = $dataDiskNames.Split('|')
            $dataDiskVhdsArray = $dataDiskVhds.Split('|')
            $i = 0
            
            foreach ($disk in $dataDisksArray)
            {
                Write-Log "Adding data disks...-DiskName $($disk) -MediaLocation $($dataDiskVhdsArray[$i])"
                Add-AzureDisk -DiskName $disk -MediaLocation $dataDiskVhdsArray[$i] 
                Write-Log "Registered data disk"
                Add-AzureDataDisk -Import -DiskName $disk -LUN $i -VM $VMConfig
                $i = $i + 1
                Write-Log "Added data disk : $disk"
            
            }     
        }

        if ($availset -ne "")
        {
            Set-AzureAvailabilitySet -AvailabilitySetName $availset -VM $VMConfig
        }

        Write-Log "Creating VM"
        $AzureVM = New-AzureVM -ServiceName $serviceName -VM $VMConfig -VNetName $vnetName -Location $deploymentLocation -WaitForBoot
        Write-Log "New-AzureVM completed"

        $retry = 1
		while($retry -le 4) {
			try {
				$vm = Get-AzureVM -Name $vmName -ServiceName $serviceName
                Write-Log "waiting....Get-AzureVM"
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
        Write-Log "Added new VM $vmName Service $ServiceName." 
        
        # create an internal load balancer in the cloud service if its needed. Can only have 1 ILB per cloud service
        if ($lbtype -eq "internal")
        {
            Write-Log "Internal load balancer required: $lbendpointname"  
            $ilb = Get-AzureInternalLoadBalancer -ServiceName $serviceName  
            if ($ilb -eq $null)
            {
                Write-Log "Internal load balancer not found for $serviceName. Creating"
                Add-AzureInternalLoadBalancer -ServiceName $serviceName -InternalLoadBalancerName "ilb1" –SubnetName $primaryNICSubnetName -StaticVNetIPAddress $lbvip  
            }
        }

        # Format: setname|privateport|publicport|endpointname|protocol|vip|directreturn|lbname|lbtype;setname|privateport|publicport|endpointname|protocol|vip|directreturn|lbname|lbtype
        $endpointArray = $endpoints.Split(';')
        $vm = Get-AzureVM -ServiceName $serviceName -Name $vmName

        foreach ($endpoint in $endpointArray)
        {
            $endpointValues = $endpoint.Split('|')
            $setname = $endpointValues[0]
            $privateport = $endpointValues[1]
            $publicport = $endpointValues[2]
            $endpointname = $endpointValues[3]
            $protocol = $endpointValues[4]
            $vip = $endpointValues[5]
            $directreturn = $endpointValues[6]
            $lbname = $endpointValues[7]
            $lbtype2 = $endpointValues[8]

            $direct = $false 
            if ($directreturn -eq "true") { $direct = $true }

            if ($lbtype2 -eq "internal")
            {
                Write-Log "Adding VM to ILB. Adding: $lbname"  
                if (($setname -eq $null) -or ($setname -eq ""))
                {
                    $vm | Add-AzureEndpoint -Name $endpointname -Protocol $protocol -LocalPort $privateport -PublicPort $publicport -InternalLoadBalancerName "ilb1" -DirectServerReturn $direct 
                }
                else
                {
                    $vm | Add-AzureEndpoint -Name $endpointname -Protocol $protocol -LocalPort $privateport -PublicPort $publicport -InternalLoadBalancerName "ilb1" -LBSetName $setname  -DirectServerReturn $direct -DefaultProbe 
                }
                Write-Log "ILB endpoint added successfully" -color Green
            }
            else # external endpoint
            {    
                Write-Log "External load balancer required. Adding: $endpointname" 
                if (($setname -eq $null) -or ($setname -eq ""))
                {
                    $vm | Add-AzureEndpoint -Name $endpointname -Protocol $protocol -LocalPort $privateport -PublicPort $publicport -DirectServerReturn $direct 
                }
                else
                {
                    $vm | Add-AzureEndpoint -Name $endpointname -Protocol $protocol -LocalPort $privateport -PublicPort $publicport -LBSetName $setname -DirectServerReturn $direct -DefaultProbe 
                }
                Write-Log "External loadbalanced endpoint added successfully" -color Green
            }
        }

        # update VM with all of the endpoints
        if (($endpoints -ne $null) -and ($endpoints -ne ""))
        {
            $vm | Update-AzureVM
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
    # CSV fields
    #
    # vmname,csname,reservedip,cscleanup,availset,mixedmodeas,lbendpointname,lbport,lbvip,lbtype,size,agent,running,status,osdisktype,datadisks,datadiskstype,os,ip,subnet,
    #     secondarynics,secondarysubnet,mixedmodenics,extensionstate,osdiskname,datadisknames,osdiskstorageaccount,osdiskvhds,datadiskvhds,endpoints
    #

    $ret = Get-AzureVM -ServiceName $vm.csname -Name $vm.vmname
    if ($ret -eq $null)
    {
        Write-Log "-vhdStorageAccount $($StandardStorageAccountName) -vmName $($vm.vmname) -serviceName $($vm.csname) -instanceSize $($vm.size) -secondaryNICSubnetName $($vm.secondarysubnet) -secondaryNICs $($vm.secondarynics) -primaryNICIP $($vm.ip) -primaryNICSubnetName $($vm.subnet) -running $($vm.running) -datadisks $($vm.datadisks) -agent $($vm.agent) -availset $($vm.avilset) -vnetName $($VirtualNetworkName) -deploymentLocation $($AzureRegion) -os $($vm.os) -lbendpointname $($vm.lbendpointname) -lbport $($vm.lbport) -lbvip $($vm.lbvip) -lbtype $($vm.lbtype) -osdiskname $($vm.osdiskname) -osdiskstorageaccount $($vm.osdiskstorageaccount) -datadisknames $($vm.datadisknames) -osdiskvhd $($vm.osdiskvhd) -datadiskvhds $($vm.datadiskvhds) -endpoints $($vm.endpoints) -reservedip $($vm.reservedip)" -color "Yellow"
        Create-VM -vhdStorageAccount $StandardStorageAccountName -vmName $vm.vmname -serviceName $vm.csname -instanceSize $vm.size -secondaryNICSubnetName $vm.secondarysubnet -secondaryNICs $vm.secondarynics -primaryNICIP $vm.ip -primaryNICSubnetName $vm.subnet -running $vm.running -datadisks $vm.datadisks -agent $vm.agent -availset $vm.availset -adminUsername "ops" -adminPwd "pass@word2" -vnetName $VirtualNetworkName -deploymentLocation $AzureRegion -os $vm.os -lbendpointname $vm.lbendpointname -lbport $vm.lbport -lbvip $vm.lbvip -lbtype $vm.lbtype -osdiskname $vm.osdiskname -osdiskstorageaccount $($vm.osdiskstorageaccount) -datadisknames $vm.datadisknames -osDiskVhd $vm.osdiskvhd -dataDiskVhds $vm.datadiskvhds -endpoints $vm.endpoints -reservedip $vm.reservedip
    }
    else
    {
        Add-Content $global:ExistsVMLog "$vmName Service $ServiceName already exists." 
    }
}

Write-Log "Script completed" -color "Green"

