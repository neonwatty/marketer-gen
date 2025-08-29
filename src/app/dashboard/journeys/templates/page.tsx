'use client'

import { useRouter } from 'next/navigation'
import Link from 'next/link'

import { ArrowLeft, Plus } from 'lucide-react'

import { DashboardBreadcrumb } from '@/components/features/dashboard/DashboardBreadcrumb'
import { JourneyTemplateGallery } from '@/components/features/journey/JourneyTemplateGallery'
import { Button } from '@/components/ui/button'
import { JourneyTemplate } from '@/lib/types/journey'

/**
 * Journey templates browsing page - focused on template selection
 */
export default function JourneyTemplatesPage() {
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
      <DashboardBreadcrumb 
        items={[
          { label: 'Dashboard', href: '/dashboard' },
          { label: 'Journeys', href: '/dashboard/journeys' },
          { label: 'Templates', href: '/dashboard/journeys/templates' }
        ]} 
      />
      
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <Button
              variant="outline"
              size="sm"
              onClick={() => router.back()}
              className="flex items-center gap-2"
            >
              <ArrowLeft className="h-4 w-4" />
              Back
            </Button>
            
            <div>
              <h1 className="text-3xl font-bold tracking-tight">Journey Templates</h1>
              <p className="text-muted-foreground">
                Browse and select from our collection of proven customer journey templates
              </p>
            </div>
          </div>
          
          <Button asChild>
            <Link href="/dashboard/journeys/new" className="flex items-center gap-2">
              <Plus className="h-4 w-4" />
              Create Custom Journey
            </Link>
          </Button>
        </div>

        <div className="rounded-lg border bg-card p-4">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
            <div className="text-center p-4">
              <div className="text-2xl font-bold text-blue-600 mb-1">50+</div>
              <div className="text-sm text-muted-foreground">Proven Templates</div>
            </div>
            <div className="text-center p-4">
              <div className="text-2xl font-bold text-green-600 mb-1">20+</div>
              <div className="text-sm text-muted-foreground">Industries Covered</div>
            </div>
            <div className="text-center p-4">
              <div className="text-2xl font-bold text-purple-600 mb-1">95%</div>
              <div className="text-sm text-muted-foreground">Success Rate</div>
            </div>
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