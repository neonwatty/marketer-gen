"use client"

import React from "react"
import { FormWrapper } from "./FormWrapper"
import { TextField, SelectField, RichTextEditorField, FormActions } from "./FormFields"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { VersionHistory, type ContentVersion } from "./VersionHistory"
import { VersionManager } from "@/lib/version-management"
import { 
  Save, 
  Eye, 
  History, 
  CheckCircle, 
  Clock, 
  AlertCircle,
  Copy,
  Download,
  RefreshCw
} from "lucide-react"
import { z } from "zod"

const contentEditorSchema = z.object({
  generatedContent: z.string().min(1, "Content is required"),
  title: z.string().min(1, "Title is required"),
  status: z.enum(['draft', 'review', 'approved', 'published']).optional(),
  version: z.number().optional(),
  lastModified: z.date().optional(),
})

export type ContentEditorFormData = z.infer<typeof contentEditorSchema>

interface ContentEditorProps {
  initialContent?: string
  title?: string
  status?: 'draft' | 'review' | 'approved' | 'published'
  version?: number
  versions?: ContentVersion[]
  currentVersionId?: string
  author?: string
  onSave?: (data: ContentEditorFormData) => void | Promise<void>
  onPublish?: (data: ContentEditorFormData) => void | Promise<void>
  onPreview?: () => void
  onVersionHistory?: () => void
  onRestoreVersion?: (versionId: string) => void
  onCompareVersions?: (version1Id: string, version2Id: string) => void
  showVersionHistory?: boolean
  showApprovalWorkflow?: boolean
  isSubmitting?: boolean
  readOnly?: boolean
}

const statusConfig = {
  draft: {
    color: "secondary" as const,
    icon: Clock,
    label: "Draft",
  },
  review: {
    color: "outline" as const,
    icon: AlertCircle,
    label: "Under Review",
  },
  approved: {
    color: "default" as const,
    icon: CheckCircle,
    label: "Approved",
  },
  published: {
    color: "default" as const,
    icon: CheckCircle,
    label: "Published",
  },
}

export function ContentEditor({
  initialContent = "",
  title = "",
  status = "draft",
  version = 1,
  versions = [],
  currentVersionId,
  author = "Current User",
  onSave,
  onPublish,
  onPreview,
  onVersionHistory,
  onRestoreVersion,
  onCompareVersions,
  showVersionHistory = true,
  showApprovalWorkflow = true,
  isSubmitting = false,
  readOnly = false,
}: ContentEditorProps) {
  const [activeTab, setActiveTab] = React.useState("editor")
  const [versionManager] = React.useState(() => new VersionManager(versions))
  const currentStatus = statusConfig[status]
  const StatusIcon = currentStatus.icon

  const defaultValues: Partial<ContentEditorFormData> = {
    generatedContent: initialContent,
    title: title,
    status: status,
    version: version,
    lastModified: new Date(),
  }

  const handleSave = (data: ContentEditorFormData) => {
    const saveData = {
      ...data,
      status: status,
      version: version,
      lastModified: new Date(),
    }
    onSave?.(saveData)
  }

  const handlePublish = (data: ContentEditorFormData) => {
    const publishData = {
      ...data,
      status: 'published' as const,
      version: version + 1,
      lastModified: new Date(),
    }
    onPublish?.(publishData)
  }

  return (
    <div className="max-w-6xl mx-auto space-y-6">
      {/* Header with status and actions */}
      <div className="flex items-center justify-between">
        <div className="space-y-1">
          <h1 className="text-2xl font-bold">{title || "Content Editor"}</h1>
          <div className="flex items-center gap-2">
            <Badge variant={currentStatus.color} className="flex items-center gap-1">
              <StatusIcon className="h-3 w-3" />
              {currentStatus.label}
            </Badge>
            <span className="text-sm text-muted-foreground">Version {version}</span>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {showVersionHistory && (
            <Button
              variant="outline"
              size="sm"
              onClick={onVersionHistory}
            >
              <History className="h-4 w-4 mr-2" />
              History
            </Button>
          )}
          <Button
            variant="outline"
            size="sm"
            onClick={onPreview}
          >
            <Eye className="h-4 w-4 mr-2" />
            Preview
          </Button>
        </div>
      </div>

      <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
        <TabsList>
          <TabsTrigger value="editor">Editor</TabsTrigger>
          <TabsTrigger value="preview">Preview</TabsTrigger>
          {showVersionHistory && <TabsTrigger value="history">Version History</TabsTrigger>}
          {showApprovalWorkflow && <TabsTrigger value="workflow">Workflow</TabsTrigger>}
        </TabsList>

        <TabsContent value="editor" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Content Editor</CardTitle>
              <CardDescription>
                Edit your generated content with rich text formatting
              </CardDescription>
            </CardHeader>
            <CardContent>
              <FormWrapper
                onSubmit={handleSave}
                schema={contentEditorSchema}
                defaultValues={defaultValues}
                cardWrapper={false}
              >
                <div className="space-y-6">
                  <TextField
                    name="title"
                    label="Content Title"
                    placeholder="Enter a title for your content..."
                    required
                    disabled={readOnly}
                  />

                  <RichTextEditorField
                    name="generatedContent"
                    label="Content"
                    placeholder="Start editing your generated content..."
                    maxCharacters={20000}
                    required
                    disabled={readOnly}
                  />

                  {!readOnly && (
                    <div className="flex justify-between">
                      <div className="flex gap-2">
                        <Button
                          variant="outline"
                          onClick={() => {
                            // Copy content functionality
                            navigator.clipboard.writeText(initialContent)
                          }}
                        >
                          <Copy className="h-4 w-4 mr-2" />
                          Copy
                        </Button>
                        <Button
                          variant="outline"
                          onClick={() => {
                            // Export functionality
                          }}
                        >
                          <Download className="h-4 w-4 mr-2" />
                          Export
                        </Button>
                        <Button
                          variant="outline"
                          onClick={() => {
                            // Regenerate functionality
                          }}
                        >
                          <RefreshCw className="h-4 w-4 mr-2" />
                          Regenerate
                        </Button>
                      </div>

                      <FormActions
                        submitText="Save Changes"
                        isSubmitting={isSubmitting}
                      >
                        <Button
                          type="button"
                          onClick={() => {
                            // Save as draft
                          }}
                          variant="outline"
                          disabled={isSubmitting}
                        >
                          <Save className="h-4 w-4 mr-2" />
                          Save Draft
                        </Button>
                        <Button
                          type="submit"
                          disabled={isSubmitting}
                        >
                          <Save className="h-4 w-4 mr-2" />
                          {isSubmitting ? "Saving..." : "Save Changes"}
                        </Button>
                        {showApprovalWorkflow && status === 'draft' && (
                          <Button
                            type="button"
                            onClick={() => handlePublish(defaultValues as ContentEditorFormData)}
                            disabled={isSubmitting}
                          >
                            Submit for Review
                          </Button>
                        )}
                      </FormActions>
                    </div>
                  )}
                </div>
              </FormWrapper>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="preview" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Content Preview</CardTitle>
              <CardDescription>
                Preview how your content will appear when published
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="prose max-w-none">
                <h1>{title || "Untitled Content"}</h1>
                <div dangerouslySetInnerHTML={{ __html: initialContent }} />
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {showVersionHistory && (
          <TabsContent value="history" className="space-y-6">
            <VersionHistory
              versions={versions}
              currentVersionId={currentVersionId}
              onRestore={onRestoreVersion}
              onCompare={onCompareVersions}
            />
          </TabsContent>
        )}

        {showApprovalWorkflow && (
          <TabsContent value="workflow" className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle>Approval Workflow</CardTitle>
                <CardDescription>
                  Track the approval status and workflow for this content
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <div className="flex items-center gap-3 p-3 border rounded-lg">
                    <div className="h-8 w-8 rounded-full bg-primary/10 flex items-center justify-center">
                      <Clock className="h-4 w-4" />
                    </div>
                    <div className="flex-1">
                      <p className="font-medium">Draft Created</p>
                      <p className="text-sm text-muted-foreground">Content created and saved as draft</p>
                    </div>
                    <Badge variant="default">Completed</Badge>
                  </div>

                  <div className="flex items-center gap-3 p-3 border rounded-lg">
                    <div className="h-8 w-8 rounded-full bg-muted flex items-center justify-center">
                      <AlertCircle className="h-4 w-4" />
                    </div>
                    <div className="flex-1">
                      <p className="font-medium">Under Review</p>
                      <p className="text-sm text-muted-foreground">Content submitted for approval</p>
                    </div>
                    <Badge variant={status === 'review' ? 'default' : 'secondary'}>
                      {status === 'review' ? 'In Progress' : 'Pending'}
                    </Badge>
                  </div>

                  <div className="flex items-center gap-3 p-3 border rounded-lg">
                    <div className="h-8 w-8 rounded-full bg-muted flex items-center justify-center">
                      <CheckCircle className="h-4 w-4" />
                    </div>
                    <div className="flex-1">
                      <p className="font-medium">Approved</p>
                      <p className="text-sm text-muted-foreground">Content approved and ready for publishing</p>
                    </div>
                    <Badge variant={status === 'approved' ? 'default' : 'secondary'}>
                      {status === 'approved' ? 'Completed' : 'Pending'}
                    </Badge>
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        )}
      </Tabs>
    </div>
  )
}