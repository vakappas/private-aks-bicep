// Parameters section
param vnetName string = 'vnet'
param vnetPrefix string = '172.16.0.0/22'
param subnets array = [
  {
    name: 'subnet1'
    subnetPrefix: '172.16.0.0/24'
    routeTableid: ''
  }
  {
    name: 'subnet2'
    subnetPrefix: '172.16.1.0/24'
    routeTableid: ''
  }
  {
    name: 'subnet3'
    subnetPrefix: '172.16.2.0/24'
    routeTableid: ''
  }
]
param tags object = {
  environment: 'production'
  projectCode: 'xyz'
}
// Variables Section

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
    subnets:[for subnet in subnets: {
      name:subnet.name
      properties:{
        addressPrefix:subnet.subnetPrefix
        routeTable: empty(subnet.routeTableid)? json('null') : {
          id: subnet.routeTableid
        }
      }
    }]
  }
}


output vnetID string = vnet.id
output subnet array = [for (subnet,i) in subnets:{
  name: vnet.properties.subnets[i].name
  subnetID: vnet.properties.subnets[i].id
}]
