'use client'

import { Suspense, useEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import dynamic from 'next/dynamic'
import { useRouter, useSearchParams } from 'next/navigation'

import { zodResolver } from '@hookform/resolvers/zod'
import { AlertCircle, ArrowLeft, CheckCircle, Sparkles } from 'lucide-react'
import { z } from 'zod'

import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Form, FormControl, FormDescription, FormField, FormItem, FormLabel, FormMessage } from '@/components/ui/form'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Skeleton } from '@/components/ui/skeleton'
import { Textarea } from '@/components/ui/textarea'
import { getCategoryDisplayName,getIndustryDisplayName, JourneyCategory, JourneyIndustry, JourneyTemplate } from '@/lib/types/journey'

// Lazy load JourneyBuilder since it imports heavy ReactFlow dependencies
const JourneyBuilder = dynamic(
  () => import('@/components/features/journey').then(mod => ({ default: mod.JourneyBuilder })),
  {
    ssr: false,
    loading: () => (
      <div className="w-full h-[600px] border border-border rounded-lg p-4">
        <div className="space-y-4">
          <Skeleton className="h-12 w-full" />
          <div className="grid grid-cols-3 gap-4">
            <Skeleton className="h-32" />
            <Skeleton className="h-32" />
            <Skeleton className="h-32" />
          </div>
          <Skeleton className="h-48 w-full" />
        </div>
      </div>
    )
  }
)

// Form validation schema
const journeyFormSchema = z.object({
  name: z.string()
    .min(1, 'Journey name is required')
    .min(3, 'Journey name must be at least 3 characters')
    .max(100, 'Journey name must be less than 100 characters')
    .regex(/^[a-zA-Z0-9\s\-_]+$/, 'Journey name can only contain letters, numbers, spaces, hyphens, and underscores'),
  description: z.string()
    .max(500, 'Description must be less than 500 characters')
    .optional(),
  industry: z.string()
    .min(1, 'Industry is required'),
  category: z.string()
    .min(1, 'Category is required'),
  templateId: z.string().optional()
})

type JourneyFormData = z.infer<typeof journeyFormSchema>

function NewJourneyContent() {
  const router = useRouter()
  const searchParams = useSearchParams()
  
  const [isCreating, setIsCreating] = useState(false)
  const [selectedTemplate, setSelectedTemplate] = useState<JourneyTemplate | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)

  // Initialize form with react-hook-form
  const form = useForm<JourneyFormData>({
    resolver: zodResolver(journeyFormSchema),
    defaultValues: {
      name: '',
      description: '',
      industry: '',
      category: '',
      templateId: searchParams?.get('templateId') || undefined
    }
  })

  // Load template if templateId is provided
  useEffect(() => {
    const templateId = searchParams?.get('templateId')
    if (templateId) {
      fetchTemplate(templateId)
    }
  }, [searchParams])

  const fetchTemplate = async (templateId: string) => {
    try {
      setError(null)
      const response = await fetch(`/api/journey-templates/${templateId}`)
      if (!response.ok) throw new Error('Failed to fetch template')
      
      const data = await response.json()
      if (data.success) {
        const template = data.data
        setSelectedTemplate(template)
        // Update form values
        form.setValue('name', `${template.name} Journey`)
        form.setValue('description', template.description || '')
        form.setValue('industry', template.industry)
        form.setValue('category', template.category)
        form.setValue('templateId', template.id)
      }
    } catch (error) {
      console.error('Error fetching template:', error)
      setError('Failed to load template. Please try again.')
    }
  }

  const onSubmit = async (values: JourneyFormData) => {
    setIsCreating(true)
    setError(null)
    setSuccess(null)
    
    try {
      // Create journey instance from template
      const journeyData = {
        ...values,
        status: 'DRAFT'
      }

      // TODO: Replace with actual journey creation API call
      console.log('Creating journey:', journeyData)
      
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 2000))
      
      setSuccess('Journey created successfully! Redirecting...')
      
      // Navigate to journey detail page after short delay
      setTimeout(() => {
        router.push('/dashboard/journeys')
      }, 1500)
      
    } catch (error: any) {
      console.error('Error creating journey:', error)
      setError(error.message || 'Failed to create journey. Please try again.')
    } finally {
      setIsCreating(false)
    }
  }

  const handleBackToTemplates = () => {
    router.push('/dashboard/journeys')
  }

  const handleClearTemplate = () => {
    setSelectedTemplate(null)
    form.reset({
      name: '',
      description: '',
      industry: '',
      category: '',
      templateId: undefined
    })
    setError(null)
    setSuccess(null)
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Button
            variant="outline"
            size="sm"
            onClick={handleBackToTemplates}
            className="flex items-center gap-2"
          >
            <ArrowLeft className="h-4 w-4" />
            Back
          </Button>
          
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Create New Journey</h1>
            <p className="text-muted-foreground">
              {selectedTemplate 
                ? `Create a journey based on "${selectedTemplate.name}" template`
                : 'Create a custom customer journey from scratch'
              }
            </p>
          </div>
        </div>
      </div>

      {/* Error and Success Alerts */}
      {error && (
        <Alert variant="destructive">
          <AlertCircle className="h-4 w-4" />
          <AlertTitle>Error</AlertTitle>
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {success && (
        <Alert variant="default" className="border-green-200 bg-green-50">
          <CheckCircle className="h-4 w-4 text-green-600" />
          <AlertTitle className="text-green-800">Success</AlertTitle>
          <AlertDescription className="text-green-700">{success}</AlertDescription>
        </Alert>
      )}

      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)}>
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Journey Configuration */}
            <div className="lg:col-span-1 space-y-6">
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <Sparkles className="h-5 w-5" />
                    Journey Details
                  </CardTitle>
                  <CardDescription>
                    Configure your journey's basic information
                  </CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <FormField
                    control={form.control}
                    name="name"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Journey Name *</FormLabel>
                        <FormControl>
                          <Input
                            placeholder="My Marketing Journey"
                            {...field}
                            disabled={isCreating}
                          />
                        </FormControl>
                        <FormDescription>
                          Choose a descriptive name for your customer journey
                        </FormDescription>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <FormField
                    control={form.control}
                    name="description"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Description</FormLabel>
                        <FormControl>
                          <Textarea
                            placeholder="Describe your journey's purpose and goals..."
                            rows={3}
                            {...field}
                            disabled={isCreating}
                          />
                        </FormControl>
                        <FormDescription>
                          Optional: Provide more details about this journey
                        </FormDescription>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <FormField
                    control={form.control}
                    name="industry"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Industry *</FormLabel>
                        <Select
                          onValueChange={field.onChange}
                          defaultValue={field.value}
                          disabled={isCreating}
                        >
                          <FormControl>
                            <SelectTrigger>
                              <SelectValue placeholder="Select your industry" />
                            </SelectTrigger>
                          </FormControl>
                          <SelectContent>
                            {Object.values(JourneyIndustry).map((industry) => (
                              <SelectItem key={industry} value={industry}>
                                {getIndustryDisplayName(industry)}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                        <FormDescription>
                          This helps us provide relevant recommendations
                        </FormDescription>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <FormField
                    control={form.control}
                    name="category"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Category *</FormLabel>
                        <Select
                          onValueChange={field.onChange}
                          defaultValue={field.value}
                          disabled={isCreating}
                        >
                          <FormControl>
                            <SelectTrigger>
                              <SelectValue placeholder="Select journey type" />
                            </SelectTrigger>
                          </FormControl>
                          <SelectContent>
                            {Object.values(JourneyCategory).map((category) => (
                              <SelectItem key={category} value={category}>
                                {getCategoryDisplayName(category)}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                        <FormDescription>
                          What is the primary goal of this journey?
                        </FormDescription>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <Button 
                    type="submit"
                    disabled={isCreating || !form.formState.isValid}
                    className="w-full"
                  >
                    {isCreating ? 'Creating Journey...' : 'Create Journey'}
                  </Button>
                </CardContent>
              </Card>

          {/* Template Information */}
          {selectedTemplate && (
            <Card>
              <CardHeader>
                <CardTitle>Template: {selectedTemplate.name}</CardTitle>
                <CardDescription>
                  Based on this template, your journey will include:
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex flex-wrap gap-2">
                  <Badge variant="secondary">
                    {getIndustryDisplayName(selectedTemplate.industry)}
                  </Badge>
                  <Badge variant="outline">
                    {getCategoryDisplayName(selectedTemplate.category)}
                  </Badge>
                  {selectedTemplate.metadata?.difficulty && (
                    <Badge variant={
                      selectedTemplate.metadata.difficulty === 'beginner' ? 'default' : 
                      selectedTemplate.metadata.difficulty === 'intermediate' ? 'secondary' : 'destructive'
                    }>
                      {selectedTemplate.metadata.difficulty}
                    </Badge>
                  )}
                </div>

                <div className="space-y-2">
                  <div className="text-sm">
                    <span className="font-medium">Stages:</span> {selectedTemplate.stages.length}
                  </div>
                  <div className="text-sm">
                    <span className="font-medium">Duration:</span> {selectedTemplate.metadata?.estimatedDuration || 'Variable'} days
                  </div>
                  <div className="text-sm">
                    <span className="font-medium">Usage:</span> {selectedTemplate.usageCount} times
                  </div>
                </div>

                <div className="space-y-2">
                  <h5 className="text-sm font-medium">Included Stages:</h5>
                  <div className="space-y-1">
                    {selectedTemplate.stages.slice(0, 3).map((stage, index) => (
                      <div key={stage.id} className="text-xs text-muted-foreground flex items-center gap-2">
                        <span className="w-5 h-5 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center text-xs font-semibold">
                          {index + 1}
                        </span>
                        {stage.title}
                      </div>
                    ))}
                    {selectedTemplate.stages.length > 3 && (
                      <div className="text-xs text-muted-foreground">
                        +{selectedTemplate.stages.length - 3} more stages...
                      </div>
                    )}
                  </div>
                </div>

                <Button
                  variant="outline"
                  size="sm"
                  onClick={handleClearTemplate}
                  className="w-full"
                  disabled={isCreating}
                >
                  Start From Scratch Instead
                </Button>
              </CardContent>
            </Card>
          )}
            </div>

            {/* Journey Builder Preview */}
            <div className="lg:col-span-2">
              <Card className="h-fit">
                <CardHeader>
                  <CardTitle>Journey Preview</CardTitle>
                  <CardDescription>
                    {selectedTemplate 
                      ? 'Preview of your journey based on the selected template'
                      : 'Visual builder will appear after you create the journey'
                    }
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  {selectedTemplate ? (
                    <div className="h-[600px] border border-border rounded-lg p-4 bg-muted/20">
                      <div className="text-center text-muted-foreground mt-48">
                        <Sparkles className="w-12 h-12 mx-auto mb-4 opacity-50" />
                        <h3 className="text-lg font-medium mb-2">Template Preview</h3>
                        <p className="text-sm">
                          Your journey will be created with {selectedTemplate.stages.length} stages
                          <br />
                          You'll be able to customize it after creation
                        </p>
                      </div>
                    </div>
                  ) : (
                    <div className="h-[600px] border border-border rounded-lg p-4 bg-muted/20">
                      <div className="text-center text-muted-foreground mt-48">
                        <div className="w-12 h-12 mx-auto mb-4 bg-muted rounded-full flex items-center justify-center">
                          <Sparkles className="w-6 h-6 opacity-50" />
                        </div>
                        <h3 className="text-lg font-medium mb-2">Custom Journey Builder</h3>
                        <p className="text-sm">
                          Create your journey to start building
                          <br />
                          You'll be able to drag and drop stages to design your flow
                        </p>
                      </div>
                    </div>
                  )}
                </CardContent>
              </Card>
            </div>
          </div>
        </form>
      </Form>
    </div>
  )
}

export default function NewJourneyPage() {
  return (
    <Suspense fallback={
      <div className="space-y-6">
        <div className="flex items-center gap-4">
          <Skeleton className="h-10 w-32" />
          <div className="space-y-2">
            <Skeleton className="h-8 w-64" />
            <Skeleton className="h-4 w-96" />
          </div>
        </div>
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="space-y-6">
            <Card>
              <CardHeader>
                <Skeleton className="h-6 w-32" />
                <Skeleton className="h-4 w-48" />
              </CardHeader>
              <CardContent className="space-y-4">
                <Skeleton className="h-10 w-full" />
                <Skeleton className="h-20 w-full" />
                <Skeleton className="h-10 w-full" />
                <Skeleton className="h-10 w-full" />
                <Skeleton className="h-10 w-full" />
              </CardContent>
            </Card>
          </div>
          <div className="lg:col-span-2">
            <Card>
              <CardHeader>
                <Skeleton className="h-6 w-32" />
                <Skeleton className="h-4 w-48" />
              </CardHeader>
              <CardContent>
                <Skeleton className="h-96 w-full" />
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    }>
      <NewJourneyContent />
    </Suspense>
  )
}