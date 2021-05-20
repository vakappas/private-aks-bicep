@description('Specifies the name of the key vault.')
param keyVaultName string

@description('Specifies the Azure location where the key vault should be created.')
param location string = resourceGroup().location

@description('Specifies whether Azure Virtual Machines are permitted to retrieve certificates stored as secrets from the key vault.')
param enabledForDeployment bool = false

@description('Specifies whether Azure Disk Encryption is permitted to retrieve secrets from the vault and unwrap keys.')
param enabledForDiskEncryption bool = false

@description('Specifies whether Azure Resource Manager is permitted to retrieve secrets from the key vault.')
param enabledForTemplateDeployment bool = false

@description('Specifies the Azure Active Directory tenant ID that should be used for authenticating requests to the key vault. Get it by using Get-AzSubscription cmdlet.')
param tenantId string = subscription().tenantId

@description('Specifies the object ID of a user, service principal or security group in the Azure Active Directory tenant for the vault. The object ID must be unique for the list of access policies. Get it by using Get-AzADUser or Get-AzADServicePrincipal cmdlets.')
param objectId string

@description('Specifies the permissions to keys in the vault. Valid values are: all, encrypt, decrypt, wrapKey, unwrapKey, sign, verify, get, list, create, update, import, delete, backup, restore, recover, and purge.')
param keysPermissions array = [
  'list'
]

@description('Specifies the permissions to secrets in the vault. Valid values are: all, get, list, set, delete, backup, restore, recover, and purge.')
param secretsPermissions array = [
  'list'
]

@allowed([
  'standard'
  'premium'
])
@description('Specifies whether the key vault is a standard vault or a premium vault.')
param skuName string = 'standard'

@secure()
@description('Specifies all secrets {"secretName":"","secretValue":""} wrapped in a secure object.')
param secretsObject object = {
  secrets: []
}
@description('Vault VNET Name')
param vaultVnetName string

@description('Vault VNET ID')
param vaultVnetID string

@description('Vault PE Subnet ID')
param vaultSubnetID string

// Create an Azure Keyvault
resource vault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: location
  tags: {
    displayName: 'KeyVault'
  }
  properties: {
    enabledForDeployment: enabledForDeployment
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    tenantId: tenantId
    accessPolicies: [
      {
        objectId: objectId
        tenantId: tenantId
        permissions: {
          keys: keysPermissions
          secrets: secretsPermissions
        }
      }
    ]
    sku: {
      name: skuName
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Create any given secrets
//resource secrets 'Microsoft.KeyVault/vaults/secrets@2018-02-14' = [for secret in secretsObject.secrets: {
//  name: '${vault.name}/${secret.secretName}'
//  properties: {
//    value: secret.secretValue
//  }
//}]

// Private DNS Zone
module vaultPrivateDNSZone 'private-DNS-Zone.bicep' = {
  name: 'vaultPrivateDNSZone'
  scope: resourceGroup()
  params: {
    privateDNSZoneName: 'privatelink.vaultcore.azure.net'
  }
}
// 
module vaultVNETLink 'private-dns-vnet-link.bicep' = {
  name: 'link-to-privatelink.vaultcore.azure.net'
  scope: resourceGroup()
  params:{
    privatednszonename: vaultPrivateDNSZone.outputs.privateDNSZoneName
    vnetID: vaultVnetID
    vnetName: vaultVnetName
  }
}

resource vaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: '${keyVaultName}-PE'
  location: location
  properties: {
    subnet: {
      id: vaultSubnetID
    }
    privateLinkServiceConnections: [
      {
        name: '${keyVaultName}-PrivateLink'
        properties: {
          privateLinkServiceId: vault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource vaultPrivateDNSZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-11-01' = {
  name: '${vaultPrivateEndpoint.name}/${vault.name}'
  properties:{
    privateDnsZoneConfigs:[
      {
        name: '${vault.name}-config'
        properties: {
          privateDnsZoneId: vaultPrivateDNSZone.outputs.privateDNSZoneID
        }
      }
    ]
  }
}
