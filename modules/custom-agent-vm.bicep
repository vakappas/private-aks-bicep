@description('Username for the Virtual Machine.')
param adminUsername string

/*
@description('Unique DNS Name for the Public IP used to access the Virtual Machine.')
param dnsNameForPublicIP string
*/

param vmName string = 'lab-vm'

@description('VM size for the Docker host.')
param vmSize string = 'Standard_D2s_v4'

param subnetID string

@allowed([
  '14.04.5-LTS'
  '16.04-LTS'
  '18.04-LTS'
  '20.04-LTS'
])
@description('The Ubuntu version for deploying the Docker containers. This will pick a fully patched image of this given Ubuntu version. Allowed values: 15.10, 16.04.0-LTS, 18.04-LTS')
param ubuntuOSVersion string = '18.04-LTS'

@description('Location for all resources.')
param location string = resourceGroup().location

@allowed([
  'sshPublicKey'
  'password'
])
@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
param authenticationType string = 'sshPublicKey'

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string
@description('The URI of the custom script to be executed after deployment')
param vmExtensionCustomScriptUri string 

// Custom script parameters
param agentuser string
param pool string
param pat string
param azdourl string


// Variables
var imagePublisher = 'Canonical'
var imageOffer = 'UbuntuServer'
var nicName = '${vmName}-nic'
var extensionName = 'DockerExtension'
var diskStorageType = 'Standard_LRS'
var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}
var nsgName = '${vmName}-nsg'

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'default-allow-22'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '22'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vmnic 'Microsoft.Network/networkInterfaces@2020-06-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: '${vmName}-ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetID
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2019-12-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? json('null') : linuxConfiguration)
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: ubuntuOSVersion
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-OSDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: diskStorageType
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmnic.id
        }
      ]
    }
  }
}

resource vmextensionName 'Microsoft.Compute/virtualMachines/extensions@2019-12-01' = {
  name: '${vm.name}/${extensionName}'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'DockerExtension'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}
resource customScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2019-12-01' = {
  name: '${vm.name}/config-app'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        vmExtensionCustomScriptUri
      ]
      commandToExecute: 'sh ./${last(split(vmExtensionCustomScriptUri, '/'))} -u ${agentuser} -p ${pool} -t ${pat} -l ${azdourl}'
    }
  }
}
