'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

import { BarChart3, Settings } from 'lucide-react'

import { Button } from '@/components/ui/button'
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarRail,
} from '@/components/ui/sidebar'
import { dashboardNavigationItems, isActiveLink,quickActions } from '@/config/navigation'

/**
 * Dashboard sidebar with navigation and responsive design
 * WCAG 2.1 compliant with keyboard navigation and screen reader support
 * Enhanced with collapsible functionality and user preference persistence
 */
export function DashboardSidebar() {
  const pathname = usePathname()

  return (
    <Sidebar 
      variant="inset" 
      collapsible="icon"
      className="lg:flex hidden md:flex"
      aria-label="Dashboard navigation sidebar"
    >
      <SidebarHeader className="border-b border-sidebar-border">
        <div className="flex items-center gap-2 px-4 py-2" role="banner">
          <div 
            className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary text-primary-foreground"
            aria-hidden="true"
          >
            <BarChart3 className="h-4 w-4" />
          </div>
          <div className="flex flex-col">
            <span className="text-sm font-semibold">Marketer Gen</span>
            <span className="text-xs text-muted-foreground">Dashboard</span>
          </div>
        </div>
      </SidebarHeader>

      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel>Navigation</SidebarGroupLabel>
          <SidebarGroupContent role="navigation" aria-label="Dashboard main navigation">
            <SidebarMenu>
              {dashboardNavigationItems.map((item) => {
                const isActive = isActiveLink(pathname, item.href)
                
                return (
                  <SidebarMenuItem key={item.href}>
                    <SidebarMenuButton asChild isActive={isActive}>
                      <Link 
                        href={item.href}
                        aria-current={isActive ? 'page' : undefined}
                        aria-label={`${item.title} - Navigate to ${item.title.toLowerCase()} page`}
                        className="focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 rounded-md"
                      >
                        {item.icon && (
                          <item.icon 
                            className="h-4 w-4" 
                            aria-hidden="true"
                          />
                        )}
                        <span>{item.title}</span>
                      </Link>
                    </SidebarMenuButton>
                  </SidebarMenuItem>
                )
              })}
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>

        <SidebarGroup>
          <SidebarGroupLabel>Quick Actions</SidebarGroupLabel>
          <SidebarGroupContent role="navigation" aria-label="Quick action shortcuts">
            <SidebarMenu>
              {quickActions.map((action) => (
                <SidebarMenuItem key={action.href}>
                  <SidebarMenuButton asChild>
                    <Link 
                      href={action.href}
                      aria-label={`${action.name} - Quick action`}
                      className="focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 rounded-md"
                    >
                      <action.icon 
                        className="h-4 w-4" 
                        aria-hidden="true"
                      />
                      <span>{action.name}</span>
                    </Link>
                  </SidebarMenuButton>
                </SidebarMenuItem>
              ))}
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>

      <SidebarFooter className="border-t border-sidebar-border">
        <div className="p-4">
          <Button 
            variant="outline" 
            size="sm" 
            className="w-full justify-start focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2"
            aria-label="Open account settings"
          >
            <Settings 
              className="h-4 w-4 mr-2" 
              aria-hidden="true"
            />
            Account Settings
          </Button>
        </div>
      </SidebarFooter>

      <SidebarRail />
    </Sidebar>
  )
}