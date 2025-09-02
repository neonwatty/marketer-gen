import { z } from 'zod'

import { CampaignStatus } from '@/generated/prisma'

export const createCampaignSchema = z.object({
  name: z.string().min(1, 'Campaign name is required').max(255, 'Campaign name must be less than 255 characters'),
  purpose: z.string().optional(),
  goals: z.any().optional(), // JSON field
  brandId: z.string().min(1, 'Brand ID is required'),
  startDate: z.string().datetime().optional().or(z.null()),
  endDate: z.string().datetime().optional().or(z.null()),
  status: z.nativeEnum(CampaignStatus).optional().default('DRAFT')
}).refine(
  (data) => {
    if (data.startDate && data.endDate) {
      return new Date(data.startDate) <= new Date(data.endDate)
    }
    return true
  },
  {
    message: 'End date must be after start date',
    path: ['endDate']
  }
)

export const updateCampaignSchema = z.object({
  name: z.string().min(1, 'Campaign name is required').max(255, 'Campaign name must be less than 255 characters').optional(),
  purpose: z.string().optional(),
  goals: z.any().optional(), // JSON field
  brandId: z.string().min(1, 'Brand ID is required').optional(),
  startDate: z.string().datetime().optional().or(z.null()),
  endDate: z.string().datetime().optional().or(z.null()),
  status: z.nativeEnum(CampaignStatus).optional()
}).refine(
  (data) => {
    if (data.startDate && data.endDate) {
      return new Date(data.startDate) <= new Date(data.endDate)
    }
    return true
  },
  {
    message: 'End date must be after start date',
    path: ['endDate']
  }
)

export const duplicateCampaignSchema = z.object({
  name: z.string().min(1, 'Campaign name is required').max(255, 'Campaign name must be less than 255 characters')
})

export const campaignQuerySchema = z.object({
  page: z.union([z.string(), z.null()]).optional().transform(val => val && val !== null ? parseInt(val, 10) : 1).refine(n => n > 0, 'Page must be positive'),
  limit: z.union([z.string(), z.null()]).optional().transform(val => val && val !== null ? parseInt(val, 10) : 10).refine(n => n > 0 && n <= 100, 'Limit must be between 1 and 100'),
  status: z.nativeEnum(CampaignStatus).optional(),
  brandId: z.union([z.string(), z.null()]).optional()
})

export const journeyTemplateRequestSchema = z.object({
  templateId: z.string().min(1, 'Template ID is required'),
  campaignId: z.string().min(1, 'Campaign ID is required'),
  customizations: z.record(z.string(), z.any()).default({})
})

export type CreateCampaignData = z.infer<typeof createCampaignSchema>
export type UpdateCampaignData = z.infer<typeof updateCampaignSchema>
export type DuplicateCampaignData = z.infer<typeof duplicateCampaignSchema>
export type CampaignQueryParams = z.infer<typeof campaignQuerySchema>
export type JourneyTemplateRequest = z.infer<typeof journeyTemplateRequestSchema>