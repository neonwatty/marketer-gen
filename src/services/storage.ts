import { STORAGE_KEYS } from '@/lib/constants'

/**
 * Storage service for managing browser storage (localStorage, sessionStorage)
 */
class StorageService {
  /**
   * Get item from localStorage
   */
  getLocal<T>(key: string, defaultValue?: T): T | null {
    if (typeof window === 'undefined') return defaultValue || null

    try {
      const item = localStorage.getItem(key)
      return item ? JSON.parse(item) : defaultValue || null
    } catch (error) {
      console.error(`Error reading from localStorage: ${key}`, error)
      return defaultValue || null
    }
  }

  /**
   * Set item in localStorage
   */
  setLocal<T>(key: string, value: T): void {
    if (typeof window === 'undefined') return

    try {
      localStorage.setItem(key, JSON.stringify(value))
    } catch (error) {
      console.error(`Error writing to localStorage: ${key}`, error)
    }
  }

  /**
   * Remove item from localStorage
   */
  removeLocal(key: string): void {
    if (typeof window === 'undefined') return

    try {
      localStorage.removeItem(key)
    } catch (error) {
      console.error(`Error removing from localStorage: ${key}`, error)
    }
  }

  /**
   * Clear all localStorage
   */
  clearLocal(): void {
    if (typeof window === 'undefined') return

    try {
      localStorage.clear()
    } catch (error) {
      console.error('Error clearing localStorage', error)
    }
  }

  /**
   * Get item from sessionStorage
   */
  getSession<T>(key: string, defaultValue?: T): T | null {
    if (typeof window === 'undefined') return defaultValue || null

    try {
      const item = sessionStorage.getItem(key)
      return item ? JSON.parse(item) : defaultValue || null
    } catch (error) {
      console.error(`Error reading from sessionStorage: ${key}`, error)
      return defaultValue || null
    }
  }

  /**
   * Set item in sessionStorage
   */
  setSession<T>(key: string, value: T): void {
    if (typeof window === 'undefined') return

    try {
      sessionStorage.setItem(key, JSON.stringify(value))
    } catch (error) {
      console.error(`Error writing to sessionStorage: ${key}`, error)
    }
  }

  /**
   * Remove item from sessionStorage
   */
  removeSession(key: string): void {
    if (typeof window === 'undefined') return

    try {
      sessionStorage.removeItem(key)
    } catch (error) {
      console.error(`Error removing from sessionStorage: ${key}`, error)
    }
  }

  /**
   * Clear all sessionStorage
   */
  clearSession(): void {
    if (typeof window === 'undefined') return

    try {
      sessionStorage.clear()
    } catch (error) {
      console.error('Error clearing sessionStorage', error)
    }
  }

  /**
   * Check if storage is available
   */
  isStorageAvailable(type: 'localStorage' | 'sessionStorage'): boolean {
    if (typeof window === 'undefined') return false

    try {
      const storage = window[type]
      const test = '__storage_test__'
      storage.setItem(test, test)
      storage.removeItem(test)
      return true
    } catch {
      return false
    }
  }

  /**
   * Get storage usage information
   */
  getStorageInfo(): {
    localStorage: { used: number; remaining: number; total: number }
    sessionStorage: { used: number; remaining: number; total: number }
  } {
    const getStorageSize = (storage: Storage): number => {
      let total = 0
      for (const key in storage) {
        if (storage.hasOwnProperty(key)) {
          total += storage[key].length + key.length
        }
      }
      return total
    }

    const maxSize = 5 * 1024 * 1024 // 5MB typical limit

    const localUsed = this.isStorageAvailable('localStorage') ? getStorageSize(localStorage) : 0
    const sessionUsed = this.isStorageAvailable('sessionStorage')
      ? getStorageSize(sessionStorage)
      : 0

    return {
      localStorage: {
        used: localUsed,
        remaining: maxSize - localUsed,
        total: maxSize,
      },
      sessionStorage: {
        used: sessionUsed,
        remaining: maxSize - sessionUsed,
        total: maxSize,
      },
    }
  }

  /**
   * Get user preferences
   */
  getUserPreferences(): Record<string, any> {
    return this.getLocal(STORAGE_KEYS.userPreferences, {}) || {}
  }

  /**
   * Set user preferences
   */
  setUserPreferences(preferences: Record<string, any>): void {
    this.setLocal(STORAGE_KEYS.userPreferences, preferences)
  }

  /**
   * Get theme preference
   */
  getTheme(): string {
    return this.getLocal(STORAGE_KEYS.theme, 'system') || 'system'
  }

  /**
   * Set theme preference
   */
  setTheme(theme: string): void {
    this.setLocal(STORAGE_KEYS.theme, theme)
  }

  /**
   * Get language preference
   */
  getLanguage(): string {
    return this.getLocal(STORAGE_KEYS.language, 'en') || 'en'
  }

  /**
   * Set language preference
   */
  setLanguage(language: string): void {
    this.setLocal(STORAGE_KEYS.language, language)
  }

  /**
   * Get recent searches
   */
  getRecentSearches(): string[] {
    return this.getLocal(STORAGE_KEYS.recentSearches, []) || []
  }

  /**
   * Add recent search
   */
  addRecentSearch(search: string, maxItems: number = 10): void {
    const searches = this.getRecentSearches()
    const filtered = searches.filter(s => s !== search)
    filtered.unshift(search)
    this.setLocal(STORAGE_KEYS.recentSearches, filtered.slice(0, maxItems))
  }

  /**
   * Clear recent searches
   */
  clearRecentSearches(): void {
    this.removeLocal(STORAGE_KEYS.recentSearches)
  }
}

export const storageService = new StorageService()
