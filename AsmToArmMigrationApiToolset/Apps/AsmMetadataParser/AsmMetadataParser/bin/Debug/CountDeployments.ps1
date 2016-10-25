Param
(
    [Parameter(Mandatory=$true)]          
    [string]$csv  
)

$map = @{}
$items = Import-Csv $csv -ErrorAction Stop

foreach($item in $items)
{
    if (!$map.ContainsKey($item.csname)) { $map.Add($item.csname, "") }
}

Write-Host "Deployments: $($map.Count)" -BackgroundColor Green

