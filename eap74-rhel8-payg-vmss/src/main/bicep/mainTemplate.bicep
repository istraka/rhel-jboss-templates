@description('User name for the Virtual Machine')
param adminUsername string = 'jbossuser'

@description('Type of authentication to use on the Virtual Machine')
@allowed([
  'password'
  'sshPublicKey'
])
param authenticationType string = 'password'

@description('Password or SSH key for the Virtual Machine')
@minLength(12)
@secure()
param adminPasswordOrSSHKey string

@description('Location for all resources')
param location string = resourceGroup().location

@description('User name for the JBoss EAP Manager')
param jbossEAPUserName string

@description('Password for the JBoss EAP Manager')
@minLength(12)
@secure()
param jbossEAPPassword string

@description('User name for Red Hat subscription Manager')
param rhsmUserName string = newGuid()

@description('Password for Red Hat subscription Manager')
@secure()
param rhsmPassword string = newGuid()

@description('Red Hat Subscription Manager Pool ID (Should have EAP entitlement)')
param rhsmPoolEAP string = newGuid()

@allowed([
  'on'
  'off'
])
param bootDiagnostics string = 'off'

@description('Specify whether to create a new or use an existing Storage Account.')
@allowed([
  'New'
  'Existing'
])
param bootStorageNewOrExisting string = 'New'

@description('Name of the existing Storage Account Name')
param existingStorageAccount string = ''

@description('Name of the Storage Account.')
param bootStorageAccountName string = 'jbboot${uniqueString(resourceGroup().id)}'

@description('Storage account kind')
param storageAccountKind string = 'Storage'

@description('Name of the resource group for the existing storage account')
param storageAccountResourceGroupName string = resourceGroup().name

@description('Select the Replication Strategy for the Storage account')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param bootStorageReplication string = 'Standard_LRS'

@description('Specify whether to create a new or existing virtual network for the VM.')
@allowed([
  'new'
  'existing'
])
param virtualNetworkNewOrExisting string = 'new'

@description('Name of the existing or new VNET')
param virtualNetworkName string = 'jbosseap-vnet'

@description('Resource group of VIrtual network')
param virtualNetworkResourceGroupName string = resourceGroup().name

@description('Address prefix of the VNET.')
param addressPrefixes array = [
  '10.0.0.0/16'
]

@description('Name of the existing or new Subnet')
param subnetName string = 'jbosseap-server-subnet'

@description('Address prefix of the subnet')
param subnetPrefix string = '10.0.0.0/24'

@description('String used as a base for naming resources (9 characters or less). A hash is prepended to this string for some resources, and resource-specific information is appended')
@maxLength(9)
param vmssName string = 'jbossvmss'

@description('Number of VM instances (100 or less)')
@minValue(2)
@maxValue(100)
param instanceCount int = 2

@description('The size of the Virtual Machine scale set')
param vmSize string = 'Standard_DS2_v2'

@description('The JDK version of the Virtual Machine')
param jdkVersion string = 'openjdk17'

@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated')
param artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated')
@secure()
param artifactsLocationSasToken string = ''

@description('Connect to an existing Red Hat Satellite Server.')
param connectSatellite bool = false

@description('Red Hat Satellite Server activation key.')
param satelliteActivationKey string = ''

@description('Red Hat Satellite Server organization name.')
param satelliteOrgName string = ''

@description('Red Hat Satellite Server VM FQDN name.')
param satelliteFqdn string = ''

param guidValue string = take(replace(newGuid(), '-', ''), 6)

@description('true to set up Application Gateway ingress.')
param enableAppGWIngress bool = false

@description('Name of the existing or new Subnet')
param subnetForAppGateway string = 'jboss-appgateway-subnet'

@description('Address prefix of the subnet')
param subnetPrefixForAppGateway string = '10.0.1.0/24'

@description('Price tier for Key Vault.')
param keyVaultSku string = 'Standard'

@description('UTC value for generating unique names.')
param utcValue string = utcNow()

@description('DNS prefix for ApplicationGateway')
param dnsNameforApplicationGateway string = 'jbossgw'

@description('The name of the secret in the specified KeyVault whose value is the SSL Certificate Data for Appliation Gateway frontend TLS/SSL.')
param keyVaultSSLCertDataSecretName string = 'kv-ssl-data'

@description('true to enable cookie based affinity.')
param enableCookieBasedAffinity bool = false

var containerName = 'eapblobcontainer'
var eapStorageAccountName_var = 'jbosstrg${uniqueString(resourceGroup().id)}'
var eapstorageReplication = 'Standard_LRS'
var vmssInstanceName_var = 'jbosseap-server${vmssName}'
var nicName = 'jbosseap-server-nic'
var bootDiagnosticsCheck = ((bootStorageNewOrExisting == 'New') && (bootDiagnostics == 'on'))
var bootStorageName_var = ((bootStorageNewOrExisting == 'Existing') ? existingStorageAccount : bootStorageAccountName)
var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrSSHKey
      }
    ]
  }
}
var imageReference = {
  publisher: 'RedHat'
  offer: 'RHEL'
  sku: '8_6'
  version: 'latest'
}
var scriptFolder = 'bin'
var fileToBeDownloaded = 'eap-session-replication.war'
var scriptArgs = '-a \'${uri(artifactsLocation, '.')}\' -t "${artifactsLocationSasToken}" -p ${scriptFolder} -f ${fileToBeDownloaded}'
var obj_uamiForDeploymentScript = {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${uamiDeployment.outputs.uamiIdForDeploymentScript}': {}
  }
}
var name_keyVaultName = take('jboss-kv${guidValue}', 24)
var name_dnsNameforApplicationGateway = '${dnsNameforApplicationGateway}${take(uniqueString(utcValue), 6)}'
var name_rgNameWithoutSpecialCharacter = replace(replace(replace(replace(resourceGroup().name, '.', ''), '(', ''), ')', ''), '_', '') // remove . () _ from resource group name
var name_domainLabelforApplicationGateway = take('${name_dnsNameforApplicationGateway}-${toLower(name_rgNameWithoutSpecialCharacter)}', 63)
var const_azureSubjectName = format('{0}.{1}.{2}', name_domainLabelforApplicationGateway, location, 'cloudapp.azure.com')
var name_appgwFrontendSSLCertName = 'appGatewaySslCert'
var name_appGateway = 'appgw${uniqueString(utcValue)}'
var property_subnet_with_app_gateway = [
  {
    name: subnetName
    properties: {
      addressPrefix: subnetPrefix
      networkSecurityGroup: {
        id: nsg.id
      }
    }
  }
  {
    // Assume it is acceptable to create a subnet for the App Gateway, even if the user
    // has not requested an App Gateway.  In support of this assumption we can note: the user may want an App 
    // Gateway after deployment.
    name: subnetForAppGateway
    properties: {
      addressPrefix: subnetPrefixForAppGateway
      networkSecurityGroup: {
        id: nsg.id
      }
    }
  }
]
var property_subnet_without_app_gateway = [
  {
    name: subnetName
    properties: {
      addressPrefix: subnetPrefix
    }
  }
]
var name_publicIPAddress = '-pubIp'
var name_networkSecurityGroup = 'jboss-nsg'
var name_appGatewayPublicIPAddress = 'gwip'

module pids './modules/_pids/_pid.bicep' = {
  name: 'initialization'
}

module partnerCenterPid './modules/_pids/_empty.bicep' = {
  name: 'pid-b57c8aee-4919-4cbb-8399-f966d39d4064-partnercenter'
  params: {}
}

module uamiDeployment 'modules/_uami/_uamiAndRoles.bicep' = {
  name: 'uami-deployment'
  params: {
    location: location
  }
}

module appgwSecretDeployment 'modules/_azure-resources/_keyvaultForGateway.bicep' = if (enableAppGWIngress) {
  name: 'appgateway-certificates-secrets-deployment'
  params: {
    identity: obj_uamiForDeploymentScript
    location: location
    sku: keyVaultSku
    subjectName: format('CN={0}', const_azureSubjectName)
    keyVaultName: name_keyVaultName
  }
}

// Get existing VNET.
resource existingVnet 'Microsoft.Network/virtualNetworks@2022-05-01' existing = if (virtualNetworkNewOrExisting != 'new') {
  name: virtualNetworkName
  scope: resourceGroup(virtualNetworkResourceGroupName)
}

// Get existing subnet.
resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' existing = if (virtualNetworkNewOrExisting != 'new') {
  name: subnetForAppGateway
  parent: existingVnet
}

module appgwDeployment 'modules/_appgateway.bicep' = if (enableAppGWIngress) {
  name: 'app-gateway-deployment'
  params: {
    appGatewayName: name_appGateway
    dnsNameforApplicationGateway: name_dnsNameforApplicationGateway
    gatewayPublicIPAddressName: name_appGatewayPublicIPAddress
    gatewaySubnetId: virtualNetworkNewOrExisting == 'new' ? resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetForAppGateway) : existingSubnet.id
    gatewaySslCertName: name_appgwFrontendSSLCertName
    location: location
    sslCertDataSecretName: (enableAppGWIngress ? appgwSecretDeployment.outputs.sslCertDataSecretName : keyVaultSSLCertDataSecretName)
    _pidAppgwStart: pids.outputs.appgwStart
    _pidAppgwEnd: pids.outputs.appgwEnd
    keyVaultName: name_keyVaultName
    enableCookieBasedAffinity: enableCookieBasedAffinity
  }
  dependsOn: [
    appgwSecretDeployment
    pids
    virtualNetworkName_resource
  ]
}

resource bootStorageName 'Microsoft.Storage/storageAccounts@2022-05-01' = if (bootDiagnosticsCheck) {
  name: bootStorageName_var
  location: location
  sku: {
    name: bootStorageReplication
  }
  kind: storageAccountKind
  tags: {
    QuickstartName: 'JBoss EAP on RHEL VMSS'
  }
}

resource eapStorageAccountName 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: eapStorageAccountName_var
  location: location
  sku: {
    name: eapstorageReplication
  }
  kind: 'Storage'
  tags: {
    QuickstartName: 'JBoss EAP on RHEL VMSS'
  }
}

// Create new network security group.
resource nsg 'Microsoft.Network/networkSecurityGroups@2022-05-01' = if (enableAppGWIngress && virtualNetworkNewOrExisting == 'new') {
  name: name_networkSecurityGroup
  location: location
  properties: {
    securityRules: [
      {
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 500
          direction: 'Inbound'
        }
        name: 'ALLOW_APPGW'
      }
      {
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 510
          direction: 'Inbound'
          destinationPortRanges: [
            '80'
            '443'
            '9990'
            '8080'
          ]
        }
        name: 'ALLOW_HTTP_ACCESS'
      }
    ]
  }
}

resource eapStorageAccountName_default_containerName 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-05-01' = {
  name: '${eapStorageAccountName_var}/default/${containerName}'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    eapStorageAccountName
  ]
}

resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@2022-05-01' = if (virtualNetworkNewOrExisting == 'new') {
  name: virtualNetworkName
  location: location
  tags: {
    QuickstartName: 'JBoss EAP on RHEL VMSS'
  }
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: enableAppGWIngress ? property_subnet_with_app_gateway : property_subnet_without_app_gateway
  }
}

resource vmssInstanceName 'Microsoft.Compute/virtualMachineScaleSets@2022-08-01' = {
  name: vmssInstanceName_var
  location: location
  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: instanceCount
  }
  tags: {
    QuickstartName: 'JBoss EAP on RHEL VMSS'
  }
  properties: {
    overprovision: false
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
        }
        imageReference: imageReference
      }
      osProfile: {
        computerNamePrefix: vmssInstanceName_var
        adminUsername: adminUsername
        adminPassword: adminPasswordOrSSHKey
        linuxConfiguration: ((authenticationType == 'password') ? json('null') : linuxConfiguration)
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: nicName
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: resourceId(virtualNetworkResourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
                    }
                    applicationGatewayBackendAddressPools: enableAppGWIngress ? [
                      {
                        id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name_appGateway, 'managedNodeBackendPool')
                      }
                    ] : null
                    publicIPAddressConfiguration: {
                      name: '${vmssInstanceName_var}${name_publicIPAddress}'
                    }
                  }
                }
              ]
            }
          }
        ]
      }
      diagnosticsProfile: ((bootDiagnostics == 'on') ? json('{"bootDiagnostics": {"enabled": true,"storageUri": "${reference(resourceId(storageAccountResourceGroupName, 'Microsoft.Storage/storageAccounts/', bootStorageName_var), '2021-06-01').primaryEndpoints.blob}"}}') : json('{"bootDiagnostics": {"enabled": false}}'))
      extensionProfile: {
        extensions: [
          {
            name: 'jbosseap-setup-extension'
            properties: {
              publisher: 'Microsoft.Azure.Extensions'
              type: 'CustomScript'
              typeHandlerVersion: '2.0'
              autoUpgradeMinorVersion: true
              settings: {
                fileUris: [
                  uri(artifactsLocation, 'scripts/jbosseap-setup-redhat.sh${artifactsLocationSasToken}')
                ]
              }
              protectedSettings: {
                commandToExecute: 'sh jbosseap-setup-redhat.sh ${scriptArgs} \'${jbossEAPUserName}\' \'${base64(jbossEAPPassword)}\' \'${rhsmUserName}\' \'${base64(rhsmPassword)}\' \'${rhsmPoolEAP}\' \'${eapStorageAccountName_var}\' \'${containerName}\' \'${base64(listKeys(eapStorageAccountName.id, '2021-06-01').keys[0].value)}\' \'${connectSatellite}\' \'${base64(satelliteActivationKey)}\' \'${base64(satelliteOrgName)}\' \'${satelliteFqdn}\' \'${jdkVersion}\''
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    bootStorageName
    virtualNetworkName_resource
    appgwDeployment
  ]
}

output appHttpURL string = enableAppGWIngress ? uri(format('http://{0}/', appgwDeployment.outputs.appGatewayURL), 'eap-session-replication/') : ''
output appHttpsURL string = enableAppGWIngress ? uri(format('https://{0}/', appgwDeployment.outputs.appGatewaySecuredURL), 'eap-session-replication/') : ''
