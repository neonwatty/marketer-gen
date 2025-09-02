'use client'

import { Suspense } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { ContentGenerator } from '@/components/features/content/ContentGenerator'

interface Brand {
  id: string
  name: string
  tagline?: string
  voiceDescription?: string
}

interface AIContentGeneratorClientProps {
  brands: Brand[]
}

export function AIContentGeneratorClient({ brands }: AIContentGeneratorClientProps) {
  const handleContentGenerated = (content: any) => {
    console.log('Content generated:', content)
    // In a real app, you might save this to a database or state management system
  }

  return (
    <Suspense fallback={
      <Card>
        <CardContent className="flex items-center justify-center py-12">
          <LoadingSpinner className="h-8 w-8" />
          <span className="ml-2">Loading AI Content Generator...</span>
        </CardContent>
      </Card>
    }>
      <ContentGenerator 
        brands={brands}
        onContentGenerated={handleContentGenerated}
      />
    </Suspense>
  )
}