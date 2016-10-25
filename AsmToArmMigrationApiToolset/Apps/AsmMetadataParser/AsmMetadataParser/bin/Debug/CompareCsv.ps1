Param
(
    [Parameter(Mandatory=$true)]          
    [string]$csvOld,
    [Parameter(Mandatory=$true)]          
    [string]$csvNew    
)

$vmMapOld = @{}
$csvItems1 = Import-Csv $csvOld -ErrorAction Stop

foreach($csvItem in $csvItems1)
{
    $vmMapOld.Add($csvItem.csname + '|' + $csvItem.vmname, $csvItem.csname + ', ' + $csvItem.vmname)   
}

$vmMapNew = @{}
$csvItems2 = Import-Csv $csvNew -ErrorAction Stop

foreach($csvItem in $csvItems2)
{
    if ($vmMapOld.ContainsKey($csvItem.csname + '|' + $csvItem.vmname))
    {
        $vmMapOld.Remove($csvItem.csname + '|' + $csvItem.vmname)
    }
    else
    {
        $vmMapNew.Add($csvItem.csname + '|' + $csvItem.vmname, $csvItem.csname + ', ' + $csvItem.vmname)   
    }
}

Write-Host "OLD"

foreach($item in $vmMapOld.Values)
{
    Write-Host $item -BackgroundColor Green
}

Write-Host ""
Write-Host "NEW"

foreach($item in $vmMapNew.Values)
{
    Write-Host $item -BackgroundColor Green
}


