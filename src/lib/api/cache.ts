import { NextRequest, NextResponse } from 'next/server'

// Cache configuration
export interface CacheConfig {
  maxAge?: number // seconds
  sMaxAge?: number // seconds for shared caches (CDN)
  staleWhileRevalidate?: number // seconds
  revalidate?: number // Next.js ISR revalidation
  tags?: string[] // Cache tags for invalidation
  vary?: readonly string[] | string[] // Vary header values
  private?: boolean // Mark cache as private
  noCache?: boolean // Prevent caching
  noStore?: boolean // Prevent storing
  mustRevalidate?: boolean // Force revalidation when stale
}

// Default cache configurations for different resource types
export const cachePresets = {
  // Static assets that rarely change
  static: {
    maxAge: 31536000, // 1 year
    sMaxAge: 31536000, // 1 year for CDN
    vary: ['Accept-Encoding'],
  },
  
  // API responses that can be cached for a short time
  api: {
    maxAge: 300, // 5 minutes
    sMaxAge: 300, // 5 minutes for CDN
    staleWhileRevalidate: 600, // 10 minutes stale-while-revalidate
    vary: ['Authorization', 'Accept'],
  },
  
  // User-specific data
  private: {
    maxAge: 300, // 5 minutes
    private: true,
    vary: ['Authorization'],
  },
  
  // Frequently updated data
  dynamic: {
    maxAge: 60, // 1 minute
    staleWhileRevalidate: 300, // 5 minutes stale-while-revalidate
    vary: ['Authorization'],
  },
  
  // Data that should not be cached
  noCache: {
    noCache: true,
    noStore: true,
    maxAge: 0,
  },
  
  // Long-term cacheable reference data
  reference: {
    maxAge: 3600, // 1 hour
    sMaxAge: 86400, // 1 day for CDN
    staleWhileRevalidate: 43200, // 12 hours stale-while-revalidate
    vary: ['Accept'],
  },
} as const

// Generate cache control header value
export const generateCacheControl = (config: CacheConfig): string => {
  const directives: string[] = []
  
  if (config.noCache) {
    directives.push('no-cache')
  }
  
  if (config.noStore) {
    directives.push('no-store')
  }
  
  if (config.private) {
    directives.push('private')
  } else if (config.sMaxAge !== undefined) {
    directives.push('public')
  }
  
  if (config.maxAge !== undefined) {
    directives.push(`max-age=${config.maxAge}`)
  }
  
  if (config.sMaxAge !== undefined) {
    directives.push(`s-maxage=${config.sMaxAge}`)
  }
  
  if (config.staleWhileRevalidate !== undefined) {
    directives.push(`stale-while-revalidate=${config.staleWhileRevalidate}`)
  }
  
  if (config.mustRevalidate) {
    directives.push('must-revalidate')
  }
  
  return directives.join(', ')
}

// Generate cache headers
export const generateCacheHeaders = (config: CacheConfig): Record<string, string> => {
  const headers: Record<string, string> = {}
  
  // Cache-Control header
  const cacheControl = generateCacheControl(config)
  if (cacheControl) {
    headers['Cache-Control'] = cacheControl
  }
  
  // Vary header
  if (config.vary && config.vary.length > 0) {
    headers['Vary'] = config.vary.join(', ')
  }
  
  // ETag for cache validation
  headers['ETag'] = `"${Date.now()}-${Math.random().toString(36).slice(2)}"`
  
  // Last-Modified header
  headers['Last-Modified'] = new Date().toUTCString()
  
  return headers
}

// Create cached response
export const createCachedResponse = <T>(
  data: T,
  config: CacheConfig = cachePresets.api,
  status = 200
): NextResponse<T> => {
  const headers = generateCacheHeaders(config)
  return NextResponse.json(data, { status, headers })
}

// Cache key generation
export const generateCacheKey = (
  request: NextRequest,
  additionalKeys: string[] = []
): string => {
  const url = new URL(request.url)
  const keyParts = [
    request.method,
    url.pathname,
    url.searchParams.toString(),
    ...additionalKeys,
  ].filter(Boolean)
  
  return keyParts.join(':')
}

// Check if request supports caching
export const isCacheable = (request: NextRequest): boolean => {
  const method = request.method
  
  // Only cache GET and HEAD requests
  if (method !== 'GET' && method !== 'HEAD') {
    return false
  }
  
  // Don't cache requests with Authorization header (unless explicitly allowed)
  if (request.headers.get('Authorization') && !request.headers.get('X-Cache-Auth')) {
    return false
  }
  
  // Don't cache requests with Cache-Control: no-cache
  const cacheControl = request.headers.get('Cache-Control')
  if (cacheControl?.includes('no-cache')) {
    return false
  }
  
  return true
}

// Check if response is fresh based on ETag
export const isResponseFresh = (
  request: NextRequest,
  etag: string
): boolean => {
  const ifNoneMatch = request.headers.get('If-None-Match')
  return ifNoneMatch === etag
}

// Check if response is fresh based on Last-Modified
export const isResponseFreshByDate = (
  request: NextRequest,
  lastModified: Date
): boolean => {
  const ifModifiedSince = request.headers.get('If-Modified-Since')
  if (!ifModifiedSince) return false
  
  const ifModifiedSinceDate = new Date(ifModifiedSince)
  return lastModified <= ifModifiedSinceDate
}

// Create 304 Not Modified response
export const createNotModifiedResponse = (): NextResponse => {
  return new NextResponse(null, { status: 304 })
}

// Cache middleware wrapper
export const withCache = <T extends any[], R>(
  handler: (...args: T) => Promise<NextResponse<R>>,
  config: CacheConfig = cachePresets.api
) => {
  return async (...args: T): Promise<NextResponse<R>> => {
    const request = args.find(arg => arg instanceof NextRequest) as NextRequest
    
    if (!request || !isCacheable(request)) {
      return handler(...args)
    }
    
    // Generate cache headers
    const headers = generateCacheHeaders(config)
    
    // Check if client has fresh version (ETag)
    const etag = headers['ETag']
    if (etag && isResponseFresh(request, etag)) {
      return createNotModifiedResponse() as NextResponse<R>
    }
    
    // Execute handler
    const response = await handler(...args)
    
    // Add cache headers to response
    Object.entries(headers).forEach(([key, value]) => {
      response.headers.set(key, value)
    })
    
    return response
  }
}

// Simple in-memory cache (for development/testing)
class InMemoryCache {
  private cache = new Map<string, {
    data: any
    expiry: number
    etag: string
  }>()
  
  set(key: string, data: any, maxAge: number): void {
    const expiry = Date.now() + (maxAge * 1000)
    const etag = `"${Date.now()}-${Math.random().toString(36).slice(2)}"`
    
    this.cache.set(key, { data, expiry, etag })
    
    // Clean up expired entries
    this.cleanup()
  }
  
  get(key: string): { data: any; etag: string } | null {
    const entry = this.cache.get(key)
    
    if (!entry || entry.expiry < Date.now()) {
      this.cache.delete(key)
      return null
    }
    
    return { data: entry.data, etag: entry.etag }
  }
  
  delete(key: string): void {
    this.cache.delete(key)
  }
  
  clear(): void {
    this.cache.clear()
  }
  
  private cleanup(): void {
    const now = Date.now()
    for (const [key, entry] of this.cache.entries()) {
      if (entry.expiry < now) {
        this.cache.delete(key)
      }
    }
  }
  
  size(): number {
    return this.cache.size
  }
}

// Global cache instance
export const memoryCache = new InMemoryCache()

// Cache-enabled handler with memory cache
export const withMemoryCache = <T extends any[], R>(
  handler: (...args: T) => Promise<NextResponse<R>>,
  config: CacheConfig & { cacheKey?: (request: NextRequest) => string } = cachePresets.api
) => {
  return async (...args: T): Promise<NextResponse<R>> => {
    const request = args.find(arg => arg instanceof NextRequest) as NextRequest
    
    if (!request || !isCacheable(request) || !config.maxAge) {
      return handler(...args)
    }
    
    // Generate cache key
    const cacheKey = config.cacheKey 
      ? config.cacheKey(request)
      : generateCacheKey(request)
    
    // Try to get from cache
    const cached = memoryCache.get(cacheKey)
    if (cached) {
      // Check if client has fresh version
      if (isResponseFresh(request, cached.etag)) {
        return createNotModifiedResponse() as NextResponse<R>
      }
      
      // Return cached response with headers
      const headers = generateCacheHeaders(config)
      headers['ETag'] = cached.etag
      
      return NextResponse.json(cached.data, { headers }) as NextResponse<R>
    }
    
    // Execute handler and cache result
    const response = await handler(...args)
    const data = await response.json()
    
    // Store in cache
    if (response.ok && config.maxAge > 0) {
      memoryCache.set(cacheKey, data, config.maxAge)
    }
    
    // Add cache headers
    const headers = generateCacheHeaders(config)
    Object.entries(headers).forEach(([key, value]) => {
      response.headers.set(key, value)
    })
    
    return response
  }
}

// Cache invalidation helpers
export const invalidateCache = (patterns: string[]): void => {
  // For in-memory cache, we need to iterate and match patterns
  const cache = (memoryCache as any).cache as Map<string, any>
  for (const [key] of cache.entries()) {
    for (const pattern of patterns) {
      if (key.includes(pattern)) {
        memoryCache.delete(key)
        break
      }
    }
  }
}

// Clear all cache
export const clearCache = (): void => {
  memoryCache.clear()
}

// Cache statistics
export const getCacheStats = (): {
  size: number
  keys: string[]
} => {
  const keys = Array.from((memoryCache as any).cache.keys()) as string[]
  return {
    size: memoryCache.size(),
    keys,
  }
}