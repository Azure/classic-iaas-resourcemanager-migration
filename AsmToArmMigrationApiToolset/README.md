<<<<<<< HEAD
<br />

# Microsoft Platform Supported <br /> Azure Classic to Azure Resource Manager Migration:

##*Lessons Learned, Recommend Practices and Additional insights gained from enterprise customer migrations* 

<br />

<br />

By: Microsoft

Colin Cole

Azure CAT

Azure Compute Product Teams

Date: Oct 2016

<br />

<br />

#### Table of Contents 
- [Background and Document Intent](#Background-and-document-intent)
- [Migration Journey Overview](#Migration-journey-overview)
- [Plan](#Plan)
   - [Technical considerations and tradeoffs](#Technical-considerations-and-tradeoffs) 
   - [Patterns of success](#Patterns-of-success)
   - [Pitfalls to avoid](#Pitfalls-to-avoid)
- [Lab Test](#Lab-test)
   - [Technical considerations and tradeoffs](#Technicalconsiderationsandtradeoffs-1)
   - [Migration Analysis/Test high level workflow](#Migration-analysis-test-high-level-workflow)
   - [Patterns of success](#Patternsofsuccess-1)
   - [Pitfalls to avoid](#Pitfalls-to-avoid-1)
- [Migration](#Migration)
   - [Technical considerations and tradeoffs](#Technical-considerations-and-tradeoffs-2)
   - [Patterns of success](#Patterns-of-success-2)
   - [Pitfalls to avoid](#Pitfalls-to-avoid-2)
- [Beyond Migration](#Beyond-migration)
   - [Technical considerations and tradeoffs](#Technicalconsiderationsandtradeoffs-3)
   - [Patterns of success](#Patterns-of-success-3)
   - [Pitfalls to avoid](#Pitfalls-to-avoid-3)
- [Appendix A – Important Links](#Appendix-a-important-links)
- [Appendix B – Toolset Execution Details](#Appendix-b-toolset-execution-details)
   - [Metadata Extract](#Metadata-extract)
   - [NSG Bindings](#Nsg-bindings)
   - [AsmMetadataParser](#Asmmetadataparser)
   - [HydrateNSG](#Hydratensg)
   - [HydrateLab](#Hydratelab)
   - [GetMigrationStatus](#Getmigrationstatus)
   - [Other Scripts](#Other-scripts)

<br />

## Background and Document Intent

Microsoft released an updated IaaS deployment model, Azure Resource Manager ([Azure RM](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-compare-deployment-models/)), in the summer of 2015.  Azure Classic, sometimes referred to as Azure Service Management (ASM), is the original IaaS deployment model for core compute, networking and storage.   There are benefits and considerations to both deployment models, as detailed [here](https://azure.microsoft.com/en-us/documentation/articles/resource-manager-deployment-model/); view a Microsoft-only webinar for additional planning options [here](https://microsoft.sharepoint.com/sites/infopedia/Media/details/aevd-3-102434).

Depending on your scenario, there are several options for migrating from Classic to Azure RM, as listed [here](https://azure.microsoft.com/en-us/blog/iaas-migration-classic-resource-manager/).  In early 2016, Microsoft released a Generally Available (GA) platform supported [Classic to Azure RM migration API](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-migration-classic-resource-manager/#unsupported-features-amp-configurations) to help existing Classic customers migrate to Azure RM.

This document is intended for a customer migrating via the Microsoft platform-supported migration API.  Content includes recommended practices captured/developed as part of a series of actual, enterprise-sized customer migrations. We document technical considerations and tradeoffs, patterns of success, and pitfalls to avoid.

Our key learning for the migration is the importance of planning, and a lab to &#39;dry run&#39; the migration.  With a bit of planning and lab testing, your Classic to Azure RM migration will be seamless and uneventful.  This document will not duplicate content from elsewhere, however, we will include links where appropriate; see Appendix A for important related content.

## Migration Journey Overview

There are four general phases of the migration journey.

![Four phases of the migration journey](Plan-labtest-migrate-beyond.png)

This document will delve into each of these four phases with technical considerations and tradeoffs, patterns of success, and pitfalls to avoid.

## Plan

### Technical considerations and tradeoffs

It is critical to plan out your migration journey.  Depending on your technical requirements size, geographies and operational practices, you might want to consider:

1. Why is Azure RM desired for your organization?  What are the business reasons for a migration?
2. What are the technical reasons for Azure RM?  What (if any) additional Azure services would you like to leverage?
3. Which application (or sets of virtual machines) is included in the migration?
4. Which scenarios are supported with the migration API?  Review the supported scenarios [here](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-migration-classic-resource-manager/#unsupported-features-and-configurations).
5. Will your operational teams now support applications/VMs in both Classic and Azure RM?
6. How (if at all) does Azure RM change your VM deployment, management, monitoring, and reporting processes?  Do your deployment scripts need to be updated?
7. What is the communications plan to alert stakeholders (end users, application owners, and infrastructure owners)?
8. Depending on the complexity of the environment, should there be a maintenance period where the application is unavailable to end users and to application owners?  If so, for how long?
9. What is the training plan to ensure stakeholders are knowledgeable and proficient in Azure RM?
10. What is the program management or project management plan for the migration?
11. What are the timelines for the Azure RM migration and other related technology road maps?  Are they optimally aligned?

### Patterns of success

Successful customers have detailed plans where the above questions are discussed, documented and governed.  Ensure the migration plans are broadly communicated to sponsors and stakeholders.  Equip yourself with knowledge about your migration options; a quick Bing search is highly recommended.

### Pitfalls to avoid

- Failure to plan.  The technology steps of this migration are proven and the outcome is predictable.
- Assumption that the platform supported migration API will account for all scenarios.  Read this [paper](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-migration-classic-resource-manager/#unsupported-features-and-configurations) to understand what scenarios are supported.
- Not planning potential application outage for end users.  Plan enough buffer to adequately warn end users of potentially unavailable application time.

## Lab Test

### Technical considerations and tradeoffs

Testing your exact scenario (compute, networking, and storage) is vital to a smooth migration.

You might want to consider:

1. A wholly separate lab or an existing non-production environment to test?  We recommend a wholly separate lab that can be migrated repeatedly and can be destructively modified.  Scripts to collect/hydrate metadata from the real subscriptions are listed below.
2. It&#39;s a good idea to create the lab in a separate subscription. The reason is that the lab will be torn down repeatedly, and having a separate, isolated subscription will reduce the chance that something real will get accidently deleted.
3. We recommend that the lab is in a separate subscription with no external connection (like Express Route), therefore causing NO change to your real traffic.
4. The hydrated lab will not contain real customer data nor actual data disks.  This should reduce security concerns, if there are any.
5. Lab subscription capacity.  Ensure compute, networking and storage capacities are correctly sized.
6. One core script and app that drives all other parts of the IP toolset is called MetadataExtract. This script and app will pull down all of the Classic metadata for the virtual network being migrated (and contained VMs), flatten it, and dump it into a useful spreadsheet to drive the rest of the toolset IP. This generated spreadsheet is core to the process of migration and is an input to many of the scripts.
7. Depending on your scale of migration, two or more people should be proficient in executing the lab testing, and therefore proficient in executing the real migrations.

### Migration Analysis/Test high level workflow

- **Collect Metadata**: Do the following three things to obtain the necessary metadata from the production Classic environment to be migrated:
     1. Run a PowerShell script called **MetadataExtract.ps1** (see Appendix B for details), which will extract all of the Classic cloud service deployments in a subscription to XML. This is the most important required step, and needed to identify any potential incompatibility areas. Steps 2 and 3 below are only needed if a simulated test environment will be hydrated using the metadata for actual testing of the platform supported Migration API.
     2. Export out the network configuration for the subscription that contains the virtual networks for migration. This step can be done in the classic Azure portal using the Export function on the virtual network dashboard. Or get-azurevnetsite will get all vNets. Using a -Debug flag will get the REST XML traces.
     3. Run a PowerShell script called **NSG-Bindings.ps1** to extract the NSGs (network security groups and rules) for the virtual network.
- **Parse Metadata**: Using the XML output from step 1 above from MetadataExtract, run the toolset provided application called **AsmMetadataParser.exe** with the metadata XML and the name of the virtual network to migrate.  This app will generate a flattened CSV from the metadata with the most critical data needed for building a test environment and analyzing migration readiness. It will also generate a report with any compatibility concerns flagged. The C# source code is included for this tool so it can be tweaked or extended. The CSV output from this tool is used for two purposes: 1) as input for many of the toolset scripts, and 2) analysis of the metadata, and exposing problem areas that need to be resolved prior to migration.
- **Simulation Test**: To build and test the Migration API in a test lab environment from the metadata, perform the following four steps:
     1. Build the virtual network. Import the exported network config to recreate the test vNet, subnets, and IP address space, just like the customer environment. **Note:** Remove any gateway subnets before importing the network config to build the test vNet, as gateways must be removed for migration.  Some manual hand-tweaking of the exported network config will be needed to import, and use it to build the test vNet.
     2. Run the **HydrateNSG.ps1** PowerShell script to create the NSGs and rules, and associate the NSGs to any subnets in the virtual network. Some hand-tweaking of this script will be required as documented in the script.
     3. Run the **HydrateLab.ps1** PowerShell script to create the simulation environment from the CSV generated from **AsmMetadataParser.exe**.  Some comments here:
       - Manual tweaking of the HydrateLab script may be required to optimize for static IPs vs dynamic IPs, special custom images, special gallery images, and other one-off needs. While it should work fine with no changes, tweaks may be needed for special requirements.
       - When building the test environment&#39;s VMs with **HydrateLab.ps1**, feel free to break the input CSV into smaller chunks and run multiple instances of the **HydrateLab.ps1** script in parallel.  We&#39;ve been successful running eight (8) concurrent streams to speed up the hydration process. The important thing to consider here is that each cloud service should exist in only one CSV stream so that two separate PowerShell instances do not attempt to modify the same Classic cloud service in parallel. Cloud service changes must be serialized per the rules of classic ASM IaaS. Keep this in mind when breaking up the CSV into smaller chunks.
       - Make sure to re-order the CSV records so that D-series VMs are created before A-series VMs, if a mix exists within one cloud service.  If A-series VMs are created before D-series, the D-series will likely fail as the chosen Azure cluster may not allow for both A and D.  The re-order step may not be needed, but if it is needed, it is manual. Just make sure D&#39;s are created before A&#39;s within a single cloud service and you should be fine.
     4. Now run the **Move-AzureVirtualNetwork** PowerShell scripts that are part of the Migration API to migrate the test environment to Azure RM. Test out the validate/prepare/commit options.
       - Get familiar with the Validate option, as running this and understanding its output is a best practice as part of a real migration.
       - While migrating with Move-AzureVirtualNetwork prepare/commit options, another PowerShell script from this toolset called **GetMigrationStatus.ps1** can be executed in a different PowerShell session to check the status of migration. It will display each cloud service (deployment) being migrated and provide overall progress insight.
     5. The below documentation explains how to use the new Azure RM Migration API.
        - [Platform supported migration of IaaS resources from Classic to Azure Resource Manager](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-migration-classic-resource-manager)
        - [Technical Deep Dive on Platform supported migration from Classic to Azure Resource Manager](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-migration-classic-resource-manager-deep-dive/)
        - [Migrate IaaS resources from Classic to Azure Resource Manager using Azure PowerShell](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-ps-migration-classic-resource-manager/)
        - [Migrate IaaS resources from Classic to Azure Resource Manager using Azure CLI](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-linux-cli-migration-classic-resource-manager/)
        - [FAQs: Platform supported migration of IaaS resources from Classic to Azure Resource Manager](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-migration-classic-resource-manager/#frequently-asked-questions)

The following is a list of the core tools contained in this toolset. Details on these tools, and an explanation of remaining scripts, are documented in Appendix B.
|[]() |     |
| --- | --- |
| **MetadataExtract.ps1** | Extract the deployment metadata from a production Azure subscription running Classic virtual networks. Output is a single XML file listing out each Cloud Service deployment from the vNet being migrated. |
| **NSG-Bindings.ps1** | Extract the Network Security Groups and rules for a Classic virtual network. |
| **AsmMetadataParser.exe** | Parse the metadata from **MetadataExtract.ps1** and build a flattened CSV and a compatibility report. This CSV is key to both preparing/validating migration readiness, but also as input to many of the included scripts. |
| **HydrateNSG.ps1** | Recreate the associated NSGs and rules in a simulated lab virtual network that matches the production virtual network. The vNet is built from the exported network configuration file, and this script adds NSGs and rules to the vNet. |
| **HydrateLab.ps1** | Use the CSV to hydrate a simulated Classic environment with the same metadata for running/testing the Platform supported Migration API. |
| **MoveErConnectedVnet.ps1** | Well-tested/reviewed script to do the actual migration of an ExpressRoute connected vNet to Azure RM.  The script disconnects the vNet from one or two ER circuits, removes the gateway, prepares the migration, commits the migration, and then reconnects to the one or two ER circuits. Designed to handle more than one linked ER circuit. Script will also handle expected migration API transient errors that can be safely retried. Lots of error handling and logging. When an error occurs during prepare/commit, the script will not terminate, but rather allow for prepare/commit retries. |
| **GetMigrationStatus.ps1** | Retrieves the status of an actual Classic migration using the Migration API Move-AzureVirtualNetwork cmdlet.  This will show each cloud service as it is being prepared and committed to Azure RM. |
| **ArmToAsmRollback.ps1** | After committing a migration to Azure RM, if applications fail and can&#39;t be resolved, the Azure RM migration can be rolled back to ASM/Classic with this script. Public VIPs will be lost but all other metadata will be brought back to ASM. Use this as a last resort risk mitigation contingency. The existence of this script should help customers feel a little safer about moving their workloads to Azure RM. This activity will take time and should be used only as a last resort. |

For further details on the toolset execution, instructions for the running the scripts above, and the remaining tools, see [Appendix B – Toolset execution Details](#Appendix-b-toolset-execution-details).

### Patterns of success

The following were issues discovered in many of the larger migrations.  This is not an exhaustive list and you should refer to the [support scenarios](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-migration-classic-resource-manager/#unsupported-features-and-configurations) for more detail.  You may or may not encounter these technical issues.  The IP provided as part of this toolkit will help with each of these issues by helping identify if the situation exists, as well as scripts and other IP to remediate the issue.

- **Do a Prepare/Abort Dry Run**.  This is perhaps the most important step to ensure Classic to Azure RM migration success. The migration API has two main steps: prepare and commit.  Prepare will move the metadata from Classic to Azure RM, but will not commit the move, and will not remove or change anything on the Classic side. The dry run involves preparing the migration, then aborting (not committing) the migration prepare. The goal of prepare/abort dry run is to see all of the metadata in the new portal, examine it, and verify that everything migrates correctly, and work through technical issues.  It will also give you a sense of migration duration so you can plan for downtime accordingly.  A prepare/abort does not cause any user downtime; therefore, it is non-disruptive to application usage.
  - The items below will need to be solved before the dry run, but a dry run test will also safely flush out these preparation steps if they are missed. We found the dry run to be a safe and invaluable way to ensure migration readiness.
  - The overall impact of the dry run on a production environment is minimal because the ER/VPN gateway does not need to be removed for the dry run. When prepare is running, the control plane (Azure management operations) will be locked for the whole virtual network, so no changes can be made to VM metadata during prepare/abort.  But otherwise any application function (RD, VM usage, etc.) will be unaffected.  Users of the VMs will not know that the dry run is being executed.
- **Express Route Circuits and VPN**. Currently virtual network gateways cannot be migrated to Azure RM and need to be removed from a virtual network before migration. Because of this, there will be a loss of connectivity to onprem environments during migration; however, connectivity within the virtual network itself will stay intact.  One common problem is if the vNet is configured with DNS servers located onprem, more work is needed to prepare for migration as VM Extensions will need to be removed. The important detail here is that there will be a loss of onprem connectivity during migration (but not within the virtual network), and that external internet access (with DNS) is required to successfully migrate VM Extensions. See below for more info on VM Extensions.
- **VM Extensions**. VM Extensions are potentially one of the biggest roadblocks to migrating running VMs. Remediation of VM Extensions could take upwards of 1-2 days, so plan accordingly.  A working Azure agent is needed to report back VM Extension status of running VMs. If the status comes back as bad for a running VM, this will halt migration. The agent itself does not need to be in working order to enable migration, but if extensions exist on the VM, then both a working agent AND outbound internet connectivity (with DNS) will be needed for migration to move forward.
  - If connectivity to a DNS server is lost during migration, all VM Extensions except BGInfo v1.\* need to first be removed from every VM before migration prepare, and subsequently re-added back to the VM after Azure RM migration.  This is only for VMs that are running.  If the VMs are stopped deallocated, VM Extensions do not need to be removed. The IP toolset contains a script called **RemoveExtensions.ps1** to solve this need, and also contains an **AddExtensions.ps1** to help jumpstart putting extensions back. **Note:** Many extensions like Azure diagnostics and security center monitoring will reinstall themselves after migration, so removing them is not a problem.
  - In addition, make sure NSGs are not restricting outbound internet access. This can happen with some NSG configurations. Outbound internet access (and DNS) is needed for VM Extensions to be migrated to Azure RM.
  - IMPORTANT: If an Azure Security Center policy is configured against the running VMs being migrated, the security policy needs to be stopped before removing extensions, otherwise the security monitoring extension will be reinstalled automatically on the VM after removing it.
  - There are two versions of the BGInfo extension: v1 and v2.  If the VM was created using the classic portal or PowerShell, the VM will likely have the v1 extension on it. This extension does not need to be removed and will be skipped (not migrated) by the migration API. However, if the Classic VM was created with the new Azure portal, it will likely have the JSON-based v2 version of BGInfo, which will need to be removed before migrating. Removing these extensions can take a while, so plan accordingly. The toolkit provided **RemoveExtensions.ps1** script will help here.
  - **Recommended Practice Option 1**. Don&#39;t worry about outbound internet access, a working DNS service, and working Azure agents on the VMs. Instead, uninstall all VM agents as part of the migration before Prepare, then reinstall the VM Extensions after migration. Included in the toolset are scripts to do the uninstall/reinstall: **RemoveExtensions.ps1** and **AddExtensions.ps1**.
  - **Recommended Practice Option 2**. If VM extensions are too big of a hurdle, another option is to shutdown/deallocate all VMs before migration. Migrate the deallocated VMs, then restart them on the Azure RM side. The benefit here is that VM extensions will migrate. The downside is that all public facing VIPs will be lost (this may be a non-starter), and obviously the VMs will shut down causing a much greater impact on working applications.
  - **Note:** The metadata extract generated CSV will show all VM extensions installed on each VM in the extensions column. BGInfo v.1 will not be shown as this extension can be ignored.
- **Availability Sets**. For a virtual network (vNet) to be migrated to Azure RM, the Classic deployment (i.e. cloud service) contained VMs must all be in one availability set, or the VMs must all not be in any availability set. Having more than one availability set in the cloud service is not compatible with Azure RM and will halt migration.  Additionally, there cannot be some VMs in an availability set, and some VMs not in an availability set. To resolve this, you will need to remediate or reshuffle your cloud service.  Plan accordingly as this might be time consuming.  The metadata extract generated CSV will show and mark all availability sets and cloud services that require availability set modification before migration. If any of the CSV cscleanup or mixedmodeas fields are set to true, those VMs/CloudServices will need to be remediated to follow the rules outlined above.
- **Web/Worker Role Deployments**.  Cloud Services containing web and worker roles cannot migrate to Azure RM. The web/worker roles must first be removed from the vNet before migration can start.  A typical solution is to just move web/worker role instances to a separate Classic vNet that is also linked to an ExpressRoute circuit, or to migrate the code to newer PaaS App Services (this discussion is beyond the scope of this document). In the former redeploy case, create a new Classic virtual network, move/redeploy the web/worker roles to that new virtual network, then delete the deployments from the virtual network being moved. No code changes required. The new [VNet Peering](https://azure.microsoft.com/en-us/documentation/articles/virtual-network-peering-overview/) capability can be used to peer together the v1 vNet containing the web/worker roles and other vNets in the same Azure region such as the vNet being migrated, hence providing the same capabilities with no performance loss and no latency/bandwidth penalties. Given the addition of [VNet Peering](https://azure.microsoft.com/en-us/documentation/articles/virtual-network-peering-overview/), web/worker role deployments can now easily be mitigated and not block the migration to Azure RM. The metadata extract generated CSV will highlight if these exist. They will be listed in a report (Remediationlist.txt) generated from the **AsmMetadataParser.exe** tool along with the CSV.
- **Multi-NIC Incompatibility**. In order to migrate a virtual network to Azure RM, cloud services may not contain VMs with just one network interface card (NIC) AND some VMs with more than one NIC (multi-NIC).  All VMs must have just one NIC, or all VMs must have more than one NIC (they do not all need to have the same number of NICs in the multi-NIC case). It is possible to have cloud services with both types of VMs, and these must first be remediated to either all single or multi-NIC.  The metadata extract generated CSV will outline where these situations exist and require cleanup. The CSV mixedmodenic column set to true will identify if any VMs need to be remediated.
- **Azure RM Quotas**. Azure regions have separate quotas/limits for both Classic and Azure RM. Even though in a migration scenario new hardware isn&#39;t being consumed (we&#39;re swapping existing VMs from Classic to Azure RM), Azure RM quotas still need to be in place with enough capacity before migration can start. Listed below are the four major limits we&#39;ve seen cause problems.  Open a Premier Support ticket to raise the limits.
  1. Azure RM network limit – this represents the number of NICs needed in Azure RM after migration is complete. The number should be raised to cover the total number of NICs used in the Classic vNet being migrated.
  2. Azure RM maxloadbalancers – the number of load balancers needed.
  3. Azure RM public IP addresses – the number of public IPs needed in Azure RM. Should be raised to the same number of VIPs used in Classic.
  4. Azure RM cores – should be raised to the same number of cores used in Classic.
- **Provisioning Timed Out VM Status**. The tools below will show the status of every VM being migrated. If any VM has the status of &quot;provisioning timed out&quot;, this needs to be resolved pre-migration. The only way to do this is with downtime by deprovisioning/reprovisioning the VM (delete it, keep the disk, and recreate the VM). Via the tools, you will have all of the metadata to easily perform these types of repairs. Metadata extract generated CSV will highlight these with the status column. Sort and filter the status.
- **RoleStateUnknown VM Status**. If migration halts due to a &quot;role state unknown&quot; error message, inspect the VM using the portal and ensure it is running. This error will typically go away on its own (no remediation required) after a few minutes and is often a transient type communication lapse between the fabric and the VM. Recommend practice: re-try migration again after a few minutes. Additionally, the metadata extract generated CSV will highlight these with the status column. Sort and filter the status.
- **Storage Cluster Not Equipped With Azure RM**.  In some cases, certain VMs cannot be migrated for various odd reasons. One of these known cases is if the VM was recently created (within the last week or so) and happened to land an Azure cluster that is not yet equipped for Azure RM workloads.  You will get an error that says &quot;fabric cluster does not exist&quot; and the VM cannot be migrated. Waiting a couple of days will usually resolve this particular problem as the cluster will soon get Azure RM enabled. However, one immediate workaround is to stop-deallocate the VM, then continue forward with migration, and start the VM back up in Azure RM after migrating.

### Pitfalls to avoid

- Do not take shortcuts and omit the test lab and the prepare/abort dry run migrations.
- Most, if not all, of your potential issues will surface during the prepare/abort steps.  The migration API will migrate one virtual network (vNet) at a time; as part of your testing, plan to hydrate/migrate the same vNet a few times.
- Does your lab environment have enough capacity to simulate your real environment?

## Migration

### Technical considerations and tradeoffs

Now you are ready because you have worked through the known issues with your environment.

For the real migrations, you might want to consider:

1. Plan and schedule the vNet (smallest unit of migration) with increasing priority.  Do the simple vNets first, and progress with the more complicated vNets.
2. Most customers will have non-production and production environments.  Schedule production last.
3. Schedule a maintenance downtime with plenty of buffer.
4. Communicate with and align with your support teams in case issues arise.
5. As a risk mitigation contingency plan, we have included a rollback script to &#39;undo&#39; a committed Azure RM migration back to Classic. Use this only if, after migrating, it is found that applications do not work, and manual remediation strategies in Azure RM prove unsuccessful.  This rollback is a last resort effort and will take time.

### Patterns of success

The technical guidance from the Lab Test section above should be considered and mitigated prior to a real migration.  With adequate testing, the migration is actually a non-event.  For production environments, it might be helpful to have additional support, such as a trusted Microsoft partner or Microsoft Premier services.

### Pitfalls to avoid

Not fully testing may cause issues and delay in the migration.  Extract metadata from all environments (per vNet) and test in the lab.

## Beyond Migration

### Technical considerations and tradeoffs

Now that you are in Azure RM, maximize the platform.  An overview of Azure RM is [here](https://azure.microsoft.com/en-us/documentation/articles/resource-group-overview/).

Things to consider:

1. Bundling the migration with other activities.  Most customers opt for an application maintenance window.  If so, you might want to use this downtime to enable other Azure RM capabilities like encryption or increase your platform resiliency with storage account rebalancing.
2. Revisit the technical and business reasons for Azure RM; enable the additional services available only on Azure RM that apply to your environment.
3. Modernize your environment with PaaS services.

### Patterns of success

Be purposeful on what services you now want to enable in Azure RM.  Many customers find the below compelling for their Azure environments:

1. RBAC – role based access control, [getting started](https://blogs.msdn.microsoft.com/cloud_solution_architect/2015/03/17/rbac-and-the-azure-resource-manager/).
2. Azure RM templates for easier and more controlled deployment.
3. Azure RM only available services.

### Pitfalls to avoid

Remember why you started this Classic to Azure RM migration journey.  What were the original business reasons? Did you achieve the business reason?



## Appendix A – Important Links

1. What is Azure RM
[https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-compare-deployment-models/](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-compare-deployment-models/)

2. Benefits of Classic and Azure RM deployment models
[https://azure.microsoft.com/en-us/documentation/articles/resource-manager-deployment-model/](https://azure.microsoft.com/en-us/documentation/articles/resource-manager-deployment-model/)

3. Migration path options depending on your scenario
[https://azure.microsoft.com/en-us/blog/iaas-migration-classic-resource-manager/](https://azure.microsoft.com/en-us/blog/iaas-migration-classic-resource-manager/)

4. Support scenarios with the Platform Migration API
[https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-migration-classic-resource-manager/#unsupported-features-amp-configurations](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-windows-migration-classic-resource-manager/#unsupported-features-amp-configurations)

5. Role Based Access Control
[https://blogs.msdn.microsoft.com/cloud\_solution\_architect/2015/03/17/rbac-and-the-azure-resource-manager/](https://blogs.msdn.microsoft.com/cloud_solution_architect/2015/03/17/rbac-and-the-azure-resource-manager/)

6. VNet Peering
[https://azure.microsoft.com/en-us/documentation/articles/virtual-network-peering-overview/](https://azure.microsoft.com/en-us/documentation/articles/virtual-network-peering-overview/)



## Appendix B – Toolset Execution Details

### Metadata Extract

Send the customer the **MetadataExtract.zip** file containing the PowerShell scripts. You may not be able to send this over email given it contains scripts, so better to have them download it. Here are the steps to run this script.

1. Copy **MetadataExtract.zip** to a folder on your machine that can run PowerShell.
2. Unzip to some folder (doesn&#39;t matter where).
3. Open an instance of PowerShell ISE.
4. Add-AzureAccount (login with credentials). You will need to be a co-admin on the subscriptions you export.
5. Change directory over to the unzipped files.
6. Execute **Install-ARMModule.ps1**.
    - .\Install-ARMModule.ps1
7. Execute **MetadataExtract.ps1** for the subscription to export (you may get re-prompted for credentials…that&#39;s expected).
    - .\MetadataExtract.ps1 -subscriptionID  subidguid
8. Grab the generated XML file for each run.  The filename will be metadata\_subcriptionid.xml. It may take a couple of minutes to run for each subscription.
    - IMPORTANT: If the generated XML file contains an empty set of &lt;deployments&gt; elements, run the script again. The _second_ time you run it from the same PS session, you should not be re-prompted for credentials, and it should run successfully and dump out all of the production deployments.
9. The exported file will have all the necessary metadata to analyze.  The other Migration API test tools will require this file.

### NSG Bindings

To extract NSGs and rules, first modify the script **NSG-Bindings.ps1** with the subnets from the vNet to be migrated. Follow the example in the PowerShell script. There is no API to retrieve the ASM subnets, and the subnet names are needed to query and see which NSGs are associated with each subnet. The subnet names can be obtained from the exported network config file.

### AsmMetadataParser

Run this utility app to parse through the XML and extract the import data to a CSV.  The CSV will be used later by **HydrateLab.ps1** to build the simulated test environment that replicates the vNet to be migrated. The source code is included; so additional fields can be added or other changes can be made.

To use the utility, just run &#34;**asmmetadataparser.exe vnetName xmlFile**&#34; from a command window, where vNetName is the name of the vNet being migrated, and xmlFile is the path and filename generated from **MetadataExtract.ps1**.  The app will output two files: the CSV, and also a compatibility report text file. The report will list out some potential problem areas that will need to be resolved before Azure RM migration (look at the report for web/worker role existence). The following list are typical compatibility problems that the parser will identify.

- List of each field in the metadata generated CSV

   \* **vmname** -- name of the VM
   \* **csname** -- name of the cloud service
   \* **cscleanup** -- there is two or more defined availability sets in the cloud service. If any cell is true, the availability set will need to be remediated.
   \* **availset** -- the name of the availabilityset
   \* **mixedmodeas** -- there are both VMs in an availability set and VMs not in an AS in the cloud service. If any of cell is true, the availability set will need to be remediated.
   \* **lbendpointname** -- load balancer endpoint name
   \* **lbport** -- load balancer port
   \* **lbvip** -- load balancer IP
   \* **lbtype** -- type of load balancer -- options are &#34;external&#34; or &quot;internal&quot;
   \* **size** -- VM size
   \* **agent** -- is an azure agent configured?
   \* **running** -- is the VM running or stopped? Options are &#34;started&#34; or &#34;stopped&#34;
   \* **status** -- status of the instance -- readyrole, stoppeddeallocated, rolestateunknown, provisioningtimedout
   \* **osdisktype** -- type of osdisk: standard or premium
   \* **datadisks** -- the number of datadisks on the VM
   \* **datadiskstype** -- the type of the data disks -- standard or premium
   \* **os** -- either windows or linux
   \* **ip** -- IP address of the primary NIC
   \* **subnet** -- subnet of the primary NIC
   \* **secondarynics** -- secondary NICs IP addresses, separated by a &#39;|&#39; char
   \* **secondarysubnet** -- secondary NICs subnet -- all must be the same
   \* **mixedmodenics** -- true if there are both single NIC and multi-MIC VMs in the same cloud service -- which isn&#39;t allowed in ARM. If any cell is true, the VM will need to be remediated.
   \* **extensions** – list of VM extensions installed on the VM outside of BGInfo
   \* **osdiskname** -- the registered OS disk name
   \* **datadisknames** -- the registered data disk names separated by a &#39;|&#39; char
   \* **osdiskstorageaccount** -- the storage account that holds the OS disk
   \* **newstorageaccount** -- used only for the optional storage account balancing script. The new V2 SA.
   \* **newsaresourcegroup** -- used only for the optional storage account balancing script. The new V2 SA resource group.
   \* **osdiskvhd** -- URL to the OS disk VHD
   \* **datadiskvhds** -- URL to the data disk VHDs separated by a &#39;|&#39; char, in the same order as datadisknames
   \* **endpoints** -- contains all the configured endpoint data for the VM
   \* **reservedip** -- does the deployment/cloudservice have a reserved IP

### HydrateNSG

The first step to build a simulation test environment is to create the vNet in a test Azure subscription. Import the **networkconfig.xml** file (exported from the production vNet to be migrated). Once the vNet is created, then create NSGs and rules. The **HydrateNSG.ps1** script will take NSG metadata and recreate the NSGs and rules.  You will need to create a top level script to execute **HydrateNSG.ps1** for each subnet in the vNet.  Example below of a top level script that calls **HydrateNSG.ps1** for a subnet with the NSG named &#34;Prod\_SG.&#34;

### HydrateLab

This is the PowerShell script that will take the CSV as input and build the lab. The script will build all of the VMs in the CSV as described by the metadata. Make sure the test subscription has the defined capacity in the region for testing before running the script (both cores and cloud services). HydrateLab will handle single NIC, multi-NIC, custom VM extensions, custom VM images, internal load balancers, external load balancers, endpoints, various VM sizes, data disks, etc.  To make it do something additional, just modify the C# AsmMetadataParser source code and/or the **HydrateLab.ps1** script.

Expect each VM will take between 5-10 minutes to create and start.  Depending on the number of VMs in the CSV, a best practice is to break the CSV into multiple files.  The CSV is organized by cloud service, so if breaking the CSV into multiple files, keep each cloud service in the same file to avoid a contention issue.  With multiple CSV files, multiple sessions of **HydrateLab.ps1** can be executed in parallel, and the lab can hydrate much faster.  This works well.

   .\ **HydrateLab.ps1** -SubscriptionId &lt;subscription id&gt; -StandardStorageAccountName &lt;storage account to place VM disks&gt; -VirtualNetworkName &lt;vnet&gt; -AzureRegion &lt;location&gt; -CloudServicePrefixLetter &lt;prefix letter for cloud service names&gt; -ImportCsvFileName &lt;csv file&gt;
   

### GetMigrationStatus

Once the simulation environment is created, it can be migrated to Azure RM using the Move-AzureVirtualNetwork cmdlets. When &#34;prepare&#34; and &#34;commit&#34; are executed with this cmdlet, status can be checked using the **GetMigrationStatus.ps1** script.  This script calls the REST API and is asynchronous.  It must be executed in a different PowerShell session because Move-AzureVirtualNetwork cmdlet is synchronous and will not end until prepare/commit/abort is completed.  Hence, GetMigrationStatus is very useful to see the progress of each cloud service.  The status will change from &#34;Not Prepared&#34; to &#34;Preparing&#34; to &#34;Prepared.&#34;  During the Commit phase, the status will change from &#34;Prepared&#34; to &#34;Committing.&#34;  Once Commit is completed, there will not be any migration jobs occurring (expected), and it may return an exception (ignore this).

To tune this script, look in the source for the TODO comment and modify the script to just return the cloud services being migrated (rather than all cloud services in the subscription).

### Other Scripts

After migrating a vNet to Azure RM, a bunch of VMs are now running that need to be validated, then deleted. A useful script called **DeleteResourceGroups.ps1** is included that calls the REST API asynchronously to delete each migrated Azure RM resource group. The script needs to be tweaked for each usage.  Look at the source.

A number of other scripts are included as described below.
|[]() |     |
| --- | --- |
| **RemoveExtensions.ps1** | Very important script for pre-migration. This script will walk through and remove all VM extensions from the VMs in the vNet being migrated. This is a key preparation step as noted above. |
| **AddExtensions.ps1** | Script to add the extensions back after migrating to Azure RM. Additions will need to be made to this script for extensions to be added back. |
| **DisconnectV1ER.ps1** **ReconnectArmER.ps1** | Scripts to disconnect a V1 ER circuit from the vNet, and reconnect the vNet back to ER. Useful scripts if there is a desire to separate the ExpressRoute functionality from the actual Azure RM migration. |
| **DryRunNoER.ps1** | Very useful script to dry run test an actual vNet that is planned for migration. No disconnection from ER or VPN is required. Simply prepare and abort a migration to flush out issues, as discussed above. |
| **PostMigrationValidateStaticIPs.ps1** **PostMigrationValidation.ps1** | Scripts to help validate the metadata post Azure RM migration. These scripts will use the metadata captured in the Classic CSV and compare it to the post migration Azure RM metadata. |
| **CleanupLabStorage.ps1** | Will quickly walk through and remove all of the migrated test lab VHDs from the storage accounts in the lab subscription.  WARNING: Be careful to not remove items from storage accounts that you want to retain. |
| **ShutdownLab.ps1** **CleanupLabASM.ps1** **CleanupLabArmAsync.ps1** **CleanupLabArmSync.ps1** | Useful scripts to shut down and clean-up a test lab. **CleanupLabArmAsync.ps1** is particularly interesting to quickly fire a REST delete call against all the newly migrated resource groups without waiting. WARNING: Be careful to not remove VMs that are not part of the lab testing. |
=======
ASM to ARM Migration API Test Toolset


Background

This document describes a validation and testing approach to ensure a customer’s virtual network and contained VMs can cleanly migrate from ASM to ARM using the new ARM Migration API.


Overview

This document will cover the steps and tools for validating and testing customer’s actual data to ensure a smooth migration to ARM.  There’s a series of tools involved that can be used for either of the two purposes below:
1.	Validate the metadata from the customer’s virtual network and identify any migration problem areas.
2.	Use the customer’s metadata to create and build a simulated test environment in a different Azure subscription to test the migration API prior to migration. 


Summary of the Tools and Workflow

The high level workflow is as follows:
•	Collect Metadata: A customer will do the following 3 things to obtain the necessary metadata from their production ASM environment to be migrated:
1.	Run a PowerShell script called MetadataExtract.ps1, which will extract all of the ASM cloud service deployments in a subscription to XML. This is the most important required step and needed to identify any potential incompatibility areas. Steps 2 and 3 below are only needed if a simulated test environment will be hydrated using the metadata for actual testing of the ARM Migration API.
2.	Export out the network configuration for the subscription that contains the virtual networks for migration. This step must be done using the Azure portal. There is no cmdlet to export the network configuration.
3.	Run a PowerShell script called NSG-Bindings.ps1 to extract the NSG’s (network security groups and rules) for the virtual network.
•	Parse Metadata: Using the XML output from 1 above from MetadataExtract, run an application called AsmMetadataParser.exe with the metadata xml and the name of the virtual network to migrate.  This app will generate a flattened .CSV from the metadata with the most critical data needed for building a test environment. It will also generate a report with any compatibility concerns flagged. The C# source code is included for this tool.
•	Simulation Test: To build and test the Migration API from the metadata, the following 4 steps are performed:
1.	Build the virtual network. Import the network config to recreate the vNet, subnets, and IP address space just like the customer environment. Note: Remove any gateways before importing the network config as gateways must be removed for migrating.
2.	Run the HydrateNSG.ps1 PowerShell script to create the NSGs, rules, and associate the NSGs to any subnets in the virtual network.
3.	Run the HydrateLab.ps1 PowerShell script to create the simulation environment from the .CSV generated from AsmMetadataParser.exe.  
4.	Now run the Move-AzureVirtualNetwork PowerShell scripts that are part of the Migration API to migrate the test environment to ARM.
	While migrating, another PowerShell script from this toolset called GetMigrationStatus.ps1 can be executed in a different PowerShell session to check the status of migration.
	Here is the blog to that explains how to use the new ARM Migration API.  https://azure.microsoft.com/en-us/blog/iaas-migration-classic-resource-manager/


The following is the list of contained tools in this toolset.

MetadataExtract.ps1:	Extract the deployment metadata from a production Azure subscription running ASM virtual networks. Output is a single XML file.
NSG-Bindings.ps1:	Extract the Network Security Groups and rules for an ASM virtual network.
AsmMetadataParser.exe:	Parse the metadata from MetadataExtract, and build a flattened CSV and a compatibility report.
HydrateNSG.ps1:	Recreate the associated NSGs and rules in a simulated lab virtual network that matches the production virtual network. The vNet is built from the exported network configuration file, and this scripts add NSGs and rules to the vNet. 
HydrateLab.ps1:	Use the CSV to hydrate a simulated ASM environment with the same metadata for running/testing the ARM Migration API.
GetMigrationStatus.ps1:	Retrieves the status of an actual ARM migration using the Migration API Move-AzureVirtualNetwork cmdlet.  This will show each cloud service as its being prepared and committed to ARM.
ShutdownLab.ps1, CleanupLabASM.ps1, CleanupLabARM.ps1.	Useful scripts to shut down and clean-up a test lab. 


Toolset Execution Details

The following contains details for running each tool in the process.

Metadata Extract
Send the customer the MetadataExtract.zip file containing the PowerShell scripts. You may not be able to send this over email given it contains scripts, so better to have them download it. Here are the steps to run this script.
1.	Copy MetadataExtract.zip to a folder on your machine that can run PowerShell.
2.	Unzip to some folder (doesn’t matter where)
3.	Open an instance of PowerShell ISE
4.	Add-AzureAccount (login with credentials). You will need to be a co-admin on the subscriptions you export.
5.	Change directory over to the unzipped files.
6.	Execute Install-ARMModule.ps1.  
a.	.\Install-ARMModule.ps1
7.	Execute MetadataExtract.ps1 for the subscription to export (you may get re-prompted for credentials…that’s expected).
a.	Example  .\MetadataExtract.ps1 -subscriptionID subidguid
8.	Grab the generated xml file for each run.  The filename will be metadata_subcriptionid.xml. It may take a couple of min to run for each subscription.  
a.	IMPORTANT. If the generated XML file contains an empty set of <deployments> elements, run the script again. The second time you run it from the same PS session, you should not be re-prompted for credentials, and it should run successfully and dump out all of the production deployments.
9.	The exported file will have all the necessary metadata to analyze.  The other Migration API test tools will require this file.

NSG Bindings
To extract NSG’s and rules, first modify the script (NSG-Bindings.ps1) with the subnets from the vNet to be migrated. Follow the example in the PowerShell script. There is no api to retrieve the ASM subnets, and the subnet names are needed to query and see which NSG’s are associated with each subnet. The subnet names can be obtained from the exported network config file.

AsmMetadataParser
Run this utility app to parse through the xml extract the import data to a CSV.  The CSV will be used later by HydrateLab.ps1 to build a simulated test environment that replicates the vNet to be migrated. The source code is included, so additional fields can be pulled or other changes can be made.  
To use the utility, just run “asmmetadataparser.exe vnetName xmlFile” from a command window.  The app will output two files, the CSV and also a compatibility report text file. The report will list out potential problem areas that will need to be resolved before ARM migration. The following list are typical compatibility problems that the parser will identify.
•	Availability Sets. To be migrated to ARM, an ASM cloud service’s contained VMs must all be in one availability set, or the VMs must all not be in any availability set. More than one availability set in the cloud service is incompatible.  Additionally, there cannot be some VMs in an availability set, and some VMs not in an availability set.  
•	Web/Worker Role deployments.  Cloud Services containing web and worker roles cannot migrate to ARM. The web/worker roles must first be removed from the vNet.  A typical solution is to move web/worker role instances to a separate ASM vNet that is also linked to an ExpressRoute circuit, or to migrate these to App Service (this discussion is beyond the scope of this document). 
•	Cloud Services that contain some VMs with just one network interface card (NIC), and some VMs with more than one NIC.  It is possible to have cloud services with both types of VMs, and these must first be moved to either all single or multi NIC.  The CSV has a column (mixedmodenics) to identify when this is the case. If any VM has the mixedmodenics field set as “true”, the cloud service will not migrate until the NIC issue is resolved.  

HydrateNSG
The first step to build a simulation test environment is to create the vNet in a test Azure subscription. Import the networkconfig.xml file (exported from the production vNet to be migrated). Once the vNet is created, now create NSGs and rules. The HydrateNSG.ps1 script will take NSG metadata and recreate the NSGs and rules.  You will need to create a top level script to execute HydrateNSG.ps1 for each subnet in the vNet.  Example below of a top level script that calls HydrateNSG.ps1 for a subnet with the NSG named “Prod_SG.”
.\hydrateNSG.ps1 -SubscriptionID zzzzzzzz-55f9-4382-856a-e38f8b5b6d31 -VirtualNetworkName Network1 -SubnetName prod_app -region "East US" -NSG_Name Prod_SG -FilePath "C:\Users\cc\Prod_SG_zzzzzzzz-59c6-4d9c-94e5-344c8bd454ab.csv"

HydrateLab
This is the PowerShell script that will take the CSV as input and build the lab. The script will build all of the VMs in the CSV as described by the metadata. Make sure the test subscription has the defined capacity in the region for testing before running the script (both cores and cloud services). HydrateLab will handle single NIC, multi NIC, custom VM extension, internal load balancers, external load balancers, various VM sizes, data disks, etc.  To make it do something additional, just modify the C# AsmMetadataParser source code and/or the HydrateLab.ps1 script.   
Expect each VM will take between 5-10 minutes to create and start.  Depending on the number of VMs in the CSV, a best practice is to break the CSV into multiple files.  The CSV is organized by cloud service, so if breaking the CSV into multiple files, keep each cloud service in the same file to avoid a contention issue.  With multiple CSV files, multiple sessions of HydrateLab.ps1 can be executed in parallel, and the lab can hydrate much faster.  Works well.

GetMigrationStatus 
Once the simulation environment is created, it can be migrated to ARM using the Move-AzureVirtualNetwork cmdlets. When “prepare” and “commit” are executed with this cmdlet, status can be checked using the GetMigrationStatus.ps1 script.  This script calls the REST api and is asynchronous.  It must be executed in a different PowerShell session because Move-AzureVirtualNetwork cmdlet is synchronous and will not end until prepare/commit/abort is completed.  Hence, GetMigrationStatus is very useful to see the progress of each cloud service.  The status will change from “Not Prepared” to “Preparing” to “Prepared.”  During the Commit phase, the status will change from “Prepared” to “Committing.”  Once commit is completed, there will not be any migration jobs occurring (expected), and it may return an exception (ignore this).  
To tune this script, look in the source for the TODO comment and modify the script to just return the cloud services being migrated (rather than all cloud services in the subscription).  

Other Scripts
After migrating a vNet to ARM, a bunch of VMs are now running that need to be validated then deleted. A useful script called DeleteResourceGroups.ps1 is included that calls the REST api asynchronously to delete each migrated ARM resource group. The script needs to be tweaked for each usage.  Look at the source.
A few other scripts are included for deleting the hydrated ASM test lab (if it isn’t migrated to ARM), and/or shutdown a test lab.
>>>>>>> origin/master
