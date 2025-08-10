"use client"

import React from "react"
import { useFormContext, useController } from "react-hook-form"
import {
  FormField,
  FormItem,
  FormLabel,
  FormControl,
  FormDescription,
  FormMessage,
} from "@/components/ui/form"
import { FileUpload, FileWithPreview } from "@/components/ui/file-upload"

interface FileUploadFieldProps {
  name: string
  label?: string
  description?: string
  disabled?: boolean
  required?: boolean
  maxFiles?: number
  maxSize?: number
  acceptedFileTypes?: Record<string, string[]>
  multiple?: boolean
  onUpload?: (files: FileWithPreview[]) => Promise<void>
}

export function FileUploadField({
  name,
  label,
  description,
  disabled = false,
  required = false,
  maxFiles,
  maxSize,
  acceptedFileTypes,
  multiple = true,
  onUpload,
}: FileUploadFieldProps) {
  const { control } = useFormContext()

  return (
    <FormField
      control={control}
      name={name}
      render={({ field: { value, onChange, ...field } }) => (
        <FormItem>
          {label && (
            <FormLabel>
              {label}
              {required && <span className="text-destructive ml-1">*</span>}
            </FormLabel>
          )}
          <FormControl>
            <FileUpload
              value={value || []}
              onFilesChange={(files) => {
                onChange(files)
              }}
              {...(onUpload && { onUpload })}
              disabled={disabled}
              {...(maxFiles && { maxFiles })}
              {...(maxSize && { maxSize })}
              {...(acceptedFileTypes && { acceptedFileTypes })}
              multiple={multiple}
              {...field}
            />
          </FormControl>
          {description && <FormDescription>{description}</FormDescription>}
          <FormMessage />
        </FormItem>
      )}
    />
  )
}