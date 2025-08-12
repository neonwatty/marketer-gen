"use client"

import React, { useState, useMemo } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { Separator } from "@/components/ui/separator"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Slider } from "@/components/ui/slider"
import { Progress } from "@/components/ui/progress"
import { 
  DollarSign,
  PieChart,
  TrendingUp,
  Users,
  Clock,
  Target,
  AlertTriangle,
  CheckCircle,
  BarChart3,
  Calculator,
  Settings,
  RefreshCw,
  Download,
  Plus,
  Minus,
  Edit,
  Save
} from "lucide-react"

// Budget allocation interfaces
interface BudgetAllocation {
  id: string
  name: string
  allocated: number
  percentage: number
  spent: number
  remaining: number
  category: 'content' | 'advertising' | 'tools' | 'personnel' | 'other'
  channels: string[]
  color: string
}

interface ResourceRequirement {
  id: string
  type: 'personnel' | 'tools' | 'content-creation' | 'advertising'
  name: string
  cost: number
  quantity: number
  duration: number // in weeks
  description: string
  priority: 'low' | 'medium' | 'high' | 'critical'
}

interface CostCalculation {
  contentType: string
  channel: string
  baseCost: number
  complexity: number
  timeEstimate: number // hours
  totalCost: number
}

interface BudgetOptimization {
  suggestion: string
  impact: number // percentage improvement
  effort: 'low' | 'medium' | 'high'
  category: string
  savings: number
}

interface BudgetAllocationDashboardProps {
  campaignId: string
  totalBudget: number
  currentAllocations?: BudgetAllocation[]
  onSaveAllocations: (allocations: BudgetAllocation[]) => void
  onOptimizeAllocations: (optimizations: BudgetOptimization[]) => void
}

// Mock data and calculations
const CONTENT_COSTS = {
  'blog-post': { base: 150, complexity: 1.2, hours: 4 },
  'social-post': { base: 50, complexity: 1.0, hours: 1 },
  'email-newsletter': { base: 200, complexity: 1.3, hours: 6 },
  'landing-page': { base: 500, complexity: 1.8, hours: 12 },
  'video-content': { base: 800, complexity: 2.5, hours: 20 },
  'infographic': { base: 300, complexity: 1.5, hours: 8 }
}

const CHANNEL_MULTIPLIERS = {
  'Email': 1.0,
  'Social Media': 1.2,
  'Blog': 1.1,
  'Display Ads': 2.0,
  'Google Ads': 2.2,
  'LinkedIn Ads': 1.8,
  'Facebook Ads': 1.5
}

const INITIAL_ALLOCATIONS: BudgetAllocation[] = [
  {
    id: 'content',
    name: 'Content Creation',
    allocated: 8000,
    percentage: 32,
    spent: 5200,
    remaining: 2800,
    category: 'content',
    channels: ['Blog', 'Social Media', 'Email'],
    color: 'bg-blue-500'
  },
  {
    id: 'advertising',
    name: 'Paid Advertising',
    allocated: 12000,
    percentage: 48,
    spent: 8500,
    remaining: 3500,
    category: 'advertising',
    channels: ['Google Ads', 'Facebook Ads', 'Display Ads'],
    color: 'bg-green-500'
  },
  {
    id: 'tools',
    name: 'Marketing Tools',
    allocated: 2000,
    percentage: 8,
    spent: 1800,
    remaining: 200,
    category: 'tools',
    channels: ['All'],
    color: 'bg-purple-500'
  },
  {
    id: 'personnel',
    name: 'Personnel Costs',
    allocated: 2500,
    percentage: 10,
    spent: 1250,
    remaining: 1250,
    category: 'personnel',
    channels: ['All'],
    color: 'bg-orange-500'
  },
  {
    id: 'other',
    name: 'Other Expenses',
    allocated: 500,
    percentage: 2,
    spent: 150,
    remaining: 350,
    category: 'other',
    channels: ['All'],
    color: 'bg-gray-500'
  }
]

const RESOURCE_REQUIREMENTS: ResourceRequirement[] = [
  {
    id: 'content-writer',
    type: 'personnel',
    name: 'Content Writer',
    cost: 150,
    quantity: 2,
    duration: 12,
    description: '2 content writers for blog posts and social media',
    priority: 'high'
  },
  {
    id: 'designer',
    type: 'personnel',
    name: 'Graphic Designer',
    cost: 120,
    quantity: 1,
    duration: 8,
    description: 'Visual content and social media graphics',
    priority: 'medium'
  },
  {
    id: 'video-editor',
    type: 'personnel',
    name: 'Video Editor',
    cost: 200,
    quantity: 1,
    duration: 4,
    description: 'Video content editing and production',
    priority: 'medium'
  },
  {
    id: 'analytics-tool',
    type: 'tools',
    name: 'Analytics Platform',
    cost: 99,
    quantity: 1,
    duration: 12,
    description: 'Comprehensive analytics and reporting',
    priority: 'high'
  }
]

const OPTIMIZATION_SUGGESTIONS: BudgetOptimization[] = [
  {
    suggestion: 'Reallocate 15% from Display Ads to Social Media Ads for better ROI',
    impact: 18,
    effort: 'low',
    category: 'advertising',
    savings: 800
  },
  {
    suggestion: 'Reduce video content frequency and increase blog posts',
    impact: 12,
    effort: 'medium',
    category: 'content',
    savings: 600
  },
  {
    suggestion: 'Consolidate marketing tools to reduce subscription costs',
    impact: 25,
    effort: 'high',
    category: 'tools',
    savings: 300
  },
  {
    suggestion: 'Use AI tools to automate social media posting',
    impact: 20,
    effort: 'medium',
    category: 'personnel',
    savings: 400
  }
]

export function BudgetAllocationDashboard({ 
  campaignId, 
  totalBudget, 
  currentAllocations = INITIAL_ALLOCATIONS,
  onSaveAllocations,
  onOptimizeAllocations 
}: BudgetAllocationDashboardProps) {
  const [allocations, setAllocations] = useState<BudgetAllocation[]>(currentAllocations)
  const [isEditing, setIsEditing] = useState(false)
  const [selectedChannel, setSelectedChannel] = useState<string>('all')
  const [costCalculator, setCostCalculator] = useState({
    contentType: 'blog-post',
    channel: 'Blog',
    quantity: 1,
    complexity: 1
  })

  // Calculate totals
  const totalAllocated = allocations.reduce((sum, alloc) => sum + alloc.allocated, 0)
  const totalSpent = allocations.reduce((sum, alloc) => sum + alloc.spent, 0)
  const totalRemaining = allocations.reduce((sum, alloc) => sum + alloc.remaining, 0)
  const budgetUtilization = (totalSpent / totalBudget) * 100

  // Calculate cost for content type
  const calculateContentCost = () => {
    const content = CONTENT_COSTS[costCalculator.contentType as keyof typeof CONTENT_COSTS]
    const multiplier = CHANNEL_MULTIPLIERS[costCalculator.channel as keyof typeof CHANNEL_MULTIPLIERS]
    const baseCost = content.base * content.complexity * costCalculator.complexity
    return Math.round(baseCost * multiplier * costCalculator.quantity)
  }

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount)
  }

  const updateAllocation = (id: string, allocated: number) => {
    setAllocations(prev => prev.map(alloc => {
      if (alloc.id === id) {
        const percentage = (allocated / totalBudget) * 100
        const remaining = allocated - alloc.spent
        return { ...alloc, allocated, percentage, remaining }
      }
      return alloc
    }))
  }

  const handleSaveAllocations = () => {
    onSaveAllocations(allocations)
    setIsEditing(false)
    alert('Budget allocations saved successfully!')
  }

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'critical': return 'bg-red-100 text-red-800 border-red-200'
      case 'high': return 'bg-orange-100 text-orange-800 border-orange-200'
      case 'medium': return 'bg-yellow-100 text-yellow-800 border-yellow-200'
      case 'low': return 'bg-green-100 text-green-800 border-green-200'
      default: return 'bg-gray-100 text-gray-800 border-gray-200'
    }
  }

  const getEffortColor = (effort: string) => {
    switch (effort) {
      case 'high': return 'bg-red-100 text-red-800'
      case 'medium': return 'bg-yellow-100 text-yellow-800'
      case 'low': return 'bg-green-100 text-green-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold">Budget Allocation & Resource Planning</h2>
          <p className="text-muted-foreground">
            Optimize budget distribution and plan resource requirements
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" onClick={() => onOptimizeAllocations(OPTIMIZATION_SUGGESTIONS)}>
            <TrendingUp className="h-4 w-4 mr-2" />
            Optimize Budget
          </Button>
          <Button 
            variant={isEditing ? "default" : "outline"}
            onClick={isEditing ? handleSaveAllocations : () => setIsEditing(true)}
          >
            {isEditing ? (
              <>
                <Save className="h-4 w-4 mr-2" />
                Save Changes
              </>
            ) : (
              <>
                <Edit className="h-4 w-4 mr-2" />
                Edit Allocations
              </>
            )}
          </Button>
          <Button variant="outline">
            <Download className="h-4 w-4 mr-2" />
            Export Report
          </Button>
        </div>
      </div>

      {/* Budget Overview Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-muted-foreground">Total Budget</p>
                <p className="text-2xl font-bold">{formatCurrency(totalBudget)}</p>
              </div>
              <DollarSign className="h-8 w-8 text-blue-600" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-muted-foreground">Allocated</p>
                <p className="text-2xl font-bold">{formatCurrency(totalAllocated)}</p>
                <p className="text-xs text-muted-foreground">
                  {((totalAllocated / totalBudget) * 100).toFixed(1)}% of total
                </p>
              </div>
              <PieChart className="h-8 w-8 text-green-600" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-muted-foreground">Spent</p>
                <p className="text-2xl font-bold">{formatCurrency(totalSpent)}</p>
                <p className="text-xs text-muted-foreground">
                  {budgetUtilization.toFixed(1)}% utilized
                </p>
              </div>
              <TrendingUp className="h-8 w-8 text-orange-600" />
            </div>
            <div className="mt-2">
              <Progress value={budgetUtilization} className="h-2" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-muted-foreground">Remaining</p>
                <p className="text-2xl font-bold">{formatCurrency(totalRemaining)}</p>
                <p className="text-xs text-muted-foreground">
                  {((totalRemaining / totalBudget) * 100).toFixed(1)}% available
                </p>
              </div>
              <Target className="h-8 w-8 text-purple-600" />
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Main Content Tabs */}
      <Tabs defaultValue="allocations" className="space-y-6">
        <TabsList>
          <TabsTrigger value="allocations">Budget Allocations</TabsTrigger>
          <TabsTrigger value="calculator">Cost Calculator</TabsTrigger>
          <TabsTrigger value="resources">Resource Planning</TabsTrigger>
          <TabsTrigger value="optimization">Optimization</TabsTrigger>
        </TabsList>

        <TabsContent value="allocations" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Budget Allocation Chart */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <PieChart className="h-5 w-5" />
                  Budget Distribution
                </CardTitle>
                <CardDescription>Current allocation across categories</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                {allocations.map((allocation) => (
                  <div key={allocation.id} className="space-y-2">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <div className={`w-3 h-3 rounded-full ${allocation.color}`}></div>
                        <span className="font-medium">{allocation.name}</span>
                      </div>
                      <div className="text-right">
                        <span className="font-bold">{formatCurrency(allocation.allocated)}</span>
                        <span className="text-sm text-muted-foreground ml-2">
                          ({allocation.percentage.toFixed(1)}%)
                        </span>
                      </div>
                    </div>
                    <Progress 
                      value={(allocation.spent / allocation.allocated) * 100} 
                      className="h-2"
                    />
                    <div className="flex justify-between text-xs text-muted-foreground">
                      <span>Spent: {formatCurrency(allocation.spent)}</span>
                      <span>Remaining: {formatCurrency(allocation.remaining)}</span>
                    </div>
                  </div>
                ))}
              </CardContent>
            </Card>

            {/* Allocation Editor */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Settings className="h-5 w-5" />
                  Adjust Allocations
                </CardTitle>
                <CardDescription>
                  {isEditing ? 'Modify budget allocations' : 'Click Edit to modify allocations'}
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                {allocations.map((allocation) => (
                  <div key={allocation.id} className="space-y-2">
                    <div className="flex items-center justify-between">
                      <Label className="font-medium">{allocation.name}</Label>
                      <div className="text-right">
                        <span className="text-sm font-mono">
                          {formatCurrency(allocation.allocated)}
                        </span>
                      </div>
                    </div>
                    {isEditing ? (
                      <div className="space-y-2">
                        <Slider
                          value={[allocation.allocated]}
                          max={totalBudget}
                          step={100}
                          onValueChange={(value) => updateAllocation(allocation.id, value[0])}
                          className="w-full"
                        />
                        <div className="flex justify-between text-xs text-muted-foreground">
                          <span>0</span>
                          <span>{allocation.percentage.toFixed(1)}%</span>
                          <span>{formatCurrency(totalBudget)}</span>
                        </div>
                      </div>
                    ) : (
                      <Progress 
                        value={allocation.percentage} 
                        className="h-2"
                      />
                    )}
                  </div>
                ))}

                {isEditing && (
                  <div className="pt-4 border-t">
                    <div className="flex justify-between items-center">
                      <span className="font-medium">Total Allocated:</span>
                      <span className="font-bold">
                        {formatCurrency(totalAllocated)}
                      </span>
                    </div>
                    {totalAllocated > totalBudget && (
                      <div className="flex items-center gap-2 text-red-600 text-sm mt-2">
                        <AlertTriangle className="h-4 w-4" />
                        Over budget by {formatCurrency(totalAllocated - totalBudget)}
                      </div>
                    )}
                  </div>
                )}
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="calculator" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Cost Calculator */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Calculator className="h-5 w-5" />
                  Content Cost Calculator
                </CardTitle>
                <CardDescription>
                  Calculate costs for different content types and channels
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <Label>Content Type</Label>
                  <Select
                    value={costCalculator.contentType}
                    onValueChange={(value) => setCostCalculator(prev => ({ ...prev, contentType: value }))}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="blog-post">Blog Post</SelectItem>
                      <SelectItem value="social-post">Social Media Post</SelectItem>
                      <SelectItem value="email-newsletter">Email Newsletter</SelectItem>
                      <SelectItem value="landing-page">Landing Page</SelectItem>
                      <SelectItem value="video-content">Video Content</SelectItem>
                      <SelectItem value="infographic">Infographic</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <div className="space-y-2">
                  <Label>Channel</Label>
                  <Select
                    value={costCalculator.channel}
                    onValueChange={(value) => setCostCalculator(prev => ({ ...prev, channel: value }))}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="Email">Email</SelectItem>
                      <SelectItem value="Social Media">Social Media</SelectItem>
                      <SelectItem value="Blog">Blog</SelectItem>
                      <SelectItem value="Display Ads">Display Ads</SelectItem>
                      <SelectItem value="Google Ads">Google Ads</SelectItem>
                      <SelectItem value="LinkedIn Ads">LinkedIn Ads</SelectItem>
                      <SelectItem value="Facebook Ads">Facebook Ads</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <div className="space-y-2">
                  <Label>Quantity</Label>
                  <Input
                    type="number"
                    min="1"
                    max="100"
                    value={costCalculator.quantity}
                    onChange={(e) => setCostCalculator(prev => ({ 
                      ...prev, 
                      quantity: parseInt(e.target.value) || 1 
                    }))}
                  />
                </div>

                <div className="space-y-2">
                  <Label>Complexity Factor: {costCalculator.complexity}x</Label>
                  <Slider
                    value={[costCalculator.complexity]}
                    min={0.5}
                    max={3}
                    step={0.1}
                    onValueChange={(value) => setCostCalculator(prev => ({ 
                      ...prev, 
                      complexity: value[0] 
                    }))}
                    className="w-full"
                  />
                  <div className="flex justify-between text-xs text-muted-foreground">
                    <span>Simple</span>
                    <span>Standard</span>
                    <span>Complex</span>
                  </div>
                </div>

                <Separator />

                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span>Estimated Cost:</span>
                    <span className="font-bold text-lg">
                      {formatCurrency(calculateContentCost())}
                    </span>
                  </div>
                  <div className="text-sm text-muted-foreground space-y-1">
                    <div className="flex justify-between">
                      <span>Base cost:</span>
                      <span>{formatCurrency(CONTENT_COSTS[costCalculator.contentType as keyof typeof CONTENT_COSTS].base)}</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Channel multiplier:</span>
                      <span>{CHANNEL_MULTIPLIERS[costCalculator.channel as keyof typeof CHANNEL_MULTIPLIERS]}x</span>
                    </div>
                    <div className="flex justify-between">
                      <span>Complexity factor:</span>
                      <span>{costCalculator.complexity}x</span>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Cost Breakdown */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <BarChart3 className="h-5 w-5" />
                  Cost Breakdown by Content Type
                </CardTitle>
                <CardDescription>
                  Compare costs across different content formats
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                {Object.entries(CONTENT_COSTS).map(([contentType, costs]) => {
                  const channelMultiplier = CHANNEL_MULTIPLIERS[costCalculator.channel as keyof typeof CHANNEL_MULTIPLIERS]
                  const totalCost = costs.base * costs.complexity * channelMultiplier
                  const maxCost = Math.max(...Object.values(CONTENT_COSTS).map(c => c.base * c.complexity * channelMultiplier))
                  
                  return (
                    <div key={contentType} className="space-y-2">
                      <div className="flex items-center justify-between">
                        <span className="capitalize font-medium">
                          {contentType.replace('-', ' ')}
                        </span>
                        <div className="flex items-center gap-2">
                          <span className="font-mono text-sm">
                            {formatCurrency(totalCost)}
                          </span>
                          <Badge variant="outline" className="text-xs">
                            {costs.hours}h
                          </Badge>
                        </div>
                      </div>
                      <Progress 
                        value={(totalCost / maxCost) * 100} 
                        className="h-2"
                      />
                    </div>
                  )
                })}
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="resources" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Users className="h-5 w-5" />
                Resource Requirements
              </CardTitle>
              <CardDescription>
                Plan personnel and tool requirements for the campaign
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {RESOURCE_REQUIREMENTS.map((resource) => {
                  const totalCost = resource.cost * resource.quantity * resource.duration
                  
                  return (
                    <div key={resource.id} className="border rounded-lg p-4 space-y-3">
                      <div className="flex items-start justify-between">
                        <div className="flex-1">
                          <div className="flex items-center gap-2">
                            <h4 className="font-medium">{resource.name}</h4>
                            <Badge className={getPriorityColor(resource.priority)}>
                              {resource.priority}
                            </Badge>
                          </div>
                          <p className="text-sm text-muted-foreground mt-1">
                            {resource.description}
                          </p>
                        </div>
                        <div className="text-right">
                          <div className="font-bold">{formatCurrency(totalCost)}</div>
                          <div className="text-sm text-muted-foreground">
                            Total cost
                          </div>
                        </div>
                      </div>
                      
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
                        <div className="flex items-center gap-2">
                          <DollarSign className="h-4 w-4 text-green-600" />
                          <span>{formatCurrency(resource.cost)} per week</span>
                        </div>
                        <div className="flex items-center gap-2">
                          <Users className="h-4 w-4 text-blue-600" />
                          <span>{resource.quantity} {resource.quantity > 1 ? 'resources' : 'resource'}</span>
                        </div>
                        <div className="flex items-center gap-2">
                          <Clock className="h-4 w-4 text-orange-600" />
                          <span>{resource.duration} weeks</span>
                        </div>
                      </div>
                    </div>
                  )
                })}
                
                <div className="border-t pt-4">
                  <div className="flex justify-between items-center">
                    <span className="font-medium">Total Resource Cost:</span>
                    <span className="text-lg font-bold">
                      {formatCurrency(
                        RESOURCE_REQUIREMENTS.reduce((sum, resource) => 
                          sum + (resource.cost * resource.quantity * resource.duration), 0
                        )
                      )}
                    </span>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="optimization" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <TrendingUp className="h-5 w-5" />
                Budget Optimization Suggestions
              </CardTitle>
              <CardDescription>
                AI-powered recommendations to improve budget efficiency
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {OPTIMIZATION_SUGGESTIONS.map((suggestion, index) => (
                  <div key={index} className="border rounded-lg p-4 space-y-3">
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <div className="flex items-center gap-2">
                          <CheckCircle className="h-5 w-5 text-green-600" />
                          <h4 className="font-medium">Optimization Opportunity</h4>
                        </div>
                        <p className="text-sm mt-1">{suggestion.suggestion}</p>
                      </div>
                      <div className="text-right">
                        <div className="font-bold text-green-600">
                          {formatCurrency(suggestion.savings)} saved
                        </div>
                        <div className="text-sm text-muted-foreground">
                          +{suggestion.impact}% efficiency
                        </div>
                      </div>
                    </div>
                    
                    <div className="flex items-center gap-4">
                      <Badge variant="outline" className="capitalize">
                        {suggestion.category}
                      </Badge>
                      <Badge className={getEffortColor(suggestion.effort)}>
                        {suggestion.effort} effort
                      </Badge>
                      <div className="flex-1"></div>
                      <Button size="sm" variant="outline">
                        Apply Suggestion
                      </Button>
                    </div>
                  </div>
                ))}
                
                <div className="border-t pt-4">
                  <div className="flex justify-between items-center">
                    <span className="font-medium">Total Potential Savings:</span>
                    <span className="text-lg font-bold text-green-600">
                      {formatCurrency(
                        OPTIMIZATION_SUGGESTIONS.reduce((sum, suggestion) => sum + suggestion.savings, 0)
                      )}
                    </span>
                  </div>
                  <p className="text-sm text-muted-foreground mt-1">
                    Implementing all suggestions could improve budget efficiency by{' '}
                    {Math.round(
                      OPTIMIZATION_SUGGESTIONS.reduce((sum, suggestion) => sum + suggestion.impact, 0) / OPTIMIZATION_SUGGESTIONS.length
                    )}% on average
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}