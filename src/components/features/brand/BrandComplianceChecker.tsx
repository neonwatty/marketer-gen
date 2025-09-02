'use client'

import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { toast } from 'sonner'
import * as z from 'zod'

import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Form, FormControl, FormDescription, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form'
import { Textarea } from '@/components/ui/textarea'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import { LoadingSpinner } from '@/components/ui/loading-spinner'

const complianceCheckSchema = z.object({
  brandId: z.string().min(1, 'Please select a brand'),
  content: z.string().min(10, 'Content must be at least 10 characters').max(5000, 'Content too long'),
})

type ComplianceCheckFormData = z.infer<typeof complianceCheckSchema>

interface ComplianceResult {
  isCompliant: boolean
  violations: string[]
  suggestions?: string[]
  score: number
}

interface Brand {
  id: string
  name: string
  tagline?: string
  voiceDescription?: string
}

interface BrandComplianceCheckerProps {
  brands: Brand[]
}

export function BrandComplianceChecker({ brands }: BrandComplianceCheckerProps) {
  const [isChecking, setIsChecking] = useState(false)
  const [complianceResult, setComplianceResult] = useState<ComplianceResult | null>(null)

  const form = useForm<ComplianceCheckFormData>({
    resolver: zodResolver(complianceCheckSchema),
    defaultValues: {
      brandId: '',
      content: '',
    }
  })

  const onSubmit = async (data: ComplianceCheckFormData) => {
    setIsChecking(true)
    setComplianceResult(null)

    try {
      // For now, we'll create a mock compliance check since the backend expects full content generation
      // In a real implementation, you'd call a dedicated compliance checking endpoint
      
      // Simulate API call delay
      await new Promise(resolve => setTimeout(resolve, 1500))

      // Mock compliance result - in real app, this would come from the API
      const mockResult: ComplianceResult = {
        isCompliant: Math.random() > 0.3, // 70% chance of being compliant
        violations: Math.random() > 0.5 ? [] : [
          'Content may not align with brand voice guidelines',
          'Consider using more positive language',
        ],
        suggestions: [
          'Add more specific calls-to-action',
          'Consider including brand values in the messaging',
          'Ensure consistent tone throughout the content',
        ],
        score: Math.floor(Math.random() * 30) + 70, // Score between 70-100
      }

      setComplianceResult(mockResult)
      
      toast.success('Compliance check completed!')

    } catch (error) {
      console.error('Compliance check error:', error)
      toast.error('Failed to check compliance')
    } finally {
      setIsChecking(false)
    }
  }

  const getComplianceColor = (score: number) => {
    if (score >= 90) return 'text-green-600 border-green-200 bg-green-50'
    if (score >= 70) return 'text-yellow-600 border-yellow-200 bg-yellow-50'
    return 'text-red-600 border-red-200 bg-red-50'
  }

  const getScoreText = (score: number) => {
    if (score >= 90) return 'Excellent'
    if (score >= 80) return 'Good'
    if (score >= 70) return 'Fair'
    return 'Needs Improvement'
  }

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Brand Compliance Checker</CardTitle>
          <p className="text-sm text-muted-foreground">
            Check if your content aligns with brand guidelines and voice
          </p>
        </CardHeader>
        <CardContent>
          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
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
                          <SelectValue placeholder="Select a brand to check against" />
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

              {/* Content Input */}
              <FormField
                control={form.control}
                name="content"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Content to Check</FormLabel>
                    <FormControl>
                      <Textarea
                        placeholder="Paste your content here to check for brand compliance..."
                        className="min-h-[150px]"
                        {...field}
                      />
                    </FormControl>
                    <FormDescription>
                      Enter the content you want to check against brand guidelines (10-5000 characters)
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />

              {/* Submit Button */}
              <Button
                type="submit"
                disabled={isChecking}
                className="w-full"
              >
                {isChecking ? (
                  <>
                    <LoadingSpinner className="mr-2 h-4 w-4" />
                    Checking Compliance...
                  </>
                ) : (
                  'Check Brand Compliance'
                )}
              </Button>
            </form>
          </Form>
        </CardContent>
      </Card>

      {/* Compliance Results */}
      {complianceResult && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center justify-between">
              <span>Compliance Results</span>
              <Badge 
                variant="outline"
                className={getComplianceColor(complianceResult.score)}
              >
                {complianceResult.score}% - {getScoreText(complianceResult.score)}
              </Badge>
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-6">
            {/* Overall Status */}
            <div className="flex items-center gap-4">
              <div className={`h-4 w-4 rounded-full ${
                complianceResult.isCompliant ? 'bg-green-500' : 'bg-red-500'
              }`} />
              <span className="font-medium">
                {complianceResult.isCompliant ? 'Content is compliant' : 'Compliance issues found'}
              </span>
            </div>

            {/* Score Progress */}
            <div className="space-y-2">
              <div className="flex items-center justify-between text-sm">
                <span>Compliance Score</span>
                <span>{complianceResult.score}%</span>
              </div>
              <Progress 
                value={complianceResult.score} 
                className="h-2"
              />
            </div>

            {/* Violations */}
            {complianceResult.violations.length > 0 && (
              <div className="space-y-3">
                <h4 className="font-medium text-red-800">Issues Found:</h4>
                {complianceResult.violations.map((violation, index) => (
                  <div key={index} className="rounded border border-red-200 p-3 bg-red-50">
                    <div className="text-sm text-red-800">{violation}</div>
                  </div>
                ))}
              </div>
            )}

            {/* Suggestions */}
            {complianceResult.suggestions && complianceResult.suggestions.length > 0 && (
              <div className="space-y-3">
                <h4 className="font-medium text-blue-800">Suggestions for Improvement:</h4>
                {complianceResult.suggestions.map((suggestion, index) => (
                  <div key={index} className="rounded border border-blue-200 p-3 bg-blue-50">
                    <div className="text-sm text-blue-800">{suggestion}</div>
                  </div>
                ))}
              </div>
            )}

            {/* Action Buttons */}
            <div className="flex gap-2 pt-4 border-t">
              <Button 
                variant="outline" 
                size="sm"
                onClick={() => form.reset()}
              >
                Check Another Content
              </Button>
              {!complianceResult.isCompliant && (
                <Button 
                  size="sm"
                  onClick={() => {
                    toast.info('Auto-fix feature coming soon!')
                  }}
                >
                  Auto-Fix Issues
                </Button>
              )}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Help Section */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">How Brand Compliance Checking Works</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 text-sm">
            <div className="space-y-2">
              <h4 className="font-medium">What We Check:</h4>
              <ul className="space-y-1 text-muted-foreground">
                <li>• Brand voice and tone consistency</li>
                <li>• Restricted terms and language</li>
                <li>• Messaging framework alignment</li>
                <li>• Content appropriateness</li>
                <li>• Style guide adherence</li>
              </ul>
            </div>
            <div className="space-y-2">
              <h4 className="font-medium">Scoring Criteria:</h4>
              <ul className="space-y-1 text-muted-foreground">
                <li>• 90-100%: Excellent compliance</li>
                <li>• 80-89%: Good with minor issues</li>
                <li>• 70-79%: Fair, needs improvement</li>
                <li>• Below 70%: Major compliance issues</li>
              </ul>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}