"use client"

import React from "react"
import { format } from "date-fns"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Separator } from "@/components/ui/separator"
import { ScrollArea } from "@/components/ui/scroll-area"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { DiffViewer } from "./DiffViewer"
import { 
  Clock, 
  User, 
  FileText, 
  GitCommit, 
  Eye, 
  RotateCcw,
  History,
  CheckCircle,
  AlertCircle,
  XCircle
} from "lucide-react"

export interface ContentVersion {
  id: string
  version: number
  title: string
  content: string
  status: 'draft' | 'review' | 'approved' | 'published'
  author: string
  createdAt: Date
  changes?: {
    title?: boolean
    content?: boolean
    status?: boolean
  }
  changeDescription?: string
  wordCount?: number
  characterCount?: number
}

interface VersionHistoryProps {
  versions: ContentVersion[]
  currentVersionId?: string
  onRestore?: (versionId: string) => void
  onCompare?: (version1Id: string, version2Id: string) => void
  className?: string
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

export function VersionHistory({
  versions,
  currentVersionId,
  onRestore,
  onCompare,
  className,
}: VersionHistoryProps) {
  const [selectedVersion, setSelectedVersion] = React.useState<string | null>(null)
  const [compareVersion1, setCompareVersion1] = React.useState<string>("")
  const [compareVersion2, setCompareVersion2] = React.useState<string>("")
  
  const sortedVersions = [...versions].sort((a, b) => 
    new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  )

  const getVersionById = (id: string) => 
    versions.find(v => v.id === id)

  const getCurrentVersion = () => 
    currentVersionId ? getVersionById(currentVersionId) : sortedVersions[0]

  const getChangesSummary = (version: ContentVersion, previousVersion?: ContentVersion) => {
    if (!previousVersion) return "Initial version"
    
    const changes: string[] = []
    
    if (version.title !== previousVersion.title) {
      changes.push("Title")
    }
    
    if (version.content !== previousVersion.content) {
      changes.push("Content")
    }
    
    if (version.status !== previousVersion.status) {
      changes.push("Status")
    }
    
    return changes.length > 0 ? `Modified: ${changes.join(", ")}` : "No changes detected"
  }

  const renderVersionItem = (version: ContentVersion, index: number) => {
    const previousVersion = sortedVersions[index + 1]
    const isCurrentVersion = version.id === currentVersionId
    const StatusIcon = statusConfig[version.status].icon
    const changesSummary = getChangesSummary(version, previousVersion)
    
    return (
      <div
        key={version.id}
        className={`border rounded-lg p-4 space-y-3 ${
          isCurrentVersion ? 'ring-2 ring-primary bg-primary/5' : 'hover:bg-muted/50'
        } transition-colors cursor-pointer`}
        onClick={() => setSelectedVersion(version.id)}
      >
        <div className="flex items-start justify-between">
          <div className="space-y-1 flex-1">
            <div className="flex items-center gap-2">
              <Badge variant={statusConfig[version.status].color} className="flex items-center gap-1">
                <StatusIcon className="h-3 w-3" />
                {statusConfig[version.status].label}
              </Badge>
              <span className="text-sm font-medium">v{version.version}</span>
              {isCurrentVersion && (
                <Badge variant="outline" className="text-xs">Current</Badge>
              )}
            </div>
            
            <h4 className="font-medium truncate">{version.title}</h4>
            <p className="text-sm text-muted-foreground">{changesSummary}</p>
            
            <div className="flex items-center gap-4 text-xs text-muted-foreground">
              <div className="flex items-center gap-1">
                <User className="h-3 w-3" />
                {version.author}
              </div>
              <div className="flex items-center gap-1">
                <Clock className="h-3 w-3" />
                {format(new Date(version.createdAt), "MMM d, yyyy 'at' h:mm a")}
              </div>
              {version.wordCount && (
                <div className="flex items-center gap-1">
                  <FileText className="h-3 w-3" />
                  {version.wordCount} words
                </div>
              )}
            </div>
          </div>
          
          <div className="flex items-center gap-1 ml-4">
            <Dialog>
              <DialogTrigger asChild>
                <Button variant="ghost" size="sm">
                  <Eye className="h-4 w-4" />
                </Button>
              </DialogTrigger>
              <DialogContent className="max-w-4xl max-h-[80vh] overflow-y-auto">
                <DialogHeader>
                  <DialogTitle>Version {version.version} - {version.title}</DialogTitle>
                  <DialogDescription>
                    Created by {version.author} on {format(new Date(version.createdAt), "MMMM d, yyyy 'at' h:mm a")}
                  </DialogDescription>
                </DialogHeader>
                <div className="prose max-w-none">
                  <div dangerouslySetInnerHTML={{ __html: version.content }} />
                </div>
              </DialogContent>
            </Dialog>
            
            {!isCurrentVersion && onRestore && (
              <Button
                variant="ghost"
                size="sm"
                onClick={(e) => {
                  e.stopPropagation()
                  onRestore(version.id)
                }}
              >
                <RotateCcw className="h-4 w-4" />
              </Button>
            )}
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className={className}>
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <History className="h-5 w-5" />
            Version History
          </CardTitle>
          <CardDescription>
            Track changes and compare different versions of your content
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* Compare versions section */}
          <div className="space-y-4">
            <h4 className="font-medium">Compare Versions</h4>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 items-end">
              <div className="space-y-2">
                <label className="text-sm font-medium">Version 1</label>
                <Select value={compareVersion1} onValueChange={setCompareVersion1}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select version" />
                  </SelectTrigger>
                  <SelectContent>
                    {sortedVersions.map((version) => (
                      <SelectItem key={version.id} value={version.id}>
                        v{version.version} - {version.title}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              
              <div className="space-y-2">
                <label className="text-sm font-medium">Version 2</label>
                <Select value={compareVersion2} onValueChange={setCompareVersion2}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select version" />
                  </SelectTrigger>
                  <SelectContent>
                    {sortedVersions.map((version) => (
                      <SelectItem key={version.id} value={version.id}>
                        v{version.version} - {version.title}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              
              <Dialog>
                <DialogTrigger asChild>
                  <Button 
                    disabled={!compareVersion1 || !compareVersion2 || compareVersion1 === compareVersion2}
                    onClick={() => onCompare?.(compareVersion1, compareVersion2)}
                  >
                    <GitCommit className="h-4 w-4 mr-2" />
                    Compare
                  </Button>
                </DialogTrigger>
                <DialogContent className="max-w-6xl max-h-[80vh] overflow-y-auto">
                  <DialogHeader>
                    <DialogTitle>Version Comparison</DialogTitle>
                    <DialogDescription>
                      Comparing changes between selected versions
                    </DialogDescription>
                  </DialogHeader>
                  {compareVersion1 && compareVersion2 && (
                    <DiffViewer
                      oldContent={getVersionById(compareVersion1)?.content || ""}
                      newContent={getVersionById(compareVersion2)?.content || ""}
                      oldLabel={`v${getVersionById(compareVersion1)?.version} - ${getVersionById(compareVersion1)?.title}`}
                      newLabel={`v${getVersionById(compareVersion2)?.version} - ${getVersionById(compareVersion2)?.title}`}
                      viewType="side-by-side"
                    />
                  )}
                </DialogContent>
              </Dialog>
            </div>
          </div>
          
          <Separator />
          
          {/* Version list */}
          <div className="space-y-4">
            <h4 className="font-medium">All Versions ({versions.length})</h4>
            <ScrollArea className="h-96">
              <div className="space-y-3">
                {sortedVersions.map((version, index) => renderVersionItem(version, index))}
              </div>
            </ScrollArea>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}