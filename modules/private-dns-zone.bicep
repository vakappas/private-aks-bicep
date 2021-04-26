param privateDNSZoneName string


// Create the privateDNSZone
resource privateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDNSZoneName
  location: 'global'
}

output privateDNSZoneName string = privateDNSZone.name
output privateDNSZoneID string = privateDNSZone.id
