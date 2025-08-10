"use client"

import React from "react"
import { FormWrapper } from "./FormWrapper"
import { TextField, TextareaField, FormActions } from "./FormFields"
import { userProfileSchema, UserProfileFormData } from "./schemas"

interface UserProfileFormProps {
  onSubmit: (data: UserProfileFormData) => void | Promise<void>
  defaultValues?: Partial<UserProfileFormData> | undefined
  isSubmitting?: boolean
  cardWrapper?: boolean
}

export function UserProfileForm({
  onSubmit,
  defaultValues,
  isSubmitting = false,
  cardWrapper = true,
}: UserProfileFormProps) {
  return (
    <FormWrapper
      onSubmit={onSubmit}
      schema={userProfileSchema}
      {...(defaultValues && { defaultValues })}
      title="Profile Information"
      description="Update your personal and professional details"
      cardWrapper={cardWrapper}
    >
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <TextField
          name="firstName"
          label="First Name"
          placeholder="Enter your first name"
          required
        />

        <TextField
          name="lastName"
          label="Last Name"
          placeholder="Enter your last name"
          required
        />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <TextField
          name="email"
          label="Email Address"
          type="email"
          placeholder="Enter your email address"
          required
        />

        <TextField
          name="phone"
          label="Phone Number"
          placeholder="(555) 123-4567"
        />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <TextField
          name="company"
          label="Company"
          placeholder="Enter your company name"
        />

        <TextField
          name="role"
          label="Job Title"
          placeholder="Enter your job title"
        />
      </div>

      <TextareaField
        name="bio"
        label="Bio"
        description="Brief description about yourself (optional)"
        placeholder="Tell us a bit about yourself..."
        rows={4}
      />

      <FormActions
        submitText="Update Profile"
        isSubmitting={isSubmitting}
      />
    </FormWrapper>
  )
}