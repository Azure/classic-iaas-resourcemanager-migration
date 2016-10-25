# RemoveExtensions.ps1
#
# version 1.3

Param
(
    [Parameter(Mandatory=$true)]         # subscription id
    [string]$SubscriptionID,
    [Parameter(Mandatory=$true)]         # vnet containing the vm's to remove vm extensions
    [string]$VnetName
      
)

$global:ScriptStartTime = (Get-Date -Format hh-mm-ss.ff)

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


try
{
    Select-AzureSubscription -SubscriptionId $SubscriptionID
    Write-Log "Starting RemoveExtensions.ps1 v1.3 script" -color Green

    $vms = Get-AzureVM | Where-Object { $_.VirtualNetworkName -eq $VnetName }

    foreach($vm1 in $vms)
    {
        try
        {
            foreach ($ext in $vm1.VM.ResourceExtensionReferences)
            {
                $vm2 = Get-AzureVM -ServiceName $vm1.ServiceName -Name $vm1.Name   # vm to be updated

                if ($ext.ReferenceName -eq "CustomScriptExtension")
                {
                    Write-Log "Remove extension from $($vm2.ServiceName) : $($vm2.Name), Extension: $($ext.ReferenceName)"
                    $vm2 | Set-AzureVMCustomScriptExtension -Uninstall -ErrorAction Stop | Update-AzureVM  -ErrorAction Stop
                }
                elseif ($ext.ReferenceName -eq "BGInfo" -and $ext.Version -eq "2.*")  # only version 2 needs to be removed
                {
                    Write-Log "Remove extension from $($vm2.ServiceName) : $($vm2.Name), Extension: $($ext.ReferenceName)"
                    $vm2 | Set-AzureVMCustomScriptExtension -Uninstall -ErrorAction Stop | Update-AzureVM  -ErrorAction Stop
                }
                elseif ( `
                    ($ext.ReferenceName -eq "Monitoring") -or `
                    ($ext.ReferenceName -eq "IaaSDiagnostics") -or `
                    ($ext.ReferenceName -eq "VMAccessAgent") -or `
                    ($ext.ReferenceName -eq "Microsoft.Compute.VMAccessAgent") -or `
                    ($ext.ReferenceName -eq "LinuxAsm") -or `
                    ($ext.ReferenceName -eq "VMAccessForLinux") -or `
                    ($ext.ReferenceName -eq "LinuxDiagnostic"))
                {
                    Write-Log "Remove extension from $($vm2.ServiceName) : $($vm2.Name), Extension: $($ext.ReferenceName)"
                    Set-AzureVMExtension -Publisher $ext.Publisher -Version $ext.Version -ExtensionName $ext.ReferenceName -Uninstall -VM $vm2  -ErrorAction Stop | Update-AzureVM  -ErrorAction Stop
                }
            }
        }
        catch
        {
            Write-Log "Unexpected ERROR checking storage stamp IP. Following exception was caught $($_.Exception.Message)" -color "Red"
        }
    }

    Write-Log "Success: script completed" -color "Green"
}
catch
{
    Write-Log "ERROR in script. Following exception was caught $($_.Exception.Message)" -color "Red"
}



