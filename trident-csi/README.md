# CSI with NetApp Astra Trident CSI on Platform9 Managed Kubernetes Clusters

This document provides pointers related to deployment of Trident CSI with PMK on Ubuntu 20.04-based BareOS on top of VMware OVA on ESXi 7.

Trident CSI supports various storage back-ends from NetApp, including ONTAP- and SolidFire-based storage systems and services (NetApp CVO in the public cloud, for example).

## Networking

If the PMK VMs have no way to reach storage services (iSCSI, NFS), follow standard host practices (whether it's vSphere, ESXi, KVM or something else) and create required networks for NFS or iSCSI. VMware hosts that want to use iSCSI SAN [may need to add a VMkernel adapter](https://docs.vmware.com/en/VMware-vSphere/7.0/com.vmware.vsphere.storage.doc/GUID-28C3CFF8-AE86-413F-BB58-3E00C1E3CCB6.html) in this process.

You may also follow related storage array or service information (such as NetApp ONTAP or SolidFire documentation) as well as [Trident](https://docs.netapp.com/us-en/trident/) documentation helpful. 

## Storage configuration

PMK uses standard NFS and iSCSI packages so simply make sure that PMK workers have the packages and valid configuration to use the protocol and back-end that you have.

Back-end storage array, storage network and client (worker) configuration must all be ready and working before you attempt to configure Trident CSI on PMK.

## Worker configuration

By default the BaseOS OVA file deployed on VMware comes with a single NIC. When external storage is used best practices call for the addition of a dedicated storage network (normally at least one per storage protocol).

In order to allow the VM access a dedicated back-end storage network - for an example iSCSI network - administrator shut down the VM, add additional network adapter (or adapters) and configure NIC details on the host (IP address, possibly VLAN, MTU and similar details).

Then create NFS shares or iSCSI block devices and try to use them from worker OS *before* PMK is deployed. Temporary shares and volumes may then be removed.

## Installation

PMK administrator may build Trident [from the source](https://github.com/NetApp/trident/releases) or try one of the supported installation methods (including Helm) mentioned [here](https://docs.netapp.com/us-en/trident/trident-get-started/kubernetes-deploy.html#choose-the-deployment-method).

Standard Trident installation steps should work without a problem (tested with PMK v1.21.3-pmk.72, Trident v22.01.1, and SolidFire 12.3).

PMK administrators using the public cloud can reference Trident documentation for respective storage service (NetApp CVO, Azure NetApp Files, etc.).

## Where to get help

Please visit [NetApp.io](https://netapp.io/) and join the NetApp Pub Slack (an invite link can be found on home page) and get help in the containers channel.
