using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO;
using System.Text.RegularExpressions;
using System.Xml;

namespace AsmMetadataParser
{
    class Program
    {
        struct VMMetadata
        {
            public string m_vmname;
            public string m_csname;
            public string m_size;
            public string m_agent;
            public string m_availset;
            public string m_readyrole;
            public string m_osDiskType;
            public int m_disks;
            public string m_disksType;
            public string m_os;
            public string m_ip;
            public string m_subnet;
            public string m_secondaryIPs;
            public string m_secondarysubnet;
            public string m_mixedmodenics;
            public string m_mixedmodeas;
            public string m_lbendpointname;
            public string m_lbendpointport;
            public string m_lbvip;
            public string m_lbtype;
            public string m_flagCsForCleanup;
            public string m_instancestatus;
            public string m_extensions;
            public string m_osDiskName;
            public string m_dataDiskNames;
            public string m_osDiskStorageAccount;
            public string m_osDiskVhd;
            public string m_dataDiskVhds;
            public string m_endpoints;
            public string m_reservedip;
        }

        /// <summary>
        /// Utility to parse the xml metadata output of a ASM classic deployment (cloud service). This utility will take in to params, the virtual network name
        /// containing VMs, and the path + filename of the metadata output file containing deployments.  This utility parses the output of the MetadataExtract powershell
        /// script, and dumps out the metadata to a CSV file.  It will generate two files, one containing the csv output, and one containing any problem areas that neeed
        /// attention before the vnet can be migrated to ARM. The 3 types of problems it looks for are:
        ///     1. Cloud Services that contain non-migratable Availability Sets (1 AS needs to be set for the whole cloud service, or no AS should be set)
        ///     2. Cloud Services that contain a mix of single NIC and multi NIC VMs (yes, this was allowed at one point and can happen)
        ///     3. Web/Worker role cloud services (this cannot be migrated)
        /// </summary>
        /// <param name="args"></param>
        static void Main(string[] args)
        {
            try
            {
                if (args.Length != 2)
                {
                    Console.WriteLine("Missing parameters. AsmMetadataParser.exe vnetName metadataXmlFile");
                    return;
                }

                string vnetName = args[0];
                string metadataXml = args[1];

                var fileOutput = System.IO.File.CreateText(vnetName + "-vmresults.csv");

                /*
                 * vmname -- name of the VM
                 * csname -- name of the cloud service
                 * cscleanup -- there is two or more defined availability sets in the cloud service
                 * availset -- the name of the availabilityset
                 * mixedmodeas -- there are both vm's in an availability set and vm's not in an AS in the cloud service
                 * lbendpointname -- load balancer endpoint name
                 * lbport -- load balancer port
                 * lbvip -- load balancer IP
                 * lbtype -- type of load balancer -- options are "external" or "internal"
                 * size -- vm size
                 * agent -- is an azure agent configured
                 * running -- is the vm running or stopped.  Options are "started" or "stopped"
                 * status -- status of the instance -- readyrole, stoppeddeallocated, rolestateunknown
                 * osdisktype -- type of osdisk: standard or premium
                 * datadisks -- the number of datadisks on the vm
                 * datadiskstype -- the type of the data disks -- standard or premium
                 * os -- either windows or linux
                 * ip -- ip address of the primary nic
                 * subnet -- subnet of the primary nic
                 * secondarynics -- secondary nics IP addresses, separated by a '|' char
                 * secondarysubnet -- secondary nics subnet -- all must be the same
                 * mixedmodenics -- true of there are both single nic and multinic VMs in the same cloud service -- which isn't allow in ARM
                 * extensions -- vm extension state -- ignore -- this is wrong and need to change
                 * osdiskname -- the registered os disk name
                 * datadisknames -- the registered data disk names separated by a '|' char
                 * osdiskstorageaccount -- the storage account that holds the OS disk
                 * newstorageaccount -- used only for the optional SA balancing script. The new V2 SA.
                 * newsaresourcegroup -- used only for the optional SA balancing script. The new V2 SA resource group.
                 * osdiskvhd -- url to the os disk vhd
                 * datadiskvhds -- url to the data disk vhds separated by a '|' char, in the same order as datadisknames
                 * endpoints -- contains all the configured endpoint data for the vm
                 * reservedip -- does the deployment/cloudservice have a reserved ip
                 */

                fileOutput.WriteLine("vmname,csname,reservedip,cscleanup,availset,mixedmodeas,lbendpointname,lbport,lbvip,lbtype,size,agent,running,status,osdisktype,datadisks,datadiskstype,os,ip,subnet,secondarynics,secondarysubnet,mixedmodenics,extensions,osdiskname,datadisknames,osdiskstorageaccount,newstorageaccount,newsaresourcegroup,osdiskvhd,datadiskvhds,endpoints");
                SortedList<string, List<VMMetadata>> sortedlist = new SortedList<string, List<VMMetadata>>();
                Dictionary<string, int> asRemediationList = new Dictionary<string, int>();  // list of VMs and that need availability set cleanup before vnet migration to ARM
                List<string> wrRemediationList = new List<string>();  // list of web/worker roles that need removal from the vnet before migration to ARM

                XmlDocument xml = new XmlDocument();
                xml.Load(metadataXml);

                var nsmgr = new XmlNamespaceManager(xml.NameTable);
                nsmgr.AddNamespace("n", "http://schemas.microsoft.com/windowsazure");

                // walk through all deployments/cloudservices
                foreach (XmlNode deployment in xml.DocumentElement.ChildNodes)
                {
                    XmlNode vnet = deployment.SelectSingleNode("n:VirtualNetworkName", nsmgr);
                    if (vnet != null && vnet.InnerText.ToLower() == vnetName.ToLower())
                        ;  // VM in the correct vnet
                    else continue;

                    string reservedip = "";
                    bool singleNicDeployment = false;
                    bool multiNicDeployment = false;
                    int vmInCloudServiceCount = 0;
                    string firstAvailabilitySetInCS = "";
                    string previousAS = "";
                    string previousAS2 = "";
                    
                    string csname = deployment.SelectSingleNode("n:Url", nsmgr).InnerText;
                    csname = csname.Substring(7);
                    csname = csname.Split('.')[0];

                    // does the deployment have a reserved ip?
                    XmlNode roleInstanceList = deployment.SelectSingleNode("n:RoleInstanceList", nsmgr);

                    // read deployment specific data
                    XmlNode virtualIpNode = deployment.SelectSingleNode("n:VirtualIPs/n:VirtualIP", nsmgr);
                    if (virtualIpNode != null)
                    {
                        XmlNode isReservedNode = virtualIpNode.SelectSingleNode("n:IsReserved", nsmgr);
                        if (isReservedNode != null)
                        {
                            reservedip = virtualIpNode.SelectSingleNode("n:Address", nsmgr).InnerText;
                        }
                    }

                    // walk through the VMs inside of the deployment -- roleInstance element
                    foreach (XmlNode roleInstance in roleInstanceList.ChildNodes)
                    {
                        string vmname = roleInstance.SelectSingleNode("n:RoleName", nsmgr).InnerText;

                        // select the role node
                        XmlNode role = deployment.SelectSingleNode("n:RoleList/n:Role[n:RoleName = \"" + vmname + "\"]", nsmgr);
                        if (role.SelectSingleNode("n:RoleSize", nsmgr) == null)  // indicator that this is a web/worker role, not an IaaS VM
                        {
                            // PaaS web/worker role instance running in the vnet
                            string cssubnet = "";
                            XmlNode cssubnetNode = role.SelectSingleNode("n:ConfigurationSets/n:ConfigurationSet/n:SubnetNames", nsmgr);
                            if (cssubnetNode.ChildNodes.Count > 0)
                                cssubnet = role.SelectSingleNode("n:ConfigurationSets/n:ConfigurationSet/n:SubnetNames/n:SubnetName", nsmgr).InnerText.ToLower();

                            wrRemediationList.Add(csname + "     " + cssubnet);
                            continue; 
                        }

                        vmInCloudServiceCount++;
                        string size = role.SelectSingleNode("n:RoleSize", nsmgr).InnerText;
                        string readyrole = roleInstance.SelectSingleNode("n:PowerState", nsmgr).InnerText;
                        string instancestatus = roleInstance.SelectSingleNode("n:InstanceStatus", nsmgr).InnerText;
                        XmlNode agentNode = roleInstance.SelectSingleNode("n:GuestAgentStatus/n:Status", nsmgr);
                        string agent = "";
                        if (agentNode != null)
                        {
                            agent = agentNode.InnerText;
                        }

                        XmlNode availsetNode = role.SelectSingleNode("n:AvailabilitySetName", nsmgr);
                        string availset = (availsetNode != null) ? availsetNode.InnerText : "";
                        if (!string.IsNullOrEmpty(previousAS2) && !string.IsNullOrEmpty(availset) && previousAS2 != availset)
                            previousAS = "true";
                        if (previousAS != availset)
                            previousAS2 = availset;

                        // cloud service has availability set incompatability with ARM and will take some AS cleanup
                        bool flagCloudServiceForCleanup = false;
                        if (vmInCloudServiceCount == 1) // first VM
                            firstAvailabilitySetInCS = availset;
                        if (firstAvailabilitySetInCS != availset)
                        {
                            flagCloudServiceForCleanup = true;
                        }

                        if (flagCloudServiceForCleanup)
                        {
                            if (asRemediationList.ContainsKey(csname))
                                asRemediationList[csname] = vmInCloudServiceCount;
                            else asRemediationList.Add(csname, vmInCloudServiceCount);
                        }

                        // search for LoadBalancedEndpointSetName elements
                        string loadbalancedEndpointSetName = "";
                        string loadbalancedPort = "";
                        string loadbalancedVip = "";
                        string loadbalancedType = "";
                        XmlNodeList endpoints = role.SelectNodes("n:ConfigurationSets/n:ConfigurationSet/n:InputEndpoints/n:InputEndpoint[n:LoadBalancedEndpointSetName]", nsmgr);
                        if (endpoints.Count == 1)
                        {
                            loadbalancedEndpointSetName = endpoints[0].SelectSingleNode("n:LoadBalancedEndpointSetName", nsmgr).InnerText;
                            loadbalancedPort = endpoints[0].SelectSingleNode("n:LocalPort", nsmgr).InnerText;
                            XmlNode vipNode = endpoints[0].SelectSingleNode("n:Vip", nsmgr);
                            XmlNode nameNode = endpoints[0].SelectSingleNode("n:LoadBalancerName", nsmgr);

                            if (vipNode != null)
                                loadbalancedVip = vipNode.InnerText;
                            if (nameNode != null)
                                loadbalancedType = "internal";
                            else loadbalancedType = "external";
                        }
                        else if (endpoints.Count > 1)
                        {
                            loadbalancedType = "unexpected";

                            loadbalancedEndpointSetName = endpoints[0].SelectSingleNode("n:LoadBalancedEndpointSetName", nsmgr).InnerText;
                            loadbalancedPort = endpoints[0].SelectSingleNode("n:LocalPort", nsmgr).InnerText;
                            XmlNode vipNode = endpoints[0].SelectSingleNode("n:Vip", nsmgr);
                            XmlNode nameNode = endpoints[0].SelectSingleNode("n:LoadBalancerName", nsmgr);

                            if (vipNode != null)
                                loadbalancedVip = vipNode.InnerText;
                            if (nameNode != null)
                                loadbalancedType = "internal";
                            else loadbalancedType = "external";
                        }

                        string allEndpoints = "";
                        // Add together all endpoints into this format
                        // setname|privateport|publicport|endpointname|protocol|vip|directreturn|lbname|lbtype;setname|privateport|publicport|endpointname|protocol|vip|directreturn|lbname|lbtype
                        XmlNode endpoints2 = role.SelectSingleNode("n:ConfigurationSets/n:ConfigurationSet/n:InputEndpoints", nsmgr);
                        if (endpoints2 != null)
                        {
                            foreach (XmlNode endpoint2 in endpoints2.ChildNodes)
                            {
                                string setname = "";
                                string privateport = "";
                                string publicport = "";
                                string endpointname = "";
                                string protocol = "";
                                string vip = "";
                                string directreturn = "";
                                string lbname = "";
                                string lbtype = "";

                                XmlNode setNode = endpoint2.SelectSingleNode("n:LoadBalancedEndpointSetName", nsmgr);
                                if (setNode != null) setname = endpoint2.SelectSingleNode("n:LoadBalancedEndpointSetName", nsmgr).InnerText;

                                privateport = endpoint2.SelectSingleNode("n:LocalPort", nsmgr).InnerText;
                                publicport = endpoint2.SelectSingleNode("n:Port", nsmgr).InnerText;
                                endpointname = endpoint2.SelectSingleNode("n:Name", nsmgr).InnerText;
                                protocol = endpoint2.SelectSingleNode("n:Protocol", nsmgr).InnerText;
                                directreturn = endpoint2.SelectSingleNode("n:EnableDirectServerReturn", nsmgr).InnerText;

                                XmlNode vipNode2 = endpoint2.SelectSingleNode("n:Vip", nsmgr);
                                if (vipNode2 != null) vip = vipNode2.InnerText;

                                XmlNode nameNode2 = endpoint2.SelectSingleNode("n:LoadBalancerName", nsmgr);
                                if (nameNode2 != null)
                                {
                                    lbtype = "internal";
                                    lbname = nameNode2.InnerText;
                                }
                                else lbtype = "external";

                                if (allEndpoints == "")
                                    allEndpoints = setname + "|" + privateport + "|" + publicport + "|" + endpointname + "|" + protocol + "|" + vip + "|" + directreturn + "|" + lbname + "|" + lbtype;
                                else allEndpoints = allEndpoints + ";" + setname + "|" + privateport + "|" + publicport + "|" + endpointname + "|" + protocol + "|" + vip + "|" + directreturn + "|" + lbname + "|" + lbtype;
                            }
                        }

                        string os = role.SelectSingleNode("n:OSVirtualHardDisk/n:OS", nsmgr).InnerText;
                        XmlNode osDiskTypeNode = role.SelectSingleNode("n:OSVirtualHardDisk/n:IOType", nsmgr);
                        string osDiskType = (osDiskTypeNode != null) ? osDiskType = osDiskTypeNode.InnerText : osDiskType = "Standard";
                        string osDiskName = role.SelectSingleNode("n:OSVirtualHardDisk/n:DiskName", nsmgr).InnerText;
                        string osDiskVhd = role.SelectSingleNode("n:OSVirtualHardDisk/n:MediaLink", nsmgr).InnerText;
                        string osDiskStorageAccount = role.SelectSingleNode("n:OSVirtualHardDisk/n:MediaLink", nsmgr).InnerText;
                        osDiskStorageAccount = osDiskStorageAccount.Substring(8);
                        int charIndex = osDiskStorageAccount.IndexOf('.');
                        osDiskStorageAccount = osDiskStorageAccount.Substring(0, charIndex);

                        string ip;
                        XmlNode ipNode = roleInstance.SelectSingleNode("n:IpAddress", nsmgr);
                        XmlNode staticIpNode = role.SelectSingleNode("n:ConfigurationSets/n:ConfigurationSet/n:StaticVirtualNetworkIPAddress", nsmgr);
                        if (ipNode != null)
                        {
                            ip = ipNode.InnerText;
                        }
                        else if (staticIpNode != null)
                        {
                            ip = staticIpNode.InnerText;
                        }
                        else ip = "";

                        XmlNode disksNode = role.SelectSingleNode("n:DataVirtualHardDisks", nsmgr);
                        int disks = 0;
                        string disksType = "";
                        string dataDiskNames = "";
                        string dataDiskVhds = "";
                        if (disksNode != null)
                        {
                            disks = disksNode.ChildNodes.Count;
                            if (disks > 0)
                            {
                                XmlNode diskTypeNode = disksNode.ChildNodes[0].SelectSingleNode("n:IOType", nsmgr);
                                disksType = (diskTypeNode != null) ? diskTypeNode.InnerText : "Standard";
                                
                                foreach (XmlNode diskNode in disksNode.ChildNodes)
                                {
                                    if (dataDiskNames != "") dataDiskNames = dataDiskNames + "|";
                                    dataDiskNames = dataDiskNames + diskNode.SelectSingleNode("n:DiskName", nsmgr).InnerText;

                                    if (dataDiskVhds != "") dataDiskVhds = dataDiskVhds + "|";
                                    dataDiskVhds = dataDiskVhds + diskNode.SelectSingleNode("n:MediaLink", nsmgr).InnerText;
                                }
                            }
                        }

                        string subnet = "";
                        XmlNode subnetNode = role.SelectSingleNode("n:ConfigurationSets/n:ConfigurationSet/n:SubnetNames", nsmgr);
                        if (subnetNode.ChildNodes.Count > 0)
                            subnet = role.SelectSingleNode("n:ConfigurationSets/n:ConfigurationSet/n:SubnetNames/n:SubnetName", nsmgr).InnerText.ToLower();

                        string extensions = "";
                        XmlNode resourceExtension = role.SelectSingleNode("n:ResourceExtensionReferences", nsmgr);
                        if (resourceExtension != null)
                        { 
                            foreach (XmlNode extension in resourceExtension.ChildNodes)
                            {
                                string ex = extension.SelectSingleNode("n:ReferenceName", nsmgr).InnerText;
                                if (ex == "BGInfo") continue;

                                if (extensions == "")
                                {
                                    extensions = ex;
                                }
                                else
                                {
                                    extensions = extensions + "|" + ex;
                                }
                            }
                        }

                        string secondaryIPs = "";
                        string secondarysubnet = "";
                        XmlNode nicNodes = roleInstance.SelectSingleNode("n:NetworkInterfaces", nsmgr);
                        if (nicNodes != null)
                        {
                            foreach (XmlNode nicnode in nicNodes.ChildNodes)
                            {
                                if (secondaryIPs != "") secondaryIPs = secondaryIPs + "|";
                                secondaryIPs = secondaryIPs + nicnode.SelectSingleNode("n:IPConfigurations/n:IPConfiguration/n:Address", nsmgr).InnerText;
                                secondarysubnet = nicnode.SelectSingleNode("n:IPConfigurations/n:IPConfiguration/n:SubnetName", nsmgr).InnerText.ToLower();
                                multiNicDeployment = true;
                            }

                            if (nicNodes.ChildNodes.Count == 0) singleNicDeployment = true;
                        }
                        else
                        {
                            singleNicDeployment = true;
                        }

                        // Collect metadata in a structure to be added to a sorted list, so we can group VMs by cloud service
                        // This is needed so when we hydrate the VMs with a PS script, we can launch multiple instances.
                        // Each instance will be isolated by cloud service so we don't run into any concurrency issues / locking. 
                        VMMetadata md = new VMMetadata();
                        md.m_vmname = vmname;
                        md.m_csname = csname;
                        md.m_size = size;
                        md.m_agent = agent;
                        md.m_readyrole = readyrole;
                        md.m_osDiskType = osDiskType;
                        md.m_os = os;
                        md.m_ip = ip;
                        md.m_instancestatus = instancestatus;
                        md.m_disks = disks;
                        md.m_disksType = disksType;
                        md.m_subnet = subnet;
                        md.m_secondaryIPs = secondaryIPs;
                        md.m_secondarysubnet = secondarysubnet;
                        md.m_availset = availset;
                        md.m_mixedmodenics = (singleNicDeployment && multiNicDeployment && (instancestatus != "StoppedDeallocated")) ? "true" : "";
                        md.m_mixedmodeas = previousAS; // (vmsInAvailabilitySet && vmsNotInAvailabilitySet) ? "true" : "";
                        md.m_lbendpointname = loadbalancedEndpointSetName;
                        md.m_lbendpointport = loadbalancedPort;
                        md.m_lbtype = loadbalancedType;
                        md.m_lbvip = loadbalancedVip;
                        md.m_flagCsForCleanup = (flagCloudServiceForCleanup) ? csname : "";
                        md.m_extensions = extensions;
                        md.m_osDiskName = osDiskName;
                        md.m_dataDiskNames = dataDiskNames;
                        md.m_osDiskVhd = osDiskVhd;
                        md.m_dataDiskVhds = dataDiskVhds;
                        md.m_osDiskStorageAccount = osDiskStorageAccount;
                        md.m_endpoints = allEndpoints;
                        md.m_reservedip = reservedip;

                        if (!sortedlist.Keys.Contains((string)csname))
                        {
                            List<VMMetadata> l = new List<VMMetadata>();
                            l.Add(md);
                            sortedlist.Add((string)csname, l);
                        }
                        else
                        {
                            List<VMMetadata> l = sortedlist[(string)csname];
                            l.Add(md);
                        }
                    }
                }

                foreach (List<VMMetadata> l_item in sortedlist.Values)
                {
                    foreach (VMMetadata item in l_item)
                    {
                        fileOutput.WriteLine("{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12},{13},{14},{15},{16},{17},{18},{19},{20},{21},{22},{23},{24},{25},{26},{27},{28},{29},{30},{31}",
                            item.m_vmname, item.m_csname, item.m_reservedip, item.m_flagCsForCleanup, item.m_availset, item.m_mixedmodeas, item.m_lbendpointname, item.m_lbendpointport, item.m_lbvip, item.m_lbtype,
                            item.m_size, item.m_agent,
                            item.m_readyrole, item.m_instancestatus, item.m_osDiskType, item.m_disks, item.m_disksType, item.m_os,
                            item.m_ip, item.m_subnet, item.m_secondaryIPs, item.m_secondarysubnet, item.m_mixedmodenics, item.m_extensions,
                            item.m_osDiskName, item.m_dataDiskNames, item.m_osDiskStorageAccount, "", "", item.m_osDiskVhd, item.m_dataDiskVhds, item.m_endpoints);
                    }
                }

                fileOutput.Close();

                // Build a report that shows the VMs that need remediation/cleanup for AS compatability
                var fileRemediation = System.IO.File.CreateText(vnetName + "-RemediationList.txt");
                int remediationCount = 0;
                fileRemediation.WriteLine("Availability Set Cleanup");
                fileRemediation.WriteLine("Cloud Service     Number of VMs");
                fileRemediation.WriteLine();
                foreach (string key in asRemediationList.Keys)
                {
                    fileRemediation.WriteLine("{0}    {1}", key, asRemediationList[key]);
                    remediationCount = remediationCount + asRemediationList[key];
                }
                fileRemediation.WriteLine();
                fileRemediation.WriteLine("AS Cleanup Totals");
                fileRemediation.WriteLine();
                fileRemediation.WriteLine("CloudServices: {0}   VMs: {1}", asRemediationList.Count, remediationCount);
                fileRemediation.WriteLine("\n\n");

                fileRemediation.WriteLine("Web/Worker Role Cleanup");
                fileRemediation.WriteLine("web/worker role cloud service list");
                fileRemediation.WriteLine();
                if (wrRemediationList.Count == 0)
                    fileRemediation.WriteLine("no web/worker roles found");
                foreach (string key in wrRemediationList)
                {
                    fileRemediation.WriteLine("-- {0}", key);
                }
                fileRemediation.WriteLine();
                fileRemediation.WriteLine("For Cloud Services that have single and multi NIC VMs in the same service, look at the csv file -- mixmodenics column = true");

                fileRemediation.Close();
                Console.WriteLine("Success. CSV created.");
            }
            catch(Exception e)
            {
                Console.WriteLine("Unexpected problem occured: " + e.Message + "\n" + e.StackTrace);
            }
        }
    }
}
