"use client"

import React from "react"
import { useForm, UseFormProps, FieldValues, DefaultValues } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Form } from "@/components/ui/form"
import { cn } from "@/lib/utils"

interface FormWrapperProps<T extends FieldValues> {
  children: React.ReactNode
  onSubmit: (data: T) => void | Promise<void>
  schema?: any
  defaultValues?: DefaultValues<T>
  className?: string
  title?: string
  description?: string
  cardWrapper?: boolean
  formProps?: UseFormProps<T>
}

export function FormWrapper<T extends FieldValues>({
  children,
  onSubmit,
  schema,
  defaultValues,
  className,
  title,
  description,
  cardWrapper = false,
  formProps,
}: FormWrapperProps<T>) {
  const formOptions: UseFormProps<T> = {
    mode: 'onChange',
    ...formProps,
  }

  if (schema) {
    formOptions.resolver = zodResolver(schema)
  }

  if (defaultValues) {
    formOptions.defaultValues = defaultValues
  }

  const form = useForm<T>(formOptions)

  const handleSubmit = async (data: T) => {
    try {
      await onSubmit(data)
    } catch (error) {
      console.error('Form submission error:', error)
    }
  }

  const formContent = (
    <Form {...form}>
      <form
        onSubmit={form.handleSubmit(handleSubmit)}
        className={cn("space-y-6", className)}
      >
        {children}
      </form>
    </Form>
  )

  if (cardWrapper) {
    return (
      <Card>
        {(title || description) && (
          <CardHeader>
            {title && <CardTitle>{title}</CardTitle>}
            {description && <CardDescription>{description}</CardDescription>}
          </CardHeader>
        )}
        <CardContent>
          {formContent}
        </CardContent>
      </Card>
    )
  }

  return (
    <div className={cn("space-y-6", cardWrapper && "p-6")}>
      {(title || description) && (
        <div className="space-y-2">
          {title && <h2 className="text-2xl font-semibold tracking-tight">{title}</h2>}
          {description && <p className="text-muted-foreground">{description}</p>}
        </div>
      )}
      {formContent}
    </div>
  )
}