'use client'

import Link from 'next/link'
import { useRouter } from 'next/navigation'

import { Plus } from 'lucide-react'

import { JourneyTemplateGallery } from '@/components/features/journey/JourneyTemplateGallery'
import { Button } from '@/components/ui/button'
import { JourneyTemplate } from '@/lib/types/journey'

// export const metadata: Metadata = {
//   title: 'Journeys | Dashboard',
//   description: 'Manage your customer journey templates',
// }

/**
 * Journey templates listing page with filters and template management
 */
export default function JourneysPage() {
  const router = useRouter()

  const handleSelectTemplate = async (template: JourneyTemplate) => {
    // Navigate to create new journey with selected template
    router.push(`/dashboard/journeys/new?templateId=${template.id}`)
  }

  const handlePreviewTemplate = (template: JourneyTemplate) => {
    // Preview is handled within the gallery component
    console.log('Previewing template:', template.name)
  }

  return (
    <div className="space-y-6">
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Customer Journeys</h1>
            <p className="text-muted-foreground">
              Create and manage customer journey templates with our drag-and-drop builder
            </p>
          </div>
          <div className="flex items-center gap-3">
            <Button variant="outline" asChild>
              <Link href="/dashboard/journeys/templates" className="flex items-center gap-2">
                Browse Templates
              </Link>
            </Button>
            <Button asChild>
              <Link href="/dashboard/journeys/new" className="flex items-center gap-2">
                <Plus className="h-4 w-4" />
                Create Journey
              </Link>
            </Button>
          </div>
        </div>

        <JourneyTemplateGallery 
          onSelectTemplate={handleSelectTemplate}
          onPreviewTemplate={handlePreviewTemplate}
        />
      </div>
    </div>
  )
}