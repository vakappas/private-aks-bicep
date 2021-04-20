// set the target scope to subscription
targetScope = 'subscription'

// parameters
param prefix string = 'aks-lab'
param location string = 'northeurope'

// Hub vnet name
param hubvnetName string = 'hub-vnet'
// description('A /24 to contain the regional firewall, management, and gateway subnet')
param hubVnetPrefix string = '192.168.0.0/24'

// description('A /26 under the VNet Address Space for the regional Azure Firewall')
param FirewallSubnetPrefix string = '192.168.0.0/26'

// description('A /26 under the VNet Address Space for the Management subnet')
param mgmtSubnetName string = 'mgmt-subnet'
param mgmtSubnetPrefix string = '192.168.0.64/26'

// description('A /27 under the VNet Address Space for regional Azure Bastion')
param azureBastionSubnetPrefix string = '192.168.0.192/27'

// description('A /27 under the VNet Address Space for our regional On-Prem Gateway')
param GatewaySubnetPrefix string = '192.168.0.224/27'

// bastion host name
param bastionHostName string = 'hub-bastion'

// AKS cluster name
param clusterName string = 'aks-cl01'

// Admin user's password or SSH public key
param adminPasswordOrKey string

// Variables
var tags = {
  environment: 'test'
  projectCode: 'aks-lab'
}

// create resource groups
resource hubrg 'Microsoft.Resources/resourceGroups@2020-06-01'={
  name: '${prefix}-hub-rg'
  location: location
  tags: tags
}
resource aksrg 'Microsoft.Resources/resourceGroups@2020-06-01'={
  name: '${prefix}-aks-rg'
  location: location
  tags: tags
}
resource devrg 'Microsoft.Resources/resourceGroups@2020-06-01'={
  name: '${prefix}-dev-rg'
  location: location
  tags: tags
}

// create resources
// Create the hub vnet with all its components
module hubvnet './modules/hub-default.bicep' = {
  name: 'hub-vnet'
  scope: resourceGroup(hubrg.name)
  params: {
    location: location
    hubVnetName: hubvnetName
    hubFwName: 'hub-fw'
    tags: tags
  }
}
// Create the aks vnet
module aksvnet './modules/vnet.bicep' = {
  name: 'aks-vnet'
  scope: resourceGroup(aksrg.name)
  params: {
    vnetName: 'aks-vnet'
    vnetPrefix: '192.168.4.0/22'
    subnets: [
      {
        name: 'nodes-subnet'
        subnetPrefix: '192.168.4.0/23'
      }
      {
        name: 'ingress-subnet'
        subnetPrefix: '192.168.6.0/24'
        routeTableid: aksroutetable.outputs.routeTableid
      }
    ]

  }
}
// Create the dev vnet
module devvnet './modules/vnet.bicep' = {
  name: 'dev-vnet'
  scope: resourceGroup(devrg.name)
  params: {
    vnetName: 'dev-vnet'
    vnetPrefix: '192.168.2.0/24'
    subnets: [
      {
        name: 'agents-subnet'
        subnetPrefix: '192.168.2.0/25'
        routeTableid: devroutetable.outputs.routeTableid
      }
      {
        name: 'PE-subnet'
        subnetPrefix: '192.168.2.224/27'
      }
    ]
    
  }
}
// Peer hub with aks vnets
module hubtoakspeering './modules/vnet-peering.bicep' = {
  name: 'hub-to-aks'
  scope: resourceGroup(hubrg.name)
  dependsOn: [
    hubvnet
    aksvnet    
  ]
  params:{
    localVnetName: hubvnet.name
    remoteVnetName: aksvnet.name
    remoteVnetRg: aksrg.name
    remoteVnetID: aksvnet.outputs.vnetID
  }
}
module akstohubpeering './modules/vnet-peering.bicep' = {
  name: 'aks-to-hub'
  scope: resourceGroup(aksrg.name)
  dependsOn: [
    hubvnet
    aksvnet    
  ]
  params:{
    localVnetName: aksvnet.name
    remoteVnetName: hubvnet.name
    remoteVnetRg: hubrg.name
    remoteVnetID: hubvnet.outputs.hubVnetId
  }
}
// Peer hub with dev vnets
module hubtodevpeering './modules/vnet-peering.bicep' = {
  name: 'hub-to-dev'
  scope: resourceGroup(hubrg.name)
  dependsOn: [
    hubvnet
    devvnet    
  ]
  params:{
    localVnetName: hubvnet.name
    remoteVnetName: devvnet.name
    remoteVnetRg: devrg.name
    remoteVnetID: devvnet.outputs.vnetID
  }
}
module devtohubpeering './modules/vnet-peering.bicep' = {
  name: 'dev-to-hub'
  scope: resourceGroup(devrg.name)
  dependsOn: [
    hubvnet
    devvnet    
  ]
  params:{
    localVnetName: devvnet.name
    remoteVnetName: hubvnet.name
    remoteVnetRg: hubrg.name
    remoteVnetID: hubvnet.outputs.hubVnetId
  }
}
// Create & assign the route tables
module aksroutetable './modules/routetable.bicep'={
  name: 'aks-rt'
  scope: resourceGroup(aksrg.name)
  params:{
    udrName: 'aks-rt'
    udrRouteName: 'Default-route'
    nextHopIpAddress: hubvnet.outputs.hubFwPrivateIPAddress
  }
}
module devroutetable './modules/routetable.bicep'={
  name: 'dev-rt'
  scope: resourceGroup(devrg.name)
  params:{
    udrName: 'dev-rt'
    udrRouteName: 'Default-route'
    nextHopIpAddress: hubvnet.outputs.hubFwPrivateIPAddress
  }
}
// Create the AKS Cluster
module akscluster './modules/aks-cluster.bicep' = {
  name: clusterName
  scope: resourceGroup(aksrg.name)
  params: {
    tags: tags
    clusterName: clusterName
    subnetID: aksvnet.outputs.subnet1ID
    nodeResourceGroup: '${clusterName}-nodes-rg' 
  }
}
// Link the private DNS zone of AKS to hub & dev vnets
module privatednshublink './modules/private-dns-vnet-link.bicep' = {
  name: 'link-to-hub-vnet'
  dependsOn: [
    akscluster
  ]
  scope: resourceGroup('${clusterName}-nodes-rg')
  params: {
    location: location
    privatednszonename: akscluster.outputs.apiServerAddress
    registrationEnabled: false
    vnetID: hubvnet.outputs.hubVnetId
    vnetName: hubvnet.name
  }
} 
module privatednsdevlink './modules/private-dns-vnet-link.bicep' = {
  name: 'link-to-dev-vnet'
  dependsOn: [
    akscluster
  ]
  scope: resourceGroup('${clusterName}-nodes-rg')
  params: {
    location: location
    privatednszonename: akscluster.outputs.apiServerAddress
    registrationEnabled: false
    vnetID: devvnet.outputs.vnetID
    vnetName: devvnet.name
  }
}
// Create a jumpbox VM, ubuntu OS with docker
module agentvm './modules/ubuntu-docker.bicep' = {
  name: '${prefix}-vm'
  scope: resourceGroup(devrg.name)
  params: {
    vmName: '${prefix}-vm'
    location: location
    adminUsername: 'adminuser'
    adminPasswordOrKey: adminPasswordOrKey
    subnetID: devvnet.outputs.subnet1ID
    authenticationType: 'password'
  }
}
