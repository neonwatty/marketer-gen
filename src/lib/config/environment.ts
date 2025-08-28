// Environment configuration and optimization utilities
export const isDevelopment = process.env.NODE_ENV === 'development'
export const isProduction = process.env.NODE_ENV === 'production'
export const isTest = process.env.NODE_ENV === 'test'

// Performance configurations per environment
export const performanceConfig = {
  development: {
    enableDevtools: true,
    logLevel: 'debug',
    cacheTime: 0,
    enableHotReload: true,
    enableSourceMaps: true,
    compressAssets: false,
  },
  production: {
    enableDevtools: false,
    logLevel: 'error',
    cacheTime: 3600000, // 1 hour
    enableHotReload: false,
    enableSourceMaps: false,
    compressAssets: true,
  },
  test: {
    enableDevtools: false,
    logLevel: 'silent',
    cacheTime: 0,
    enableHotReload: false,
    enableSourceMaps: true,
    compressAssets: false,
  },
}

// Get current environment config
export const currentConfig = performanceConfig[process.env.NODE_ENV as keyof typeof performanceConfig] || performanceConfig.development

// Database configuration per environment
export const dbConfig = {
  development: {
    poolSize: 5,
    connectionTimeout: 5000,
    logQueries: true,
  },
  production: {
    poolSize: 20,
    connectionTimeout: 10000,
    logQueries: false,
  },
  test: {
    poolSize: 1,
    connectionTimeout: 2000,
    logQueries: false,
  },
}

// API rate limiting per environment
export const rateLimitConfig = {
  development: {
    enabled: false,
    maxRequests: Infinity,
    windowMs: 60000,
  },
  production: {
    enabled: true,
    maxRequests: 1000,
    windowMs: 60000, // 1 minute
  },
  test: {
    enabled: false,
    maxRequests: Infinity,
    windowMs: 60000,
  },
}

// Caching strategies per environment
export const cacheConfig = {
  development: {
    enableApiCache: false,
    apiCacheTTL: 0,
    enableStaticCache: false,
    staticCacheTTL: 0,
  },
  production: {
    enableApiCache: true,
    apiCacheTTL: 300000, // 5 minutes
    enableStaticCache: true,
    staticCacheTTL: 86400000, // 24 hours
  },
  test: {
    enableApiCache: false,
    apiCacheTTL: 0,
    enableStaticCache: false,
    staticCacheTTL: 0,
  },
}

// Security configurations
export const securityConfig = {
  development: {
    enableCSP: false,
    enableHSTS: false,
    cors: {
      origin: ['http://localhost:3000', 'http://localhost:3001'],
      credentials: true,
    },
  },
  production: {
    enableCSP: true,
    enableHSTS: true,
    cors: {
      origin: process.env.ALLOWED_ORIGINS?.split(',') || [],
      credentials: true,
    },
  },
  test: {
    enableCSP: false,
    enableHSTS: false,
    cors: {
      origin: '*',
      credentials: false,
    },
  },
}

// Helper functions
export function getEnvironmentConfig<T extends keyof typeof performanceConfig>(
  configType: 'performance' | 'db' | 'rateLimit' | 'cache' | 'security'
): any {
  const configs = {
    performance: performanceConfig,
    db: dbConfig,
    rateLimit: rateLimitConfig,
    cache: cacheConfig,
    security: securityConfig,
  }
  
  const config = configs[configType]
  return config[process.env.NODE_ENV as keyof typeof config] || config.development
}

export function shouldEnableFeature(feature: string): boolean {
  // Feature flags per environment
  const features = {
    development: {
      analytics: true,
      debugMode: true,
      experimentalFeatures: true,
      performanceMonitoring: true,
    },
    production: {
      analytics: true,
      debugMode: false,
      experimentalFeatures: false,
      performanceMonitoring: true,
    },
    test: {
      analytics: false,
      debugMode: false,
      experimentalFeatures: false,
      performanceMonitoring: false,
    },
  }
  
  const envFeatures = features[process.env.NODE_ENV as keyof typeof features] || features.development
  return envFeatures[feature as keyof typeof envFeatures] || false
}