import { 
  BarChart3, 
  FolderOpen, 
  GitBranch,  Home, 
  type LucideIcon, 
  Megaphone, 
  Plus, 
  Settings, 
  Users} from 'lucide-react'

export interface NavigationItem {
  name: string
  title: string
  href: string
  icon?: LucideIcon
}

export interface QuickAction {
  name: string
  href: string
  icon: LucideIcon
}

export const mainNavigationItems: NavigationItem[] = [
  { name: 'Dashboard', title: 'Overview', href: '/dashboard', icon: Home },
  { name: 'Journeys', title: 'Journeys', href: '/dashboard/journeys', icon: GitBranch },
  { name: 'Campaigns', title: 'Campaigns', href: '/dashboard/campaigns', icon: Megaphone },
  { name: 'Analytics', title: 'Analytics', href: '/dashboard/analytics', icon: BarChart3 },
  { name: 'Content', title: 'Audience', href: '/dashboard/audience', icon: Users },
]

export const publicNavigationItems: NavigationItem[] = [
  { name: 'Dashboard', title: 'Dashboard', href: '/' },
  { name: 'Campaigns', title: 'Campaigns', href: '/campaigns' },
  { name: 'Analytics', title: 'Analytics', href: '/analytics' },
  { name: 'Content', title: 'Content', href: '/content' },
]

export const dashboardNavigationItems: NavigationItem[] = [
  { name: 'Overview', title: 'Overview', href: '/dashboard', icon: Home },
  { name: 'Journeys', title: 'Journeys', href: '/dashboard/journeys', icon: GitBranch },
  { name: 'Campaigns', title: 'Campaigns', href: '/dashboard/campaigns', icon: Megaphone },
  { name: 'Analytics', title: 'Analytics', href: '/dashboard/analytics', icon: BarChart3 },
  { name: 'Audience', title: 'Audience', href: '/dashboard/audience', icon: Users },
  { name: 'Templates', title: 'Templates', href: '/dashboard/templates', icon: FolderOpen },
  { name: 'Settings', title: 'Settings', href: '/dashboard/settings', icon: Settings },
]

export const quickActions: QuickAction[] = [
  { name: 'New Journey', href: '/dashboard/journeys/new', icon: Plus },
  { name: 'New Campaign', href: '/dashboard/campaigns/new', icon: Plus },
]

export function isActiveLink(pathname: string, href: string): boolean {
  if (href === '/dashboard' || href === '/') {
    return pathname === href
  }
  return pathname.startsWith(href)
}