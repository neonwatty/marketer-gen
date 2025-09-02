'use client'

import { Bell, Search, User } from 'lucide-react'

import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Input } from '@/components/ui/input'
import { SidebarTrigger } from '@/components/ui/sidebar'

/**
 * Dashboard header with navigation, search, and user menu
 * WCAG 2.1 compliant with keyboard navigation and screen reader support
 */
export function DashboardHeader() {
  return (
    <div 
      className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60"
    >
      <div className="flex h-14 items-center px-4">
        {/* Mobile sidebar trigger */}
        <div className="flex items-center gap-2 md:gap-4">
          <SidebarTrigger 
            className="md:hidden focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2" 
            aria-label="Toggle sidebar navigation"
          />
          
          {/* Search */}
          <div className="relative hidden md:flex">
            <Search 
              className="absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" 
              aria-hidden="true"
            />
            <Input
              type="search"
              placeholder="Search campaigns..."
              className="w-64 pl-9 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2"
              aria-label="Search campaigns"
            />
          </div>
        </div>

        {/* Spacer */}
        <div className="flex-1" />

        {/* Right side actions */}
        <div className="flex items-center gap-2" role="toolbar" aria-label="Dashboard actions">
          {/* Mobile search button */}
          <Button 
            variant="ghost" 
            size="icon" 
            className="md:hidden focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2"
            aria-label="Open search"
          >
            <Search className="h-4 w-4" aria-hidden="true" />
            <span className="sr-only">Search</span>
          </Button>

          {/* Notifications */}
          <Button 
            variant="ghost" 
            size="icon" 
            className="relative focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2"
            aria-label="View notifications (3 new)"
            aria-describedby="notification-count"
          >
            <Bell className="h-4 w-4" aria-hidden="true" />
            <Badge 
              id="notification-count"
              variant="destructive" 
              className="absolute -top-1 -right-1 h-5 w-5 rounded-full p-0 text-xs"
              aria-live="polite"
            >
              3
            </Badge>
            <span className="sr-only">Notifications</span>
          </Button>

          {/* User menu */}
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button 
                variant="ghost" 
                className="relative h-8 w-8 rounded-full focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2"
                aria-label="Open user menu - Demo User"
                aria-haspopup="menu"
              >
                <Avatar className="h-8 w-8">
                  <AvatarImage src="/placeholder-avatar.svg" alt="Demo User profile picture" />
                  <AvatarFallback>
                    <User className="h-4 w-4" aria-hidden="true" />
                  </AvatarFallback>
                </Avatar>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent 
              className="w-56" 
              align="end" 
              forceMount
              role="menu"
              aria-label="User account menu"
            >
              <DropdownMenuLabel className="font-normal">
                <div className="flex flex-col space-y-1">
                  <p className="text-sm font-medium leading-none">Demo User</p>
                  <p className="text-xs leading-none text-muted-foreground">
                    demo@example.com
                  </p>
                </div>
              </DropdownMenuLabel>
              <DropdownMenuSeparator />
              <DropdownMenuItem role="menuitem">
                Profile Settings
              </DropdownMenuItem>
              <DropdownMenuItem role="menuitem">
                Billing
              </DropdownMenuItem>
              <DropdownMenuItem role="menuitem">
                Team
              </DropdownMenuItem>
              <DropdownMenuItem role="menuitem">
                Support
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem role="menuitem">
                Log out
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>
    </div>
  )
}