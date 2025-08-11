"use client"

import React from "react"
import { ContentEditor } from "./ContentEditor"
import { ContentGenerationForm, type ContentGenerationFormData } from "./ContentGenerationForm"
import { VersionManager, createMockVersions } from "@/lib/version-management"
import { type ContentVersion } from "./VersionHistory"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Wand2, FileText } from "lucide-react"

interface GeneratedContent {
  id: string
  title: string
  content: string
  prompt: ContentGenerationFormData
  versions: ContentVersion[]
  currentVersionId: string
}

export function ContentGenerationWithVersions() {
  const [activeTab, setActiveTab] = React.useState("generate")
  const [generatedContent, setGeneratedContent] = React.useState<GeneratedContent | null>(null)
  const [isGenerating, setIsGenerating] = React.useState(false)
  const [versionManager, setVersionManager] = React.useState<VersionManager | null>(null)

  // Initialize with mock data for demonstration
  React.useEffect(() => {
    const mockContent = createMockGeneratedContent()
    setGeneratedContent(mockContent)
    setVersionManager(new VersionManager(mockContent.versions))
  }, [])

  const handleGenerate = async (data: ContentGenerationFormData) => {
    setIsGenerating(true)
    
    // Simulate API call delay
    await new Promise(resolve => setTimeout(resolve, 2000))
    
    // Generate mock content based on form data
    const mockHtmlContent = generateMockHtmlContent(data)
    
    // Create new content with initial version
    const newContent: GeneratedContent = {
      id: `content-${Date.now()}`,
      title: data.title,
      content: mockHtmlContent,
      prompt: data,
      versions: [],
      currentVersionId: "",
    }

    // Create version manager and add initial version
    const vm = new VersionManager()
    const initialVersion = vm.addVersion({
      title: data.title,
      content: mockHtmlContent,
      status: 'draft',
      author: 'AI Assistant',
      changeDescription: 'Initial AI-generated content',
      wordCount: mockHtmlContent.split(' ').length,
      characterCount: mockHtmlContent.length,
    })

    newContent.versions = vm.getAllVersions()
    newContent.currentVersionId = initialVersion.id

    setGeneratedContent(newContent)
    setVersionManager(vm)
    setActiveTab("editor")
    setIsGenerating(false)
  }

  const handleSaveContent = (data: any) => {
    if (!generatedContent || !versionManager) return
    
    // Create new version when content is saved
    const newVersion = versionManager.addVersion({
      title: data.title,
      content: data.generatedContent,
      status: 'draft',
      author: 'User',
      changeDescription: 'Manual edits and refinements',
      wordCount: data.generatedContent.split(' ').length,
      characterCount: data.generatedContent.length,
    })

    setGeneratedContent({
      ...generatedContent,
      title: data.title,
      content: data.generatedContent,
      versions: versionManager.getAllVersions(),
      currentVersionId: newVersion.id,
    })
  }

  const handleRestoreVersion = (versionId: string) => {
    if (!versionManager || !generatedContent) return
    
    const version = versionManager.getVersion(versionId)
    if (version) {
      // Create restore point
      const restoredVersion = versionManager.createRestorePoint(versionId, 'User')
      if (restoredVersion) {
        setGeneratedContent({
          ...generatedContent,
          title: version.title,
          content: version.content,
          versions: versionManager.getAllVersions(),
          currentVersionId: restoredVersion.id,
        })
      }
    }
  }

  const handleCompareVersions = (version1Id: string, version2Id: string) => {
    // This would typically open a modal or navigate to comparison view
    console.log('Comparing versions:', version1Id, version2Id)
  }

  return (
    <div className="max-w-6xl mx-auto space-y-6">
      {/* Header */}
      <div className="space-y-4">
        <h1 className="text-3xl font-bold tracking-tight">Content Generation Studio</h1>
        <p className="text-muted-foreground text-lg">
          Generate, edit, and manage marketing content with version control
        </p>
      </div>

      <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
        <TabsList>
          <TabsTrigger value="generate">Generate</TabsTrigger>
          <TabsTrigger value="editor" disabled={!generatedContent}>
            Editor & Versions
          </TabsTrigger>
        </TabsList>

        <TabsContent value="generate" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Wand2 className="h-5 w-5" />
                Generate New Content
              </CardTitle>
              <CardDescription>
                Configure your content requirements and generate marketing copy with AI
              </CardDescription>
            </CardHeader>
            <CardContent>
              <ContentGenerationForm
                onSubmit={handleGenerate}
                isSubmitting={isGenerating}
                cardWrapper={false}
              />
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="editor" className="space-y-6">
          {generatedContent ? (
            <ContentEditor
              initialContent={generatedContent.content}
              title={generatedContent.title}
              status="draft"
              version={generatedContent.versions.length}
              versions={generatedContent.versions}
              currentVersionId={generatedContent.currentVersionId}
              author="User"
              onSave={handleSaveContent}
              onRestoreVersion={handleRestoreVersion}
              onCompareVersions={handleCompareVersions}
              showVersionHistory={true}
              showApprovalWorkflow={true}
            />
          ) : (
            <Card>
              <CardContent className="flex items-center justify-center py-12">
                <div className="text-center space-y-4">
                  <FileText className="h-12 w-12 text-muted-foreground mx-auto" />
                  <div>
                    <p className="text-sm font-medium">No content generated yet</p>
                    <p className="text-xs text-muted-foreground">
                      Use the Generate tab to create your first piece of content
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>
          )}
        </TabsContent>
      </Tabs>
    </div>
  )
}

// Helper functions for mock content generation
function createMockGeneratedContent(): GeneratedContent {
  const mockVersions = createMockVersions(3)
  return {
    id: 'demo-content-1',
    title: 'Summer Marketing Campaign',
    content: mockVersions[mockVersions.length - 1].content,
    prompt: {
      title: 'Summer Marketing Campaign',
      description: 'Create engaging content for summer product launch',
      contentType: 'social-post' as const,
      tone: 'friendly' as const,
      targetAudience: 'Young adults aged 18-35',
      keywords: 'summer, launch, exciting',
      additionalInstructions: 'Keep it energetic and vibrant',
    },
    versions: mockVersions,
    currentVersionId: mockVersions[mockVersions.length - 1].id,
  }
}

function generateMockHtmlContent(data: ContentGenerationFormData): string {
  const contentTypeTemplates = {
    'social-post': `
      <h2>🌟 ${data.title}</h2>
      <p>Hey ${data.targetAudience}! 👋</p>
      <p>${data.description}</p>
      <p>Perfect for those who love ${data.keywords?.split(',')[0] || 'amazing experiences'}!</p>
      <p><strong>Ready to get started? Let's make it happen! 🚀</strong></p>
    `,
    'email': `
      <h1>${data.title}</h1>
      <p>Dear Valued Customer,</p>
      <p>${data.description}</p>
      <p>This opportunity is perfect for ${data.targetAudience}.</p>
      <p>Key benefits include:</p>
      <ul>
        <li>Premium quality and service</li>
        <li>Exclusive access and pricing</li>
        <li>100% satisfaction guaranteed</li>
      </ul>
      <p><strong>${data.callToAction || 'Take action today'}</strong></p>
      <p>Best regards,<br>The Marketing Team</p>
    `,
    'ad-copy': `
      <h2>${data.title}</h2>
      <p><strong>Attention ${data.targetAudience}!</strong></p>
      <p>${data.description}</p>
      <p>✅ Premium quality<br>✅ Fast delivery<br>✅ Money-back guarantee</p>
      <p><strong style="font-size: 1.2em; color: #e11d48;">${data.callToAction || 'Order Now!'}</strong></p>
    `,
    'landing-page': `
      <h1>${data.title}</h1>
      <p class="lead">${data.description}</p>
      <h2>Why Choose Us?</h2>
      <p>We understand what ${data.targetAudience} need most.</p>
      <h3>Key Features:</h3>
      <ul>
        <li>Industry-leading quality</li>
        <li>24/7 customer support</li>
        <li>Lightning-fast delivery</li>
      </ul>
      <p><strong>${data.callToAction || 'Get Started Today'}</strong></p>
    `,
    'video-script': `
      <h2>Video Script: ${data.title}</h2>
      <p><strong>[SCENE 1 - Opening Hook]</strong></p>
      <p><em>Narrator:</em> "Are you tired of the same old routine, ${data.targetAudience}?"</p>
      <p><strong>[SCENE 2 - Problem/Solution]</strong></p>
      <p><em>Narrator:</em> "${data.description}"</p>
      <p><strong>[SCENE 3 - Call to Action]</strong></p>
      <p><em>Narrator:</em> "${data.callToAction || 'Take action now!'}"</p>
      <p><strong>[END SCREEN]</strong></p>
    `
  }

  const template = contentTypeTemplates[data.contentType as keyof typeof contentTypeTemplates] || 
                  contentTypeTemplates['social-post']

  return template.trim()
}