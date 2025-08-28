'use client'

import { useEffect, useRef,useState } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'

import { Menu, X } from 'lucide-react'

import { Button } from '@/components/ui/button'
import { isActiveLink,publicNavigationItems } from '@/config/navigation'

import { UserMenu } from '../auth/UserMenu'

interface HeaderProps {
  className?: string
}

export function Header({ className }: HeaderProps) {
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false)
  const pathname = usePathname()
  const mobileMenuRef = useRef<HTMLDivElement>(null)
  const mobileButtonRef = useRef<HTMLButtonElement>(null)


  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && isMobileMenuOpen) {
        setIsMobileMenuOpen(false)
        mobileButtonRef.current?.focus()
      }
    }

    const handleClickOutside = (event: MouseEvent) => {
      if (
        isMobileMenuOpen &&
        mobileMenuRef.current &&
        !mobileMenuRef.current.contains(event.target as Node) &&
        !mobileButtonRef.current?.contains(event.target as Node)
      ) {
        setIsMobileMenuOpen(false)
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    document.addEventListener('mousedown', handleClickOutside)

    return () => {
      document.removeEventListener('keydown', handleKeyDown)
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [isMobileMenuOpen])

  useEffect(() => {
    setIsMobileMenuOpen(false)
  }, [pathname])


  const closeMobileMenu = () => {
    setIsMobileMenuOpen(false)
  }

  return (
    <header 
      className={`bg-background border-b border-border ${className || ''}`}
      role="banner"
    >
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center py-4">
          {/* Logo */}
          <div className="flex items-center">
            <Link 
              href="/" 
              className="text-xl font-bold text-foreground focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 rounded-md px-2 py-1"
              aria-label="Marketer Gen - Go to homepage"
            >
              Marketer Gen
            </Link>
          </div>

          {/* Desktop Navigation */}
          <nav 
            className="hidden md:flex items-center space-x-6" 
            role="navigation" 
            aria-label="Main navigation"
          >
            {publicNavigationItems.map((item) => (
              <Link
                key={item.name}
                href={item.href}
                className={`text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 rounded-md px-3 py-2 ${
                  isActiveLink(pathname, item.href)
                    ? 'text-foreground bg-muted'
                    : 'text-muted-foreground hover:text-foreground hover:bg-muted'
                }`}
                aria-current={isActiveLink(pathname, item.href) ? 'page' : undefined}
              >
                {item.name}
              </Link>
            ))}
          </nav>

          {/* Desktop User Menu */}
          <div className="hidden md:flex items-center">
            <UserMenu />
          </div>

          {/* Mobile menu button */}
          <div className="md:hidden flex items-center space-x-2">
            <UserMenu />
            <Button
              ref={mobileButtonRef}
              variant="ghost"
              size="sm"
              onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
              aria-expanded={isMobileMenuOpen}
              aria-controls="mobile-menu"
              aria-label={isMobileMenuOpen ? 'Close mobile menu' : 'Open mobile menu'}
              className="focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2"
            >
              {isMobileMenuOpen ? (
                <X className="w-4 h-4" aria-hidden="true" />
              ) : (
                <Menu className="w-4 h-4" aria-hidden="true" />
              )}
            </Button>
          </div>
        </div>
      </div>

      {/* Mobile Navigation */}
      {isMobileMenuOpen && (
        <div 
          ref={mobileMenuRef}
          id="mobile-menu"
          className="md:hidden border-t border-border"
          role="navigation"
          aria-label="Mobile navigation"
        >
          <div className="px-2 pt-2 pb-3 space-y-1">
            {publicNavigationItems.map((item) => (
              <Link
                key={item.name}
                href={item.href}
                className={`block px-3 py-2 text-base font-medium transition-colors rounded-md focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 ${
                  isActiveLink(pathname, item.href)
                    ? 'text-foreground bg-muted'
                    : 'text-muted-foreground hover:text-foreground hover:bg-muted'
                }`}
                onClick={closeMobileMenu}
                aria-current={isActiveLink(pathname, item.href) ? 'page' : undefined}
              >
                {item.name}
              </Link>
            ))}
          </div>
        </div>
      )}
    </header>
  )
}