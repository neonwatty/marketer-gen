"use client"

import React from "react"
import { FormWrapper } from "./FormWrapper"
import { TextField, TextareaField, SelectField, FormActions } from "./FormFields"
import { contentGenerationSchema, ContentGenerationFormData } from "./schemas"

const contentTypeOptions = [
  { value: 'social-post', label: 'Social Media Post' },
  { value: 'ad-copy', label: 'Advertisement Copy' },
  { value: 'email', label: 'Email Campaign' },
  { value: 'landing-page', label: 'Landing Page' },
  { value: 'video-script', label: 'Video Script' },
  { value: 'blog-post', label: 'Blog Post' },
  { value: 'product-description', label: 'Product Description' },
  { value: 'press-release', label: 'Press Release' },
]

const toneOptions = [
  { value: 'professional', label: 'Professional' },
  { value: 'casual', label: 'Casual' },
  { value: 'friendly', label: 'Friendly' },
  { value: 'persuasive', label: 'Persuasive' },
  { value: 'informative', label: 'Informative' },
  { value: 'urgent', label: 'Urgent' },
  { value: 'humorous', label: 'Humorous' },
  { value: 'authoritative', label: 'Authoritative' },
  { value: 'empathetic', label: 'Empathetic' },
]

const contentLengthOptions = [
  { value: 'short', label: 'Short (< 500 words)' },
  { value: 'medium', label: 'Medium (500-1500 words)' },
  { value: 'long', label: 'Long (1500+ words)' },
]

const channelOptions = [
  { value: 'facebook', label: 'Facebook' },
  { value: 'instagram', label: 'Instagram' },
  { value: 'twitter', label: 'Twitter/X' },
  { value: 'linkedin', label: 'LinkedIn' },
  { value: 'tiktok', label: 'TikTok' },
  { value: 'youtube', label: 'YouTube' },
  { value: 'email', label: 'Email' },
  { value: 'website', label: 'Website' },
  { value: 'blog', label: 'Blog' },
  { value: 'print', label: 'Print' },
]

const urgencyLevelOptions = [
  { value: 'low', label: 'Low' },
  { value: 'medium', label: 'Medium' },
  { value: 'high', label: 'High' },
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

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <SelectField
          name="tone"
          label="Tone of Voice"
          placeholder="Select tone"
          options={toneOptions}
          required
        />

        <SelectField
          name="contentLength"
          label="Content Length"
          placeholder="Select length"
          options={contentLengthOptions}
        />

        <SelectField
          name="urgencyLevel"
          label="Urgency Level"
          placeholder="Select urgency"
          options={urgencyLevelOptions}
        />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <TextField
          name="targetAudience"
          label="Target Audience"
          placeholder="e.g., Small business owners, Tech professionals..."
          required
        />

        <SelectField
          name="channel"
          label="Publication Channel"
          placeholder="Select channel"
          options={channelOptions}
        />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <TextField
          name="callToAction"
          label="Call to Action (Optional)"
          placeholder="e.g., Shop Now, Learn More, Sign Up..."
        />

        <TextField
          name="keywords"
          label="Keywords (Optional)"
          description="Comma-separated list of keywords to include"
          placeholder="marketing, automation, efficiency..."
        />
      </div>

      <TextareaField
        name="brandContext"
        label="Brand Context (Optional)"
        description="Provide brand guidelines, voice, or context to incorporate"
        placeholder="Brand voice, guidelines, or specific messaging to include..."
        rows={3}
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