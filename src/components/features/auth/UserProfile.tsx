'use client'

import Image from 'next/image'

import { User as UserIcon } from 'lucide-react'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { type User } from '@/lib/types'

interface UserProfileProps {
  user?: User
  isLoading?: boolean
  onEdit?: () => void
  onSignOut?: () => void
}

const roleColors = {
  user: 'default',
  admin: 'destructive',
  moderator: 'secondary',
} as const

export function UserProfile({ user, isLoading = false, onEdit, onSignOut }: UserProfileProps) {
  // Placeholder user data when no user is provided
  const displayUser = user || {
    id: 'placeholder',
    name: 'Demo User',
    email: 'demo@example.com',
    role: 'user' as const,
    avatar: undefined,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  }

  if (isLoading) {
    return (
      <Card className="w-full max-w-md">
        <CardHeader>
          <div className="flex items-center space-x-4">
            <div className="w-16 h-16 bg-muted rounded-full animate-pulse" />
            <div className="space-y-2">
              <div className="h-4 bg-muted rounded animate-pulse w-24" />
              <div className="h-3 bg-muted rounded animate-pulse w-32" />
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="h-4 bg-muted rounded animate-pulse w-full" />
            <div className="h-4 bg-muted rounded animate-pulse w-3/4" />
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card className="w-full max-w-md">
      <CardHeader>
        <div className="flex items-center space-x-4">
          {displayUser.avatar ? (
            <Image
              src={displayUser.avatar}
              alt={displayUser.name || 'User avatar'}
              width={64}
              height={64}
              className="w-16 h-16 rounded-full object-cover"
            />
          ) : (
            <div className="w-16 h-16 bg-muted rounded-full flex items-center justify-center">
              <UserIcon className="w-8 h-8 text-muted-foreground" />
            </div>
          )}
          <div>
            <CardTitle className="text-xl">
              {displayUser.name || 'Anonymous User'}
            </CardTitle>
            <CardDescription>{displayUser.email}</CardDescription>
            <div className="mt-2">
              <Badge variant={roleColors[displayUser.role]}>
                {displayUser.role}
              </Badge>
            </div>
          </div>
        </div>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <p className="font-medium text-muted-foreground">Email Status</p>
              <p className="text-orange-600">
                Unverified
              </p>
            </div>
            <div>
              <p className="font-medium text-muted-foreground">Member Since</p>
              <p>
                {new Date(displayUser.createdAt).toLocaleDateString() || 'N/A'}
              </p>
            </div>
          </div>
          
          <div className="flex gap-2 pt-4 border-t">
            <Button variant="outline" className="flex-1" onClick={onEdit}>
              Edit Profile
            </Button>
            <Button variant="ghost" onClick={onSignOut}>
              Sign Out
            </Button>
          </div>
        </div>
        
        {!user && (
          <div className="mt-4 p-4 bg-muted/50 rounded-lg">
            <p className="text-xs text-muted-foreground text-center">
              This is a placeholder profile. Authentication is not currently active.
            </p>
          </div>
        )}
      </CardContent>
    </Card>
  )
}