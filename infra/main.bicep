param location string = resourceGroup().location
param name string

resource staticWebApp 'Microsoft.Web/staticSites@2025-03-01' = {
  name: name
  location: location
  sku: {
    name: 'Free'
    tier: 'Free'
  }
}

output defaultHostname string = staticWebApp.properties.defaultHostname
