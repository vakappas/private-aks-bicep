// params
param prefix string

@minLength(5)
@maxLength(50)
@description('Specifies the name of the azure container registry.')
param acrName string = '${toLower(replace(prefix, '-', ''))}${uniqueString(resourceGroup().id)}' // must be globally unique

@description('Enable admin user that have push / pull permission to the registry.')
param acrAdminUserEnabled bool = false

@description('Specifies the Azure location where the key vault should be created.')
param location string = resourceGroup().location

@allowed([
  'Basic'
  'Standard'
  'Premium'
])
@description('Tier of your Azure Container Registry.')
param acrSku string = 'Basic'

@description('ACR VNET Name')
param acrVnetName string

@description('ACR VNET ID')
param acrVnetID string

@description('ACR PE Subnet ID')
param acrSubnetID string

// azure container registry
resource acr 'Microsoft.ContainerRegistry/registries@2019-12-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    adminUserEnabled: acrAdminUserEnabled
  }
}

// Private DNS Zone
module acrPrivateDNSZone 'private-DNS-Zone.bicep' = {
  name: 'acrPrivateDNSZone'
  scope: resourceGroup()
  params: {
    privateDNSZoneName: 'privatelink.azurecr.io'
  }
}
// 
module acrVNETLink 'private-dns-vnet-link.bicep' = {
  name: 'link-to-privatelink.azurecr.io'
  scope: resourceGroup()
  params:{
    privatednszonename: acrPrivateDNSZone.outputs.privateDNSZoneName
    vnetID: acrVnetID
    vnetName: acrVnetName
  }
}

resource acrPrivateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: '${acrName}-PE'
  location: location
  properties: {
    subnet: {
      id: acrSubnetID
    }
    privateLinkServiceConnections: [
      {
        name: '${acrName}-PrivateLink'
        properties: {
          privateLinkServiceId: acr.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}

resource acrPrivateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = {
  name: '${acrPrivateEndpoint.name}/${acr.name}'
  properties:{
    privateDnsZoneConfigs:[
      {
        name: '${acr.name}-config'
        properties: {
          privateDnsZoneId: acrPrivateDNSZone.outputs.privateDNSZoneID
        }
      }
    ]
  }
}

output acrLoginServer string = acr.properties.loginServer
