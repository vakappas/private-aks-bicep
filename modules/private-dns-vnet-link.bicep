// The name of the private DNS Zone
param privatednsfqdn string = 'acr.privatelink.azurecr.io'
param vnetName string = 'vnet-name'
param vnetID string
param registrationEnabled bool = false

param privatednszonename string = substring(privatednsfqdn, indexOf(privatednsfqdn, '.') + 1, length(privatednsfqdn)-(indexOf(privatednsfqdn, '.') + 1))

resource privatednsvnetlink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${privatednszonename}/link-to-${vnetName}'
  location: 'global'
  tags: {}
  properties: {
    virtualNetwork: {
      id: vnetID
    }
    registrationEnabled: registrationEnabled
  }
}
