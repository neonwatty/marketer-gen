"use client"

import * as React from "react"
import { JourneyBuilder, JourneyTemplate } from "@/components/campaigns/journey-builder"
import { JourneyTemplates } from "@/components/campaigns/journey-templates"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { ArrowLeft, Lightbulb, LayoutTemplate, Sparkles } from "lucide-react"
import Link from "next/link"

export default function JourneyBuilderPage() {
  const [stages, setStages] = React.useState([])
  const [activeTab, setActiveTab] = React.useState("builder")

  const handleStagesChange = (newStages) => {
    setStages(newStages)
    console.log("Journey stages updated:", newStages)
  }

  const handleSelectTemplate = (template: JourneyTemplate) => {
    // Convert template to stages with unique IDs
    const templateStages = template.stages.map((stage, index) => ({
      ...stage,
      id: `stage-${Date.now()}-${index}`,
      position: index,
    }))
    
    setStages(templateStages)
    setActiveTab("builder") // Switch to builder tab after selecting template
  }

  const handleShowTemplates = () => {
    setActiveTab("templates")
  }

  return (
    <div className="container mx-auto p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Link href="/campaigns">
          <Button variant="ghost" size="sm" className="gap-2">
            <ArrowLeft className="h-4 w-4" />
            Back to Campaigns
          </Button>
        </Link>
        <div>
          <h1 className="text-3xl font-bold">Journey Builder</h1>
          <p className="text-muted-foreground">
            Create and customize customer journeys for your marketing campaigns
          </p>
        </div>
      </div>

      {/* Main Interface */}
      <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-6">
        <TabsList className="grid w-full grid-cols-2">
          <TabsTrigger value="templates" className="gap-2">
            <LayoutTemplate className="h-4 w-4" />
            Templates
          </TabsTrigger>
          <TabsTrigger value="builder" className="gap-2">
            <Sparkles className="h-4 w-4" />
            Builder
            {stages.length > 0 && (
              <span className="ml-1 px-2 py-0.5 text-xs bg-primary text-primary-foreground rounded-full">
                {stages.length}
              </span>
            )}
          </TabsTrigger>
        </TabsList>

        <TabsContent value="templates" className="space-y-6">
          <JourneyTemplates onSelectTemplate={handleSelectTemplate} />
        </TabsContent>

        <TabsContent value="builder" className="space-y-6">
          {/* Getting Started Guide */}
          {stages.length === 0 && (
            <Card className="bg-gradient-to-r from-blue-50 to-indigo-50 border-blue-200">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-blue-900">
                  <Lightbulb className="h-5 w-5" />
                  Getting Started
                </CardTitle>
                <CardDescription className="text-blue-700">
                  Choose how you&apos;d like to build your customer journey
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div className="p-4 border border-blue-200 rounded-lg bg-white/50">
                    <div className="flex items-center gap-2 mb-2">
                      <LayoutTemplate className="h-5 w-5 text-blue-600" />
                      <h3 className="font-semibold text-blue-900">Start with Template</h3>
                    </div>
                    <p className="text-sm text-blue-800 mb-3">
                      Choose from proven journey templates and customize them for your needs
                    </p>
                    <Button 
                      size="sm" 
                      className="w-full"
                      onClick={() => setActiveTab("templates")}
                    >
                      Browse Templates
                    </Button>
                  </div>
                  
                  <div className="p-4 border border-blue-200 rounded-lg bg-white/50">
                    <div className="flex items-center gap-2 mb-2">
                      <Sparkles className="h-5 w-5 text-blue-600" />
                      <h3 className="font-semibold text-blue-900">Build from Scratch</h3>
                    </div>
                    <p className="text-sm text-blue-800 mb-3">
                      Create a completely custom journey by adding stages manually
                    </p>
                    <div className="text-xs text-blue-600">
                      Use the &ldquo;Add&rdquo; buttons below to get started
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          )}

          {/* Journey Builder Component */}
          <JourneyBuilder 
            initialStages={stages}
            onStagesChange={handleStagesChange}
            onShowTemplates={handleShowTemplates}
          />
        </TabsContent>
      </Tabs>
    </div>
  )
}