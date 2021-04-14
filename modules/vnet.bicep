param vnetName string = 'vnet'
param vnetPrefix string = '172.16.0.0/22'
param subnet1Name string = 'first-subnet'
param subnet1Prefix string = '172.16.1.0/24'
param subnet2Name string = 'second-subnet'
param subnet2Prefix string = '172.16.2.0/24'
param routeTableid string
param tags object = {
  environment: 'production'
  projectCode: 'xyz'
}
// var vnetName = 'vnet-${suffix}'

resource vnet 'Microsoft.Network/virtualNetworks@2019-12-01' = {
  name: vnetName
  location: resourceGroup().location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetPrefix
      ]
    }
    enableVmProtection: false
    enableDdosProtection: false
    subnets: [
      {
        name: subnet1Name
        properties: {
          addressPrefix: subnet1Prefix
          routeTable: {
            id: routeTableid
          }
        }
      }
      {
        name: subnet2Name
        properties: {
          addressPrefix: subnet2Prefix
        }
      }
    ]
  }
}

output vnetID string = vnet.id
output subnet1ID string = vnet.properties.subnets[0].id
output subnet2ID string = vnet.properties.subnets[1].id
