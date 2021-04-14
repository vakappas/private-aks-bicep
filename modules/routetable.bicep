// Define parameters
param udrName string = 'demoUserDefinedRoute'
param udrRouteName string = 'demoRoute'
param addressPrefix string = '0.0.0.0/0'
param nextHopType string = 'VirtualAppliance'
param nextHopIpAddress string = '10.10.3.4'

//Create User Defined Route Acc
resource udr 'Microsoft.Network/routeTables@2020-06-01' = {
  name: udrName
  location: resourceGroup().location
  properties: {
    routes: [
      {
        name: udrRouteName
        properties: {
          addressPrefix: addressPrefix
          nextHopType: nextHopType
          nextHopIpAddress: nextHopIpAddress
        }
      }
    ]
    disableBgpRoutePropagation: false
  }
}

output routeTableid string = udr.id
