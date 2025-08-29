'use client'

import { createContext, type ReactNode,useContext, useState } from 'react'
import { useSession, signIn as nextAuthSignIn } from 'next-auth/react'

import { type User } from '@/lib/types'

interface AuthContextType {
  user: User | null
  isAuthenticated: boolean
  isLoading: boolean
  error: string | null
  signIn: (email: string, password: string) => Promise<void>
  signUp: (name: string, email: string, password: string) => Promise<void>
  signOut: () => Promise<void>
  clearError: () => void
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

interface AuthProviderProps {
  children: ReactNode
}

export function AuthProvider({ children }: AuthProviderProps) {
  const { data: session, status } = useSession()
  const [error, setError] = useState<string | null>(null)
  
  // Convert NextAuth session to our User type
  const user: User | null = session?.user ? {
    id: (session.user as any).id || '',
    email: session.user.email || '',
    name: session.user.name || '',
    avatar: session.user.image || undefined,
    role: (session.user as any).role || 'user',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  } : null

  const isAuthenticated = !!session && !!user
  const isLoading = status === 'loading'

  // Placeholder auth methods - these will be properly implemented when auth is activated
  const signIn = async (email: string, password: string) => {
    try {
      setError(null)
      // Placeholder implementation
      console.log('Sign in attempted with:', { email, password })
      
      // In the future, this will use NextAuth signIn
      // const result = await signIn('credentials', { email, password, redirect: false })
      // if (result?.error) {
      //   setError(result.error)
      //   throw new Error(result.error)
      // }
      
      // For now, just log the attempt
      setError('Authentication is not currently active. This is a placeholder implementation.')
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Sign in failed'
      setError(message)
      throw new Error(message)
    }
  }

  const signUp = async (name: string, email: string, password: string) => {
    try {
      setError(null)
      // Placeholder implementation
      console.log('Sign up attempted with:', { name, email, password })
      
      // In the future, this will create a user account
      // const response = await fetch('/api/auth/signup', {
      //   method: 'POST',
      //   headers: { 'Content-Type': 'application/json' },
      //   body: JSON.stringify({ name, email, password }),
      // })
      // if (!response.ok) {
      //   throw new Error('Sign up failed')
      // }
      
      // For now, just log the attempt
      setError('Authentication is not currently active. This is a placeholder implementation.')
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Sign up failed'
      setError(message)
      throw new Error(message)
    }
  }

  const signOut = async () => {
    try {
      setError(null)
      // Placeholder implementation
      console.log('Sign out attempted')
      
      // In the future, this will use NextAuth signOut
      // await nextAuthSignOut({ redirect: false })
      
      // For now, just log the attempt
      setError('Authentication is not currently active. This is a placeholder implementation.')
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Sign out failed'
      setError(message)
      throw new Error(message)
    }
  }

  const clearError = () => {
    setError(null)
  }

  const value: AuthContextType = {
    user,
    isAuthenticated,
    isLoading,
    error,
    signIn,
    signUp,
    signOut,
    clearError,
  }

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth(): AuthContextType {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}

// Additional hook for protected routes (placeholder implementation)
export function useRequireAuth(): User {
  const { user, isAuthenticated, isLoading } = useAuth()
  
  // In a real implementation, this would redirect to login if not authenticated
  // For now, it just returns a placeholder user or the current user
  if (!isAuthenticated && !isLoading) {
    // Would redirect to /auth/signin in production
    console.log('User not authenticated, would redirect to login')
  }
  
  return user || {
    id: 'placeholder',
    email: 'demo@example.com',
    name: 'Demo User',
    role: 'user',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  }
}