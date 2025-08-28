'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

import {
  Breadcrumb,
  BreadcrumbEllipsis,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from '@/components/ui/breadcrumb'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'

interface BreadcrumbItem {
  label: string
  href?: string
}

interface DashboardBreadcrumbProps {
  items?: BreadcrumbItem[]
  className?: string
  maxItems?: number
  showHome?: boolean
}

/**
 * Breadcrumb navigation component for dashboard pages
 * Enhanced with responsive design, state management, and accessibility
 */
export function DashboardBreadcrumb({ 
  items, 
  className, 
  maxItems = 3,
  showHome = true 
}: DashboardBreadcrumbProps) {
  const pathname = usePathname()

  // Auto-generate breadcrumbs from pathname if items not provided
  const breadcrumbItems = items || generateBreadcrumbsFromPath(pathname, showHome)
  
  if (!breadcrumbItems.length) return null

  const lastItemIndex = breadcrumbItems.length - 1

  // Handle responsive collapsing for mobile
  const shouldCollapse = breadcrumbItems.length > maxItems
  const visibleItems = shouldCollapse 
    ? [
        ...breadcrumbItems.slice(0, 1),
        ...breadcrumbItems.slice(-(maxItems - 2))
      ]
    : breadcrumbItems
  
  const hiddenItems = shouldCollapse 
    ? breadcrumbItems.slice(1, -(maxItems - 2))
    : []

  return (
    <Breadcrumb className={className} aria-label="Page navigation breadcrumbs">
      <BreadcrumbList>
        {shouldCollapse ? (
          <>
            {/* First item */}
            <BreadcrumbItem>
              <BreadcrumbLink asChild>
                <Link 
                  href={breadcrumbItems[0].href || '/'}
                  className="focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 rounded-md"
                >
                  {breadcrumbItems[0].label}
                </Link>
              </BreadcrumbLink>
            </BreadcrumbItem>
            <BreadcrumbSeparator />

            {/* Collapsed items dropdown */}
            {hiddenItems.length > 0 && (
              <>
                <BreadcrumbItem>
                  <DropdownMenu>
                    <DropdownMenuTrigger 
                      className="flex h-9 w-9 items-center justify-center focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 rounded-md"
                      aria-label={`Show ${hiddenItems.length} hidden navigation items`}
                    >
                      <BreadcrumbEllipsis className="h-4 w-4" />
                      <span className="sr-only">Toggle breadcrumb menu</span>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="start">
                      {hiddenItems.map((item, index) => (
                        <DropdownMenuItem key={index} asChild>
                          <Link 
                            href={item.href || '#'}
                            className="focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 rounded-md"
                          >
                            {item.label}
                          </Link>
                        </DropdownMenuItem>
                      ))}
                    </DropdownMenuContent>
                  </DropdownMenu>
                </BreadcrumbItem>
                <BreadcrumbSeparator />
              </>
            )}

            {/* Last items */}
            {visibleItems.slice(1).map((item, index) => {
              const actualIndex = index + 1 + (breadcrumbItems.length - visibleItems.length + 1)
              const isLast = actualIndex === lastItemIndex
              
              return (
                <div key={actualIndex} className="flex items-center">
                  <BreadcrumbItem>
                    {isLast ? (
                      <BreadcrumbPage className="font-medium text-foreground">
                        {item.label}
                      </BreadcrumbPage>
                    ) : item.href ? (
                      <BreadcrumbLink asChild>
                        <Link 
                          href={item.href}
                          className="focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 rounded-md"
                        >
                          {item.label}
                        </Link>
                      </BreadcrumbLink>
                    ) : (
                      <span className="text-muted-foreground">{item.label}</span>
                    )}
                  </BreadcrumbItem>
                  {!isLast && <BreadcrumbSeparator />}
                </div>
              )
            })}
          </>
        ) : (
          // Non-collapsed items
          breadcrumbItems.map((item, index) => {
            const isLast = index === lastItemIndex
            
            return (
              <div key={index} className="flex items-center">
                <BreadcrumbItem>
                  {isLast ? (
                    <BreadcrumbPage className="font-medium text-foreground">
                      {item.label}
                    </BreadcrumbPage>
                  ) : item.href ? (
                    <BreadcrumbLink asChild>
                      <Link 
                        href={item.href}
                        className="focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 rounded-md"
                      >
                        {item.label}
                      </Link>
                    </BreadcrumbLink>
                  ) : (
                    <span className="text-muted-foreground">{item.label}</span>
                  )}
                </BreadcrumbItem>
                {!isLast && <BreadcrumbSeparator />}
              </div>
            )
          })
        )}
      </BreadcrumbList>
    </Breadcrumb>
  )
}

/**
 * Generate breadcrumbs from the current pathname
 */
function generateBreadcrumbsFromPath(pathname: string, showHome: boolean): BreadcrumbItem[] {
  const segments = pathname.split('/').filter(Boolean)
  const breadcrumbs: BreadcrumbItem[] = []

  if (showHome) {
    breadcrumbs.push({ label: 'Dashboard', href: '/dashboard' })
  }

  let path = ''
  segments.forEach((segment, index) => {
    path += `/${segment}`
    
    // Skip the first 'dashboard' segment if showHome is true
    if (showHome && segment === 'dashboard' && index === 0) {
      return
    }

    const label = formatSegmentLabel(segment)
    const href = index === segments.length - 1 ? undefined : path
    
    breadcrumbs.push({ label, href })
  })

  return breadcrumbs
}

/**
 * Format a URL segment into a readable label
 */
function formatSegmentLabel(segment: string): string {
  return segment
    .split('-')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ')
}