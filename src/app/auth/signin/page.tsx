'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { getSession,signIn } from 'next-auth/react'

import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'

export default function SignInPage() {
  const [email, setEmail] = useState('demo@example.com')
  const [isLoading, setIsLoading] = useState(false)
  const router = useRouter()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setIsLoading(true)

    try {
      const result = await signIn('demo', {
        email,
        redirect: false,
      })

      if (result?.ok) {
        // Wait for session to be set
        const session = await getSession()
        if (session) {
          router.push('/dashboard')
        }
      } else {
        console.error('Sign in failed')
      }
    } catch (error) {
      console.error('Sign in error:', error)
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 px-4">
      <Card 
        className="w-full max-w-2xl" 
        style={{ maxWidth: '672px', width: '100%', minWidth: '320px' }}
      >
        <CardHeader>
          <CardTitle>Demo Sign In</CardTitle>
          <CardDescription>
            Development-only demo authentication. Use demo@example.com to sign in.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-gray-700">
                Email
              </label>
              <Input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="demo@example.com"
                required
                style={{ width: '100%', minWidth: '280px' }}
              />
            </div>
            <Button type="submit" className="w-full" disabled={isLoading}>
              {isLoading ? 'Signing in...' : 'Sign In'}
            </Button>
          </form>
          <p className="mt-4 text-xs text-gray-500 text-center">
            This is a development-only authentication system.
            <br />
            Use "demo@example.com" to access the application.
          </p>
        </CardContent>
      </Card>
    </div>
  )
}