"use client"

import React from "react"
import { FormWrapper } from "./FormWrapper"
import { TextField, TextareaField, SelectField, FormActions } from "./FormFields"
import { FileUploadField } from "./FileUploadField"
import { FileWithPreview } from "@/components/ui/file-upload"
import { z } from "zod"

const campaignAssetsSchema = z.object({
  campaignName: z.string().min(1, "Campaign name is required"),
  description: z.string().optional(),
  campaignType: z.enum(['email', 'social-media', 'display-ads', 'print', 'video'], {
    message: "Please select a campaign type",
  }),
  brandAssets: z.array(z.any()).optional(), // Files will be validated separately
  additionalNotes: z.string().optional(),
})

type CampaignAssetsFormData = z.infer<typeof campaignAssetsSchema>

const campaignTypeOptions = [
  { value: 'email', label: 'Email Campaign' },
  { value: 'social-media', label: 'Social Media' },
  { value: 'display-ads', label: 'Display Advertising' },
  { value: 'print', label: 'Print Materials' },
  { value: 'video', label: 'Video Content' },
]

interface CampaignAssetsFormProps {
  onSubmit: (data: CampaignAssetsFormData) => void | Promise<void>
  defaultValues?: Partial<CampaignAssetsFormData>
  isSubmitting?: boolean
  cardWrapper?: boolean
}

export function CampaignAssetsForm({
  onSubmit,
  defaultValues,
  isSubmitting = false,
  cardWrapper = true,
}: CampaignAssetsFormProps) {
  const handleFileUpload = async (files: FileWithPreview[]): Promise<void> => {
    // Simulate file upload to storage service
    console.log('Uploading files:', files.map(f => f.name))
    
    // In a real implementation, this would upload to cloud storage
    // and update the files with their URLs
    await new Promise(resolve => setTimeout(resolve, 2000))
    
    // Update files with upload URLs (in practice, you'd update state or call a callback)
    files.forEach(file => {
      console.log(`File ${file.name} uploaded to: https://example.com/uploads/${file.name}`)
    })
  }

  return (
    <FormWrapper
      onSubmit={onSubmit}
      schema={campaignAssetsSchema}
      {...(defaultValues && { defaultValues })}
      title="Campaign Assets"
      description="Upload brand assets and configure campaign settings"
      cardWrapper={cardWrapper}
    >
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <TextField
          name="campaignName"
          label="Campaign Name"
          placeholder="Enter campaign name..."
          required
        />

        <SelectField
          name="campaignType"
          label="Campaign Type"
          placeholder="Select campaign type"
          options={campaignTypeOptions}
          required
        />
      </div>

      <TextareaField
        name="description"
        label="Campaign Description"
        description="Brief description of the campaign goals and target audience"
        placeholder="Describe your campaign..."
        rows={3}
      />

      <FileUploadField
        name="brandAssets"
        label="Brand Assets"
        description="Upload logos, images, videos, and other brand materials (max 50MB per file)"
        onUpload={handleFileUpload}
        maxFiles={15}
        maxSize={50 * 1024 * 1024} // 50MB
        acceptedFileTypes={{
          'image/*': ['.jpeg', '.jpg', '.png', '.gif', '.webp', '.svg'],
          'application/pdf': ['.pdf'],
          'video/mp4': ['.mp4'],
          'video/quicktime': ['.mov'],
          'application/zip': ['.zip'],
        }}
        multiple
      />

      <TextareaField
        name="additionalNotes"
        label="Additional Notes"
        description="Any special requirements or notes for the campaign"
        placeholder="Additional information..."
        rows={3}
      />

      <FormActions
        submitText="Create Campaign"
        isSubmitting={isSubmitting}
      />
    </FormWrapper>
  )
}