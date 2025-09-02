import { Metadata } from 'next'
import { Suspense } from 'react'

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { LoadingSpinner } from '@/components/ui/loading-spinner'
import { BrandComplianceChecker } from '@/components/features/brand/BrandComplianceChecker'

export const metadata: Metadata = {
  title: 'Brand Compliance Checker',
  description: 'Check content against brand guidelines and compliance rules',
}

// Mock brands data - in a real app, this would come from an API or database
const mockBrands = [
  {
    id: 'brand-1',
    name: 'TechCorp Solutions',
    tagline: 'Innovation that drives success',
    voiceDescription: 'Professional, innovative, and customer-focused. We communicate with confidence while remaining approachable and helpful.'
  },
  {
    id: 'brand-2', 
    name: 'GreenLeaf Wellness',
    tagline: 'Natural living, naturally better',
    voiceDescription: 'Warm, caring, and authentic. We speak with genuine passion about health and wellness, using encouraging and supportive language.'
  },
  {
    id: 'brand-3',
    name: 'Urban Style Co.',
    tagline: 'Fashion forward, always',
    voiceDescription: 'Trendy, confident, and stylish. We use contemporary language that resonates with young, fashion-conscious consumers.'
  }
]

function BrandCompliancePage() {
  return (
    <div className="container mx-auto py-8 space-y-8">
      <div className="space-y-2">
        <h1 className="text-3xl font-bold tracking-tight">Brand Compliance Checker</h1>
        <p className="text-muted-foreground">
          Ensure your content aligns with brand guidelines and maintains consistent voice and messaging
        </p>
      </div>

      {/* Feature highlights */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-lg">🎯 Voice Analysis</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground">
              Advanced AI analyzes your content against brand voice guidelines and tone requirements
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-lg">🚫 Restriction Checking</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground">
              Automatically detects restricted terms and language that violates brand guidelines
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-lg">💡 Smart Suggestions</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground">
              Get actionable recommendations to improve compliance and align with brand standards
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Compliance Stats */}
      <Card>
        <CardHeader>
          <CardTitle>Compliance Overview</CardTitle>
          <p className="text-sm text-muted-foreground">
            Your brand compliance performance at a glance
          </p>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="text-center space-y-2">
              <div className="text-2xl font-bold text-green-600">94%</div>
              <div className="text-sm text-muted-foreground">Average Score</div>
            </div>
            <div className="text-center space-y-2">
              <div className="text-2xl font-bold text-blue-600">156</div>
              <div className="text-sm text-muted-foreground">Content Checked</div>
            </div>
            <div className="text-center space-y-2">
              <div className="text-2xl font-bold text-yellow-600">23</div>
              <div className="text-sm text-muted-foreground">Issues Resolved</div>
            </div>
            <div className="text-center space-y-2">
              <div className="text-2xl font-bold text-purple-600">7</div>
              <div className="text-sm text-muted-foreground">Active Rules</div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Main compliance checker */}
      <Suspense fallback={
        <Card>
          <CardContent className="flex items-center justify-center py-12">
            <LoadingSpinner className="h-8 w-8" />
            <span className="ml-2">Loading Brand Compliance Checker...</span>
          </CardContent>
        </Card>
      }>
        <BrandComplianceChecker brands={mockBrands} />
      </Suspense>

      {/* Common Compliance Issues */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">Common Compliance Issues</CardTitle>
          <p className="text-sm text-muted-foreground">
            Learn about the most frequent brand compliance issues and how to avoid them
          </p>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 text-sm">
            <div className="space-y-3">
              <h4 className="font-medium text-red-600">❌ Common Violations:</h4>
              <ul className="space-y-2 text-muted-foreground">
                <li>• Using inconsistent tone or voice</li>
                <li>• Including restricted terminology</li>
                <li>• Missing required brand elements</li>
                <li>• Inappropriate language for target audience</li>
                <li>• Conflicting with brand values or messaging</li>
              </ul>
            </div>
            <div className="space-y-3">
              <h4 className="font-medium text-green-600">✅ Best Practices:</h4>
              <ul className="space-y-2 text-muted-foreground">
                <li>• Review brand guidelines before writing</li>
                <li>• Use approved terminology consistently</li>
                <li>• Match tone to brand personality</li>
                <li>• Include key brand messages naturally</li>
                <li>• Test content with compliance checker</li>
              </ul>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

export default BrandCompliancePage