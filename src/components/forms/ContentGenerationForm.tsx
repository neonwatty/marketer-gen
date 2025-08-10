"use client"

import React from "react"
import { FormWrapper } from "./FormWrapper"
import { TextField, TextareaField, SelectField, FormActions } from "./FormFields"
import { contentGenerationSchema, ContentGenerationFormData } from "./schemas"

const contentTypeOptions = [
  { value: 'blog-post', label: 'Blog Post' },
  { value: 'social-media', label: 'Social Media Post' },
  { value: 'email', label: 'Email Campaign' },
  { value: 'landing-page', label: 'Landing Page' },
  { value: 'ad-copy', label: 'Advertisement Copy' },
]

const toneOptions = [
  { value: 'professional', label: 'Professional' },
  { value: 'casual', label: 'Casual' },
  { value: 'friendly', label: 'Friendly' },
  { value: 'persuasive', label: 'Persuasive' },
  { value: 'informative', label: 'Informative' },
]

interface ContentGenerationFormProps {
  onSubmit: (data: ContentGenerationFormData) => void | Promise<void>
  defaultValues?: Partial<ContentGenerationFormData> | undefined
  isSubmitting?: boolean
  cardWrapper?: boolean
}

export function ContentGenerationForm({
  onSubmit,
  defaultValues,
  isSubmitting = false,
  cardWrapper = true,
}: ContentGenerationFormProps) {
  return (
    <FormWrapper
      onSubmit={onSubmit}
      schema={contentGenerationSchema}
      {...(defaultValues && { defaultValues })}
      title="Generate Marketing Content"
      description="Create compelling marketing content using AI assistance"
      cardWrapper={cardWrapper}
    >
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <TextField
          name="title"
          label="Content Title"
          placeholder="Enter a compelling title..."
          required
        />

        <SelectField
          name="contentType"
          label="Content Type"
          placeholder="Select content type"
          options={contentTypeOptions}
          required
        />
      </div>

      <TextareaField
        name="description"
        label="Content Description"
        description="Provide details about what you want the content to cover"
        placeholder="Describe your content requirements..."
        rows={4}
        required
      />

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <SelectField
          name="tone"
          label="Tone of Voice"
          placeholder="Select tone"
          options={toneOptions}
          required
        />

        <TextField
          name="targetAudience"
          label="Target Audience"
          placeholder="e.g., Small business owners, Tech professionals..."
          required
        />
      </div>

      <TextField
        name="keywords"
        label="Keywords (Optional)"
        description="Comma-separated list of keywords to include"
        placeholder="marketing, automation, efficiency..."
      />

      <TextareaField
        name="additionalInstructions"
        label="Additional Instructions (Optional)"
        description="Any specific requirements or style preferences"
        placeholder="Additional context or requirements..."
        rows={3}
      />

      <FormActions
        submitText="Generate Content"
        isSubmitting={isSubmitting}
      />
    </FormWrapper>
  )
}