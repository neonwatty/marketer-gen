'use client'

import * as React from 'react'
import { useEffect,useState } from 'react'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { 
  Card, 
  CardContent, 
  CardDescription, 
  CardHeader, 
  CardTitle 
} from '@/components/ui/card'
import { Progress } from '@/components/ui/progress'
import { Separator } from '@/components/ui/separator'
import { 
  Tabs, 
  TabsContent, 
  TabsList, 
  TabsTrigger 
} from '@/components/ui/tabs'
import { 
  ContentTypeValue, 
  ContentVariant, 
  getContentTypeDisplayName 
} from '@/lib/types/content-generation'

interface VariantComparisonProps {
  originalContent: string
  contentType: ContentTypeValue
  brandContext: string
  variants?: ContentVariant[]
  onVariantSelect?: (variant: ContentVariant | null) => void
  onGenerateVariants?: () => void
  isGenerating?: boolean
}

interface PerformanceMetric {
  name: string
  value: number
  description: string
  color: 'blue' | 'green' | 'yellow' | 'red'
}

export function VariantComparison({
  originalContent,
  contentType,
  brandContext,
  variants = [],
  onVariantSelect,
  onGenerateVariants,
  isGenerating = false
}: VariantComparisonProps) {
  const [selectedVariant, setSelectedVariant] = useState<string>('original')
  const [performanceData, setPerformanceData] = useState<Record<string, PerformanceMetric[]>>({})

  type ExtendedVariant = (ContentVariant | {
    id: string
    content: string
    strategy: string
    metrics?: {
      estimatedEngagement: number
      readabilityScore: number
      brandAlignment: number
      formatOptimization: number
    }
    formatOptimizations?: {
      platform?: string
      characterCount: number
      wordCount: number
      hasHashtags?: boolean
      hasCTA?: boolean
      keywordDensity: Record<string, number>
    }
  })

  const allVariants: ExtendedVariant[] = [
    {
      id: 'original',
      content: originalContent,
      strategy: 'original',
      metrics: {
        estimatedEngagement: 65,
        readabilityScore: 70,
        brandAlignment: 85,
        formatOptimization: 75
      },
      formatOptimizations: {
        characterCount: originalContent.length,
        wordCount: originalContent.split(/\s+/).length,
        hasHashtags: originalContent.includes('#'),
        hasCTA: /\b(click|buy|purchase|subscribe|sign up|learn more|get started|contact|download|try)\b/i.test(originalContent),
        keywordDensity: {}
      }
    },
    ...variants
  ]

  useEffect(() => {
    const calculatePerformanceMetrics = async () => {
      const newPerformanceData: Record<string, PerformanceMetric[]> = {}
      
      for (const variant of allVariants) {
        const metrics = variant.metrics || {
          estimatedEngagement: 50,
          readabilityScore: 60,
          brandAlignment: 70,
          formatOptimization: 65
        }

        newPerformanceData[variant.id] = [
          {
            name: 'Engagement',
            value: metrics.estimatedEngagement,
            description: 'Predicted audience engagement potential',
            color: metrics.estimatedEngagement > 70 ? 'green' : metrics.estimatedEngagement > 50 ? 'yellow' : 'red'
          },
          {
            name: 'Readability',
            value: metrics.readabilityScore,
            description: 'Content readability and clarity score',
            color: metrics.readabilityScore > 70 ? 'green' : metrics.readabilityScore > 50 ? 'yellow' : 'red'
          },
          {
            name: 'Brand Alignment',
            value: metrics.brandAlignment,
            description: 'Alignment with brand voice and guidelines',
            color: metrics.brandAlignment > 80 ? 'green' : metrics.brandAlignment > 60 ? 'yellow' : 'red'
          },
          {
            name: 'Format Optimization',
            value: metrics.formatOptimization,
            description: 'Optimization for target content format',
            color: metrics.formatOptimization > 75 ? 'green' : metrics.formatOptimization > 55 ? 'yellow' : 'red'
          }
        ]
      }
      
      setPerformanceData(newPerformanceData)
    }

    if (allVariants.length > 0) {
      calculatePerformanceMetrics()
    }
  }, [originalContent, variants])

  const handleVariantSelect = (variantId: string) => {
    setSelectedVariant(variantId)
    if (variantId === 'original') {
      onVariantSelect?.(null)
    } else {
      const variant = allVariants.find(v => v.id === variantId)
      if (variant) {
        // Convert back to ContentVariant type if it's not the original
        if ('strategy' in variant && (variant.strategy === 'style_variation' || variant.strategy === 'length_variation' || variant.strategy === 'angle_variation' || variant.strategy === 'tone_variation' || variant.strategy === 'cta_variation')) {
          onVariantSelect?.(variant as ContentVariant)
        } else {
          onVariantSelect?.(null)
        }
      } else {
        onVariantSelect?.(null)
      }
    }
  }

  const getStrategyDisplayName = (strategy: string): string => {
    const displayNames: Record<string, string> = {
      'original': 'Original',
      'style_variation': 'Style Variation',
      'length_variation': 'Length Variation',
      'angle_variation': 'Angle Variation',
      'tone_variation': 'Tone Variation',
      'cta_variation': 'CTA Variation'
    }
    return displayNames[strategy] || strategy
  }

  const getMetricColor = (color: string): string => {
    const colors: Record<string, string> = {
      'blue': 'text-blue-600',
      'green': 'text-green-600', 
      'yellow': 'text-yellow-600',
      'red': 'text-red-600'
    }
    return colors[color] || 'text-gray-600'
  }

  if (allVariants.length === 1 && !isGenerating) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Content Variants & A/B Testing</CardTitle>
          <CardDescription>
            Generate multiple content variants to optimize performance through A/B testing
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="text-center py-8">
            <p className="text-muted-foreground mb-4">
              No variants generated yet. Create multiple versions of your content to compare performance.
            </p>
            <Button onClick={onGenerateVariants} disabled={isGenerating}>
              {isGenerating ? 'Generating Variants...' : 'Generate Variants'}
            </Button>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>Content Variants & A/B Testing</CardTitle>
              <CardDescription>
                Compare {allVariants.length} variants of your {getContentTypeDisplayName(contentType).toLowerCase()} content
              </CardDescription>
            </div>
            {variants.length > 0 && (
              <Button 
                variant="outline" 
                onClick={onGenerateVariants}
                disabled={isGenerating}
              >
                {isGenerating ? 'Generating...' : 'Generate More'}
              </Button>
            )}
          </div>
        </CardHeader>
        <CardContent>
          <Tabs value={selectedVariant} onValueChange={handleVariantSelect}>
            <TabsList className="grid w-full grid-cols-auto gap-1">
              {allVariants.map((variant) => (
                <TabsTrigger 
                  key={variant.id}
                  value={variant.id}
                  className="flex flex-col items-center gap-1 min-w-[120px]"
                >
                  <span className="text-sm font-medium">
                    {getStrategyDisplayName(variant.strategy)}
                  </span>
                  {variant.id !== 'original' && (
                    <Badge variant="secondary" className="text-xs">
                      Variant {variant.id.split('_')[1] || ''}
                    </Badge>
                  )}
                </TabsTrigger>
              ))}
            </TabsList>

            {allVariants.map((variant) => (
              <TabsContent 
                key={variant.id}
                value={variant.id}
                className="mt-6 space-y-6"
              >
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                  {/* Content Preview */}
                  <Card>
                    <CardHeader>
                      <CardTitle className="text-lg">Content Preview</CardTitle>
                      <div className="flex items-center gap-2">
                        <Badge variant={variant.id === 'original' ? 'default' : 'secondary'}>
                          {getStrategyDisplayName(variant.strategy)}
                        </Badge>
                        {variant.formatOptimizations && (
                          <span className="text-sm text-muted-foreground">
                            {variant.formatOptimizations.wordCount} words, {variant.formatOptimizations.characterCount} chars
                          </span>
                        )}
                      </div>
                    </CardHeader>
                    <CardContent>
                      <div className="prose prose-sm max-w-none">
                        <div className="whitespace-pre-wrap text-sm leading-relaxed">
                          {variant.content}
                        </div>
                      </div>
                    </CardContent>
                  </Card>

                  {/* Performance Metrics */}
                  <Card>
                    <CardHeader>
                      <CardTitle className="text-lg">Performance Metrics</CardTitle>
                      <CardDescription>
                        Predicted performance indicators for this variant
                      </CardDescription>
                    </CardHeader>
                    <CardContent>
                      <div className="space-y-4">
                        {performanceData[variant.id]?.map((metric, index) => (
                          <div key={index} className="space-y-2">
                            <div className="flex items-center justify-between">
                              <span className="text-sm font-medium">{metric.name}</span>
                              <span className={`text-sm font-semibold ${getMetricColor(metric.color)}`}>
                                {metric.value}%
                              </span>
                            </div>
                            <Progress value={metric.value} className="h-2" />
                            <p className="text-xs text-muted-foreground">{metric.description}</p>
                          </div>
                        ))}
                      </div>
                    </CardContent>
                  </Card>
                </div>

                {/* Format Optimizations */}
                {variant.formatOptimizations && (
                  <Card>
                    <CardHeader>
                      <CardTitle className="text-lg">Format Analysis</CardTitle>
                      <CardDescription>
                        Content optimization details for {getContentTypeDisplayName(contentType).toLowerCase()}
                      </CardDescription>
                    </CardHeader>
                    <CardContent>
                      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                        <div className="text-center">
                          <div className="text-2xl font-bold text-blue-600">
                            {variant.formatOptimizations.wordCount}
                          </div>
                          <div className="text-sm text-muted-foreground">Words</div>
                        </div>
                        <div className="text-center">
                          <div className="text-2xl font-bold text-green-600">
                            {variant.formatOptimizations.characterCount}
                          </div>
                          <div className="text-sm text-muted-foreground">Characters</div>
                        </div>
                        <div className="text-center">
                          <div className="text-2xl font-bold text-yellow-600">
                            {variant.formatOptimizations.hasCTA ? '✓' : '✗'}
                          </div>
                          <div className="text-sm text-muted-foreground">Call to Action</div>
                        </div>
                        <div className="text-center">
                          <div className="text-2xl font-bold text-purple-600">
                            {variant.formatOptimizations.hasHashtags ? '✓' : '✗'}
                          </div>
                          <div className="text-sm text-muted-foreground">Hashtags</div>
                        </div>
                      </div>

                      {/* Keyword Density */}
                      {variant.formatOptimizations.keywordDensity && 
                       Object.keys(variant.formatOptimizations.keywordDensity).length > 0 && (
                        <div className="mt-6">
                          <Separator className="mb-4" />
                          <h4 className="text-sm font-medium mb-3">Top Keywords</h4>
                          <div className="flex flex-wrap gap-2">
                            {Object.entries(variant.formatOptimizations.keywordDensity)
                              .sort(([,a], [,b]) => (b as number) - (a as number))
                              .slice(0, 8)
                              .map(([keyword, density]) => (
                                <Badge key={keyword} variant="outline" className="text-xs">
                                  {keyword} ({density}%)
                                </Badge>
                              ))
                            }
                          </div>
                        </div>
                      )}
                    </CardContent>
                  </Card>
                )}
              </TabsContent>
            ))}
          </Tabs>
        </CardContent>
      </Card>

      {/* A/B Testing Recommendations */}
      {variants.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">A/B Testing Recommendations</CardTitle>
            <CardDescription>
              Suggested testing approach for optimizing content performance
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="text-center p-4 bg-muted rounded-lg">
                  <div className="text-lg font-semibold text-blue-600">Split Traffic</div>
                  <div className="text-sm text-muted-foreground mt-1">
                    Equal distribution across {allVariants.length} variants
                  </div>
                </div>
                <div className="text-center p-4 bg-muted rounded-lg">
                  <div className="text-lg font-semibold text-green-600">Test Duration</div>
                  <div className="text-sm text-muted-foreground mt-1">
                    Minimum 7-14 days for statistical significance
                  </div>
                </div>
                <div className="text-center p-4 bg-muted rounded-lg">
                  <div className="text-lg font-semibold text-purple-600">Key Metrics</div>
                  <div className="text-sm text-muted-foreground mt-1">
                    Engagement, clicks, conversions
                  </div>
                </div>
              </div>

              <div className="mt-6">
                <h4 className="text-sm font-medium mb-3">Testing Strategy</h4>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                  <div>
                    <h5 className="font-medium text-green-600 mb-2">Best Performing Variant</h5>
                    <p className="text-muted-foreground">
                      Based on initial metrics, the{' '}
                      {(() => {
                        const bestVariant = allVariants.reduce((best, current) => {
                          const bestScore = best.metrics?.estimatedEngagement || 0
                          const currentScore = current.metrics?.estimatedEngagement || 0
                          return currentScore > bestScore ? current : best
                        })
                        return getStrategyDisplayName(bestVariant.strategy).toLowerCase()
                      })()} shows highest engagement potential.
                    </p>
                  </div>
                  <div>
                    <h5 className="font-medium text-blue-600 mb-2">Testing Focus</h5>
                    <p className="text-muted-foreground">
                      Focus on measuring engagement rates, click-through rates, and conversion metrics 
                      to identify the optimal content approach.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}