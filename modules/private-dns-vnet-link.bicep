// The name of the private DNS Zone
param privatednszonename string

param location string = resourceGroup().location
param vnetName string = 'vnet-name'
param vnetID string
param registrationEnabled bool = false

var privatednsfqdn = substring(privatednszonename, indexOf(privatednszonename, '.') + 1, length(privatednszonename)-(indexOf(privatednszonename, '.') + 1))

resource privatednsvnetlink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${privatednsfqdn}/link-to-${vnetName}'
  location: 'global'
  tags: {}
  properties: {
    virtualNetwork: {
      id: vnetID
    }
    registrationEnabled: registrationEnabled
  }
}
