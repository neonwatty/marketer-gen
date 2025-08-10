/**
 * Format a number as currency
 */
export const formatCurrency = (
  amount: number,
  currency = 'USD',
  locale = 'en-US'
): string => {
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
  }).format(amount)
}

/**
 * Format a number with thousand separators
 */
export const formatNumber = (
  num: number,
  locale = 'en-US'
): string => {
  return new Intl.NumberFormat(locale).format(num)
}

/**
 * Format a number as a percentage
 */
export const formatPercentage = (
  num: number,
  decimals = 0,
  locale = 'en-US'
): string => {
  return new Intl.NumberFormat(locale, {
    style: 'percent',
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(num / 100)
}

/**
 * Format file size in human readable format
 */
export const formatFileSize = (bytes: number): string => {
  if (bytes === 0) return '0 Bytes'
  
  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`
}

/**
 * Format duration in milliseconds to human readable format
 */
export const formatDuration = (ms: number): string => {
  const seconds = Math.floor(ms / 1000)
  const minutes = Math.floor(seconds / 60)
  const hours = Math.floor(minutes / 60)
  const days = Math.floor(hours / 24)
  
  if (days > 0) {
    return `${days}d ${hours % 24}h`
  } else if (hours > 0) {
    return `${hours}h ${minutes % 60}m`
  } else if (minutes > 0) {
    return `${minutes}m ${seconds % 60}s`
  } else {
    return `${seconds}s`
  }
}

/**
 * Format a date to a relative time string (e.g., "2 hours ago")
 */
export const formatRelativeTime = (date: Date | string, locale = 'en-US'): string => {
  const now = new Date()
  const targetDate = typeof date === 'string' ? new Date(date) : date
  const diffMs = now.getTime() - targetDate.getTime()
  
  const rtf = new Intl.RelativeTimeFormat(locale, { numeric: 'auto' })
  
  const diffSeconds = Math.floor(diffMs / 1000)
  const diffMinutes = Math.floor(diffSeconds / 60)
  const diffHours = Math.floor(diffMinutes / 60)
  const diffDays = Math.floor(diffHours / 24)
  const diffWeeks = Math.floor(diffDays / 7)
  const diffMonths = Math.floor(diffDays / 30)
  const diffYears = Math.floor(diffDays / 365)
  
  if (diffYears > 0) {
    return rtf.format(-diffYears, 'year')
  } else if (diffMonths > 0) {
    return rtf.format(-diffMonths, 'month')
  } else if (diffWeeks > 0) {
    return rtf.format(-diffWeeks, 'week')
  } else if (diffDays > 0) {
    return rtf.format(-diffDays, 'day')
  } else if (diffHours > 0) {
    return rtf.format(-diffHours, 'hour')
  } else if (diffMinutes > 0) {
    return rtf.format(-diffMinutes, 'minute')
  } else {
    return rtf.format(-diffSeconds, 'second')
  }
}

/**
 * Format a date to a specific format
 */
export const formatDate = (
  date: Date | string,
  options: Intl.DateTimeFormatOptions = {},
  locale = 'en-US'
): string => {
  const targetDate = typeof date === 'string' ? new Date(date) : date
  
  const defaultOptions: Intl.DateTimeFormatOptions = {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  }
  
  return new Intl.DateTimeFormat(locale, { ...defaultOptions, ...options }).format(targetDate)
}

/**
 * Format a date to ISO string (for API usage)
 */
export const formatDateISO = (date: Date | string): string => {
  const targetDate = typeof date === 'string' ? new Date(date) : date
  return targetDate.toISOString()
}

/**
 * Format a phone number
 */
export const formatPhoneNumber = (phone: string): string => {
  // Remove all non-digit characters
  const cleaned = phone.replace(/\D/g, '')
  
  // Check if the input is of correct length
  const match = cleaned.match(/^(\d{3})(\d{3})(\d{4})$/)
  
  if (match) {
    return `(${match[1]}) ${match[2]}-${match[3]}`
  }
  
  return phone // Return original if it doesn't match expected format
}

/**
 * Format text to title case
 */
export const formatTitleCase = (text: string): string => {
  return text
    .toLowerCase()
    .split(' ')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ')
}

/**
 * Format text to sentence case
 */
export const formatSentenceCase = (text: string): string => {
  if (!text) return text
  return text.charAt(0).toUpperCase() + text.slice(1).toLowerCase()
}

/**
 * Format a URL to display format (remove protocol, www, trailing slash)
 */
export const formatDisplayUrl = (url: string): string => {
  try {
    const urlObj = new URL(url)
    let hostname = urlObj.hostname
    
    // Remove www. prefix
    if (hostname.startsWith('www.')) {
      hostname = hostname.slice(4)
    }
    
    // Add path if it exists and is not just "/"
    let path = urlObj.pathname
    if (path !== '/') {
      // Remove trailing slash
      path = path.replace(/\/$/, '')
      hostname += path
    }
    
    return hostname
  } catch {
    return url // Return original if URL is invalid
  }
}

/**
 * Format text for search highlighting
 */
export const highlightSearchTerm = (text: string, searchTerm: string): string => {
  if (!searchTerm) return text
  
  const regex = new RegExp(`(${searchTerm})`, 'gi')
  return text.replace(regex, '<mark>$1</mark>')
}

/**
 * Format initials from a name
 */
export const formatInitials = (name: string, maxLength = 2): string => {
  return name
    .split(' ')
    .map(word => word.charAt(0))
    .join('')
    .toUpperCase()
    .slice(0, maxLength)
}

/**
 * Format a list of items as a grammatically correct string
 */
export const formatList = (items: string[], conjunction = 'and'): string => {
  if (items.length === 0) return ''
  if (items.length === 1) return items[0] ?? ''
  if (items.length === 2) return `${items[0] ?? ''} ${conjunction} ${items[1] ?? ''}`
  
  const lastItem = items[items.length - 1] ?? ''
  const otherItems = items.slice(0, -1).join(', ')
  
  return `${otherItems}, ${conjunction} ${lastItem}`
}