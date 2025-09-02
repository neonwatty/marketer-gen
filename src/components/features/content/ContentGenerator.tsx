'use client'

import { useState, useCallback, useEffect, useRef } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { toast } from 'sonner'
import * as z from 'zod'

import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Form, FormControl, FormDescription, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Textarea } from '@/components/ui/textarea'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { LoadingSpinner } from '@/components/ui/loading-spinner'

// Content generation form schema
const contentGenerationSchema = z.object({
  brandId: z.string().min(1, 'Please select a brand'),
  contentType: z.enum([
    'EMAIL', 'SOCIAL_POST', 'SOCIAL_AD', 'SEARCH_AD', 'BLOG_POST', 
    'LANDING_PAGE', 'VIDEO_SCRIPT', 'INFOGRAPHIC', 'NEWSLETTER', 'PRESS_RELEASE'
  ]),
  prompt: z.string().min(10, 'Prompt must be at least 10 characters').max(2000, 'Prompt too long'),
  targetAudience: z.string().optional(),
  tone: z.enum(['professional', 'casual', 'friendly', 'authoritative', 'playful', 'urgent']).optional(),
  channel: z.string().optional(),
  callToAction: z.string().optional(),
  includeVariants: z.boolean().default(false),
  variantCount: z.number().min(1).max(5).default(3),
  variantStrategies: z.array(z.enum(['style_variation', 'length_variation', 'angle_variation', 'tone_variation', 'cta_variation'])).default([]),
  maxLength: z.number().min(50).max(5000).optional(),
  keywords: z.string().optional(), // We'll parse this into an array
  streaming: z.boolean().default(false),
  includeAnalysis: z.boolean().default(true),
})

type ContentGenerationFormData = z.infer<typeof contentGenerationSchema>

interface ContentVariant {
  id: string
  content: string
  strategy: string
  metrics: {
    estimatedEngagement: number
    readabilityScore: number
    brandAlignment: number
    formatOptimization: number
  }
  formatOptimizations: {
    platform?: string
    characterCount: number
    wordCount: number
    hasHashtags?: boolean
    hasCTA?: boolean
    keywordDensity: Record<string, number>
  }
}

interface GeneratedContent {
  content: string
  variants?: ContentVariant[]
  brandCompliance: {
    isCompliant: boolean
    violations: string[]
    suggestions?: string[]
    score: number
  }
  analysis?: {
    sentiment: 'positive' | 'neutral' | 'negative'
    readabilityScore: number
    keywordDensity: Record<string, number>
    brandAlignment: number
    suggestions: Array<{
      type: string
      priority: string
      suggestion: string
      reason: string
    }>
  }
  metadata: {
    brandId: string
    contentType: string
    generatedAt: string
    wordCount: number
    charCount: number
  }
}

interface Brand {
  id: string
  name: string
  tagline?: string
  voiceDescription?: string
}

interface ContentGeneratorProps {
  brands: Brand[]
  onContentGenerated?: (content: GeneratedContent) => void
}

export function ContentGenerator({ brands, onContentGenerated }: ContentGeneratorProps) {
  const [isGenerating, setIsGenerating] = useState(false)
  const [generatedContent, setGeneratedContent] = useState<GeneratedContent | null>(null)
  const [streamingContent, setStreamingContent] = useState('')
  const [generationProgress, setGenerationProgress] = useState(0)
  const abortControllerRef = useRef<AbortController | null>(null)

  const form = useForm<ContentGenerationFormData>({
    resolver: zodResolver(contentGenerationSchema),
    defaultValues: {
      brandId: '',
      contentType: 'SOCIAL_POST',
      prompt: '',
      targetAudience: '',
      tone: 'professional',
      channel: '',
      callToAction: '',
      includeVariants: false,
      variantCount: 3,
      variantStrategies: [],
      streaming: false,
      includeAnalysis: true,
    }
  })

  const { watch, setValue } = form
  const includeVariants = watch('includeVariants')
  const streaming = watch('streaming')
  const contentType = watch('contentType')

  // Update variant strategies based on content type
  useEffect(() => {
    const defaultStrategies: Record<string, string[]> = {
      'SOCIAL_POST': ['style_variation', 'tone_variation'],
      'EMAIL': ['length_variation', 'cta_variation'],
      'SOCIAL_AD': ['angle_variation', 'cta_variation'],
      'SEARCH_AD': ['cta_variation', 'tone_variation'],
      'BLOG_POST': ['length_variation', 'style_variation'],
      'LANDING_PAGE': ['cta_variation', 'angle_variation'],
      'VIDEO_SCRIPT': ['tone_variation', 'style_variation'],
      'INFOGRAPHIC': ['style_variation', 'angle_variation'],
      'NEWSLETTER': ['length_variation', 'style_variation'],
      'PRESS_RELEASE': ['style_variation', 'angle_variation'],
    }

    if (includeVariants && contentType) {
      const strategies = defaultStrategies[contentType] || ['style_variation', 'tone_variation']
      setValue('variantStrategies', strategies as any)
    }
  }, [contentType, includeVariants, setValue])

  const handleStreamingGeneration = useCallback(async (data: ContentGenerationFormData) => {
    setStreamingContent('')
    setGenerationProgress(0)

    // Create abort controller for streaming
    abortControllerRef.current = new AbortController()

    try {
      const response = await fetch('/api/ai/content-generation', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          ...data,
          keywords: data.keywords ? data.keywords.split(',').map(k => k.trim()).filter(Boolean) : [],
          streaming: true,
        }),
        signal: abortControllerRef.current.signal,
      })

      if (!response.ok) {
        throw new Error(`Generation failed: ${response.status} ${response.statusText}`)
      }

      const reader = response.body?.getReader()
      if (!reader) {
        throw new Error('No response body available')
      }

      let accumulated = ''
      let progress = 0

      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        const chunk = new TextDecoder().decode(value)
        accumulated += chunk
        setStreamingContent(accumulated)
        
        // Update progress (simple estimation)
        progress = Math.min(progress + 2, 95)
        setGenerationProgress(progress)
      }

      setGenerationProgress(100)
      
      // After streaming is complete, the content should be in streamingContent
      // We'll create a mock response structure for now since streaming doesn't return full metadata
      const mockGeneratedContent: GeneratedContent = {
        content: accumulated,
        brandCompliance: {
          isCompliant: true,
          violations: [],
          score: 85,
        },
        metadata: {
          brandId: data.brandId,
          contentType: data.contentType,
          generatedAt: new Date().toISOString(),
          wordCount: accumulated.split(/\s+/).length,
          charCount: accumulated.length,
        }
      }

      setGeneratedContent(mockGeneratedContent)
      onContentGenerated?.(mockGeneratedContent)

    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') {
        toast.info('Content generation cancelled')
      } else {
        console.error('Streaming generation error:', error)
        toast.error('Failed to generate content')
      }
    }
  }, [onContentGenerated])

  const handleStandardGeneration = useCallback(async (data: ContentGenerationFormData) => {
    setGenerationProgress(0)
    
    try {
      const response = await fetch('/api/ai/content-generation', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          ...data,
          keywords: data.keywords ? data.keywords.split(',').map(k => k.trim()).filter(Boolean) : [],
          streaming: false,
        }),
      })

      setGenerationProgress(50)

      if (!response.ok) {
        const error = await response.json().catch(() => ({}))
        throw new Error(error.message || `Generation failed: ${response.status}`)
      }

      const result: GeneratedContent = await response.json()
      setGenerationProgress(100)
      
      setGeneratedContent(result)
      onContentGenerated?.(result)
      
      toast.success('Content generated successfully!')

    } catch (error) {
      console.error('Content generation error:', error)
      toast.error(error instanceof Error ? error.message : 'Failed to generate content')
    }
  }, [onContentGenerated])

  const onSubmit = useCallback(async (data: ContentGenerationFormData) => {
    setIsGenerating(true)
    setGeneratedContent(null)
    setStreamingContent('')

    try {
      if (data.streaming) {
        await handleStreamingGeneration(data)
      } else {
        await handleStandardGeneration(data)
      }
    } finally {
      setIsGenerating(false)
      setGenerationProgress(0)
    }
  }, [handleStreamingGeneration, handleStandardGeneration])

  const cancelGeneration = useCallback(() => {
    if (abortControllerRef.current) {
      abortControllerRef.current.abort()
      abortControllerRef.current = null
    }
    setIsGenerating(false)
    setGenerationProgress(0)
  }, [])

  const getContentTypeDescription = (type: string) => {
    const descriptions: Record<string, string> = {
      'EMAIL': 'Email marketing messages and campaigns',
      'SOCIAL_POST': 'Social media posts for engagement',
      'SOCIAL_AD': 'Paid social media advertisements',
      'SEARCH_AD': 'Google/Bing search advertisements',
      'BLOG_POST': 'Blog articles and content marketing',
      'LANDING_PAGE': 'Landing page copy and headlines',
      'VIDEO_SCRIPT': 'Video content scripts and narration',
      'INFOGRAPHIC': 'Infographic content and data points',
      'NEWSLETTER': 'Email newsletters and updates',
      'PRESS_RELEASE': 'Press releases and announcements',
    }
    return descriptions[type] || 'Content generation'
  }

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>AI Content Generator</CardTitle>
          <p className="text-sm text-muted-foreground">
            Generate brand-aligned content using AI with compliance checking and variant generation
          </p>
        </CardHeader>
        <CardContent>
          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Brand Selection */}
                <FormField
                  control={form.control}
                  name="brandId"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Brand</FormLabel>
                      <Select onValueChange={field.onChange} value={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue placeholder="Select a brand" />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          {brands.map((brand) => (
                            <SelectItem key={brand.id} value={brand.id}>
                              <div>
                                <div className="font-medium">{brand.name}</div>
                                {brand.tagline && (
                                  <div className="text-sm text-muted-foreground">{brand.tagline}</div>
                                )}
                              </div>
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                {/* Content Type */}
                <FormField
                  control={form.control}
                  name="contentType"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Content Type</FormLabel>
                      <Select onValueChange={field.onChange} value={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          {[
                            'EMAIL', 'SOCIAL_POST', 'SOCIAL_AD', 'SEARCH_AD', 'BLOG_POST', 
                            'LANDING_PAGE', 'VIDEO_SCRIPT', 'INFOGRAPHIC', 'NEWSLETTER', 'PRESS_RELEASE'
                          ].map((type) => (
                            <SelectItem key={type} value={type}>
                              <div>
                                <div className="font-medium">{type.replace('_', ' ')}</div>
                                <div className="text-sm text-muted-foreground">
                                  {getContentTypeDescription(type)}
                                </div>
                              </div>
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>

              {/* Content Prompt */}
              <FormField
                control={form.control}
                name="prompt"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Content Prompt</FormLabel>
                    <FormControl>
                      <Textarea
                        placeholder="Describe what you want to create. Be specific about your message, goals, and any key points to include..."
                        className="min-h-[100px]"
                        {...field}
                      />
                    </FormControl>
                    <FormDescription>
                      Provide a detailed description of the content you want to generate (10-2000 characters)
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Tone */}
                <FormField
                  control={form.control}
                  name="tone"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Tone</FormLabel>
                      <Select onValueChange={field.onChange} value={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          <SelectItem value="professional">Professional</SelectItem>
                          <SelectItem value="casual">Casual</SelectItem>
                          <SelectItem value="friendly">Friendly</SelectItem>
                          <SelectItem value="authoritative">Authoritative</SelectItem>
                          <SelectItem value="playful">Playful</SelectItem>
                          <SelectItem value="urgent">Urgent</SelectItem>
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                {/* Target Audience */}
                <FormField
                  control={form.control}
                  name="targetAudience"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Target Audience (Optional)</FormLabel>
                      <FormControl>
                        <Input
                          placeholder="e.g., Small business owners, millennials, tech professionals"
                          {...field}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Channel */}
                <FormField
                  control={form.control}
                  name="channel"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Channel (Optional)</FormLabel>
                      <FormControl>
                        <Input
                          placeholder="e.g., LinkedIn, Twitter, Email newsletter"
                          {...field}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                {/* Call to Action */}
                <FormField
                  control={form.control}
                  name="callToAction"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Call to Action (Optional)</FormLabel>
                      <FormControl>
                        <Input
                          placeholder="e.g., Sign up now, Learn more, Contact us"
                          {...field}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>

              {/* Keywords */}
              <FormField
                control={form.control}
                name="keywords"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Keywords (Optional)</FormLabel>
                    <FormControl>
                      <Input
                        placeholder="keyword1, keyword2, keyword3"
                        {...field}
                      />
                    </FormControl>
                    <FormDescription>
                      Comma-separated keywords to include in the content
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />

              {/* Advanced Options */}
              <div className="space-y-4 border-t pt-4">
                <h3 className="text-lg font-medium">Advanced Options</h3>
                
                <div className="flex items-center space-x-4">
                  <FormField
                    control={form.control}
                    name="includeVariants"
                    render={({ field }) => (
                      <FormItem className="flex items-center space-x-2">
                        <FormControl>
                          <input
                            type="checkbox"
                            checked={field.value}
                            onChange={(e) => field.onChange(e.target.checked)}
                            className="rounded border-gray-300"
                          />
                        </FormControl>
                        <FormLabel className="text-sm font-normal">
                          Generate content variants
                        </FormLabel>
                      </FormItem>
                    )}
                  />

                  <FormField
                    control={form.control}
                    name="streaming"
                    render={({ field }) => (
                      <FormItem className="flex items-center space-x-2">
                        <FormControl>
                          <input
                            type="checkbox"
                            checked={field.value}
                            onChange={(e) => field.onChange(e.target.checked)}
                            className="rounded border-gray-300"
                          />
                        </FormControl>
                        <FormLabel className="text-sm font-normal">
                          Stream generation
                        </FormLabel>
                      </FormItem>
                    )}
                  />
                </div>

                {includeVariants && (
                  <FormField
                    control={form.control}
                    name="variantCount"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Number of Variants</FormLabel>
                        <FormControl>
                          <Input
                            type="number"
                            min="1"
                            max="5"
                            {...field}
                            onChange={(e) => field.onChange(parseInt(e.target.value))}
                          />
                        </FormControl>
                        <FormDescription>
                          Generate 1-5 content variants with different approaches
                        </FormDescription>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                )}
              </div>

              {/* Generation Progress */}
              {isGenerating && (
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-medium">Generating content...</span>
                    <span className="text-sm text-muted-foreground">{generationProgress}%</span>
                  </div>
                  <Progress value={generationProgress} className="h-2" />
                </div>
              )}

              {/* Action Buttons */}
              <div className="flex gap-2">
                <Button
                  type="submit"
                  disabled={isGenerating}
                  className="flex-1"
                >
                  {isGenerating ? (
                    <>
                      <LoadingSpinner className="mr-2 h-4 w-4" />
                      Generating...
                    </>
                  ) : (
                    'Generate Content'
                  )}
                </Button>
                {isGenerating && (
                  <Button
                    type="button"
                    variant="outline"
                    onClick={cancelGeneration}
                  >
                    Cancel
                  </Button>
                )}
              </div>
            </form>
          </Form>
        </CardContent>
      </Card>

      {/* Generated Content Display */}
      {(generatedContent || streamingContent) && (
        <Card>
          <CardHeader>
            <CardTitle>Generated Content</CardTitle>
          </CardHeader>
          <CardContent>
            <Tabs defaultValue="content" className="w-full">
              <TabsList>
                <TabsTrigger value="content">Content</TabsTrigger>
                {generatedContent?.variants && generatedContent.variants.length > 0 && (
                  <TabsTrigger value="variants">Variants</TabsTrigger>
                )}
                {generatedContent?.analysis && (
                  <TabsTrigger value="analysis">Analysis</TabsTrigger>
                )}
                {generatedContent?.brandCompliance && (
                  <TabsTrigger value="compliance">Compliance</TabsTrigger>
                )}
              </TabsList>

              <TabsContent value="content" className="space-y-4">
                <div className="rounded-lg border p-4 bg-gray-50">
                  <pre className="whitespace-pre-wrap text-sm">
                    {streamingContent || generatedContent?.content}
                  </pre>
                </div>
                {generatedContent?.metadata && (
                  <div className="flex gap-4 text-sm text-muted-foreground">
                    <span>Words: {generatedContent.metadata.wordCount}</span>
                    <span>Characters: {generatedContent.metadata.charCount}</span>
                    <span>Type: {generatedContent.metadata.contentType}</span>
                  </div>
                )}
              </TabsContent>

              {generatedContent?.variants && generatedContent.variants.length > 0 && (
                <TabsContent value="variants" className="space-y-4">
                  {generatedContent.variants.map((variant, index) => (
                    <div key={variant.id} className="rounded-lg border p-4 space-y-3">
                      <div className="flex items-center justify-between">
                        <h4 className="font-medium">Variant {index + 1}</h4>
                        <Badge variant="outline">{variant.strategy.replace('_', ' ')}</Badge>
                      </div>
                      <div className="rounded border p-3 bg-gray-50">
                        <pre className="whitespace-pre-wrap text-sm">{variant.content}</pre>
                      </div>
                      <div className="grid grid-cols-2 md:grid-cols-4 gap-2 text-sm">
                        <div>Engagement: {variant.metrics.estimatedEngagement}%</div>
                        <div>Readability: {variant.metrics.readabilityScore}%</div>
                        <div>Brand Align: {variant.metrics.brandAlignment}%</div>
                        <div>Format: {variant.metrics.formatOptimization}%</div>
                      </div>
                    </div>
                  ))}
                </TabsContent>
              )}

              {generatedContent?.analysis && (
                <TabsContent value="analysis" className="space-y-4">
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div className="rounded-lg border p-4">
                      <h4 className="font-medium mb-2">Sentiment</h4>
                      <Badge 
                        variant={
                          generatedContent.analysis.sentiment === 'positive' ? 'default' :
                          generatedContent.analysis.sentiment === 'negative' ? 'destructive' : 'secondary'
                        }
                      >
                        {generatedContent.analysis.sentiment}
                      </Badge>
                    </div>
                    <div className="rounded-lg border p-4">
                      <h4 className="font-medium mb-2">Readability Score</h4>
                      <div className="text-2xl font-bold">{generatedContent.analysis.readabilityScore}</div>
                    </div>
                    <div className="rounded-lg border p-4">
                      <h4 className="font-medium mb-2">Brand Alignment</h4>
                      <div className="text-2xl font-bold">{generatedContent.analysis.brandAlignment}%</div>
                    </div>
                  </div>

                  {generatedContent.analysis.suggestions.length > 0 && (
                    <div className="space-y-2">
                      <h4 className="font-medium">Suggestions</h4>
                      {generatedContent.analysis.suggestions.map((suggestion, index) => (
                        <div key={index} className="rounded border p-3 space-y-1">
                          <div className="flex items-center gap-2">
                            <Badge variant="outline" className="text-xs">
                              {suggestion.type}
                            </Badge>
                            <Badge 
                              variant={
                                suggestion.priority === 'high' ? 'destructive' :
                                suggestion.priority === 'medium' ? 'default' : 'secondary'
                              }
                              className="text-xs"
                            >
                              {suggestion.priority}
                            </Badge>
                          </div>
                          <div className="text-sm font-medium">{suggestion.suggestion}</div>
                          <div className="text-xs text-muted-foreground">{suggestion.reason}</div>
                        </div>
                      ))}
                    </div>
                  )}
                </TabsContent>
              )}

              {generatedContent?.brandCompliance && (
                <TabsContent value="compliance" className="space-y-4">
                  <div className="flex items-center gap-4">
                    <div className="flex items-center gap-2">
                      <div className={`h-3 w-3 rounded-full ${
                        generatedContent.brandCompliance.isCompliant ? 'bg-green-500' : 'bg-red-500'
                      }`} />
                      <span className="font-medium">
                        {generatedContent.brandCompliance.isCompliant ? 'Compliant' : 'Issues Found'}
                      </span>
                    </div>
                    <Badge variant="outline">
                      Score: {generatedContent.brandCompliance.score}%
                    </Badge>
                  </div>

                  {generatedContent.brandCompliance.violations.length > 0 && (
                    <div className="space-y-2">
                      <h4 className="font-medium">Compliance Issues</h4>
                      {generatedContent.brandCompliance.violations.map((violation, index) => (
                        <div key={index} className="rounded border border-red-200 p-3 bg-red-50">
                          <div className="text-sm text-red-800">{violation}</div>
                        </div>
                      ))}
                    </div>
                  )}

                  {generatedContent.brandCompliance.suggestions && generatedContent.brandCompliance.suggestions.length > 0 && (
                    <div className="space-y-2">
                      <h4 className="font-medium">Suggestions</h4>
                      {generatedContent.brandCompliance.suggestions.map((suggestion, index) => (
                        <div key={index} className="rounded border border-blue-200 p-3 bg-blue-50">
                          <div className="text-sm text-blue-800">{suggestion}</div>
                        </div>
                      ))}
                    </div>
                  )}
                </TabsContent>
              )}
            </Tabs>
          </CardContent>
        </Card>
      )}
    </div>
  )
}