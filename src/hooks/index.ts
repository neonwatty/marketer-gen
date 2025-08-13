'use client'

import { useState, useEffect, useCallback, useRef } from 'react'

/**
 * Hook for managing local storage state
 */
export function useLocalStorage<T>(
  key: string,
  initialValue: T
): [T, (value: T | ((val: T) => T)) => void] {
  // State to store our value
  const [storedValue, setStoredValue] = useState<T>(() => {
    if (typeof window === 'undefined') {
      return initialValue
    }
    
    try {
      const item = window.localStorage.getItem(key)
      return item ? JSON.parse(item) : initialValue
    } catch (error) {
      console.warn(`Error reading localStorage key "${key}":`, error)
      return initialValue
    }
  })

  // Return a wrapped version of useState's setter function that persists the new value to localStorage
  const setValue = useCallback(
    (value: T | ((val: T) => T)) => {
      try {
        // Allow value to be a function so we have the same API as useState
        const valueToStore = value instanceof Function ? value(storedValue) : value
        setStoredValue(valueToStore)
        
        if (typeof window !== 'undefined') {
          window.localStorage.setItem(key, JSON.stringify(valueToStore))
        }
      } catch (error) {
        console.warn(`Error setting localStorage key "${key}":`, error)
      }
    },
    [key, storedValue]
  )

  return [storedValue, setValue]
}

/**
 * Hook for debouncing a value
 */
export function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value)

  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedValue(value)
    }, delay)

    return () => {
      clearTimeout(handler)
    }
  }, [value, delay])

  return debouncedValue
}

/**
 * Hook for detecting clicks outside of an element
 */
export function useClickOutside<T extends HTMLElement = HTMLElement>(
  handler: () => void
): React.RefObject<T | null> {
  const ref = useRef<T | null>(null)

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (ref.current && !ref.current.contains(event.target as Node)) {
        handler()
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [handler])

  return ref
}

/**
 * Hook for managing async operations
 */
export function useAsync<T, E = string>(
  asyncFunction: () => Promise<T>,
  immediate = true
) {
  const [status, setStatus] = useState<'idle' | 'pending' | 'success' | 'error'>('idle')
  const [data, setData] = useState<T | null>(null)
  const [error, setError] = useState<E | null>(null)

  const execute = useCallback(async () => {
    setStatus('pending')
    setData(null)
    setError(null)

    try {
      const response = await asyncFunction()
      setData(response)
      setStatus('success')
      return response
    } catch (error) {
      setError(error as E)
      setStatus('error')
      throw error
    }
  }, [asyncFunction])

  useEffect(() => {
    if (immediate) {
      execute()
    }
  }, [execute, immediate])

  return {
    execute,
    status,
    data,
    error,
    isIdle: status === 'idle',
    isPending: status === 'pending',
    isSuccess: status === 'success',
    isError: status === 'error',
  }
}

/**
 * Hook for managing previous value
 */
export function usePrevious<T>(value: T): T | undefined {
  const ref = useRef<T | undefined>(undefined)
  
  useEffect(() => {
    ref.current = value
  })
  
  return ref.current
}

/**
 * Hook for detecting when component is mounted
 */
export function useIsMounted(): boolean {
  const [isMounted, setIsMounted] = useState(false)

  useEffect(() => {
    setIsMounted(true)
    return () => setIsMounted(false)
  }, [])

  return isMounted
}

/**
 * Hook for copying text to clipboard
 */
export function useClipboard(): {
  copy: (text: string) => Promise<boolean>
  isSupported: boolean
} {
  const isSupported = typeof navigator !== 'undefined' && 'clipboard' in navigator

  const copy = useCallback(async (text: string): Promise<boolean> => {
    if (!isSupported) {
      console.warn('Clipboard API not supported')
      return false
    }

    try {
      await navigator.clipboard.writeText(text)
      return true
    } catch (error) {
      console.warn('Failed to copy text to clipboard:', error)
      return false
    }
  }, [isSupported])

  return { copy, isSupported }
}

/**
 * Hook for managing toggle state
 */
export function useToggle(
  initialValue = false
): [boolean, () => void, (value?: boolean) => void] {
  const [value, setValue] = useState(initialValue)

  const toggle = useCallback(() => {
    setValue(v => !v)
  }, [])

  const setToggle = useCallback((value?: boolean) => {
    setValue(value ?? (v => !v))
  }, [])

  return [value, toggle, setToggle]
}

/**
 * Hook for managing counter state
 */
export function useCounter(
  initialValue = 0
): {
  count: number
  increment: () => void
  decrement: () => void
  reset: () => void
  set: (value: number) => void
} {
  const [count, setCount] = useState(initialValue)

  const increment = useCallback(() => setCount(v => v + 1), [])
  const decrement = useCallback(() => setCount(v => v - 1), [])
  const reset = useCallback(() => setCount(initialValue), [initialValue])
  const set = useCallback((value: number) => setCount(value), [])

  return { count, increment, decrement, reset, set }
}

/**
 * Hook for detecting media query matches
 */
export function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(false)

  useEffect(() => {
    if (typeof window === 'undefined') return

    const media = window.matchMedia(query)
    
    if (media.matches !== matches) {
      setMatches(media.matches)
    }

    const listener = () => setMatches(media.matches)
    media.addListener(listener)
    
    return () => media.removeListener(listener)
  }, [matches, query])

  return matches
}

/**
 * Hook for detecting mobile devices
 */
export function useIsMobile(): boolean {
  return useMediaQuery("(max-width: 768px)")
}

// Re-export specialized hooks
export { useLLM } from './useLLM'
export { useApprovalWorkflow } from './useApprovalWorkflow'
export { useAISuggestions } from './useAISuggestions'
export { useJourneyPersistence } from './useJourneyPersistence'