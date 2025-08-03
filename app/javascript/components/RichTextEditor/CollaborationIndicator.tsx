import React, { useState, useEffect } from 'react'

interface Collaborator {
  id: string
  name: string
  avatar?: string
  color: string
  isActive?: boolean
  lastSeen?: Date
  cursor?: {
    x: number
    y: number
  }
}

interface CollaborationIndicatorProps {
  collaborators: Collaborator[]
  currentUserId?: string
  onlineUsers?: string[]
}

export const CollaborationIndicator: React.FC<CollaborationIndicatorProps> = ({
  collaborators,
  currentUserId,
  onlineUsers = []
}) => {
  const [showAllCollaborators, setShowAllCollaborators] = useState(false)
  const [cursors, setCursors] = useState<Map<string, { x: number, y: number }>>(new Map())

  // Filter out current user and mark active collaborators
  const activeCollaborators = collaborators
    .filter(collaborator => collaborator.id !== currentUserId)
    .map(collaborator => ({
      ...collaborator,
      isActive: onlineUsers.includes(collaborator.id)
    }))

  const visibleCollaborators = showAllCollaborators 
    ? activeCollaborators 
    : activeCollaborators.slice(0, 3)

  const remainingCount = Math.max(0, activeCollaborators.length - 3)

  // Simulate cursor tracking (in real implementation, this would come from WebSocket)
  useEffect(() => {
    const interval = setInterval(() => {
      const newCursors = new Map()
      activeCollaborators.forEach(collaborator => {
        if (collaborator.isActive && Math.random() > 0.3) {
          newCursors.set(collaborator.id, {
            x: Math.random() * window.innerWidth,
            y: Math.random() * window.innerHeight
          })
        }
      })
      setCursors(newCursors)
    }, 2000)

    return () => clearInterval(interval)
  }, [activeCollaborators])

  const getInitials = (name: string) => {
    return name
      .split(' ')
      .map(word => word[0])
      .join('')
      .toUpperCase()
      .slice(0, 2)
  }

  const formatLastSeen = (date: Date) => {
    const now = new Date()
    const diffInMinutes = Math.floor((now.getTime() - date.getTime()) / (1000 * 60))
    
    if (diffInMinutes < 1) {return 'Just now'}
    if (diffInMinutes < 60) {return `${diffInMinutes}m ago`}
    if (diffInMinutes < 1440) {return `${Math.floor(diffInMinutes / 60)}h ago`}
    return `${Math.floor(diffInMinutes / 1440)}d ago`
  }

  if (activeCollaborators.length === 0) {
    return null
  }

  return (
    <>
      {/* Collaboration Bar */}
      <div className="flex items-center justify-between px-4 py-2 bg-blue-50 border-b border-blue-200">
        <div className="flex items-center space-x-2">
          <svg className="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path 
              strokeLinecap="round" 
              strokeLinejoin="round" 
              strokeWidth={2} 
              d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z" 
            />
          </svg>
          <span className="text-sm font-medium text-blue-800">
            Collaborative Editing
          </span>
          <span className="text-xs text-blue-600">
            {activeCollaborators.filter(c => c.isActive).length} online
          </span>
        </div>

        {/* Collaborator Avatars */}
        <div className="flex items-center space-x-1">
          <div 
            className="flex -space-x-2"
            onMouseEnter={() => setShowAllCollaborators(true)}
            onMouseLeave={() => setShowAllCollaborators(false)}
          >
            {visibleCollaborators.map((collaborator) => (
              <div
                key={collaborator.id}
                className="relative group"
                title={`${collaborator.name} ${collaborator.isActive ? '(online)' : `(${collaborator.lastSeen ? formatLastSeen(collaborator.lastSeen) : 'offline'})`}`}
              >
                <div
                  className={`w-8 h-8 rounded-full border-2 border-white flex items-center justify-center text-xs font-medium text-white shadow-sm ${
                    collaborator.isActive ? 'ring-2 ring-green-400' : ''
                  }`}
                  style={{ backgroundColor: collaborator.color }}
                >
                  {collaborator.avatar ? (
                    <img
                      src={collaborator.avatar}
                      alt={collaborator.name}
                      className="w-full h-full rounded-full object-cover"
                    />
                  ) : (
                    getInitials(collaborator.name)
                  )}
                </div>
                
                {/* Online indicator */}
                {collaborator.isActive && (
                  <div className="absolute -bottom-0.5 -right-0.5 w-3 h-3 bg-green-400 border-2 border-white rounded-full" />
                )}

                {/* Tooltip */}
                <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 opacity-0 group-hover:opacity-100 transition-opacity z-10">
                  <div className="bg-gray-900 text-white text-xs rounded py-1 px-2 whitespace-nowrap">
                    {collaborator.name}
                    <div className="text-gray-300">
                      {collaborator.isActive ? 'Online' : collaborator.lastSeen ? formatLastSeen(collaborator.lastSeen) : 'Offline'}
                    </div>
                  </div>
                </div>
              </div>
            ))}

            {/* Show remaining count */}
            {remainingCount > 0 && (
              <div className="w-8 h-8 rounded-full bg-gray-200 border-2 border-white flex items-center justify-center text-xs font-medium text-gray-600 shadow-sm">
                +{remainingCount}
              </div>
            )}
          </div>

          {/* Collaboration Status */}
          <div className="ml-3 flex items-center space-x-1">
            <div className="w-2 h-2 bg-green-400 rounded-full animate-pulse" />
            <span className="text-xs text-green-700 font-medium">Live</span>
          </div>
        </div>
      </div>

      {/* Collaborator Details Dropdown */}
      {showAllCollaborators && activeCollaborators.length > 3 && (
        <div className="absolute top-12 right-4 z-20 bg-white border border-gray-200 rounded-lg shadow-lg p-3 min-w-[200px]">
          <h4 className="text-sm font-medium text-gray-900 mb-2">All Collaborators</h4>
          <div className="space-y-2">
            {activeCollaborators.map((collaborator) => (
              <div key={collaborator.id} className="flex items-center space-x-2">
                <div
                  className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-medium text-white ${
                    collaborator.isActive ? 'ring-1 ring-green-400' : ''
                  }`}
                  style={{ backgroundColor: collaborator.color }}
                >
                  {collaborator.avatar ? (
                    <img
                      src={collaborator.avatar}
                      alt={collaborator.name}
                      className="w-full h-full rounded-full object-cover"
                    />
                  ) : (
                    getInitials(collaborator.name)
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-900 truncate">
                    {collaborator.name}
                  </p>
                  <p className="text-xs text-gray-500">
                    {collaborator.isActive ? (
                      <span className="flex items-center">
                        <span className="w-1.5 h-1.5 bg-green-400 rounded-full mr-1" />
                        Online
                      </span>
                    ) : (
                      collaborator.lastSeen ? formatLastSeen(collaborator.lastSeen) : 'Offline'
                    )}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Cursor Indicators */}
      {Array.from(cursors.entries()).map(([userId, position]) => {
        const collaborator = activeCollaborators.find(c => c.id === userId)
        if (!collaborator) {return null}

        return (
          <div
            key={userId}
            className="fixed pointer-events-none z-50 transition-all duration-200"
            style={{
              left: position.x,
              top: position.y,
              transform: 'translate(-2px, -2px)'
            }}
          >
            <div className="flex items-center">
              <div
                className="w-4 h-4 transform rotate-45"
                style={{ backgroundColor: collaborator.color }}
               />
              <div
                className="ml-1 px-2 py-1 rounded text-xs text-white whitespace-nowrap"
                style={{ backgroundColor: collaborator.color }}
              >
                {collaborator.name}
              </div>
            </div>
          </div>
        )
      })}

      {/* Real-time Activity Feed */}
      <div className="fixed bottom-4 right-4 z-30 max-w-xs">
        {activeCollaborators
          .filter(c => c.isActive && Math.random() > 0.7) // Simulate random activity
          .slice(0, 1)
          .map((collaborator) => (
            <div
              key={`activity-${collaborator.id}`}
              className="mb-2 bg-white border border-gray-200 rounded-lg shadow-lg p-3 animate-fade-in"
            >
              <div className="flex items-center space-x-2">
                <div
                  className="w-4 h-4 rounded-full flex-shrink-0"
                  style={{ backgroundColor: collaborator.color }}
                 />
                <p className="text-sm text-gray-700">
                  <span className="font-medium">{collaborator.name}</span> is editing...
                </p>
              </div>
            </div>
          ))}
      </div>

      {/* Styles for animations */}
      <style jsx>{`
        @keyframes fade-in {
          from {
            opacity: 0;
            transform: translateY(10px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }
        
        .animate-fade-in {
          animation: fade-in 0.3s ease-out;
        }
      `}</style>
    </>
  )
}

export default CollaborationIndicator