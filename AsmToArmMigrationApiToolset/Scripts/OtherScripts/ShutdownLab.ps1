<#
Purpose: Useful scripts to shut down and clean-up a test lab. CleanupLabArmAsync.ps1 is particularly interesting to quickly fire a REST delete call against all the newly migrated resource groups without waiting. WARNING. Be careful to not remove VMs that are not part of the lab testing.
#>

Select-AzureSubscription -SubscriptionId ""

$services = Get-AzureService | Where-Object {$_.ServiceName.StartsWith("y")}
foreach ($svc in $services)
{
    try
    {
        $vms = Get-AzureVM -ServiceName $svc.ServiceName 
        foreach ($vm in $vms)
        {
            if ($vm.PowerState -ne "Stopped")
            {
                Write-Host "Stopping the vm: $($vm.Name)."
                Stop-AzureVM -ServiceName $svc.ServiceName -Name $vm.Name -Force
                Write-Host "Success stopping the vm: $($vm.Name)." -ForegroundColor "Green"
            }
        }
    }
    catch
    {
        Write-Host "Error stopping the vm: $($vm.Name). Following exception was caught $($_.Exception.Message)" -ForegroundColor "Red"
    }
}
