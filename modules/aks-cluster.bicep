// parameters 
// description('The DNS prefix to use with hosted Kubernetes API server FQDN.')
param dnsPrefix string = 'cl01'

// description('The name of the Managed Cluster resource.')
param clusterName string = 'aks101'

// description('Specifies the Azure location where the cluster should be created.')
param location string = resourceGroup().location

// minValue(1), maxValue(50)
// description('The number of nodes for the cluster. 1 Node is enough for Dev/Test and minimum 3 nodes, is recommended for Production')
param nodeCount int = 1

// description('The size of the Virtual Machine.')
param nodeVMSize string = 'Standard_D2s_v3'

// The nodes' subnet ID
param subnetID string

// The Kubernetes version
param kubeVersion string = '1.19.7'

// The nodes resource group name
param nodeResourceGroup string = '${dnsPrefix}-${clusterName}-rg'

param tags object = {
  environment: 'production'
  projectCode: 'xyz'
}

// vars
// var nodeResourceGroup = '${dnsPrefix}-${clusterName}-rg'

var nodePoolName = 'systempool'

// Create the Azure kubernetes service cluster
resource aks 'Microsoft.ContainerService/managedClusters@2020-09-01' = {
  name: clusterName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubeVersion
    enableRBAC: true
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: nodePoolName
        count: nodeCount
        mode: 'System'
        vmSize: nodeVMSize
        type: 'VirtualMachineScaleSets'
        osType: 'Linux'
        enableAutoScaling: false
        vnetSubnetID: subnetID
      }
    ]
    apiServerAccessProfile:{
      enablePrivateCluster:true
    }
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    nodeResourceGroup: nodeResourceGroup
    networkProfile: {
      networkPlugin: 'azure'
      loadBalancerSku: 'standard'
    }
  }
}

output aksid string = aks.id
output apiServerAddress string = aks.properties.privateFQDN
output aksnodesrg string = aks.properties.nodeResourceGroup
