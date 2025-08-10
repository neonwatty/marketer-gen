"use client"

import React from "react"
import Link from "next/link"
import { usePathname } from "next/navigation"
import {
  Home,
  PenTool,
  Target,
  FileText,
  BarChart,
  Settings,
  User,
  Search,
  Bell,
  Menu,
  X,
} from "lucide-react"

import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet"
import { Separator } from "@/components/ui/separator"
import { useIsMobile } from "@/hooks"

const navigationItems = [
  {
    title: "Dashboard",
    url: "/",
    icon: Home,
  },
  {
    title: "Generate Content",
    url: "/generate",
    icon: PenTool,
  },
  {
    title: "Campaigns",
    url: "/campaigns",
    icon: Target,
  },
  {
    title: "Templates",
    url: "/templates",
    icon: FileText,
  },
  {
    title: "Analytics",
    url: "/analytics",
    icon: BarChart,
  },
  {
    title: "Settings",
    url: "/settings",
    icon: Settings,
  },
]

interface HeaderProps {
  className?: string
}

export function Header({ className }: HeaderProps) {
  const pathname = usePathname()
  const isMobile = useIsMobile()
  const [isOpen, setIsOpen] = React.useState(false)

  return (
    <header className={`sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 ${className}`}>
      <div className="container flex h-14 items-center">
        {/* Logo */}
        <div className="mr-4 md:mr-6 flex items-center">
          <Link href="/" className="flex items-center gap-2">
            <div className="flex aspect-square size-8 items-center justify-center rounded-lg bg-primary text-primary-foreground">
              <PenTool className="size-4" />
            </div>
            <span className="hidden font-bold sm:inline-block">
              Marketer Gen
            </span>
          </Link>
        </div>

        {/* Desktop Navigation */}
        <nav className="hidden md:flex items-center gap-6 text-sm">
          {navigationItems.slice(0, 5).map((item) => (
            <Link
              key={item.url}
              href={item.url}
              className={`transition-colors hover:text-foreground/80 ${
                pathname === item.url
                  ? "text-foreground"
                  : "text-foreground/60"
              }`}
            >
              {item.title}
            </Link>
          ))}
        </nav>

        <div className="flex flex-1 items-center justify-between space-x-2 md:justify-end">
          {/* Search */}
          <div className="w-full flex-1 md:w-auto md:flex-none">
            <div className="relative">
              <Search className="absolute left-2.5 top-2.5 size-4 text-muted-foreground" />
              <Input
                type="search"
                placeholder="Search..."
                className="pl-8 md:w-[300px] lg:w-[400px]"
              />
            </div>
          </div>

          {/* Desktop Actions */}
          <nav className="hidden md:flex items-center gap-2">
            <Button variant="ghost" size="sm">
              <Bell className="size-4" />
              <span className="sr-only">Notifications</span>
            </Button>
            <Button variant="ghost" size="sm">
              <User className="size-4" />
              <span className="sr-only">User menu</span>
            </Button>
          </nav>

          {/* Mobile Menu */}
          <Sheet open={isOpen} onOpenChange={setIsOpen}>
            <SheetTrigger asChild className="md:hidden">
              <Button
                variant="ghost"
                className="ml-2 px-0 text-base hover:bg-transparent focus-visible:bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0"
                size="sm"
              >
                <Menu className="size-6" />
                <span className="sr-only">Toggle Menu</span>
              </Button>
            </SheetTrigger>
            <SheetContent side="left" className="pr-0">
              <SheetHeader>
                <SheetTitle className="flex items-center gap-2">
                  <div className="flex aspect-square size-6 items-center justify-center rounded-md bg-primary text-primary-foreground">
                    <PenTool className="size-3" />
                  </div>
                  Marketer Gen
                </SheetTitle>
                <SheetDescription>
                  AI-powered marketing content generator
                </SheetDescription>
              </SheetHeader>
              
              <div className="my-4 h-[calc(100vh-8rem)] pb-10 pl-6">
                <div className="flex flex-col space-y-3">
                  {navigationItems.map((item) => (
                    <Link
                      key={item.url}
                      href={item.url}
                      onClick={() => setIsOpen(false)}
                      className={`flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-all hover:bg-accent ${
                        pathname === item.url
                          ? "bg-accent text-accent-foreground"
                          : "text-muted-foreground"
                      }`}
                    >
                      <item.icon className="size-4" />
                      {item.title}
                    </Link>
                  ))}
                  
                  <Separator className="my-4" />
                  
                  <div className="flex flex-col space-y-2">
                    <Button variant="ghost" className="justify-start gap-3" size="sm">
                      <Bell className="size-4" />
                      Notifications
                    </Button>
                    <Button variant="ghost" className="justify-start gap-3" size="sm">
                      <User className="size-4" />
                      Profile
                    </Button>
                  </div>
                </div>
              </div>
            </SheetContent>
          </Sheet>
        </div>
      </div>
    </header>
  )
}