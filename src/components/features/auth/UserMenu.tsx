'use client'

import Image from 'next/image'

import { ChevronDown, User as UserIcon } from 'lucide-react'

import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import { useAuth } from '@/lib/auth/AuthContext'

import { UserProfile } from './UserProfile'

interface UserMenuProps {
  className?: string
}

export function UserMenu({ className }: UserMenuProps) {
  const { user, isAuthenticated, isLoading, signOut } = useAuth()

  if (isLoading) {
    return (
      <div className={`flex items-center gap-2 ${className || ''}`}>
        <div className="w-8 h-8 bg-muted rounded-full animate-pulse" />
        <div className="hidden md:block">
          <div className="h-4 bg-muted rounded animate-pulse w-20" />
        </div>
      </div>
    )
  }

  if (!isAuthenticated) {
    return (
      <div className={`flex items-center gap-2 ${className || ''}`}>
        <Button variant="ghost" size="sm" asChild>
          <a href="/auth/signin">Sign in</a>
        </Button>
        <Button size="sm" asChild>
          <a href="/auth/signup">Sign up</a>
        </Button>
      </div>
    )
  }

  const displayUser = user || {
    id: 'demo',
    name: 'Demo User',
    email: 'demo@example.com',
    role: 'user' as const,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  }

  return (
    <div className={`flex items-center gap-2 ${className || ''}`}>
      <Dialog>
        <DialogTrigger asChild data-testid="dialog-trigger">
          <Button variant="ghost" className="flex items-center gap-2 h-auto px-2 py-1">
            <div className="w-8 h-8 bg-muted rounded-full flex items-center justify-center">
              {displayUser.avatar ? (
                <Image
                  src={displayUser.avatar}
                  alt={displayUser.name || 'User avatar'}
                  width={32}
                  height={32}
                  className="w-full h-full rounded-full object-cover"
                />
              ) : (
                <UserIcon className="w-4 h-4 text-muted-foreground" />
              )}
            </div>
            <div className="hidden md:block text-left">
              <p className="text-sm font-medium leading-none">
                {displayUser.name || 'User'}
              </p>
              <p className="text-xs text-muted-foreground mt-0.5">
                {displayUser.email}
              </p>
            </div>
            <ChevronDown className="w-4 h-4 text-muted-foreground" />
          </Button>
        </DialogTrigger>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>User Profile</DialogTitle>
            <DialogDescription>
              Manage your account settings and preferences.
            </DialogDescription>
          </DialogHeader>
          <UserProfile
            user={displayUser}
            onEdit={() => {/* TODO: Implement edit profile functionality */}}
            onSignOut={async () => {
              try {
                await signOut()
              } catch (error) {
                console.error('Sign out error:', error)
                // Component remains functional even if sign out fails
              }
            }}
          />
        </DialogContent>
      </Dialog>
    </div>
  )
}