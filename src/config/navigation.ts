import { 
  BarChart3, 
  Brain,
  FolderOpen, 
  GitBranch,  
  Home, 
  type LucideIcon, 
  Megaphone, 
  Plus, 
  Settings, 
  ShieldCheck,
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
  { name: 'Brands', title: 'Brands', href: '/dashboard/brands', icon: ShieldCheck },
  { name: 'AI Content', title: 'AI Content', href: '/dashboard/content/ai-generator', icon: Brain },
  { name: 'Brand Compliance', title: 'Brand Compliance', href: '/dashboard/brands/compliance', icon: ShieldCheck },
  { name: 'Analytics', title: 'Analytics', href: '/dashboard/analytics', icon: BarChart3 },
  { name: 'Audience', title: 'Audience', href: '/dashboard/audience', icon: Users },
  { name: 'Templates', title: 'Templates', href: '/dashboard/templates', icon: FolderOpen },
  { name: 'Settings', title: 'Settings', href: '/dashboard/settings', icon: Settings },
]

export const quickActions: QuickAction[] = [
  { name: 'New Journey', href: '/dashboard/journeys/new', icon: Plus },
  { name: 'Generate AI Content', href: '/dashboard/content/ai-generator', icon: Brain },
]

export function isActiveLink(pathname: string, href: string): boolean {
  if (href === '/dashboard' || href === '/') {
    return pathname === href
  }
  return pathname.startsWith(href)
}