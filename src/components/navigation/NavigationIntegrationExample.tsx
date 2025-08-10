"use client"

import * as React from "react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"

import { StepperNavigation, type StepperStep } from "@/components/ui/stepper-navigation"
import { EnhancedTabs, type EnhancedTabItem } from "@/components/ui/enhanced-tabs"
import { StepValidation, ValidationSummary, useStepValidation, type ValidationRule } from "@/components/ui/step-validation"
import { NavigationGuidance, StepGuidance } from "@/components/ui/navigation-guidance"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { 
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form"
import { FileUploadField } from "@/components/forms/FileUploadField"

// Form schemas for each step
const step1Schema = z.object({
  projectName: z.string().min(1, "Project name is required"),
  description: z.string().min(10, "Description must be at least 10 characters"),
})

const step2Schema = z.object({
  targetAudience: z.string().min(1, "Target audience is required"),
  goals: z.array(z.string()).min(1, "At least one goal is required"),
})

const step3Schema = z.object({
  brandAssets: z.array(z.any()).optional(),
  brandColors: z.string().optional(),
})

const fullSchema = z.object({
  ...step1Schema.shape,
  ...step2Schema.shape,
  ...step3Schema.shape,
})

type FormData = z.infer<typeof fullSchema>

export function NavigationIntegrationExample() {
  const [currentStep, setCurrentStep] = React.useState(0)
  const [completedSteps, setCompletedSteps] = React.useState<Set<number>>(new Set())

  const form = useForm<FormData>({
    resolver: zodResolver(fullSchema),
    defaultValues: {
      projectName: "",
      description: "",
      targetAudience: "",
      goals: [],
      brandAssets: [],
      brandColors: "",
    },
  })

  const formValues = form.watch()

  // Define steps for stepper navigation
  const steps: StepperStep[] = [
    {
      id: "project-details",
      title: "Project Details",
      description: "Basic information about your project",
      isCompleted: completedSteps.has(0),
    },
    {
      id: "targeting",
      title: "Target & Goals", 
      description: "Define your audience and objectives",
      isCompleted: completedSteps.has(1),
    },
    {
      id: "branding",
      title: "Brand Assets",
      description: "Upload brand materials and set colors",
      isCompleted: completedSteps.has(2),
      isOptional: true,
    },
  ]

  // Enhanced tabs configuration
  const tabItems: EnhancedTabItem[] = [
    {
      id: "project-details",
      label: "Project Details",
      content: <Step1Form form={form} />,
      hasError: !!form.formState.errors.projectName || !!form.formState.errors.description,
      isCompleted: completedSteps.has(0),
      badge: form.formState.errors.projectName || form.formState.errors.description ? "!" : undefined,
      description: "Set up your project basics",
    },
    {
      id: "targeting",
      label: "Target & Goals",
      content: <Step2Form form={form} />,
      hasError: !!form.formState.errors.targetAudience || !!form.formState.errors.goals,
      isCompleted: completedSteps.has(1),
      badge: form.formState.errors.targetAudience || form.formState.errors.goals ? "!" : undefined,
      description: "Define your marketing strategy",
    },
    {
      id: "branding",
      label: "Brand Assets",
      content: <Step3Form form={form} />,
      isCompleted: completedSteps.has(2),
      description: "Upload brand materials (optional)",
    },
  ]

  // Validation rules for each step
  const validationRules: Record<string, ValidationRule[]> = React.useMemo(() => {
    const errors = form.formState.errors
    
    return {
      "project-details": [
        {
          id: "project-name",
          field: "projectName",
          message: errors.projectName?.message || "Project name is valid",
          status: errors.projectName ? "invalid" : formValues.projectName ? "valid" : "pending",
          required: true,
        },
        {
          id: "description", 
          field: "description",
          message: errors.description?.message || "Description is valid",
          status: errors.description ? "invalid" : formValues.description?.length >= 10 ? "valid" : "pending",
          required: true,
        },
      ],
      "targeting": [
        {
          id: "target-audience",
          field: "targetAudience", 
          message: errors.targetAudience?.message || "Target audience is valid",
          status: errors.targetAudience ? "invalid" : formValues.targetAudience ? "valid" : "pending",
          required: true,
        },
        {
          id: "goals",
          field: "goals",
          message: "At least one goal must be specified",
          status: !formValues.goals?.length ? "invalid" : "valid",
          required: true,
        },
      ],
      "branding": [
        {
          id: "brand-assets",
          field: "brandAssets",
          message: "Brand assets uploaded successfully",
          status: "info",
        },
        {
          id: "brand-colors",
          field: "brandColors",
          message: "Brand colors are optional but recommended",
          status: formValues.brandColors ? "valid" : "info",
        },
      ],
    }
  }, [form.formState.errors, formValues])

  // Use step validation hook
  const { validationResults, canProceedToStep } = useStepValidation(
    ["project-details", "targeting", "branding"],
    validationRules
  )

  // Step change handlers
  const handleStepChange = (stepIndex: number) => {
    setCurrentStep(stepIndex)
  }

  const handleNext = async () => {
    const currentStepId = steps[currentStep]?.id
    const isValid = await form.trigger(getFieldsForStep(currentStep))
    
    if (isValid) {
      setCompletedSteps(prev => new Set([...Array.from(prev), currentStep]))
      if (currentStep < steps.length - 1) {
        setCurrentStep(currentStep + 1)
      }
    }
  }

  const handlePrevious = () => {
    if (currentStep > 0) {
      setCurrentStep(currentStep - 1)
    }
  }

  const handleSubmit = form.handleSubmit((data) => {
    console.log("Form submitted:", data)
    alert("Form submitted successfully!")
  })

  const getFieldsForStep = (stepIndex: number): (keyof FormData)[] => {
    switch (stepIndex) {
      case 0: return ["projectName", "description"]
      case 1: return ["targetAudience", "goals"]
      case 2: return ["brandAssets", "brandColors"]
      default: return []
    }
  }

  const canGoNext = canProceedToStep(currentStep + 1)
  const currentStepValidation = validationResults.find(r => r.stepId === steps[currentStep]?.id)

  return (
    <div className="max-w-4xl mx-auto p-6 space-y-8">
      <div className="text-center">
        <h1 className="text-3xl font-bold mb-2">Campaign Creation Wizard</h1>
        <p className="text-muted-foreground">
          Create your marketing campaign using our guided process
        </p>
      </div>

      {/* Stepper Navigation Example */}
      <div className="space-y-6">
        <h2 className="text-xl font-semibold">Stepper Navigation Example</h2>
        
        <Form {...form}>
          <form onSubmit={handleSubmit} className="space-y-6">
            <StepperNavigation
              steps={steps}
              currentStep={currentStep}
              onStepChange={handleStepChange}
              onNext={handleNext}
              onPrevious={handlePrevious}
              onComplete={handleSubmit}
              canGoNext={canGoNext}
              showProgress={true}
              showStepNumbers={true}
            >
              {/* Step Content */}
              {currentStep === 0 && <Step1Form form={form} />}
              {currentStep === 1 && <Step2Form form={form} />}
              {currentStep === 2 && <Step3Form form={form} />}

              {/* Step Validation */}
              {currentStepValidation && (
                <StepValidation
                  stepId={currentStepValidation.stepId}
                  validationRules={validationRules[currentStepValidation.stepId] || []}
                />
              )}
            </StepperNavigation>
          </form>
        </Form>
      </div>

      {/* Enhanced Tabs Example */}
      <div className="space-y-6">
        <h2 className="text-xl font-semibold">Enhanced Tabs Example</h2>
        
        <EnhancedTabs
          items={tabItems}
          value={steps[currentStep]?.id || steps[0]?.id || ""}
          onValueChange={(value) => {
            const stepIndex = steps.findIndex(step => step.id === value)
            if (stepIndex >= 0) handleStepChange(stepIndex)
          }}
          variant="cards"
          showNavigation={true}
          allowTabSwitching={true}
        />
      </div>

      {/* Navigation Guidance Example */}
      <div className="space-y-6">
        <h2 className="text-xl font-semibold">Navigation Guidance Example</h2>
        
        <NavigationGuidance
          currentStep={currentStep}
          totalSteps={steps.length}
          onNext={handleNext}
          onPrevious={handlePrevious}
          onSave={() => console.log("Saving...")}
          onPreview={() => console.log("Previewing...")}
          canGoNext={canGoNext}
          stepTitle={steps[currentStep]?.title || ""}
          stepDescription={steps[currentStep]?.description}
          validationStatus={currentStepValidation?.isValid ? "valid" : "invalid"}
          helpContent={
            <div>
              <p className="font-medium">Need help with this step?</p>
              <p className="text-sm mt-1">
                {getHelpContent(currentStep)}
              </p>
            </div>
          }
          tips={getTipsForStep(currentStep)}
        />
      </div>

      {/* Step Guidance Examples */}
      <div className="space-y-6">
        <h2 className="text-xl font-semibold">Step Guidance Examples</h2>
        
        <div className="grid gap-4">
          {steps.map((step, index) => (
            <StepGuidance
              key={step.id}
              title={step.title}
              description={step.description}
              status={
                index < currentStep ? "completed" :
                index === currentStep ? "current" : 
                index === currentStep + 1 ? "upcoming" : "upcoming"
              }
              estimatedTime={getEstimatedTime(index)}
              requiredFields={getRequiredFields(index)}
              optionalFields={getOptionalFields(index)}
              tips={getTipsForStep(index)}
            />
          ))}
        </div>
      </div>

      {/* Validation Summary */}
      <ValidationSummary
        validationResults={validationResults}
        currentStep={currentStep}
      />
    </div>
  )
}

// Step form components
function Step1Form({ form }: { form: any }) {
  return (
    <div className="space-y-4">
      <FormField
        control={form.control}
        name="projectName"
        render={({ field }) => (
          <FormItem>
            <FormLabel>Project Name *</FormLabel>
            <FormControl>
              <Input placeholder="Enter your project name" {...field} />
            </FormControl>
            <FormMessage />
          </FormItem>
        )}
      />
      
      <FormField
        control={form.control}
        name="description"
        render={({ field }) => (
          <FormItem>
            <FormLabel>Description *</FormLabel>
            <FormControl>
              <Textarea 
                placeholder="Describe your project (minimum 10 characters)" 
                {...field} 
              />
            </FormControl>
            <FormMessage />
          </FormItem>
        )}
      />
    </div>
  )
}

function Step2Form({ form }: { form: any }) {
  const [goalInput, setGoalInput] = React.useState("")
  const goals = form.watch("goals") || []

  const addGoal = () => {
    if (goalInput.trim()) {
      form.setValue("goals", [...goals, goalInput.trim()])
      setGoalInput("")
    }
  }

  const removeGoal = (index: number) => {
    form.setValue("goals", goals.filter((_: any, i: number) => i !== index))
  }

  return (
    <div className="space-y-4">
      <FormField
        control={form.control}
        name="targetAudience"
        render={({ field }) => (
          <FormItem>
            <FormLabel>Target Audience *</FormLabel>
            <FormControl>
              <Textarea 
                placeholder="Describe your target audience" 
                {...field} 
              />
            </FormControl>
            <FormMessage />
          </FormItem>
        )}
      />

      <div>
        <Label>Goals *</Label>
        <div className="flex gap-2 mt-2">
          <Input
            placeholder="Add a goal"
            value={goalInput}
            onChange={(e) => setGoalInput(e.target.value)}
            onKeyPress={(e) => e.key === "Enter" && addGoal()}
          />
          <Button type="button" onClick={addGoal}>
            Add
          </Button>
        </div>
        
        {goals.length > 0 && (
          <div className="mt-2 space-y-1">
            {goals.map((goal: string, index: number) => (
              <div key={index} className="flex items-center justify-between p-2 bg-muted rounded">
                <span>{goal}</span>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => removeGoal(index)}
                >
                  Remove
                </Button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

function Step3Form({ form }: { form: any }) {
  return (
    <div className="space-y-4">
      <FormField
        control={form.control}
        name="brandAssets"
        render={({ field }) => (
          <FormItem>
            <FormLabel>Brand Assets (Optional)</FormLabel>
            <FormControl>
              <FileUploadField
                {...field}
                onUpload={async (files) => field.onChange(files)}
                maxFiles={5}
                acceptedFileTypes={{
                  "image/*": [".png", ".jpg", ".jpeg", ".svg"]
                }}
              />
            </FormControl>
          </FormItem>
        )}
      />
      
      <FormField
        control={form.control}
        name="brandColors"
        render={({ field }) => (
          <FormItem>
            <FormLabel>Brand Colors (Optional)</FormLabel>
            <FormControl>
              <Input 
                placeholder="e.g., #FF5733, #C70039" 
                {...field} 
              />
            </FormControl>
          </FormItem>
        )}
      />
    </div>
  )
}

// Helper functions
function getHelpContent(stepIndex: number): string {
  const content = [
    "Provide basic information about your marketing project. This will help us understand your needs.",
    "Define who you're trying to reach and what you want to achieve with your campaign.",
    "Upload your brand assets and colors to maintain consistency across your materials."
  ]
  return content[stepIndex] || ""
}

function getTipsForStep(stepIndex: number): string[] {
  const tips = [
    [
      "Choose a descriptive project name that clearly identifies your campaign",
      "Include key details in the description like campaign duration and main objectives"
    ],
    [
      "Be specific about your target audience demographics and interests", 
      "Set measurable goals that you can track and evaluate"
    ],
    [
      "Upload high-quality brand assets in PNG, JPG, or SVG format",
      "Provide hex color codes for consistent branding across materials"
    ]
  ]
  return tips[stepIndex] || []
}

function getEstimatedTime(stepIndex: number): string {
  const times = ["3-5 minutes", "5-8 minutes", "2-3 minutes"]
  return times[stepIndex] || "2-5 minutes"
}

function getRequiredFields(stepIndex: number): string[] {
  const fields = [
    ["Project Name", "Description"],
    ["Target Audience", "Goals"],
    []
  ]
  return fields[stepIndex] || []
}

function getOptionalFields(stepIndex: number): string[] {
  const fields = [
    [],
    [],
    ["Brand Assets", "Brand Colors"]
  ]
  return fields[stepIndex] || []
}