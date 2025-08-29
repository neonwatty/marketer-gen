'use client'

import dynamic from 'next/dynamic'
import { Skeleton } from '@/components/ui/skeleton'

// Lazy load JourneyBuilder since it imports heavy ReactFlow dependencies
const JourneyBuilder = dynamic(
  () => import('@/components/features/journey').then(mod => ({ default: mod.JourneyBuilder })),
  {
    ssr: false,
    loading: () => (
      <div className="w-full h-[600px] border border-border rounded-lg p-4">
        <div className="space-y-4">
          <Skeleton className="h-12 w-full" />
          <div className="grid grid-cols-3 gap-4">
            <Skeleton className="h-32" />
            <Skeleton className="h-32" />
            <Skeleton className="h-32" />
          </div>
          <Skeleton className="h-48 w-full" />
        </div>
      </div>
    )
  }
)

export default function JourneyDemoPage() {
  return (
    <div className="container mx-auto py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-2">Journey Builder Demo</h1>
        <p className="text-muted-foreground">
          Interactive customer journey visualization with drag-and-drop functionality.
        </p>
      </div>
      
      <JourneyBuilder />
      
      <div className="mt-8 p-4 bg-muted rounded-lg">
        <h2 className="text-lg font-semibold mb-2">Features:</h2>
        <ul className="space-y-1 text-sm text-muted-foreground">
          <li>• Drag and drop to rearrange stages</li>
          <li>• Click on any stage to configure content types and messaging</li>
          <li>• Use the toolbar to add new stages</li>
          <li>• Zoom controls and minimap for large journeys</li>
          <li>• Real-time connection management between stages</li>
        </ul>
      </div>
    </div>
  )
}