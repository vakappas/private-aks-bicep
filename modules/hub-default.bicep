// Parameters
param location string = 'northeurope'

param tags object = {
  environment: 'production'
  projectCode: 'xyz'
}

// The name of the hub vnet
param hubVnetName string = 'hub-vnet'
// description('A /24 to contain the regional firewall, management, and gateway subnet')
param hubVnetPrefix string = '192.168.0.0/24'

// The hub FW name
param hubFwName string = 'hub-fw'

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

// variables
var FwPipName = '${hubFwName}-pip'
var bastionSubnetNsgName = 'bastion-nsg'
var hubLawsName = 'hub-laws-${uniqueString(resourceGroup().id)}'


// resources
resource hub_workspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: hubLawsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource bastionSubnetNsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: bastionSubnetNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowWebExperienceInBound'
        properties: {
          description: 'Allow our users in. Update this to be as restrictive as possible.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowControlPlaneInBound'
        properties: {
          description: 'Service Requirement. Allow control plane access. Regional Tag not yet supported.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'GatewayManager'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHealthProbesInBound'
        properties: {
          description: 'Service Requirement. Allow Health Probes.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowBastionHostToHostInBound'
        properties: {
          description: 'Service Requirement. Allow Required Host to Host Communication.'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSshToVnetOutBound'
        properties: {
          description: 'Allow SSH out to the VNet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '22'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowRdpToVnetOutBound'
        properties: {
          protocol: 'Tcp'
          description: 'Allow RDP out to the VNet'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '3389'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowControlPlaneOutBound'
        properties: {
          description: 'Required for control plane outbound. Regional prefix not yet supported'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '443'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionHostToHostOutBound'
        properties: {
          description: 'Service Requirement. Allow Required Host to Host Communication.'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionCertificateValidationOutBound'
        properties: {
          description: 'Service Requirement. Allow Required Session and Certificate Validation.'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '80'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 140
          direction: 'Outbound'
        }
      }
      {
        name: 'DenyAllOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource bastionNetworkNsg_diagnostic 'Microsoft.Network/networkSecurityGroups/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${bastionSubnetNsg.name}/Microsoft.Insights/${bastionSubnetNsg.name}-diag'
  tags: tags
  properties: {
    workspaceId: hub_workspace.id
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
  dependsOn: [
    hub_workspace
    bastionSubnetNsg
  ]
}

resource bastionHostPip 'Microsoft.Network/publicIpAddresses@2020-05-01' = {
  name: '${bastionHostName}-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2020-06-01'= {
  name: bastionHostName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: '${bastionHostName}-ipconfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnet.name, 'AzureBastionSubnet')
          }
          publicIPAddress: {
            id: bastionHostPip.id
          }
        }
      }
    ]
  }
}

resource hubVnet 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: hubVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVnetPrefix
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: FirewallSubnetPrefix
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: GatewaySubnetPrefix
        }
      }
      {
        name: mgmtSubnetName
        properties: {
          addressPrefix: mgmtSubnetPrefix
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: azureBastionSubnetPrefix
          networkSecurityGroup: {
            id: bastionSubnetNsg.id
          }
        }
      }
    ]
  }
}

resource hubVnet_diagnostic 'Microsoft.Network/virtualNetworks/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${hubVnet.name}/Microsoft.Insights/${hubVnet.name}-diag'
  tags: tags
  properties: {
    workspaceId: hub_workspace.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
  dependsOn: [
    hubVnet
  ]
}

resource hubFwPip 'Microsoft.Network/publicIpAddresses@2020-05-01' = {
  name: FwPipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
  }
}

resource hubFw 'Microsoft.Network/azureFirewalls@2020-05-01' = {
  name: hubFwName
  location: location
  tags: tags
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    additionalProperties: {
      'Network.DNS.EnableProxy': 'true'
    }
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    threatIntelMode: 'Deny'
    ipConfigurations: [
      {
        name: hubFwPip.name
        properties: {
          subnet: {
            id: hubVnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: hubFwPip.id
          }
        }
      }
    ]
    natRuleCollections: []
    networkRuleCollections: [
      {
        name: 'time'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 101
          rules: [
            {
              name: 'Allow time'
              description: 'Network Rule to allow time sync'
              sourceAddresses: [
                '*'
              ]
              protocols: [
                'UDP'
              ]
              destinationPorts: [
                '123'
              ]
              destinationAddresses: [
                '*'
              ]
            }
          ]
        }
      }
      {
        name: 'dns'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 102
          rules: [
            {
              name: 'Allow DNS'
              description: 'Network Rule to allow DNS queries'
              sourceAddresses: [
                '*'
              ]
              protocols: [
                'UDP'
              ]
              destinationPorts: [
                '53'
              ]
              destinationAddresses: [
                '*'
              ]
            }
          ]
        }
      }
      {
        name: 'servicetags'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 103
          rules: [
            {
              name: 'Allow servicetags'
              description: 'Network Rule to allow Service Tags'
              sourceAddresses: [
                '*'
              ]
              protocols: [
                'Any'
              ]
              destinationPorts: [
                '*'
              ]
              destinationAddresses: [
                'AzureContainerRegistry'
                'MicrosoftContainerRegistry'
                'AzureActiveDirectory' 
                'AzureMonitor'
              ]
            }
          ]
        }
      }
    ]
    applicationRuleCollections: [
      {
        name: 'aksbasics'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 101
          rules: [
            {
              name: 'Allow AKS basic FQDNs'
              description: 'Application Rule to allow access to certain FQDNs'
              sourceAddresses: [
                '*'
              ]
              protocols: [
                {
                  port: 80
                  protocolType:'Http'              
                }
                {
                  port: 443
                  protocolType: 'Https'
                }

              ]
              targetFqdns:[
                '*.cdn.mscr.io'
                'mcr.microsoft.com'
                '*.data.mcr.microsoft.com'
                'management.azure.com'
                'login.microsoftonline.com'
                'acs-mirror.azureedge.net'
                'dc.services.visualstudio.com'
                '*.opinsights.azure.com'
                '*.oms.opinsights.azure.com'
                '*.microsoftonline.com'
                '*.monitoring.azure.com'
                'api.snapcraft.io'
                '*.agentsvc.azure-automation.net'
                'md-0fz4cs3dgc1b.z37.blob.storage.azure.net'
                'azurecliprod.blob.core.windows.net'
                '3097d017-5d0e-452d-a367-e8f14ba6c9f7.agentsvc.azure-automation.net'
                'vstsagentpackage.azureedge.net'
                'cc-jobruntimedata-prod-su1.azure-automation.net'
              ]

            }
          ]

        }
      }
      {
        name: 'osupdates'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 102
          rules: [
            {
              name: 'Allow OS Updates'
              description: 'Application Rule to allow access to OS Updates'
              sourceAddresses: [
                '*'
              ]
              protocols: [
                {
                  port: 80
                  protocolType:'Http'              
                }
                {
                  port: 443
                  protocolType: 'Https'
                }

              ]
              targetFqdns:[
                'download.opensuse.org'
                'security.ubuntu.com'
                'archieve.ubuntu.com'
                'changelogs.ubuntu.com'
                'azure.archive.ubuntu.com'
                'ntp.ubuntu.com'
                'packages.microsoft.com'
                'snapcraft.io'
              ]

            }
          ]

        }
      }
      {
        name: 'publicimages'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 103
          rules: [
            {
              name: 'Allow public images'
              description: 'Application Rule to allow access to public registries'
              sourceAddresses: [
                '*'
              ]
              protocols: [
                {
                  port: 80
                  protocolType:'Http'              
                }
                {
                  port: 443
                  protocolType: 'Https'
                }

              ]
              targetFqdns:[
                'auth.docker.io'
                'registry-1.docker.io'
                'production.cloudflare.docker.com'
                '*.docker.com'
              ]

            }
          ]

        }
      }
      {
        name: 'istio'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 104
          rules: [
            {
              name: 'Allow istio binaries'
              description: 'Application Rule to allow access to istio binaries'
              sourceAddresses: [
                '*'
              ]
              protocols: [
                {
                  port: 80
                  protocolType:'Http'              
                }
                {
                  port: 443
                  protocolType: 'Https'
                }

              ]
              targetFqdns:[
                'istio.io'
                'quay.io'
                '*istio.io'
                'grafana.com'
                '*.grafana.com'
              ]

            }
            {
              name: 'Allow helm binaries'
              description: 'Application Rule to allow access to helm binaries'
              sourceAddresses: [
                '*'
              ]
              protocols: [
                {
                  port: 80
                  protocolType:'Http'              
                }
                {
                  port: 443
                  protocolType: 'Https'
                }

              ]
              targetFqdns:[
                'get.helm.sh'
              ]

            }
          ]

        }
      }
      {
        name: 'github'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 105
          rules: [
            {
              name: 'Allow github'
              description: 'Application Rule to allow access to github'
              sourceAddresses: [
                '*'
              ]
              protocols: [
                {
                  port: 80
                  protocolType:'Http'              
                }
                {
                  port: 443
                  protocolType: 'Https'
                }

              ]
              targetFqdns:[
                '*.github.com'
                'github.com'
                '*.s3.amazonaws.com'
                '*.github.io'
                'github-releases.githubusercontent.com'
              ]

            }
          ]

        }
      }
      {
        name: 'miscbinaries'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 106
          rules: [
            {
              name: 'Allow MS and Google Binaries'
              description: 'Application Rule to allow access to MS and Google binaries'
              sourceAddresses: [
                '*'
              ]
              protocols: [
                {
                  port: 80
                  protocolType:'Http'              
                }
                {
                  port: 443
                  protocolType: 'Https'
                }

              ]
              targetFqdns:[
                '*.aka.ms'
                'aka.ms'
                '*.microsoft.com'
                'storage.googleapis.com'
                '*.storage.googleapis.com'
              ]

            }
          ]

        }
      }
    ]
  }
  dependsOn: [
    hubFwPip
    hubVnet
  ]
}

resource hubFw_diagnostic 'Microsoft.Network/azureFirewalls/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${hubFw.name}/Microsoft.Insights/${hubFw.name}-diag'
  tags: tags
  properties: {
    workspaceId: hub_workspace.id
    logs: [
      {
        category: 'AzureFirewallApplicationRule'
        enabled: true
      }
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
      }
      {
        category: 'AzureFirewallDnsProxy'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
  dependsOn: [
    hubFw
  ]
}

output hubVnetId string = hubVnet.id
output hubFwPrivateIPAddress string = hubFw.properties.ipConfigurations[0].properties.privateIPAddress
