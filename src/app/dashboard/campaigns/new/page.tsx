'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'

import { ArrowLeft } from 'lucide-react'
import { toast } from 'sonner'

import { type CampaignFormData,CampaignWizard } from '@/components/features/campaigns/CampaignWizard'
import { Button } from '@/components/ui/button'

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
    
    // Show loading toast
    const loadingToast = toast.loading('Creating your campaign...', {
      description: 'Setting up your campaign structure and templates',
    })
    
    try {
      // TODO: Replace with actual API call
      console.log('Creating campaign:', data)
      
      // Simulate API call with validation
      if (!data.name?.trim()) {
        throw new Error('Campaign name is required')
      }
      if (!data.startDate || !data.endDate) {
        throw new Error('Campaign dates are required')
      }
      if (new Date(data.startDate) >= new Date(data.endDate)) {
        throw new Error('End date must be after start date')
      }
      
      await new Promise(resolve => setTimeout(resolve, 2000))
      
      // Dismiss loading toast and show success
      toast.dismiss(loadingToast)
      toast.success('Campaign created successfully!', {
        description: `"${data.name}" is now ready to launch. You can view it in your campaigns dashboard.`,
        duration: 5000,
      })
      
      // Navigate to campaigns list
      router.push('/dashboard/campaigns')
    } catch (error) {
      console.error('Error creating campaign:', error)
      
      // Dismiss loading toast and show specific error
      toast.dismiss(loadingToast)
      
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred'
      const isValidationError = errorMessage.includes('required') || errorMessage.includes('date')
      
      toast.error(isValidationError ? 'Campaign validation failed' : 'Failed to create campaign', {
        description: isValidationError 
          ? `${errorMessage}. Please check your inputs and try again.`
          : 'There was a problem saving your campaign. Please try again or contact support if the issue persists.',
        duration: isValidationError ? 4000 : 6000,
        action: !isValidationError ? {
          label: 'Retry',
          onClick: () => handleSubmit(data)
        } : undefined,
      })
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
      
      // Show success toast
      toast.success('Draft saved', {
        description: 'Your campaign progress has been saved.',
      })
    } catch (error) {
      console.error('Error saving draft:', error)
      
      // Show error toast
      toast.error('Failed to save draft', {
        description: 'Your changes could not be saved. Please try again.',
      })
    } finally {
      setIsSavingDraft(false)
    }
  }

  return (
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
        brands={[]}
        quickMode={true}
      />
    </div>
  )
}