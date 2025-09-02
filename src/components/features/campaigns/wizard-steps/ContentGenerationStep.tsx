'use client'

import { useState, useEffect } from 'react'
import { useFormContext } from 'react-hook-form'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { ContentGenerator } from '@/components/features/content/ContentGenerator'

interface Brand {
  id: string
  name: string
  tagline?: string
  voiceDescription?: string
}

interface GeneratedContent {
  id: string
  type: string
  stage: string
  content: string
  variants?: Array<{
    id: string
    content: string
    strategy: string
    metrics: {
      estimatedEngagement: number
      readabilityScore: number
      brandAlignment: number
      formatOptimization: number
    }
  }>
  compliance: {
    isCompliant: boolean
    score: number
    violations: string[]
  }
  metadata: {
    generatedAt: string
    wordCount: number
    charCount: number
  }
}

interface ContentGenerationStepProps {
  brands: Brand[]
}

export function ContentGenerationStep({ brands }: ContentGenerationStepProps) {
  const { watch, setValue, getValues } = useFormContext()
  const [generatedContents, setGeneratedContents] = useState<GeneratedContent[]>([])
  const [selectedBrand, setSelectedBrand] = useState<Brand | null>(null)
  const [currentStage, setCurrentStage] = useState('awareness')

  // Get campaign data from form
  const templateId = watch('templateId')
  const campaignName = watch('name')
  const targetAudience = watch('targetAudience')
  const goals = watch('goals')

  // Journey stages based on typical customer journey
  const journeyStages = [
    {
      id: 'awareness',
      name: 'Awareness',
      description: 'Introduce your brand and capture attention',
      contentTypes: ['SOCIAL_POST', 'BLOG_POST', 'INFOGRAPHIC'],
      suggestedPrompts: [
        'Create engaging content that introduces our brand to new audiences',
        'Develop educational content about industry trends and insights',
        'Share behind-the-scenes content that humanizes our brand'
      ]
    },
    {
      id: 'consideration',
      name: 'Consideration', 
      description: 'Provide value and build trust with potential customers',
      contentTypes: ['EMAIL', 'BLOG_POST', 'VIDEO_SCRIPT'],
      suggestedPrompts: [
        'Create informative content that helps prospects solve their problems',
        'Develop comparison content that highlights our unique value proposition',
        'Share customer success stories and testimonials'
      ]
    },
    {
      id: 'conversion',
      name: 'Conversion',
      description: 'Drive action and convert prospects to customers',
      contentTypes: ['LANDING_PAGE', 'SOCIAL_AD', 'EMAIL'],
      suggestedPrompts: [
        'Create compelling offer-focused content with clear call-to-actions',
        'Develop urgency-driven content for limited-time promotions',
        'Write conversion-optimized landing page copy'
      ]
    },
    {
      id: 'retention',
      name: 'Retention',
      description: 'Keep customers engaged and encourage repeat business',
      contentTypes: ['NEWSLETTER', 'EMAIL', 'SOCIAL_POST'],
      suggestedPrompts: [
        'Create helpful content that maximizes customer success with our product',
        'Develop exclusive content and offers for existing customers',
        'Share product updates and new feature announcements'
      ]
    }
  ]

  // Get brand from brands array when brandId changes
  useEffect(() => {
    const formData = getValues()
    if (formData.brandId && brands.length > 0) {
      const brand = brands.find(b => b.id === formData.brandId)
      setSelectedBrand(brand || null)
    }
  }, [brands, getValues])

  const getCurrentStageData = () => {
    return journeyStages.find(stage => stage.id === currentStage)
  }

  const handleContentGenerated = (content: any) => {
    const newContent: GeneratedContent = {
      id: `${currentStage}-${Date.now()}`,
      type: content.metadata.contentType,
      stage: currentStage,
      content: content.content,
      variants: content.variants?.map((variant: any) => ({
        id: variant.id,
        content: variant.content,
        strategy: variant.strategy,
        metrics: variant.metrics
      })),
      compliance: {
        isCompliant: content.brandCompliance.isCompliant,
        score: content.brandCompliance.score,
        violations: content.brandCompliance.violations
      },
      metadata: {
        generatedAt: content.metadata.generatedAt,
        wordCount: content.metadata.wordCount,
        charCount: content.metadata.charCount
      }
    }

    setGeneratedContents(prev => [...prev, newContent])
    
    // Update form data with generated content
    setValue('generatedContent', [...generatedContents, newContent])
    
    toast.success(`Content generated for ${currentStage} stage!`)
  }

  const removeContent = (contentId: string) => {
    const updated = generatedContents.filter(content => content.id !== contentId)
    setGeneratedContents(updated)
    setValue('generatedContent', updated)
    toast.info('Content removed')
  }

  const stageData = getCurrentStageData()

  return (
    <div className="space-y-6">
      <div className="text-center space-y-2">
        <h2 className="text-2xl font-bold">AI Content Generation</h2>
        <p className="text-muted-foreground">
          Generate brand-aligned content for each stage of your customer journey
        </p>
      </div>

      {/* Campaign Context */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">Campaign Context</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
            <div>
              <span className="font-medium">Campaign:</span> {campaignName || 'Untitled'}
            </div>
            <div>
              <span className="font-medium">Brand:</span> {selectedBrand?.name || 'No brand selected'}
            </div>
            <div>
              <span className="font-medium">Primary Goal:</span> {goals?.primary || 'Not set'}
            </div>
          </div>
          {targetAudience?.segments && targetAudience.segments.length > 0 && (
            <div className="text-sm">
              <span className="font-medium">Target Audience:</span> {targetAudience.segments.join(', ')}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Journey Stage Selection */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">Select Journey Stage</CardTitle>
        </CardHeader>
        <CardContent>
          <Tabs value={currentStage} onValueChange={setCurrentStage} className="w-full">
            <TabsList className="grid w-full grid-cols-4">
              {journeyStages.map((stage) => (
                <TabsTrigger key={stage.id} value={stage.id} className="text-xs">
                  {stage.name}
                </TabsTrigger>
              ))}
            </TabsList>

            {journeyStages.map((stage) => (
              <TabsContent key={stage.id} value={stage.id} className="space-y-4">
                <div className="text-center space-y-2">
                  <h3 className="text-xl font-semibold">{stage.name} Stage</h3>
                  <p className="text-muted-foreground">{stage.description}</p>
                </div>

                {/* Recommended Content Types */}
                <div className="space-y-2">
                  <h4 className="font-medium">Recommended Content Types:</h4>
                  <div className="flex gap-2 flex-wrap">
                    {stage.contentTypes.map((type) => (
                      <Badge key={type} variant="outline">
                        {type.replace('_', ' ')}
                      </Badge>
                    ))}
                  </div>
                </div>

                {/* Suggested Prompts */}
                <div className="space-y-2">
                  <h4 className="font-medium">Content Ideas:</h4>
                  <ul className="text-sm text-muted-foreground space-y-1">
                    {stage.suggestedPrompts.map((prompt, index) => (
                      <li key={index} className="flex items-start gap-2">
                        <span className="text-xs mt-1">•</span>
                        <span>{prompt}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              </TabsContent>
            ))}
          </Tabs>
        </CardContent>
      </Card>

      {/* Content Generator */}
      {selectedBrand && stageData && (
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Generate Content for {stageData.name}</CardTitle>
          </CardHeader>
          <CardContent>
            <ContentGenerator
              brands={[selectedBrand]}
              onContentGenerated={handleContentGenerated}
            />
          </CardContent>
        </Card>
      )}

      {!selectedBrand && (
        <Card>
          <CardContent className="text-center py-8">
            <p className="text-muted-foreground">
              Please select a brand in the previous steps to begin content generation
            </p>
          </CardContent>
        </Card>
      )}

      {/* Generated Content Summary */}
      {generatedContents.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Generated Content ({generatedContents.length})</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {generatedContents.map((content) => (
              <div key={content.id} className="rounded-lg border p-4 space-y-3">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <Badge variant="outline">{content.stage}</Badge>
                    <Badge variant="secondary">{content.type.replace('_', ' ')}</Badge>
                    <div className={`h-2 w-2 rounded-full ${
                      content.compliance.isCompliant ? 'bg-green-500' : 'bg-yellow-500'
                    }`} />
                    <span className="text-sm text-muted-foreground">
                      Compliance: {content.compliance.score}%
                    </span>
                  </div>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => removeContent(content.id)}
                  >
                    Remove
                  </Button>
                </div>
                
                <div className="rounded border p-3 bg-gray-50">
                  <div className="text-sm line-clamp-3">
                    {content.content}
                  </div>
                </div>

                <div className="flex items-center gap-4 text-xs text-muted-foreground">
                  <span>{content.metadata.wordCount} words</span>
                  <span>{content.metadata.charCount} characters</span>
                  {content.variants && (
                    <span>{content.variants.length} variants</span>
                  )}
                  <span>Generated {new Date(content.metadata.generatedAt).toLocaleString()}</span>
                </div>

                {!content.compliance.isCompliant && content.compliance.violations.length > 0 && (
                  <div className="space-y-1">
                    <h5 className="text-sm font-medium text-yellow-800">Compliance Issues:</h5>
                    {content.compliance.violations.map((violation, index) => (
                      <div key={index} className="text-xs text-yellow-700 bg-yellow-50 rounded px-2 py-1">
                        {violation}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            ))}
          </CardContent>
        </Card>
      )}

      {/* Progress Summary */}
      <Card>
        <CardContent className="pt-6">
          <div className="grid grid-cols-4 gap-4 text-center">
            {journeyStages.map((stage) => {
              const stageContent = generatedContents.filter(c => c.stage === stage.id)
              return (
                <div key={stage.id} className="space-y-2">
                  <div className="font-medium">{stage.name}</div>
                  <div className="text-2xl font-bold text-muted-foreground">
                    {stageContent.length}
                  </div>
                  <div className="text-xs text-muted-foreground">content pieces</div>
                </div>
              )
            })}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}