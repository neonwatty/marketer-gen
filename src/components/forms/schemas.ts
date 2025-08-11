import { z } from "zod"

// Common validation patterns
export const emailSchema = z.string().email("Please enter a valid email address")

export const passwordSchema = z
  .string()
  .min(8, "Password must be at least 8 characters")
  .regex(
    /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/,
    "Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character"
  )

export const urlSchema = z.string().url("Please enter a valid URL")

export const phoneSchema = z
  .string()
  .regex(
    /^(\+1\s?)?(\(?\d{3}\)?[\s\-]?)?\d{3}[\s\-]?\d{4}$/,
    "Please enter a valid phone number"
  )

// Marketing-specific schemas
export const campaignNameSchema = z
  .string()
  .min(1, "Campaign name is required")
  .max(100, "Campaign name must be less than 100 characters")

export const contentTitleSchema = z
  .string()
  .min(1, "Title is required")
  .max(200, "Title must be less than 200 characters")

export const contentDescriptionSchema = z
  .string()
  .min(10, "Description must be at least 10 characters")
  .max(1000, "Description must be less than 1000 characters")

export const tagSchema = z
  .string()
  .regex(/^[a-zA-Z0-9-_]+$/, "Tags can only contain letters, numbers, hyphens, and underscores")
  .max(50, "Tag must be less than 50 characters")

// Content generation schemas
export const contentGenerationSchema = z.object({
  title: contentTitleSchema,
  description: contentDescriptionSchema,
  contentType: z.enum([
    'social-post', 
    'ad-copy', 
    'email', 
    'landing-page', 
    'video-script', 
    'blog-post',
    'product-description',
    'press-release'
  ], {
    message: "Please select a content type",
  }),
  tone: z.enum([
    'professional', 
    'casual', 
    'friendly', 
    'persuasive', 
    'informative',
    'urgent',
    'humorous',
    'authoritative',
    'empathetic'
  ], {
    message: "Please select a tone",
  }),
  targetAudience: z.string().min(1, "Target audience is required"),
  keywords: z.string().optional(),
  additionalInstructions: z.string().optional(),
  brandContext: z.string().optional(),
  contentLength: z.enum(['short', 'medium', 'long'], {
    message: "Please select content length",
  }).optional(),
  channel: z.enum([
    'facebook',
    'instagram', 
    'twitter',
    'linkedin',
    'tiktok',
    'youtube',
    'email',
    'website',
    'blog',
    'print'
  ]).optional(),
  callToAction: z.string().optional(),
  urgencyLevel: z.enum(['low', 'medium', 'high']).optional(),
})

export type ContentGenerationFormData = z.infer<typeof contentGenerationSchema>

// Campaign creation schema
export const campaignSchema = z.object({
  name: campaignNameSchema,
  description: z.string().min(10, "Description must be at least 10 characters"),
  startDate: z.date({
    message: "Start date is required",
  }),
  endDate: z.date({
    message: "End date is required",
  }),
  budget: z.number().min(0, "Budget must be a positive number"),
  status: z.enum(['draft', 'active', 'paused', 'completed'], {
    message: "Please select a status",
  }),
  tags: z.array(tagSchema).optional(),
}).refine(
  (data) => data.endDate > data.startDate,
  {
    message: "End date must be after start date",
    path: ["endDate"],
  }
)

export type CampaignFormData = z.infer<typeof campaignSchema>

// User profile schema
export const userProfileSchema = z.object({
  firstName: z.string().min(1, "First name is required"),
  lastName: z.string().min(1, "Last name is required"),
  email: emailSchema,
  phone: phoneSchema.optional(),
  company: z.string().optional(),
  role: z.string().optional(),
  bio: z.string().max(500, "Bio must be less than 500 characters").optional(),
})

export type UserProfileFormData = z.infer<typeof userProfileSchema>

// Login/Register schemas
export const loginSchema = z.object({
  email: emailSchema,
  password: z.string().min(1, "Password is required"),
  rememberMe: z.boolean().optional(),
})

export type LoginFormData = z.infer<typeof loginSchema>

export const registerSchema = z.object({
  firstName: z.string().min(1, "First name is required"),
  lastName: z.string().min(1, "Last name is required"),
  email: emailSchema,
  password: passwordSchema,
  confirmPassword: z.string(),
  acceptTerms: z.boolean().refine((val) => val === true, {
    message: "You must accept the terms and conditions",
  }),
}).refine(
  (data) => data.password === data.confirmPassword,
  {
    message: "Passwords don't match",
    path: ["confirmPassword"],
  }
)

export type RegisterFormData = z.infer<typeof registerSchema>

// Template schema
export const templateSchema = z.object({
  name: z.string().min(1, "Template name is required"),
  description: z.string().optional(),
  category: z.enum(['email', 'social', 'blog', 'landing-page', 'ad'], {
    message: "Please select a category",
  }),
  content: z.string().min(1, "Template content is required"),
  variables: z.array(z.string()).optional(),
  isPublic: z.boolean().optional(),
})

export type TemplateFormData = z.infer<typeof templateSchema>