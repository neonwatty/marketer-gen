'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Metadata } from 'next'

import { CampaignWizard, type CampaignFormData } from '@/components/features/campaigns/CampaignWizard'
import { DashboardBreadcrumb } from '@/components/features/dashboard/DashboardBreadcrumb'
import { Button } from '@/components/ui/button'
import { ArrowLeft } from 'lucide-react'

// Note: This would normally be generated on the server side
// export const metadata: Metadata = {
//   title: 'Create Campaign | Dashboard',
//   description: 'Create a new marketing campaign with our step-by-step wizard',
// }

export default function NewCampaignPage() {
  const router = useRouter()
  const [isCreating, setIsCreating] = useState(false)
  const [isSavingDraft, setIsSavingDraft] = useState(false)

  const handleSubmit = async (data: CampaignFormData) => {
    setIsCreating(true)
    
    try {
      // TODO: Replace with actual API call
      console.log('Creating campaign:', data)
      
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 2000))
      
      // TODO: Handle successful creation
      router.push('/dashboard/campaigns')
    } catch (error) {
      console.error('Error creating campaign:', error)
      // TODO: Show error message to user
    } finally {
      setIsCreating(false)
    }
  }

  const handleSaveDraft = async (data: Partial<CampaignFormData>) => {
    setIsSavingDraft(true)
    
    try {
      // TODO: Replace with actual API call
      console.log('Saving draft:', data)
      
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1000))
      
      // TODO: Show success message
      console.log('Draft saved successfully')
    } catch (error) {
      console.error('Error saving draft:', error)
      // TODO: Show error message to user
    } finally {
      setIsSavingDraft(false)
    }
  }

  return (
    <div className="space-y-6">
      <DashboardBreadcrumb 
        items={[
          { label: 'Dashboard', href: '/dashboard' },
          { label: 'Campaigns', href: '/dashboard/campaigns' },
          { label: 'Create New', href: '/dashboard/campaigns/new' }
        ]} 
      />
      
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
            <h1 className="text-3xl font-bold tracking-tight">Create New Campaign</h1>
            <p className="text-muted-foreground">
              Use our step-by-step wizard to create a comprehensive marketing campaign
            </p>
          </div>
        </div>
      </div>

      <CampaignWizard
        onSubmit={handleSubmit}
        onSaveDraft={handleSaveDraft}
        isLoading={isCreating || isSavingDraft}
      />
    </div>
  )
}