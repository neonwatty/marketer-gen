'use client'

import { SessionProvider as NextAuthSessionProvider } from 'next-auth/react'

import type { ReactNode } from 'react'

interface SessionProviderProps {
  children: ReactNode
}

export function SessionProvider({ children }: SessionProviderProps) {
  return (
    <NextAuthSessionProvider
      // Session configuration - currently allows the app to work without authentication
      session={null} // No initial session
      refetchInterval={0} // Disable session refetching
      refetchOnWindowFocus={false} // Disable refetch on window focus
    >
      {children}
    </NextAuthSessionProvider>
  )
}