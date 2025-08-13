// Channel preview types and configurations for different marketing channels

export type MarketingChannel = 
  | 'facebook'
  | 'instagram'
  | 'twitter'
  | 'linkedin'
  | 'email'
  | 'google-ads'
  | 'facebook-ads'
  | 'display-ad'
  | 'landing-page'
  | 'blog'
  | 'youtube'
  | 'tiktok'

export type ContentFormat = 
  | 'social-post'
  | 'story'
  | 'reel'
  | 'carousel'
  | 'video'
  | 'email-template'
  | 'search-ad'
  | 'display-ad'
  | 'banner-ad'
  | 'landing-page'
  | 'blog-post'
  | 'newsletter'

export interface ContentDimensions {
  width: number
  height: number
  aspectRatio: string
}

export interface ChannelLimits {
  maxTextLength?: number
  maxHashtags?: number
  maxMentions?: number
  maxImages?: number
  maxVideos?: number
  videoMaxDuration?: number // in seconds
  imageFormats?: string[]
  videoFormats?: string[]
  minDimensions?: ContentDimensions
  maxDimensions?: ContentDimensions
  recommendedDimensions?: ContentDimensions[]
}

export interface ChannelPreviewConfig {
  channel: MarketingChannel
  format: ContentFormat
  name: string
  description: string
  dimensions: ContentDimensions
  limits: ChannelLimits
  previewClassName: string
  containerClassName: string
  deviceFrame?: 'mobile' | 'tablet' | 'desktop' | 'none'
  supportedFeatures: {
    text: boolean
    images: boolean
    video: boolean
    hashtags: boolean
    mentions: boolean
    links: boolean
    emojis: boolean
    formatting: boolean
  }
  brandingElements: {
    logo: boolean
    colors: boolean
    fonts: boolean
    overlay: boolean
  }
}

export interface PreviewContent {
  id?: string
  text?: string
  headline?: string
  subtext?: string
  callToAction?: string
  images?: Array<{
    url: string
    alt: string
    width?: number
    height?: number
  }>
  video?: {
    url: string
    thumbnail?: string
    duration?: number
  }
  hashtags?: string[]
  mentions?: string[]
  links?: Array<{
    url: string
    text: string
    isButton?: boolean
  }>
  branding?: {
    logoUrl?: string
    colors?: string[]
    fontFamily?: string
    companyName?: string
  }
  metadata?: {
    timestamp?: Date
    author?: string
    engagement?: {
      likes?: number
      shares?: number
      comments?: number
      views?: number
    }
  }
}

export interface ValidationResult {
  isValid: boolean
  warnings: Array<{
    type: 'length' | 'format' | 'dimension' | 'content' | 'accessibility'
    message: string
    severity: 'error' | 'warning' | 'info'
    field?: string
  }>
  characterCount?: number
  characterLimit?: number
  suggestions: string[]
}

export interface ExportOptions {
  format: 'json' | 'html' | 'png' | 'jpg' | 'pdf' | 'csv'
  quality?: 'low' | 'medium' | 'high'
  includeMetadata?: boolean
  templateId?: string
  customDimensions?: ContentDimensions
}

// Channel configuration definitions
export const CHANNEL_CONFIGS: Record<string, ChannelPreviewConfig> = {
  // Social Media - Facebook
  'facebook-post': {
    channel: 'facebook',
    format: 'social-post',
    name: 'Facebook Post',
    description: 'Standard Facebook news feed post',
    dimensions: { width: 500, height: 400, aspectRatio: '5:4' },
    limits: {
      maxTextLength: 63206,
      maxImages: 10,
      maxVideos: 1,
      videoMaxDuration: 240,
      imageFormats: ['jpg', 'png', 'gif'],
      videoFormats: ['mp4', 'mov'],
      recommendedDimensions: [
        { width: 1200, height: 630, aspectRatio: '1.91:1' },
        { width: 1080, height: 1080, aspectRatio: '1:1' }
      ]
    },
    previewClassName: 'facebook-post-preview',
    containerClassName: 'bg-white border rounded-lg shadow-sm',
    deviceFrame: 'desktop',
    supportedFeatures: {
      text: true,
      images: true,
      video: true,
      hashtags: true,
      mentions: true,
      links: true,
      emojis: true,
      formatting: false
    },
    brandingElements: {
      logo: true,
      colors: true,
      fonts: false,
      overlay: false
    }
  },

  'facebook-story': {
    channel: 'facebook',
    format: 'story',
    name: 'Facebook Story',
    description: 'Vertical Facebook story format',
    dimensions: { width: 360, height: 640, aspectRatio: '9:16' },
    limits: {
      maxTextLength: 500,
      maxImages: 1,
      maxVideos: 1,
      videoMaxDuration: 15,
      recommendedDimensions: [
        { width: 1080, height: 1920, aspectRatio: '9:16' }
      ]
    },
    previewClassName: 'facebook-story-preview',
    containerClassName: 'bg-black rounded-lg overflow-hidden',
    deviceFrame: 'mobile',
    supportedFeatures: {
      text: true,
      images: true,
      video: true,
      hashtags: false,
      mentions: true,
      links: false,
      emojis: true,
      formatting: false
    },
    brandingElements: {
      logo: true,
      colors: true,
      fonts: true,
      overlay: true
    }
  },

  // Social Media - Instagram
  'instagram-post': {
    channel: 'instagram',
    format: 'social-post',
    name: 'Instagram Post',
    description: 'Square Instagram feed post',
    dimensions: { width: 400, height: 400, aspectRatio: '1:1' },
    limits: {
      maxTextLength: 2200,
      maxHashtags: 30,
      maxImages: 10,
      maxVideos: 1,
      videoMaxDuration: 60,
      recommendedDimensions: [
        { width: 1080, height: 1080, aspectRatio: '1:1' },
        { width: 1080, height: 1350, aspectRatio: '4:5' }
      ]
    },
    previewClassName: 'instagram-post-preview',
    containerClassName: 'bg-white rounded-lg shadow-sm',
    deviceFrame: 'mobile',
    supportedFeatures: {
      text: true,
      images: true,
      video: true,
      hashtags: true,
      mentions: true,
      links: false,
      emojis: true,
      formatting: false
    },
    brandingElements: {
      logo: true,
      colors: true,
      fonts: false,
      overlay: false
    }
  },

  'instagram-story': {
    channel: 'instagram',
    format: 'story',
    name: 'Instagram Story',
    description: 'Vertical Instagram story format',
    dimensions: { width: 360, height: 640, aspectRatio: '9:16' },
    limits: {
      maxTextLength: 500,
      maxHashtags: 10,
      maxImages: 1,
      maxVideos: 1,
      videoMaxDuration: 15,
      recommendedDimensions: [
        { width: 1080, height: 1920, aspectRatio: '9:16' }
      ]
    },
    previewClassName: 'instagram-story-preview',
    containerClassName: 'bg-gradient-to-br from-purple-400 via-pink-500 to-red-500 rounded-lg overflow-hidden',
    deviceFrame: 'mobile',
    supportedFeatures: {
      text: true,
      images: true,
      video: true,
      hashtags: true,
      mentions: true,
      links: false,
      emojis: true,
      formatting: false
    },
    brandingElements: {
      logo: true,
      colors: true,
      fonts: true,
      overlay: true
    }
  },

  'instagram-reel': {
    channel: 'instagram',
    format: 'reel',
    name: 'Instagram Reel',
    description: 'Vertical Instagram reel video format',
    dimensions: { width: 360, height: 640, aspectRatio: '9:16' },
    limits: {
      maxTextLength: 2200,
      maxHashtags: 30,
      maxVideos: 1,
      videoMaxDuration: 90,
      recommendedDimensions: [
        { width: 1080, height: 1920, aspectRatio: '9:16' }
      ]
    },
    previewClassName: 'instagram-reel-preview',
    containerClassName: 'bg-black rounded-lg overflow-hidden',
    deviceFrame: 'mobile',
    supportedFeatures: {
      text: true,
      images: false,
      video: true,
      hashtags: true,
      mentions: true,
      links: false,
      emojis: true,
      formatting: false
    },
    brandingElements: {
      logo: true,
      colors: true,
      fonts: true,
      overlay: true
    }
  },

  // Social Media - Twitter/X
  'twitter-post': {
    channel: 'twitter',
    format: 'social-post',
    name: 'Twitter/X Post',
    description: 'Standard Twitter/X post',
    dimensions: { width: 500, height: 300, aspectRatio: '5:3' },
    limits: {
      maxTextLength: 280,
      maxImages: 4,
      maxVideos: 1,
      videoMaxDuration: 140,
      recommendedDimensions: [
        { width: 1200, height: 675, aspectRatio: '16:9' },
        { width: 1080, height: 1080, aspectRatio: '1:1' }
      ]
    },
    previewClassName: 'twitter-post-preview',
    containerClassName: 'bg-white border rounded-lg',
    deviceFrame: 'desktop',
    supportedFeatures: {
      text: true,
      images: true,
      video: true,
      hashtags: true,
      mentions: true,
      links: true,
      emojis: true,
      formatting: false
    },
    brandingElements: {
      logo: false,
      colors: false,
      fonts: false,
      overlay: false
    }
  },

  // Social Media - LinkedIn
  'linkedin-post': {
    channel: 'linkedin',
    format: 'social-post',
    name: 'LinkedIn Post',
    description: 'Professional LinkedIn post',
    dimensions: { width: 500, height: 400, aspectRatio: '5:4' },
    limits: {
      maxTextLength: 3000,
      maxImages: 9,
      maxVideos: 1,
      videoMaxDuration: 600,
      recommendedDimensions: [
        { width: 1200, height: 627, aspectRatio: '1.91:1' },
        { width: 1080, height: 1080, aspectRatio: '1:1' }
      ]
    },
    previewClassName: 'linkedin-post-preview',
    containerClassName: 'bg-white border rounded-lg shadow-sm',
    deviceFrame: 'desktop',
    supportedFeatures: {
      text: true,
      images: true,
      video: true,
      hashtags: true,
      mentions: true,
      links: true,
      emojis: true,
      formatting: false
    },
    brandingElements: {
      logo: true,
      colors: true,
      fonts: false,
      overlay: false
    }
  },

  // Email Templates
  'email-newsletter': {
    channel: 'email',
    format: 'newsletter',
    name: 'Email Newsletter',
    description: 'Email newsletter template',
    dimensions: { width: 600, height: 800, aspectRatio: '3:4' },
    limits: {
      maxTextLength: 50000,
      maxImages: 20,
      imageFormats: ['jpg', 'png', 'gif'],
      recommendedDimensions: [
        { width: 600, height: 400, aspectRatio: '3:2' }
      ]
    },
    previewClassName: 'email-newsletter-preview',
    containerClassName: 'bg-white shadow-lg',
    deviceFrame: 'desktop',
    supportedFeatures: {
      text: true,
      images: true,
      video: false,
      hashtags: false,
      mentions: false,
      links: true,
      emojis: true,
      formatting: true
    },
    brandingElements: {
      logo: true,
      colors: true,
      fonts: true,
      overlay: false
    }
  },

  'email-promotional': {
    channel: 'email',
    format: 'email-template',
    name: 'Promotional Email',
    description: 'Marketing promotional email',
    dimensions: { width: 600, height: 600, aspectRatio: '1:1' },
    limits: {
      maxTextLength: 5000,
      maxImages: 10,
      imageFormats: ['jpg', 'png', 'gif']
    },
    previewClassName: 'email-promotional-preview',
    containerClassName: 'bg-white shadow-lg',
    deviceFrame: 'desktop',
    supportedFeatures: {
      text: true,
      images: true,
      video: false,
      hashtags: false,
      mentions: false,
      links: true,
      emojis: true,
      formatting: true
    },
    brandingElements: {
      logo: true,
      colors: true,
      fonts: true,
      overlay: false
    }
  },

  // Advertising
  'google-search-ad': {
    channel: 'google-ads',
    format: 'search-ad',
    name: 'Google Search Ad',
    description: 'Text-based Google search advertisement',
    dimensions: { width: 500, height: 200, aspectRatio: '5:2' },
    limits: {
      maxTextLength: 90,
      maxImages: 0,
      maxVideos: 0
    },
    previewClassName: 'google-search-ad-preview',
    containerClassName: 'bg-white border rounded p-4',
    deviceFrame: 'desktop',
    supportedFeatures: {
      text: true,
      images: false,
      video: false,
      hashtags: false,
      mentions: false,
      links: true,
      emojis: false,
      formatting: false
    },
    brandingElements: {
      logo: false,
      colors: false,
      fonts: false,
      overlay: false
    }
  },

  'facebook-ad': {
    channel: 'facebook-ads',
    format: 'display-ad',
    name: 'Facebook Ad',
    description: 'Facebook advertising format',
    dimensions: { width: 400, height: 400, aspectRatio: '1:1' },
    limits: {
      maxTextLength: 125,
      maxImages: 1,
      maxVideos: 1,
      videoMaxDuration: 240,
      recommendedDimensions: [
        { width: 1080, height: 1080, aspectRatio: '1:1' },
        { width: 1200, height: 628, aspectRatio: '1.91:1' }
      ]
    },
    previewClassName: 'facebook-ad-preview',
    containerClassName: 'bg-white border rounded-lg shadow-sm',
    deviceFrame: 'mobile',
    supportedFeatures: {
      text: true,
      images: true,
      video: true,
      hashtags: false,
      mentions: false,
      links: true,
      emojis: true,
      formatting: false
    },
    brandingElements: {
      logo: true,
      colors: true,
      fonts: false,
      overlay: false
    }
  },

  // Web Content
  'landing-page-hero': {
    channel: 'landing-page',
    format: 'landing-page',
    name: 'Landing Page Hero',
    description: 'Hero section of a landing page',
    dimensions: { width: 800, height: 600, aspectRatio: '4:3' },
    limits: {
      maxTextLength: 1000,
      maxImages: 5
    },
    previewClassName: 'landing-page-hero-preview',
    containerClassName: 'bg-gradient-to-r from-blue-500 to-purple-600 text-white',
    deviceFrame: 'desktop',
    supportedFeatures: {
      text: true,
      images: true,
      video: true,
      hashtags: false,
      mentions: false,
      links: true,
      emojis: false,
      formatting: true
    },
    brandingElements: {
      logo: true,
      colors: true,
      fonts: true,
      overlay: false
    }
  },

  'blog-post-header': {
    channel: 'blog',
    format: 'blog-post',
    name: 'Blog Post Header',
    description: 'Blog article header and featured image',
    dimensions: { width: 800, height: 400, aspectRatio: '2:1' },
    limits: {
      maxTextLength: 200,
      maxImages: 1,
      recommendedDimensions: [
        { width: 1200, height: 630, aspectRatio: '1.91:1' }
      ]
    },
    previewClassName: 'blog-post-header-preview',
    containerClassName: 'bg-white',
    deviceFrame: 'desktop',
    supportedFeatures: {
      text: true,
      images: true,
      video: false,
      hashtags: false,
      mentions: false,
      links: false,
      emojis: false,
      formatting: true
    },
    brandingElements: {
      logo: true,
      colors: true,
      fonts: true,
      overlay: true
    }
  }
}

// Utility functions for channel previews
export function getChannelConfig(configId: string): ChannelPreviewConfig | null {
  return CHANNEL_CONFIGS[configId] || null
}

export function getChannelsByType(channel: MarketingChannel): ChannelPreviewConfig[] {
  return Object.values(CHANNEL_CONFIGS).filter(config => config.channel === channel)
}

export function validateContent(content: PreviewContent, config: ChannelPreviewConfig): ValidationResult {
  const warnings: ValidationResult['warnings'] = []
  const suggestions: string[] = []

  // Text length validation
  if (content.text && config.limits.maxTextLength) {
    const characterCount = content.text.length
    const characterLimit = config.limits.maxTextLength

    if (characterCount > characterLimit) {
      warnings.push({
        type: 'length',
        message: `Text exceeds ${characterLimit} character limit by ${characterCount - characterLimit} characters`,
        severity: 'error',
        field: 'text'
      })
    } else if (characterCount > characterLimit * 0.9) {
      warnings.push({
        type: 'length',
        message: `Text is approaching the ${characterLimit} character limit`,
        severity: 'warning',
        field: 'text'
      })
    }
  }

  // Hashtag validation
  if (content.hashtags && config.limits.maxHashtags) {
    if (content.hashtags.length > config.limits.maxHashtags) {
      warnings.push({
        type: 'content',
        message: `Too many hashtags (${content.hashtags.length}). Maximum allowed: ${config.limits.maxHashtags}`,
        severity: 'error',
        field: 'hashtags'
      })
    }
  }

  // Image validation
  if (content.images && config.limits.maxImages) {
    if (content.images.length > config.limits.maxImages) {
      warnings.push({
        type: 'content',
        message: `Too many images (${content.images.length}). Maximum allowed: ${config.limits.maxImages}`,
        severity: 'error',
        field: 'images'
      })
    }
  }

  // Feature support validation
  if (content.hashtags?.length && !config.supportedFeatures.hashtags) {
    warnings.push({
      type: 'content',
      message: `Hashtags are not supported on ${config.name}`,
      severity: 'warning',
      field: 'hashtags'
    })
    suggestions.push('Consider removing hashtags or using a different channel')
  }

  if (content.video && !config.supportedFeatures.video) {
    warnings.push({
      type: 'content',
      message: `Video content is not supported on ${config.name}`,
      severity: 'error',
      field: 'video'
    })
  }

  // Add helpful suggestions
  if (config.channel === 'instagram' && (!content.hashtags || content.hashtags.length < 5)) {
    suggestions.push('Instagram posts perform better with 5-10 relevant hashtags')
  }

  if (config.channel === 'twitter' && content.text && content.text.length < 100) {
    suggestions.push('Twitter posts with 100-280 characters tend to get more engagement')
  }

  if (config.format === 'email-template' && !content.callToAction) {
    suggestions.push('Consider adding a clear call-to-action button for better conversion')
  }

  return {
    isValid: warnings.filter(w => w.severity === 'error').length === 0,
    warnings,
    characterCount: content.text?.length || 0,
    characterLimit: config.limits.maxTextLength,
    suggestions
  }
}

export function exportContent(
  content: PreviewContent, 
  config: ChannelPreviewConfig, 
  options: ExportOptions
): Promise<string | Blob> {
  return new Promise((resolve, reject) => {
    try {
      switch (options.format) {
        case 'json':
          const jsonData = {
            content,
            config: options.includeMetadata ? config : { name: config.name, channel: config.channel },
            exportedAt: new Date(),
            format: options.format
          }
          resolve(JSON.stringify(jsonData, null, 2))
          break

        case 'html':
          // Generate HTML representation
          const html = generateHTMLPreview(content, config)
          resolve(html)
          break

        case 'csv':
          // Generate CSV for content analysis
          const csv = generateCSVExport(content, config)
          resolve(csv)
          break

        default:
          reject(new Error(`Export format ${options.format} not yet implemented`))
      }
    } catch (error) {
      reject(error)
    }
  })
}

function generateHTMLPreview(content: PreviewContent, config: ChannelPreviewConfig): string {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${config.name} Preview</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .preview-container { max-width: ${config.dimensions.width}px; margin: 0 auto; }
        .content-text { font-size: 14px; line-height: 1.4; }
        .hashtags { color: #1da1f2; }
        .cta-button { background: #1da1f2; color: white; padding: 10px 20px; border-radius: 5px; text-decoration: none; }
    </style>
</head>
<body>
    <div class="preview-container">
        <h1>${config.name}</h1>
        ${content.text ? `<div class="content-text">${content.text}</div>` : ''}
        ${content.callToAction ? `<a href="#" class="cta-button">${content.callToAction}</a>` : ''}
        ${content.hashtags ? `<div class="hashtags">${content.hashtags.map(tag => `#${tag}`).join(' ')}</div>` : ''}
    </div>
</body>
</html>`
}

function generateCSVExport(content: PreviewContent, config: ChannelPreviewConfig): string {
  const rows = [
    ['Field', 'Value'],
    ['Channel', config.channel],
    ['Format', config.format],
    ['Text Length', content.text?.length || 0],
    ['Character Limit', config.limits.maxTextLength || 'No limit'],
    ['Has Images', content.images ? content.images.length : 0],
    ['Has Video', content.video ? 'Yes' : 'No'],
    ['Hashtag Count', content.hashtags?.length || 0],
    ['Has CTA', content.callToAction ? 'Yes' : 'No'],
    ['Text', content.text || ''],
    ['Call to Action', content.callToAction || ''],
    ['Hashtags', content.hashtags?.join(', ') || '']
  ]

  return rows.map(row => row.map(cell => `"${cell}"`).join(',')).join('\n')
}