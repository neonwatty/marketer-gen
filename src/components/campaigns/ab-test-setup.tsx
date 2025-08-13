"use client"

import * as React from "react"
import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Slider } from "@/components/ui/slider"
import { Separator } from "@/components/ui/separator"
import { 
  FlaskConical,
  Target,
  Users,
  Calendar,
  BarChart3,
  Settings,
  Play,
  Pause,
  Info,
  CheckCircle,
  AlertTriangle,
  Copy,
  ArrowRight,
  Zap,
  TrendingUp
} from "lucide-react"

interface ABTestConfig {
  testName: string
  hypothesis: string
  primaryMetric: string
  secondaryMetrics: string[]
  trafficSplit: number
  duration: number
  minimumSampleSize: number
  significanceLevel: number
  variants: ABTestVariant[]
}

interface ABTestVariant {
  id: string
  name: string
  description: string
  trafficPercentage: number
  changes: VariantChange[]
}

interface VariantChange {
  element: string
  changeType: 'text' | 'image' | 'color' | 'layout' | 'targeting'
  originalValue: string
  newValue: string
  description: string
}

interface ABTestSetupProps {
  onSave?: (config: ABTestConfig) => void
  onCancel?: () => void
  className?: string
}

const availableMetrics = [
  { value: 'conversions', label: 'Conversions', description: 'Number of successful conversions' },
  { value: 'clickThroughRate', label: 'Click-through Rate', description: 'Percentage of clicks from impressions' },
  { value: 'conversionRate', label: 'Conversion Rate', description: 'Percentage of conversions from clicks' },
  { value: 'engagement', label: 'Engagement Rate', description: 'User interaction with content' },
  { value: 'costPerConversion', label: 'Cost per Conversion', description: 'Average cost to acquire a conversion' },
  { value: 'returnOnAdSpend', label: 'Return on Ad Spend', description: 'Revenue generated per dollar spent' }
]

const changeTypes = [
  { value: 'text', label: 'Text Content', description: 'Headlines, copy, CTAs' },
  { value: 'image', label: 'Images/Media', description: 'Photos, videos, graphics' },
  { value: 'color', label: 'Colors/Design', description: 'Brand colors, button colors' },
  { value: 'layout', label: 'Layout/Structure', description: 'Page structure, component placement' },
  { value: 'targeting', label: 'Audience Targeting', description: 'Audience segments, demographics' }
]

export function ABTestSetup({ onSave, onCancel, className }: ABTestSetupProps) {
  const [config, setConfig] = React.useState<ABTestConfig>({
    testName: "",
    hypothesis: "",
    primaryMetric: "",
    secondaryMetrics: [],
    trafficSplit: 50,
    duration: 14,
    minimumSampleSize: 1000,
    significanceLevel: 95,
    variants: [
      {
        id: "control",
        name: "Control (Original)",
        description: "Current campaign version",
        trafficPercentage: 50,
        changes: []
      },
      {
        id: "variant-a",
        name: "Variant A",
        description: "Test variation",
        trafficPercentage: 50,
        changes: []
      }
    ]
  })

  const [currentStep, setCurrentStep] = React.useState(1)
  const [newChange, setNewChange] = React.useState<VariantChange>({
    element: "",
    changeType: "text",
    originalValue: "",
    newValue: "",
    description: ""
  })

  const updateConfig = (updates: Partial<ABTestConfig>) => {
    setConfig(prev => ({ ...prev, ...updates }))
  }

  const updateVariant = (variantId: string, updates: Partial<ABTestVariant>) => {
    setConfig(prev => ({
      ...prev,
      variants: prev.variants.map(v => 
        v.id === variantId ? { ...v, ...updates } : v
      )
    }))
  }

  const addChange = (variantId: string) => {
    if (newChange.element && newChange.description) {
      updateVariant(variantId, {
        changes: [...config.variants.find(v => v.id === variantId)?.changes || [], newChange]
      })
      setNewChange({
        element: "",
        changeType: "text",
        originalValue: "",
        newValue: "",
        description: ""
      })
    }
  }

  const removeChange = (variantId: string, changeIndex: number) => {
    const variant = config.variants.find(v => v.id === variantId)
    if (variant) {
      updateVariant(variantId, {
        changes: variant.changes.filter((_, index) => index !== changeIndex)
      })
    }
  }

  const addVariant = () => {
    const newVariantId = `variant-${String.fromCharCode(65 + config.variants.length - 1)}`
    const newVariant: ABTestVariant = {
      id: newVariantId,
      name: `Variant ${String.fromCharCode(65 + config.variants.length - 1)}`,
      description: "New test variation",
      trafficPercentage: Math.floor(100 / (config.variants.length + 1)),
      changes: []
    }

    // Redistribute traffic evenly
    const redistributedPercentage = Math.floor(100 / (config.variants.length + 1))
    const updatedVariants = config.variants.map(v => ({
      ...v,
      trafficPercentage: redistributedPercentage
    }))

    setConfig(prev => ({
      ...prev,
      variants: [...updatedVariants, newVariant]
    }))
  }

  const calculatePowerAnalysis = () => {
    // Simple power analysis calculation
    const baseConversionRate = 0.05 // 5% baseline
    const minDetectableEffect = 0.20 // 20% improvement
    const alpha = (100 - config.significanceLevel) / 100
    const beta = 0.20 // 80% power
    
    // Simplified sample size calculation
    const samplesPerVariant = Math.ceil(
      (2 * Math.pow(1.96 + 0.84, 2) * baseConversionRate * (1 - baseConversionRate)) /
      Math.pow(baseConversionRate * minDetectableEffect, 2)
    )

    return {
      samplesPerVariant,
      totalSamples: samplesPerVariant * config.variants.length,
      estimatedDuration: Math.ceil(samplesPerVariant / (config.minimumSampleSize / config.duration)),
      detectionPower: 80
    }
  }

  const powerAnalysis = calculatePowerAnalysis()

  const handleSave = () => {
    onSave?.(config)
  }

  const isConfigValid = () => {
    return config.testName && 
           config.hypothesis && 
           config.primaryMetric &&
           config.variants.length >= 2 &&
           config.variants.some(v => v.changes.length > 0)
  }

  return (
    <div className={cn("space-y-6", className)}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <FlaskConical className="h-6 w-6 text-blue-600" />
          <div>
            <h2 className="text-2xl font-bold tracking-tight">A/B Test Setup</h2>
            <p className="text-muted-foreground">Configure your campaign A/B test experiment</p>
          </div>
        </div>
        
        <div className="flex items-center gap-2">
          <Button variant="outline" onClick={onCancel}>
            Cancel
          </Button>
          <Button onClick={handleSave} disabled={!isConfigValid()}>
            <Play className="h-4 w-4 mr-2" />
            Start Test
          </Button>
        </div>
      </div>

      {/* Step Progress */}
      <div className="flex items-center gap-4">
        {[1, 2, 3, 4].map((step) => (
          <div key={step} className="flex items-center gap-2">
            <div className={cn(
              "w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium",
              currentStep >= step ? "bg-blue-600 text-white" : "bg-gray-200 text-gray-600"
            )}>
              {step}
            </div>
            <span className={cn(
              "text-sm",
              currentStep >= step ? "text-blue-600 font-medium" : "text-gray-600"
            )}>
              {step === 1 && "Test Setup"}
              {step === 2 && "Variants"}
              {step === 3 && "Configuration"}
              {step === 4 && "Review"}
            </span>
            {step < 4 && <ArrowRight className="h-4 w-4 text-gray-400" />}
          </div>
        ))}
      </div>

      {/* Step 1: Basic Test Setup */}
      {currentStep === 1 && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <Card>
            <CardHeader>
              <CardTitle>Test Information</CardTitle>
              <CardDescription>
                Define your A/B test objectives and hypothesis
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              <div>
                <Label htmlFor="test-name">Test Name *</Label>
                <Input
                  id="test-name"
                  placeholder="e.g., Email Subject Line Test"
                  value={config.testName}
                  onChange={(e) => updateConfig({ testName: e.target.value })}
                />
              </div>

              <div>
                <Label htmlFor="hypothesis">Test Hypothesis *</Label>
                <Textarea
                  id="hypothesis"
                  placeholder="e.g., Changing the email subject line from 'Sale Today' to 'Limited Time: 50% Off' will increase open rates by 15%"
                  value={config.hypothesis}
                  onChange={(e) => updateConfig({ hypothesis: e.target.value })}
                  className="min-h-[80px]"
                />
              </div>

              <div>
                <Label htmlFor="primary-metric">Primary Success Metric *</Label>
                <Select value={config.primaryMetric} onValueChange={(value) => updateConfig({ primaryMetric: value })}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select primary metric" />
                  </SelectTrigger>
                  <SelectContent>
                    {availableMetrics.map((metric) => (
                      <SelectItem key={metric.value} value={metric.value}>
                        <div>
                          <div className="font-medium">{metric.label}</div>
                          <div className="text-xs text-gray-500">{metric.description}</div>
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div>
                <Label>Secondary Metrics (Optional)</Label>
                <div className="grid grid-cols-2 gap-2 mt-2">
                  {availableMetrics
                    .filter(m => m.value !== config.primaryMetric)
                    .map((metric) => (
                    <label key={metric.value} className="flex items-center space-x-2 text-sm">
                      <input
                        type="checkbox"
                        checked={config.secondaryMetrics.includes(metric.value)}
                        onChange={(e) => {
                          if (e.target.checked) {
                            updateConfig({ 
                              secondaryMetrics: [...config.secondaryMetrics, metric.value] 
                            })
                          } else {
                            updateConfig({ 
                              secondaryMetrics: config.secondaryMetrics.filter(m => m !== metric.value) 
                            })
                          }
                        }}
                        className="rounded"
                      />
                      <span>{metric.label}</span>
                    </label>
                  ))}
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Test Parameters</CardTitle>
              <CardDescription>
                Configure duration and sample size requirements
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              <div>
                <Label>Test Duration (days)</Label>
                <div className="mt-2">
                  <Slider
                    value={[config.duration]}
                    onValueChange={(value) => updateConfig({ duration: value[0] })}
                    max={30}
                    min={3}
                    step={1}
                    className="mb-2"
                  />
                  <div className="flex justify-between text-sm text-gray-500">
                    <span>3 days</span>
                    <span className="font-medium">{config.duration} days</span>
                    <span>30 days</span>
                  </div>
                </div>
              </div>

              <div>
                <Label>Significance Level (%)</Label>
                <div className="mt-2">
                  <Slider
                    value={[config.significanceLevel]}
                    onValueChange={(value) => updateConfig({ significanceLevel: value[0] })}
                    max={99}
                    min={90}
                    step={1}
                    className="mb-2"
                  />
                  <div className="flex justify-between text-sm text-gray-500">
                    <span>90%</span>
                    <span className="font-medium">{config.significanceLevel}%</span>
                    <span>99%</span>
                  </div>
                </div>
              </div>

              <div>
                <Label htmlFor="sample-size">Minimum Sample Size per Variant</Label>
                <Input
                  id="sample-size"
                  type="number"
                  value={config.minimumSampleSize}
                  onChange={(e) => updateConfig({ minimumSampleSize: parseInt(e.target.value) || 1000 })}
                  min="100"
                  step="100"
                />
              </div>

              <div className="p-4 bg-blue-50 rounded-lg border border-blue-200">
                <div className="flex items-start gap-2">
                  <Info className="h-4 w-4 text-blue-600 mt-0.5" />
                  <div className="text-sm">
                    <p className="font-medium text-blue-900 mb-1">Power Analysis</p>
                    <div className="text-blue-800 space-y-1">
                      <p>• Samples needed per variant: {powerAnalysis.samplesPerVariant.toLocaleString()}</p>
                      <p>• Total samples needed: {powerAnalysis.totalSamples.toLocaleString()}</p>
                      <p>• Estimated duration: {powerAnalysis.estimatedDuration} days</p>
                      <p>• Statistical power: {powerAnalysis.detectionPower}%</p>
                    </div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Step 2: Variant Configuration */}
      {currentStep === 2 && (
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-medium">Test Variants</h3>
            <Button onClick={addVariant} variant="outline" size="sm">
              <Copy className="h-4 w-4 mr-2" />
              Add Variant
            </Button>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {config.variants.map((variant, index) => (
              <Card key={variant.id}>
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <CardTitle className="flex items-center gap-2">
                      {variant.id === 'control' ? (
                        <CheckCircle className="h-5 w-5 text-green-600" />
                      ) : (
                        <FlaskConical className="h-5 w-5 text-blue-600" />
                      )}
                      {variant.name}
                    </CardTitle>
                    <Badge variant="outline">
                      {variant.trafficPercentage}% traffic
                    </Badge>
                  </div>
                  <CardDescription>{variant.description}</CardDescription>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div>
                    <Label htmlFor={`variant-name-${variant.id}`}>Variant Name</Label>
                    <Input
                      id={`variant-name-${variant.id}`}
                      value={variant.name}
                      onChange={(e) => updateVariant(variant.id, { name: e.target.value })}
                    />
                  </div>

                  <div>
                    <Label htmlFor={`variant-desc-${variant.id}`}>Description</Label>
                    <Textarea
                      id={`variant-desc-${variant.id}`}
                      value={variant.description}
                      onChange={(e) => updateVariant(variant.id, { description: e.target.value })}
                      className="min-h-[60px]"
                    />
                  </div>

                  <Separator />

                  <div>
                    <div className="flex items-center justify-between mb-3">
                      <Label>Changes</Label>
                      <span className="text-sm text-gray-500">
                        {variant.changes.length} change{variant.changes.length !== 1 ? 's' : ''}
                      </span>
                    </div>

                    {variant.changes.length > 0 && (
                      <div className="space-y-2 mb-4">
                        {variant.changes.map((change, changeIndex) => (
                          <div key={changeIndex} className="flex items-center justify-between p-3 border rounded">
                            <div className="flex-1">
                              <div className="flex items-center gap-2 mb-1">
                                <Badge variant="secondary" className="text-xs">
                                  {changeTypes.find(t => t.value === change.changeType)?.label}
                                </Badge>
                                <span className="font-medium text-sm">{change.element}</span>
                              </div>
                              <p className="text-xs text-gray-600">{change.description}</p>
                            </div>
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => removeChange(variant.id, changeIndex)}
                            >
                              ×
                            </Button>
                          </div>
                        ))}
                      </div>
                    )}

                    {variant.id !== 'control' && (
                      <div className="space-y-3 p-3 border-2 border-dashed border-gray-200 rounded">
                        <div className="grid grid-cols-2 gap-3">
                          <div>
                            <Label className="text-xs">Element/Component</Label>
                            <Input
                              placeholder="e.g., Email Subject"
                              value={newChange.element}
                              onChange={(e) => setNewChange(prev => ({ ...prev, element: e.target.value }))}
                              className="text-sm"
                            />
                          </div>
                          <div>
                            <Label className="text-xs">Change Type</Label>
                            <Select 
                              value={newChange.changeType} 
                              onValueChange={(value: any) => setNewChange(prev => ({ ...prev, changeType: value }))}
                            >
                              <SelectTrigger className="text-sm">
                                <SelectValue />
                              </SelectTrigger>
                              <SelectContent>
                                {changeTypes.map((type) => (
                                  <SelectItem key={type.value} value={type.value}>
                                    {type.label}
                                  </SelectItem>
                                ))}
                              </SelectContent>
                            </Select>
                          </div>
                        </div>
                        
                        <div>
                          <Label className="text-xs">Change Description</Label>
                          <Input
                            placeholder="Describe what you're changing..."
                            value={newChange.description}
                            onChange={(e) => setNewChange(prev => ({ ...prev, description: e.target.value }))}
                            className="text-sm"
                          />
                        </div>

                        <Button 
                          size="sm" 
                          onClick={() => addChange(variant.id)}
                          disabled={!newChange.element || !newChange.description}
                          className="w-full"
                        >
                          Add Change
                        </Button>
                      </div>
                    )}
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      )}

      {/* Navigation */}
      <div className="flex items-center justify-between pt-6 border-t">
        <Button
          variant="outline"
          onClick={() => setCurrentStep(Math.max(1, currentStep - 1))}
          disabled={currentStep === 1}
        >
          Previous
        </Button>
        
        <div className="flex items-center gap-2">
          <span className="text-sm text-gray-500">
            Step {currentStep} of 4
          </span>
        </div>

        <Button
          onClick={() => setCurrentStep(Math.min(4, currentStep + 1))}
          disabled={currentStep === 4}
        >
          Next
        </Button>
      </div>
    </div>
  )
}