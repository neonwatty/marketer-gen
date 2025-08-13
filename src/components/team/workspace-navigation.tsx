'use client'

import React, { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Separator } from '@/components/ui/separator'
import { ScrollArea } from '@/components/ui/scroll-area'
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from '@/components/ui/dropdown-menu'
import {
  Home,
  Users,
  Calendar,
  CheckCircle,
  Clock,
  BarChart3,
  Settings,
  Plus,
  Bell,
  Search,
  MessageSquare,
  FileText,
  Folder,
  Star,
  Archive,
  MoreHorizontal,
  ChevronRight,
  ChevronDown,
  Hash,
  Lock,
  Globe,
  Zap
} from 'lucide-react'

interface WorkspaceSection {
  id: string
  name: string
  icon: React.ReactNode
  items: WorkspaceItem[]
  isExpanded: boolean
}

interface WorkspaceItem {
  id: string
  name: string
  type: 'channel' | 'project' | 'document' | 'folder'
  icon?: React.ReactNode
  unreadCount?: number
  isPrivate?: boolean
  members?: string[]
  lastActivity?: Date
}

const mockWorkspaceData: WorkspaceSection[] = [
  {
    id: 'channels',
    name: 'Channels',
    icon: <Hash className="h-4 w-4" />,
    isExpanded: true,
    items: [
      {
        id: 'general',
        name: 'general',
        type: 'channel',
        icon: <Hash className="h-4 w-4" />,
        unreadCount: 3,
        members: ['John', 'Sarah', 'Mike', 'Lisa', 'David']
      },
      {
        id: 'marketing',
        name: 'marketing',
        type: 'channel',
        icon: <Hash className="h-4 w-4" />,
        unreadCount: 7,
        members: ['John', 'Sarah', 'Lisa']
      },
      {
        id: 'design',
        name: 'design',
        type: 'channel',
        icon: <Hash className="h-4 w-4" />,
        unreadCount: 0,
        members: ['Mike', 'Sarah']
      },
      {
        id: 'leadership',
        name: 'leadership',
        type: 'channel',
        icon: <Lock className="h-4 w-4" />,
        isPrivate: true,
        unreadCount: 2,
        members: ['John', 'Lisa']
      }
    ]
  },
  {
    id: 'projects',
    name: 'Projects',
    icon: <Folder className="h-4 w-4" />,
    isExpanded: true,
    items: [
      {
        id: 'summer-campaign',
        name: 'Summer Campaign 2024',
        type: 'project',
        icon: <Zap className="h-4 w-4" />,
        unreadCount: 5,
        members: ['John', 'Sarah', 'Mike']
      },
      {
        id: 'website-redesign',
        name: 'Website Redesign',
        type: 'project',
        icon: <Globe className="h-4 w-4" />,
        unreadCount: 12,
        members: ['Mike', 'David', 'Sarah']
      },
      {
        id: 'q1-planning',
        name: 'Q1 Planning',
        type: 'project',
        icon: <Calendar className="h-4 w-4" />,
        unreadCount: 0,
        members: ['John', 'Lisa']
      }
    ]
  },
  {
    id: 'documents',
    name: 'Documents',
    icon: <FileText className="h-4 w-4" />,
    isExpanded: false,
    items: [
      {
        id: 'brand-guidelines',
        name: 'Brand Guidelines',
        type: 'document',
        icon: <FileText className="h-4 w-4" />,
        members: ['John', 'Sarah', 'Mike', 'Lisa', 'David']
      },
      {
        id: 'marketing-templates',
        name: 'Marketing Templates',
        type: 'folder',
        icon: <Folder className="h-4 w-4" />,
        members: ['Sarah', 'David']
      },
      {
        id: 'meeting-notes',
        name: 'Meeting Notes',
        type: 'folder',
        icon: <Folder className="h-4 w-4" />,
        members: ['John', 'Lisa']
      }
    ]
  }
]

export const WorkspaceNavigation: React.FC = () => {
  const [sections, setSections] = useState<WorkspaceSection[]>(mockWorkspaceData)
  const [activeItem, setActiveItem] = useState<string>('general')

  const toggleSection = (sectionId: string) => {
    setSections(prev => 
      prev.map(section => 
        section.id === sectionId 
          ? { ...section, isExpanded: !section.isExpanded }
          : section
      )
    )
  }

  const getItemIcon = (item: WorkspaceItem) => {
    if (item.icon) return item.icon
    
    switch (item.type) {
      case 'channel':
        return item.isPrivate ? <Lock className="h-4 w-4" /> : <Hash className="h-4 w-4" />
      case 'project':
        return <Folder className="h-4 w-4" />
      case 'document':
        return <FileText className="h-4 w-4" />
      case 'folder':
        return <Folder className="h-4 w-4" />
      default:
        return <Hash className="h-4 w-4" />
    }
  }

  const getTotalUnreadCount = () => {
    return sections.reduce((total, section) => 
      total + section.items.reduce((sectionTotal, item) => 
        sectionTotal + (item.unreadCount || 0), 0
      ), 0
    )
  }

  return (
    <div className="w-64 bg-muted/30 border-r flex flex-col h-full">
      {/* Header */}
      <div className="p-4 border-b">
        <div className="flex items-center justify-between mb-3">
          <h2 className="font-semibold">Marketing Team</h2>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="sm" className="h-6 w-6 p-0">
                <MoreHorizontal className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem>
                <Settings className="h-4 w-4 mr-2" />
                Workspace Settings
              </DropdownMenuItem>
              <DropdownMenuItem>
                <Users className="h-4 w-4 mr-2" />
                Invite Members
              </DropdownMenuItem>
              <DropdownMenuItem>
                <Archive className="h-4 w-4 mr-2" />
                Archive Workspace
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
        
        {/* Quick Actions */}
        <div className="flex gap-2">
          <Button size="sm" className="flex-1">
            <Plus className="h-4 w-4 mr-1" />
            Create
          </Button>
          <Button variant="outline" size="sm">
            <Search className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {/* Navigation */}
      <ScrollArea className="flex-1">
        <div className="p-2">
          {/* Quick Navigation */}
          <div className="space-y-1 mb-4">
            <Button 
              variant={activeItem === 'home' ? 'secondary' : 'ghost'} 
              className="w-full justify-start"
              onClick={() => setActiveItem('home')}
            >
              <Home className="h-4 w-4 mr-2" />
              Home
            </Button>
            <Button 
              variant={activeItem === 'team' ? 'secondary' : 'ghost'} 
              className="w-full justify-start"
              onClick={() => setActiveItem('team')}
            >
              <Users className="h-4 w-4 mr-2" />
              Team Dashboard
            </Button>
            <Button 
              variant={activeItem === 'calendar' ? 'secondary' : 'ghost'} 
              className="w-full justify-start"
              onClick={() => setActiveItem('calendar')}
            >
              <Calendar className="h-4 w-4 mr-2" />
              Calendar
            </Button>
            <Button 
              variant={activeItem === 'tasks' ? 'secondary' : 'ghost'} 
              className="w-full justify-start"
              onClick={() => setActiveItem('tasks')}
            >
              <CheckCircle className="h-4 w-4 mr-2" />
              Tasks
              {getTotalUnreadCount() > 0 && (
                <Badge variant="destructive" className="ml-auto text-xs">
                  {getTotalUnreadCount()}
                </Badge>
              )}
            </Button>
          </div>

          <Separator className="my-4" />

          {/* Workspace Sections */}
          <div className="space-y-2">
            {sections.map(section => (
              <div key={section.id}>
                <Button
                  variant="ghost"
                  className="w-full justify-start p-2 h-auto font-medium text-muted-foreground hover:text-foreground"
                  onClick={() => toggleSection(section.id)}
                >
                  {section.isExpanded ? (
                    <ChevronDown className="h-3 w-3 mr-1" />
                  ) : (
                    <ChevronRight className="h-3 w-3 mr-1" />
                  )}
                  {section.icon}
                  <span className="ml-2">{section.name}</span>
                  {section.items.reduce((total, item) => total + (item.unreadCount || 0), 0) > 0 && (
                    <Badge variant="secondary" className="ml-auto text-xs">
                      {section.items.reduce((total, item) => total + (item.unreadCount || 0), 0)}
                    </Badge>
                  )}
                </Button>

                {section.isExpanded && (
                  <div className="ml-4 space-y-1 mt-1">
                    {section.items.map(item => (
                      <Button
                        key={item.id}
                        variant={activeItem === item.id ? 'secondary' : 'ghost'}
                        className="w-full justify-start p-2 h-auto text-sm"
                        onClick={() => setActiveItem(item.id)}
                      >
                        {getItemIcon(item)}
                        <span className="ml-2 truncate">{item.name}</span>
                        {item.unreadCount && item.unreadCount > 0 && (
                          <Badge variant="destructive" className="ml-auto text-xs">
                            {item.unreadCount}
                          </Badge>
                        )}
                        {item.isPrivate && !item.unreadCount && (
                          <Lock className="h-3 w-3 ml-auto text-muted-foreground" />
                        )}
                      </Button>
                    ))}
                    
                    {/* Add item button */}
                    <Button
                      variant="ghost"
                      className="w-full justify-start p-2 h-auto text-sm text-muted-foreground"
                    >
                      <Plus className="h-3 w-3 mr-2" />
                      Add {section.name.slice(0, -1).toLowerCase()}
                    </Button>
                  </div>
                )}
              </div>
            ))}
          </div>

          <Separator className="my-4" />

          {/* Starred Items */}
          <div className="space-y-1">
            <Button
              variant="ghost"
              className="w-full justify-start p-2 h-auto font-medium text-muted-foreground"
            >
              <Star className="h-4 w-4 mr-2" />
              Starred
            </Button>
            <div className="ml-6 space-y-1">
              <Button
                variant="ghost"
                className="w-full justify-start p-1 h-auto text-sm"
              >
                <FileText className="h-3 w-3 mr-2" />
                Brand Guidelines
              </Button>
              <Button
                variant="ghost"
                className="w-full justify-start p-1 h-auto text-sm"
              >
                <Folder className="h-3 w-3 mr-2" />
                Summer Campaign
              </Button>
            </div>
          </div>
        </div>
      </ScrollArea>

      {/* Footer */}
      <div className="p-4 border-t">
        <div className="flex items-center gap-2">
          <Avatar className="h-8 w-8">
            <AvatarFallback className="text-xs">JD</AvatarFallback>
          </Avatar>
          <div className="flex-1 min-w-0">
            <div className="text-sm font-medium truncate">John Doe</div>
            <div className="text-xs text-muted-foreground">Marketing Manager</div>
          </div>
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="sm" className="h-6 w-6 p-0">
                <MoreHorizontal className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem>
                <Settings className="h-4 w-4 mr-2" />
                Preferences
              </DropdownMenuItem>
              <DropdownMenuItem>
                <Bell className="h-4 w-4 mr-2" />
                Notifications
              </DropdownMenuItem>
              <DropdownMenuItem>
                <MessageSquare className="h-4 w-4 mr-2" />
                Set Status
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>
    </div>
  )
}

export default WorkspaceNavigation