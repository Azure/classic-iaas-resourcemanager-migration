# Classic IaaS to Azure Resource Manager IaaS migration using ASMtoARMTool

This article will show you how to use ASMtoARMTool located at [Azure/classic-iaas-resourcemanager-migration](https://github.com/Azure/classic-iaas-resourcemanager-migration) to migrate or clone classic IaaS solutions to Azure Resource Manager IaaS.

## What it does

The Azure Service Management to Azure Resource Manager migration tool for IaaS workloads (ASMtoARMTool) is an additional option to migrate Azure Service Management IaaS resources to Azure Resource Manager IaaS resources. The migration can occur within the same subscription or between different subscriptions and subscription types (ex: CSP subscriptions).

This article provides the functional details to use the tool for Azure Service Management to Azure Resource Manager migration of IaaS workloads. The tool exports the following resources:


**For Virtual Networks the tool exports the ARM corresponding object types**

- Virtual networks

- Subnets

- VPN gateways

- Public IP

- Connections

- Local gateways

- Network security groups

- Route tables

**For Storage Accounts the tool exports the ARM corresponding object type**

- Storage Account

**For Cloud Services the tool exports the ARM corresponding object types**

- Load Balancer

- Inbound NAT rules

- Load balancing rules

- Public IP

**For Virtual Machines the tool exports the ARM corresponding object types**

- Virtual machines

- Network interfaces

- Availability Sets

The tool uses Service Management REST API calls to gather all the details on Network, Storage and Compute related resources. As per your selection, all the related configurations are exported into the JSON file which can be used for the deployment into Azure Resource Manager. The files created during the process are listed below:

- **Export.JSON** - This is the ARM template that the tool generates

- **Copyblobdetails.JSON** - This file contains the Source and Target Storage Accounts with their keys to access them for the blob copy

- **ASMtoARMTool-&lt;YYYYMMDD&gt;.log** - This file is created in the %USERPROFILE%\appdata\Local and record each steps processed in the tool

- **ASMtoARMTool-XML-&lt;YYYYMMDD&gt;.log** - This file is created in the %USERPROFILE%\appdata\Local and it is an export of the raw xml captured and processed from the REST API calls

<br>
> Migrating resources with these tool will cause downtime for your classic Virtual Machines. If you're looking for platform supported migration, please visit 

- [Platform supported migration of IaaS resources from Classic to Azure Resource Manager stack](./virtual-machines-windows-migration-classic-resource-manager.md)
- [Technical Deep Dive on Platform supported migration from Classic to Azure Resource Manager](./virtual-machines-windows-migration-classic-resource-manager-deep-dive.md)
- [Migrate IaaS resources from Classic to Azure Resource Manager using Azure PowerShell](./virtual-machines-windows-ps-migration-classic-resource-manager.md)

<br>

> The ASMtoARMTool is not supported by Microsoft Support. Therefore, it is open sourced on Github and we're happy to accept PRs for fixes or additional scenarios.

<br>

## Get it
You can either get the tool by downloading the zip file from the above specified repo or clone the repo using the either of the commands below


    git clone https://github.com/Azure/classic-iaas-resourcemanager-migration.git

or

    git clone git@github.com:Azure/classic-iaas-resourcemanager-migration.git


## How to use

### Pre-requisites
1. Windows 8 or Windows Server 2012, or later
1. .Net Framework 4.0 or higher
1. Latest [Azure PowerShell Module](https://azure.microsoft.com/en-us/documentation/articles/powershell-install-configure)
1. Login credentials at source Azure subscription
1. Login credentials at destination Azure subscription

### Launch ASMtoARMTool.exe

![ASMtoARMTool main window](./media/virtual-machines-windows-migration-asmtoarmtool/asmtoarmtool-main.png)

**Step 1:** The tool requires the Tenant ID or Domain Name of the Tenant before listing the Subscriptions. Type it in the Tenant textbox of the tool and hit on the “Get Subscriptions” button. The “Get Subscription” button will launch the Azure Authentication page and user has to enter the credentials to access the source subscription. Post successful authentication the Subscriptions will be loaded.

**Step 2:** Select one of the Subscriptions from the list and wait for the components to completely load. The status bar will show as “Ready” when all the components are loaded.

**Step 3:** The tool can export the configurations of Virtual Networks, Storage and Virtual Machine. User can select any of them or combination of the resources to export.

**Step 4:** The Export Objects button will be enabled only after choosing the Output folder. Once the resources are selected and Output Folder is set, user can click on Export Objects.

**Step 5:** The Export Objects will then collect all the properties of selected resources and create a JSON Template and a blob details file in the Output Folder selected.

**Step 6:** Once the export completes, start the deployment of the template using the cmdlet:


    New-AzureRmResourceGroupDeployment -Name "<Deployment Name>" -ResourceGroupName "<Resource Group Name>" -TemplateFile "<full path of the export.JSON>" -Verbose

> If virtual machines were included on the export, an error will show up stating that the virtual machines VHDs were not found. This is expected since the blobs haven’t been copied yet to the new storage accounts.

Execute steps 7 and 9 only if virtual machines were included on the export.

**Step 7:** initiate and complete the blob copy the required OS disks and data disks using BlobCopy.PS1 script

> BlobCopy.ps1 script creates temporary snapshots to copy the blobs. This means that it will be able to copy disks from running virtual machines. But, depending on the workload, it can be absolutely required to stop the virtual machine to guarantee data consistency. This is the case, for example, for virtual machines using multiple data disks to create stripped volumes (like storage spaces).

1.This command will initiate the asynchronous copy of the Storage Blobs

    .\BlobCopy.ps1 -ResourcegroupName "<Resource Group Name>" -DetailsFilePath "<Full Path of copyblobdetails.JSON>" -StartType StartBlobCopy

2.This command will monitor and show the progress of the copy

    .\BlobCopy.ps1 -ResourcegroupName "<Resource Group Name>" -DetailsFilePath "<Full Path of copyblobdetails.JSON>" -StartType MonitorBlobCopy

> Always run above commands in sequence. The first, creates the snapshots and initiate the asynchronous copies. The second, will monitor the asynchronous copy status of each blob and clean the snapshots at the end.

**Step 8:** Once the BlobCopy is completed re-deploy the export.JSON template (step 7) since the VHD’s required for the virtual machines are available now.

**Step 9:** Because the tool creates a Load Balancer matching each Cloud Service, after the migration is complete, you need to change the DNS records that were pointing to the Cloud Service DNS name or IP to point to the new Load Balancer DNS name or IP.

## Tool Options

![ASMtoARMTool main window](./media/virtual-machines-windows-migration-asmtoarmtool/asmtoarmtool-options.png)

### Uniqueness suffix

When exporting storage accounts and cloud services, the tool appends to the resource name the “uniqueness suffix” string to avoid names conflicts. You have the option to change this uniqueness suffix string.

### Build empty environment

If this option is selected, the selected virtual machines will be exported to export.json file as new virtual machines with empty data disks. By default, Windows virtual machines will be created using Windows Server 2012 R2 Datacenter SKU and Linux virtual machine will be created using Ubuntu Server 16.04.0-LTS SKU. You can change this by editing the export.json template and change the image references.

### Allow telemetry collection

“Allow telemetry collection” is enabled by default. It is used to collect information such as Tenant ID, Subscription ID, Processed Resource Type, Processed Resource Location and the Execution date. This data is collected only to know the tool usage and it will remain only with the development team. You can disable this at any time.

## Scenarios

### Migration using new virtual network with different address space
One of the biggest priorities when planning for an ASM to ARM migration is to minimize the solution downtime. When possible, application level data replication is the option that guarantees minimal downtime, for example using SQL Server AlwaysOn replication.

If the migration scenario allows to create a new ARM virtual network with a different address space, you can create a site 2 site VPN connecting both ASM and ARM virtual networks. This will allow you to deploy an additional server on the new ARM environment, replicate the data and failover service with minimal downtime.

You can leverage ASMtoARMTool to help on the migration of servers that do not require data replication, like application servers and web servers. 

### Migration using new virtual network with same address space
If it’s not possible to have a new ARM virtual network with a different address space, you will use the tool to migrate all solution virtual machines, but you need to plan for a larger downtime window. The downtime will be as large as the largest virtual machine to migrate (largest = OS disk used space + all data disks used space).

Because the tool uses snapshots to copy the blobs, you can use the tool without stopping any virtual machine and test how much downtime you need to plan for the data migration process.

### Clone environment for testing
Planning and testing are key for a successful migration. The tool enables you to create a full copy of the environment and test it when deployed to ARM. This will allow you to proactively identify any configuration change required during the final migration execution.

### Clone environment with new virtual machines and data disks
It’s entirely possible that you opt for a full redeployment of the solution during the migration to ARM environment. The tool can help you to setup a new environment with similar configuration but with new and empty virtual machines.

Use “Build empty environment” option to enable this.

## Notes

### Storage account names
As the Storage Accounts supports a maximum of 24 characters in the name, and the tool adds the "uniqueness string" in the target Storage Account name, it is possible that the deployment fails if the name exceeds the limit. In such cases you need to modify the export.JSON and copyblobdetails.JSON to make it 24 characters. This is also true if the target Storage Account name is already in use.

### Troubleshooting
The detailed logs and output of the REST API are captured in the location %USERPROFILE%\appdata\Local with the file name ASMtoARMTool-&lt;YYYYMMDD&gt;.log and ASMtoARMTool-XML-&lt;YYYYMMDD&gt;.log.
In case of any issues during the deployment of the Export.JSON you need to troubleshoot the template properties and fix the invalid entries. Report any issue on the tool site.

## Known Issues
Issue #1: If there are more than one Availability set in a Cloud Service then the ARM deployment fails with the below error message.

Error: “Microsoft.Compute/virtualMachines/<VM Name> is using different Availability Set than other Virtual Machines connected to the Load Balancer(s) <VM Name>”

Workaround: As ARM does not support multiple Availability sets under a single Load Balancer we need to use single availability set for all the VM’s or we need to have a separate Load Balancer for each Availability Set.