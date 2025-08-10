"use client"

import React from "react"
import { useFormContext } from "react-hook-form"
import {
  FormField,
  FormItem,
  FormLabel,
  FormControl,
  FormDescription,
  FormMessage,
} from "@/components/ui/form"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Button } from "@/components/ui/button"
import { Eye, EyeOff } from "lucide-react"

interface BaseFormFieldProps {
  name: string
  label?: string
  description?: string
  placeholder?: string
  disabled?: boolean
  required?: boolean
}

interface TextFieldProps extends BaseFormFieldProps {
  type?: 'text' | 'email' | 'url'
}

interface PasswordFieldProps extends BaseFormFieldProps {
  showPasswordToggle?: boolean
}

interface TextareaFieldProps extends BaseFormFieldProps {
  rows?: number
}

interface SelectFieldProps extends BaseFormFieldProps {
  options: Array<{ value: string; label: string; disabled?: boolean }>
  placeholder?: string
}

export function TextField({ 
  name, 
  label, 
  description, 
  placeholder, 
  type = 'text',
  disabled = false,
  required = false,
}: TextFieldProps) {
  const { control } = useFormContext()

  return (
    <FormField
      control={control}
      name={name}
      render={({ field }) => (
        <FormItem>
          {label && (
            <FormLabel>
              {label}
              {required && <span className="text-destructive ml-1">*</span>}
            </FormLabel>
          )}
          <FormControl>
            <Input
              type={type}
              placeholder={placeholder}
              disabled={disabled}
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

export function PasswordField({ 
  name, 
  label = "Password", 
  description, 
  placeholder = "Enter your password",
  disabled = false,
  required = false,
  showPasswordToggle = true,
}: PasswordFieldProps) {
  const { control } = useFormContext()
  const [showPassword, setShowPassword] = React.useState(false)

  return (
    <FormField
      control={control}
      name={name}
      render={({ field }) => (
        <FormItem>
          <FormLabel>
            {label}
            {required && <span className="text-destructive ml-1">*</span>}
          </FormLabel>
          <FormControl>
            <div className="relative">
              <Input
                type={showPassword ? 'text' : 'password'}
                placeholder={placeholder}
                disabled={disabled}
                className={showPasswordToggle ? "pr-10" : ""}
                {...field}
              />
              {showPasswordToggle && (
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="absolute right-0 top-0 h-full px-3 py-2 hover:bg-transparent"
                  onClick={() => setShowPassword(!showPassword)}
                  disabled={disabled}
                >
                  {showPassword ? (
                    <EyeOff className="h-4 w-4" />
                  ) : (
                    <Eye className="h-4 w-4" />
                  )}
                  <span className="sr-only">
                    {showPassword ? "Hide password" : "Show password"}
                  </span>
                </Button>
              )}
            </div>
          </FormControl>
          {description && <FormDescription>{description}</FormDescription>}
          <FormMessage />
        </FormItem>
      )}
    />
  )
}

export function TextareaField({ 
  name, 
  label, 
  description, 
  placeholder,
  rows = 3,
  disabled = false,
  required = false,
}: TextareaFieldProps) {
  const { control } = useFormContext()

  return (
    <FormField
      control={control}
      name={name}
      render={({ field }) => (
        <FormItem>
          {label && (
            <FormLabel>
              {label}
              {required && <span className="text-destructive ml-1">*</span>}
            </FormLabel>
          )}
          <FormControl>
            <Textarea
              placeholder={placeholder}
              rows={rows}
              disabled={disabled}
              className="resize-none"
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

export function SelectField({ 
  name, 
  label, 
  description, 
  placeholder = "Select an option",
  options,
  disabled = false,
  required = false,
}: SelectFieldProps) {
  const { control } = useFormContext()

  return (
    <FormField
      control={control}
      name={name}
      render={({ field }) => (
        <FormItem>
          {label && (
            <FormLabel>
              {label}
              {required && <span className="text-destructive ml-1">*</span>}
            </FormLabel>
          )}
          <Select
            onValueChange={field.onChange}
            defaultValue={field.value}
            disabled={disabled}
          >
            <FormControl>
              <SelectTrigger>
                <SelectValue placeholder={placeholder} />
              </SelectTrigger>
            </FormControl>
            <SelectContent>
              {options.map((option) => (
                <SelectItem
                  key={option.value}
                  value={option.value}
                  disabled={option.disabled || false}
                >
                  {option.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          {description && <FormDescription>{description}</FormDescription>}
          <FormMessage />
        </FormItem>
      )}
    />
  )
}

interface FormActionsProps {
  children?: React.ReactNode
  submitText?: string
  cancelText?: string
  onCancel?: () => void
  isSubmitting?: boolean
  submitDisabled?: boolean
  showCancel?: boolean
  className?: string
}

export function FormActions({
  children,
  submitText = "Submit",
  cancelText = "Cancel",
  onCancel,
  isSubmitting = false,
  submitDisabled = false,
  showCancel = false,
  className = "",
}: FormActionsProps) {
  if (children) {
    return <div className={`flex gap-3 ${className}`}>{children}</div>
  }

  return (
    <div className={`flex gap-3 ${className}`}>
      {showCancel && onCancel && (
        <Button
          type="button"
          variant="outline"
          onClick={onCancel}
          disabled={isSubmitting}
        >
          {cancelText}
        </Button>
      )}
      <Button
        type="submit"
        disabled={isSubmitting || submitDisabled}
      >
        {isSubmitting ? "Submitting..." : submitText}
      </Button>
    </div>
  )
}