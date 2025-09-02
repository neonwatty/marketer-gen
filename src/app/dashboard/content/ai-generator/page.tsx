import { Metadata } from 'next'

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { AIContentGeneratorClient } from '@/components/features/content/AIContentGeneratorClient'

export const metadata: Metadata = {
  title: 'AI Content Generator',
  description: 'Generate brand-aligned content using AI',
}

async function getBrands() {
  // For now, return mock data since server components can't access authenticated API endpoints easily
  // In production, this would use a server-side data fetching approach with authentication
  return [
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
}

async function AIContentGeneratorPage() {
  const brands = await getBrands()

  return (
    <div className="container mx-auto py-8 space-y-8">
      <div className="space-y-2">
        <h1 className="text-3xl font-bold tracking-tight">AI Content Generator</h1>
        <p className="text-muted-foreground">
          Generate professional, brand-aligned content for all your marketing channels using advanced AI
        </p>
      </div>

      {/* Feature highlights */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-lg">🎯 Brand-Aligned</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground">
              Content automatically matches your brand voice, tone, and messaging guidelines
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-lg">✨ Multiple Variants</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground">
              Generate multiple content variations with different strategies and approaches
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-lg">🛡️ Compliance Checked</CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-sm text-muted-foreground">
              Real-time brand compliance checking with violation detection and suggestions
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Supported content types */}
      <Card>
        <CardHeader>
          <CardTitle>Supported Content Types</CardTitle>
          <p className="text-sm text-muted-foreground">
            Generate content for any marketing channel or format
          </p>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-5 gap-3 text-sm">
            <div className="flex items-center gap-2 p-2 rounded border">
              <span>📧</span>
              <span>Email Marketing</span>
            </div>
            <div className="flex items-center gap-2 p-2 rounded border">
              <span>📱</span>
              <span>Social Media Posts</span>
            </div>
            <div className="flex items-center gap-2 p-2 rounded border">
              <span>💰</span>
              <span>Paid Ads</span>
            </div>
            <div className="flex items-center gap-2 p-2 rounded border">
              <span>📝</span>
              <span>Blog Articles</span>
            </div>
            <div className="flex items-center gap-2 p-2 rounded border">
              <span>🎯</span>
              <span>Landing Pages</span>
            </div>
            <div className="flex items-center gap-2 p-2 rounded border">
              <span>🎥</span>
              <span>Video Scripts</span>
            </div>
            <div className="flex items-center gap-2 p-2 rounded border">
              <span>📊</span>
              <span>Infographics</span>
            </div>
            <div className="flex items-center gap-2 p-2 rounded border">
              <span>📮</span>
              <span>Newsletters</span>
            </div>
            <div className="flex items-center gap-2 p-2 rounded border">
              <span>📰</span>
              <span>Press Releases</span>
            </div>
            <div className="flex items-center gap-2 p-2 rounded border">
              <span>🔍</span>
              <span>Search Ads</span>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Main content generator */}
      <AIContentGeneratorClient brands={brands} />

      {/* Quick tips */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">💡 Quick Tips for Better Results</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
            <div className="space-y-2">
              <h4 className="font-medium">Writing Better Prompts:</h4>
              <ul className="space-y-1 text-muted-foreground">
                <li>• Be specific about your goals and audience</li>
                <li>• Include key messages and value propositions</li>
                <li>• Specify the desired tone and style</li>
                <li>• Mention any important details or constraints</li>
              </ul>
            </div>
            <div className="space-y-2">
              <h4 className="font-medium">Optimizing Content:</h4>
              <ul className="space-y-1 text-muted-foreground">
                <li>• Use content variants for A/B testing</li>
                <li>• Pay attention to compliance scores</li>
                <li>• Review suggested improvements</li>
                <li>• Consider format-specific optimizations</li>
              </ul>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

export default AIContentGeneratorPage