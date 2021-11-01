
@description('Web App Name')
param webAppName string 
@description('VIrtual Network Name')
param virtualNetworkName string 

@description('Application Gateway Subnet name')
param appGatewaySubnetName string 

@description('Application Gateway Name')
param appGatewayName string 

param storageAccountName string = 'sentstagg'

param fileShareName string = 'filesent'

param virtualNetworkAddressPrefix string
param publicIpAddressSku string 
param publicIpAddressAllocationType string

@description('Subnet Prefix')
param virtualNetworkSubnetPrefix string
@description('Application Gateway Size')
param applicationGatewaySkuSize string

@description('Application Gateway Tier')
param applicationGatewayTier string

@description('Application Gateway Mai Capacity')
param applicationGatewayAutoScaleMinCapacity int

@description('Application Gateway Max Capacity')
param applicationGatewayAutoScaleMaxCapacity int

@description('web app plan ')
param webAppPlanSku string

@description('Cosmos DB account name')
param accountName string = 'mongodb-${uniqueString(resourceGroup().id)}'

@description('Location for the Cosmos DB account.')
param location string = resourceGroup().location

@description('The primary replica region for the Cosmos DB account.')
param primaryRegion string

@description('The secondary replica region for the Cosmos DB account.')
param secondaryRegion string

@description('The default consistency level of the Cosmos DB account.')
@allowed([
  'Eventual'
  'ConsistentPrefix'
  'Session'
  'BoundedStaleness'
  'Strong'
])
param defaultConsistencyLevel string

@description('Specifies the MongoDB server version to use.')
@allowed([
  '3.2'
  '3.6'
  '4.0'
])
param serverVersion string
@description('Max stale requests. Required for BoundedStaleness. Valid ranges, Single Region: 10 to 1000000. Multi Region: 100000 to 1000000.')
@minValue(10)
@maxValue(2147483647)
param maxStalenessPrefix int = 100000

@description('Max lag time (seconds). Required for BoundedStaleness. Valid ranges, Single Region: 5 to 84600. Multi Region: 300 to 86400.')
@minValue(5)
@maxValue(86400)
param maxIntervalInSeconds int = 300

@description('The name for the Mongo DB database')
param databaseName string

@description('The shared throughput for the Mongo DB database')
@minValue(400)
@maxValue(1000000)
param throughput int = 400

@description('The name for the first Mongo DB collection')
param collection1Name string

@description('The name for the second Mongo DB collection')
param collection2Name string

var accountName_var_var = toLower(accountName)
var consistencyPolicy = {
  Eventual: {
    defaultConsistencyLevel: 'Eventual'
  }
  ConsistentPrefix: {
    defaultConsistencyLevel: 'ConsistentPrefix'
  }
  Session: {
    defaultConsistencyLevel: 'Session'
  }
  BoundedStaleness: {
    defaultConsistencyLevel: 'BoundedStaleness'
    maxStalenessPrefix: maxStalenessPrefix
    maxIntervalInSeconds: maxIntervalInSeconds
  }
  Strong: {
    defaultConsistencyLevel: 'Strong'
  }
}
var locations = [
  {
    locationName: primaryRegion
    failoverPriority: 0
    isZoneRedundant: false
  }
  {
    locationName: secondaryRegion
    failoverPriority: 1
    isZoneRedundant: false
  }
]

var location_var = location
var virtualNetworkName_var = '${virtualNetworkName}-${uniqueString(resourceGroup().id)}'
var virtualNetworkSubnetName = appGatewaySubnetName

//var virtualNetworkId = virtualNetworkName_resource.id
var virtualNetworkSubnetId = resourceId('Microsoft.Network/virtualNetworks/subnets/', virtualNetworkName_var, virtualNetworkSubnetName)
var publicIpAddressName_var = 'myAppGatewayPublicIp-${uniqueString(resourceGroup().id)}'

var publicIpAddressId = publicIpAddressName.id
var webAppName_var = '${webAppName}-${uniqueString(resourceGroup().id)}'
var webAppPlanName_var = '${webAppName}Plan-${uniqueString(resourceGroup().id)}'
var webAppPlanId = webAppPlanName.id
var applicationGatewayName_var = '${appGatewayName}-${uniqueString(resourceGroup().id)}'

var appGwIpConfigName = 'appGatewayIpConfigName'
var appGwFrontendPortName = 'appGatewayFrontendPort_80'
var appGwFrontendPort = 80
var appGwFrontendPortId = resourceId('Microsoft.Network/applicationGateways/frontendPorts/', applicationGatewayName_var, appGwFrontendPortName)
var appGwFrontendIpConfigName = 'appGatewayPublicFrontendIpConfig'
var appGwFrontendIpConfigId = resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations/', applicationGatewayName_var, appGwFrontendIpConfigName)
var appGwHttpSettingName = 'appGatewayHttpSetting_80'
var appGwHttpSettingId = resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection/', applicationGatewayName_var, appGwHttpSettingName)
var appGwHttpSettingProbeName = 'appGatewayHttpSettingProbe_80'
var appGwBackendAddressPoolName = 'appGateway${webAppName_var}BackendPool'
var appGwBackendAddressPoolId = resourceId('Microsoft.Network/applicationGateways/backendAddressPools/', applicationGatewayName_var, appGwBackendAddressPoolName)
var appGwListenerName = 'appGatewayListener'
var appGwListenerId = resourceId('Microsoft.Network/applicationGateways/httpListeners/', applicationGatewayName_var, appGwListenerName)
var appGwRoutingRuleName = 'appGatewayRoutingRule'

resource virtualNetworkName_resource 'Microsoft.Network/virtualNetworks@2021-03-01' = {
  name: virtualNetworkName_var
  location: location_var
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressPrefix
      ]
    }
    subnets: [
      {
        name: virtualNetworkSubnetName
        properties: {
          addressPrefix: virtualNetworkSubnetPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.Web'
              locations: [
                '*'
              ]
            }
          ]
        }
      }
    ]
  }
}

resource webAppPlanName 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: webAppPlanName_var
  location: location_var
  
  properties: {
    reserved: false

  }
  sku: {
    name: webAppPlanSku
    capacity: 1
     
  }
}

resource webAppName_resource 'Microsoft.Web/sites@2021-02-01' = {
  name: webAppName_var
  location: location_var
  properties: {
    serverFarmId: webAppPlanId
    storageAccountRequired:true
    reserved: false
    siteConfig: {
      http20Enabled: true
      minTlsVersion: '1.2'
      connectionStrings:[
        {
          connectionString: listKeys(accountName_var.id, accountName_var.apiVersion).primaryMasterKey
          name: 'mongodbconnstring'
          type: 'DocDb'
        }
      ]
      azureStorageAccounts: {
          myshareid: {
            type: 'AzureFiles'
            accountName: storageAccountName
            shareName: fileShareName
            mountPath: '/mnt/myshare'
            accessKey:  listKeys(storageaccount.id, '2019-04-01').keys[0].value
          }
        
      }
      ipSecurityRestrictions: [
        {
          vnetSubnetResourceId: virtualNetworkSubnetId
          action: 'Allow'
          tag: 'Default'
          priority: 200
          name: 'appGatewaySubnet'
          description: 'Isolate traffic to subnet containing Azure Application Gateway'
        }
      ]
    }
    httpsOnly: false
  }
}

resource publicIpAddressName 'Microsoft.Network/publicIPAddresses@2021-03-01' = {
  name: publicIpAddressName_var
  location: location_var
  sku: {
    name: publicIpAddressSku
  }
  properties: {
    publicIPAllocationMethod: publicIpAddressAllocationType
    dnsSettings: {
      domainNameLabel: toLower(webAppName_var)
    }
  }
}

resource applicationGatewayName 'Microsoft.Network/applicationGateways@2021-03-01' = {
  name: applicationGatewayName_var
  location: location_var
  properties: {
    sku: {
      name: applicationGatewaySkuSize
      tier: applicationGatewayTier
    }
    gatewayIPConfigurations: [
      {
        name: appGwIpConfigName
        properties: {
          subnet: {
            id: virtualNetworkSubnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: appGwFrontendIpConfigName
        properties: {
          publicIPAddress: {
            id: publicIpAddressId
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: appGwFrontendPortName
        properties: {
          port: appGwFrontendPort
        }
      }
    ]
    backendAddressPools: [
      {
        name: appGwBackendAddressPoolName
        properties: {
          backendAddresses: [
            {
              fqdn: webAppName_resource.properties.hostNames[0]
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: appGwHttpSettingName
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 20
          pickHostNameFromBackendAddress: true
        }
      }
    ]
    httpListeners: [
      {
        name: appGwListenerName
        properties: {
          frontendIPConfiguration: {
            id: appGwFrontendIpConfigId
          }
          frontendPort: {
            id: appGwFrontendPortId
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: appGwRoutingRuleName
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: appGwListenerId
          }
          backendAddressPool: {
            id: appGwBackendAddressPoolId
          }
          backendHttpSettings: {
            id: appGwHttpSettingId
          }
        }
      }
    ]
    enableHttp2: true
    probes: [
      {
        name: appGwHttpSettingProbeName
        properties: {
          interval: 30
          minServers: 0
          path: '/'
          protocol: 'Http'
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
        }
      }
    ]
    autoscaleConfiguration: {
      minCapacity: applicationGatewayAutoScaleMinCapacity
      maxCapacity: applicationGatewayAutoScaleMaxCapacity
    }
  }
}

resource accountName_var 'Microsoft.DocumentDB/databaseAccounts@2021-06-15' = {
  name: accountName_var_var
  location: location
  kind: 'MongoDB'
  properties: {
    consistencyPolicy: consistencyPolicy[defaultConsistencyLevel]
    locations: locations
    databaseAccountOfferType: 'Standard'
    apiProperties: {
      serverVersion: serverVersion
    }
  }
}

resource accountName_var_databaseName 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2021-06-15' = {
  parent: accountName_var
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
    options: {
      throughput: throughput
    }
  }
}

resource accountName_var_databaseName_collection1Name 'Microsoft.DocumentDb/databaseAccounts/mongodbDatabases/collections@2021-06-15' = {
  parent: accountName_var_databaseName
  name: collection1Name
  properties: {
    resource: {
      id: collection1Name
      shardKey: {
        user_id: 'Hash'
      }
      indexes: [
        {
          key: {
            keys: [
              '_id'
            ]
          }
        }
        {
          key: {
            keys: [
              '$**'
            ]
          }
        }
        {
          key: {
            keys: [
              'user_id'
              'user_address'
            ]
          }
          options: {
            unique: true
          }
        }
        {
          key: {
            keys: [
              '_ts'
            ]
          }
          options: {
            expireAfterSeconds: 2629746
          }
        }
      ]
    }
  }
}

resource accountName_var_databaseName_collection2Name 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2021-06-15' = {
  parent: accountName_var_databaseName
  name: collection2Name
  properties: {
    resource: {
      id: collection2Name
      shardKey: {
        company_id: 'Hash'
      }
      indexes: [
        {
          key: {
            keys: [
              '_id'
            ]
          }
        }
        {
          key: {
            keys: [
              '$**'
            ]
          }
        }
        {
          key: {
            keys: [
              'company_id'
              'company_address'
            ]
          }
          options: {
            unique: true
          }
        }
        {
          key: {
            keys: [
              '_ts'
            ]
          }
          options: {
            expireAfterSeconds: 2629746
          }
        }
      ]
    }
  }
  
}

resource storageaccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageAccountName
  location: resourceGroup().location
  kind: 'StorageV2'
  properties:{
    allowSharedKeyAccess: true
  }
  sku: {
    name: 'Premium_LRS'

  }
}

resource storageAccountName_default_fileShareName 'Microsoft.Storage/storageAccounts/fileServices/shares@2019-06-01' = {
  name: '${storageAccountName}/default/${fileShareName}'
  dependsOn: [
    storageaccount
  ]
}


output appGatewayUrl string = 'http://${publicIpAddressName.properties.dnsSettings.fqdn}/'
output webAppUrl string = 'http://${webAppName_resource.properties.hostNames[0]}/'
