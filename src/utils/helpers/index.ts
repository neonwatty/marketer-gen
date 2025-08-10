/**
 * Sleep for a given number of milliseconds
 */
export const sleep = (ms: number): Promise<void> => {
  return new Promise(resolve => setTimeout(resolve, ms))
}

/**
 * Generate a unique ID
 */
export const generateId = (): string => {
  return Math.random().toString(36).substring(2) + Date.now().toString(36)
}

/**
 * Create a URL-friendly slug from a string
 */
export const slugify = (text: string): string => {
  return text
    .toLowerCase()
    .trim()
    .replace(/[^\w\s-]/g, '')
    .replace(/[-\s]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

/**
 * Truncate text to a given length
 */
export const truncate = (text: string, length: number, suffix = '...'): string => {
  if (text.length <= length) return text
  return text.substring(0, length - suffix.length) + suffix
}

/**
 * Capitalize the first letter of a string
 */
export const capitalize = (text: string): string => {
  if (!text) return text
  return text.charAt(0).toUpperCase() + text.slice(1).toLowerCase()
}

/**
 * Convert camelCase to kebab-case
 */
export const camelToKebab = (text: string): string => {
  return text.replace(/([a-z0-9])([A-Z])/g, '$1-$2').toLowerCase()
}

/**
 * Convert kebab-case to camelCase
 */
export const kebabToCamel = (text: string): string => {
  return text.replace(/-([a-z])/g, (_, letter) => letter.toUpperCase())
}

/**
 * Deep merge two objects
 */
export const deepMerge = <T extends Record<string, unknown>>(
  target: T,
  source: Partial<T>
): T => {
  const result = { ...target }
  
  for (const key in source) {
    const targetValue = result[key]
    const sourceValue = source[key]
    
    if (
      targetValue &&
      sourceValue &&
      typeof targetValue === 'object' &&
      typeof sourceValue === 'object' &&
      !Array.isArray(targetValue) &&
      !Array.isArray(sourceValue)
    ) {
      result[key] = deepMerge(targetValue as Record<string, unknown>, sourceValue as Record<string, unknown>) as T[Extract<keyof T, string>]
    } else if (sourceValue !== undefined) {
      result[key] = sourceValue as T[Extract<keyof T, string>]
    }
  }
  
  return result
}

/**
 * Debounce a function
 */
export const debounce = <T extends unknown[]>(
  func: (...args: T) => void,
  wait: number
): ((...args: T) => void) => {
  let timeout: NodeJS.Timeout | null = null
  
  return (...args: T) => {
    if (timeout) clearTimeout(timeout)
    timeout = setTimeout(() => func(...args), wait)
  }
}

/**
 * Throttle a function
 */
export const throttle = <T extends unknown[]>(
  func: (...args: T) => void,
  limit: number
): ((...args: T) => void) => {
  let inThrottle = false
  
  return (...args: T) => {
    if (!inThrottle) {
      func(...args)
      inThrottle = true
      setTimeout(() => (inThrottle = false), limit)
    }
  }
}

/**
 * Check if a value is empty (null, undefined, empty string, empty array, empty object)
 */
export const isEmpty = (value: unknown): boolean => {
  if (value == null) return true
  if (typeof value === 'string') return value.trim().length === 0
  if (Array.isArray(value)) return value.length === 0
  if (typeof value === 'object') return Object.keys(value).length === 0
  return false
}

/**
 * Pick specific properties from an object
 */
export const pick = <T extends Record<string, unknown>, K extends keyof T>(
  obj: T,
  keys: K[]
): Pick<T, K> => {
  const result = {} as Pick<T, K>
  for (const key of keys) {
    if (key in obj) {
      result[key] = obj[key]
    }
  }
  return result
}

/**
 * Omit specific properties from an object
 */
export const omit = <T extends Record<string, unknown>, K extends keyof T>(
  obj: T,
  keys: K[]
): Omit<T, K> => {
  const result = { ...obj }
  for (const key of keys) {
    delete result[key]
  }
  return result
}

/**
 * Get a random item from an array
 */
export const randomItem = <T>(array: T[]): T | undefined => {
  if (array.length === 0) return undefined
  const index = Math.floor(Math.random() * array.length)
  return array[index]
}

/**
 * Shuffle an array
 */
export const shuffle = <T>(array: T[]): T[] => {
  const result = [...array]
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    const temp = result[i]
    if (temp !== undefined && result[j] !== undefined) {
      result[i] = result[j]!
      result[j] = temp
    }
  }
  return result
}

/**
 * Group array items by a key
 */
export const groupBy = <T, K extends keyof T>(
  array: T[],
  key: K
): Record<string, T[]> => {
  return array.reduce((groups, item) => {
    const groupKey = String(item[key])
    if (!groups[groupKey]) {
      groups[groupKey] = []
    }
    groups[groupKey].push(item)
    return groups
  }, {} as Record<string, T[]>)
}

/**
 * Create an array of numbers from start to end
 */
export const range = (start: number, end: number, step = 1): number[] => {
  const result = []
  for (let i = start; i < end; i += step) {
    result.push(i)
  }
  return result
}