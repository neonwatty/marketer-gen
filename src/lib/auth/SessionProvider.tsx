'use client'

import { SessionProvider as NextAuthSessionProvider } from 'next-auth/react'

import type { ReactNode } from 'react'

interface SessionProviderProps {
  children: ReactNode
}

export function SessionProvider({ children }: SessionProviderProps) {
  return (
    <NextAuthSessionProvider
      // Enable session management for proper authentication
      refetchInterval={5 * 60} // Refetch session every 5 minutes
      refetchOnWindowFocus={true} // Refetch on window focus
    >
      {children}
    </NextAuthSessionProvider>
  )
}