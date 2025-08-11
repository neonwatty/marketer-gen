"use client"

import React, { useState, useEffect } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Badge } from '@/components/ui/badge'
import { Separator } from '@/components/ui/separator'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { 
  History, 
  Upload, 
  Download, 
  Eye, 
  RotateCcw, 
  GitBranch, 
  Clock, 
  User, 
  Tag,
  FileText,
  Compare,
  Plus,
  AlertCircle,
  CheckCircle,
  ArrowRight
} from 'lucide-react'
import { BrandAsset } from '@/lib/brand-assets'
import { cn } from '@/lib/utils'

interface AssetVersion {
  id: string
  version: number
  assetId: string
  fileName: string
  url: string
  size: number
  uploadedAt: string
  uploadedBy?: string
  changeNote?: string
  changes: VersionChange[]
  status: 'current' | 'archived' | 'deprecated'
  metadata: {
    width?: number
    height?: number
    format?: string
    [key: string]: any
  }
}

interface VersionChange {
  type: 'upload' | 'replace' | 'metadata' | 'restore'
  description: string
  timestamp: string
  user?: string
}

interface AssetVersionControlProps {
  asset: BrandAsset
  brandId: string
  onVersionRestore?: (version: AssetVersion) => void
  onVersionUpload?: (file: File, changeNote: string) => void
  className?: string
}

// Mock version history - in a real app, this would come from your API
const mockVersionHistory: AssetVersion[] = [
  {
    id: '1',
    version: 3,
    assetId: 'asset1',
    fileName: 'logo-v3.png',
    url: '/uploads/logo-v3.png',
    size: 25600,
    uploadedAt: '2024-01-15T10:30:00Z',
    uploadedBy: 'user1',
    changeNote: 'Updated brand colors and refined typography',
    status: 'current',
    changes: [
      {
        type: 'replace',
        description: 'Replaced with updated brand colors',
        timestamp: '2024-01-15T10:30:00Z',
        user: 'Marketing Team'
      }
    ],
    metadata: {
      width: 512,
      height: 512,
      format: 'PNG'
    }
  },
  {
    id: '2',
    version: 2,
    assetId: 'asset1',
    fileName: 'logo-v2.png',
    url: '/uploads/logo-v2.png',
    size: 23400,
    uploadedAt: '2024-01-10T14:20:00Z',
    uploadedBy: 'user2',
    changeNote: 'Minor spacing adjustments',
    status: 'archived',
    changes: [
      {
        type: 'replace',
        description: 'Adjusted logo spacing',
        timestamp: '2024-01-10T14:20:00Z',
        user: 'Design Team'
      }
    ],
    metadata: {
      width: 512,
      height: 512,
      format: 'PNG'
    }
  },
  {
    id: '3',
    version: 1,
    assetId: 'asset1',
    fileName: 'logo-v1.png',
    url: '/uploads/logo-v1.png',
    size: 22100,
    uploadedAt: '2024-01-01T09:00:00Z',
    uploadedBy: 'user1',
    changeNote: 'Initial logo upload',
    status: 'archived',
    changes: [
      {
        type: 'upload',
        description: 'Initial asset upload',
        timestamp: '2024-01-01T09:00:00Z',
        user: 'Brand Team'
      }
    ],
    metadata: {
      width: 512,
      height: 512,
      format: 'PNG'
    }
  }
]

export function AssetVersionControl({ 
  asset, 
  brandId, 
  onVersionRestore, 
  onVersionUpload,
  className 
}: AssetVersionControlProps) {
  const [versions, setVersions] = useState<AssetVersion[]>(mockVersionHistory)
  const [selectedVersions, setSelectedVersions] = useState<string[]>([])
  const [uploadDialogOpen, setUploadDialogOpen] = useState(false)
  const [compareDialogOpen, setCompareDialogOpen] = useState(false)
  const [newVersionFile, setNewVersionFile] = useState<File | null>(null)
  const [changeNote, setChangeNote] = useState('')
  const [isUploading, setIsUploading] = useState(false)

  const currentVersion = versions.find(v => v.status === 'current')
  const sortedVersions = [...versions].sort((a, b) => b.version - a.version)

  const handleVersionRestore = async (version: AssetVersion) => {
    try {
      // In a real app, make API call to restore version
      setVersions(prev => prev.map(v => ({
        ...v,
        status: v.id === version.id ? 'current' : 'archived'
      })))
      
      onVersionRestore?.(version)
    } catch (error) {
      console.error('Failed to restore version:', error)
    }
  }

  const handleNewVersionUpload = async () => {
    if (!newVersionFile || !changeNote.trim()) return

    setIsUploading(true)
    try {
      // In a real app, upload file and create new version
      const newVersion: AssetVersion = {
        id: `v${Date.now()}`,
        version: currentVersion ? currentVersion.version + 1 : 1,
        assetId: asset.id,
        fileName: newVersionFile.name,
        url: URL.createObjectURL(newVersionFile),
        size: newVersionFile.size,
        uploadedAt: new Date().toISOString(),
        changeNote: changeNote,
        status: 'current',
        changes: [
          {
            type: 'replace',
            description: changeNote,
            timestamp: new Date().toISOString(),
            user: 'Current User'
          }
        ],
        metadata: {
          format: newVersionFile.type.split('/')[1].toUpperCase()
        }
      }

      // Update versions list
      setVersions(prev => [
        newVersion,
        ...prev.map(v => ({ ...v, status: 'archived' as const }))
      ])

      onVersionUpload?.(newVersionFile, changeNote)
      setUploadDialogOpen(false)
      setNewVersionFile(null)
      setChangeNote('')
    } catch (error) {
      console.error('Failed to upload new version:', error)
    } finally {
      setIsUploading(false)
    }
  }

  const handleVersionSelect = (versionId: string) => {
    setSelectedVersions(prev => 
      prev.includes(versionId)
        ? prev.filter(id => id !== versionId)
        : prev.length < 2 
          ? [...prev, versionId]
          : [prev[1], versionId]
    )
  }

  const formatFileSize = (bytes: number): string => {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  const getVersionIcon = (version: AssetVersion) => {
    switch (version.status) {
      case 'current':
        return <CheckCircle className="size-4 text-green-500" />
      case 'deprecated':
        return <AlertCircle className="size-4 text-orange-500" />
      default:
        return <History className="size-4 text-muted-foreground" />
    }
  }

  const getChangeTypeIcon = (changeType: VersionChange['type']) => {
    switch (changeType) {
      case 'upload':
        return <Upload className="size-4 text-blue-500" />
      case 'replace':
        return <RotateCcw className="size-4 text-purple-500" />
      case 'metadata':
        return <Tag className="size-4 text-orange-500" />
      case 'restore':
        return <History className="size-4 text-green-500" />
      default:
        return <FileText className="size-4 text-muted-foreground" />
    }
  }

  return (
    <div className={cn("space-y-6", className)}>
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <GitBranch className="size-5" />
          <div>
            <h3 className="font-semibold">Version History</h3>
            <p className="text-sm text-muted-foreground">
              {versions.length} version{versions.length !== 1 ? 's' : ''} • Current: v{currentVersion?.version || 1}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <Dialog open={compareDialogOpen} onOpenChange={setCompareDialogOpen}>
            <DialogTrigger asChild>
              <Button
                variant="outline"
                size="sm"
                disabled={selectedVersions.length !== 2}
              >
                <Compare className="size-4 mr-2" />
                Compare
              </Button>
            </DialogTrigger>
            <DialogContent className="max-w-4xl">
              <DialogHeader>
                <DialogTitle>Compare Versions</DialogTitle>
                <DialogDescription>
                  Compare selected versions to see differences
                </DialogDescription>
              </DialogHeader>
              <VersionComparison 
                versions={versions.filter(v => selectedVersions.includes(v.id))}
              />
            </DialogContent>
          </Dialog>

          <Dialog open={uploadDialogOpen} onOpenChange={setUploadDialogOpen}>
            <DialogTrigger asChild>
              <Button size="sm">
                <Plus className="size-4 mr-2" />
                New Version
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Upload New Version</DialogTitle>
                <DialogDescription>
                  Upload a new version of this asset
                </DialogDescription>
              </DialogHeader>
              <div className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="file-upload">Select File</Label>
                  <Input
                    id="file-upload"
                    type="file"
                    onChange={(e) => setNewVersionFile(e.target.files?.[0] || null)}
                    accept="image/*,video/*,audio/*,.pdf,.doc,.docx"
                  />
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="change-note">Change Note *</Label>
                  <Textarea
                    id="change-note"
                    placeholder="Describe what changed in this version..."
                    value={changeNote}
                    onChange={(e) => setChangeNote(e.target.value)}
                    rows={3}
                  />
                </div>

                <div className="flex justify-end gap-2">
                  <Button
                    variant="outline"
                    onClick={() => setUploadDialogOpen(false)}
                  >
                    Cancel
                  </Button>
                  <Button
                    onClick={handleNewVersionUpload}
                    disabled={!newVersionFile || !changeNote.trim() || isUploading}
                  >
                    {isUploading ? 'Uploading...' : 'Upload Version'}
                  </Button>
                </div>
              </div>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {/* Version List */}
      <div className="space-y-3">
        {sortedVersions.map((version, index) => (
          <Card 
            key={version.id} 
            className={cn(
              "cursor-pointer transition-colors",
              selectedVersions.includes(version.id) && "ring-2 ring-primary",
              version.status === 'current' && "border-green-200 bg-green-50/50"
            )}
            onClick={() => handleVersionSelect(version.id)}
          >
            <CardContent className="p-4">
              <div className="flex items-start justify-between">
                <div className="flex items-start gap-3">
                  {/* Selection Checkbox */}
                  <input
                    type="checkbox"
                    checked={selectedVersions.includes(version.id)}
                    onChange={() => handleVersionSelect(version.id)}
                    className="mt-1 w-4 h-4 text-primary bg-white border-2 border-gray-300 rounded"
                  />

                  {/* Version Info */}
                  <div className="space-y-2">
                    <div className="flex items-center gap-2">
                      {getVersionIcon(version)}
                      <span className="font-medium">Version {version.version}</span>
                      {version.status === 'current' && (
                        <Badge variant="default" className="text-xs">Current</Badge>
                      )}
                      {version.status === 'deprecated' && (
                        <Badge variant="secondary" className="text-xs">Deprecated</Badge>
                      )}
                    </div>

                    <div className="text-sm text-muted-foreground">
                      <div className="flex items-center gap-4">
                        <span className="flex items-center gap-1">
                          <Clock className="size-3" />
                          {new Date(version.uploadedAt).toLocaleDateString()}
                        </span>
                        <span className="flex items-center gap-1">
                          <User className="size-3" />
                          {version.uploadedBy || 'Unknown'}
                        </span>
                        <span>{formatFileSize(version.size)}</span>
                      </div>
                    </div>

                    {version.changeNote && (
                      <p className="text-sm">{version.changeNote}</p>
                    )}

                    {/* Changes */}
                    {version.changes.length > 0 && (
                      <div className="space-y-1">
                        {version.changes.map((change, changeIndex) => (
                          <div key={changeIndex} className="flex items-center gap-2 text-xs text-muted-foreground">
                            {getChangeTypeIcon(change.type)}
                            <span>{change.description}</span>
                            {change.user && (
                              <span>by {change.user}</span>
                            )}
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                </div>

                {/* Actions */}
                <div className="flex items-center gap-2">
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={(e) => {
                      e.stopPropagation()
                      window.open(version.url, '_blank')
                    }}
                  >
                    <Eye className="size-4" />
                  </Button>
                  
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={(e) => {
                      e.stopPropagation()
                      // Download logic
                    }}
                  >
                    <Download className="size-4" />
                  </Button>

                  {version.status !== 'current' && (
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={(e) => {
                        e.stopPropagation()
                        handleVersionRestore(version)
                      }}
                    >
                      <RotateCcw className="size-4" />
                    </Button>
                  )}
                </div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Selection Info */}
      {selectedVersions.length > 0 && (
        <div className="text-sm text-muted-foreground">
          {selectedVersions.length} version{selectedVersions.length !== 1 ? 's' : ''} selected
          {selectedVersions.length === 2 && ' • Ready to compare'}
        </div>
      )}
    </div>
  )
}

interface VersionComparisonProps {
  versions: AssetVersion[]
}

function VersionComparison({ versions }: VersionComparisonProps) {
  if (versions.length !== 2) {
    return <div>Select exactly two versions to compare</div>
  }

  const [version1, version2] = versions.sort((a, b) => b.version - a.version)

  return (
    <div className="space-y-6">
      {/* Comparison Header */}
      <div className="grid grid-cols-3 gap-4 items-center">
        <div className="text-center">
          <h4 className="font-medium">Version {version1.version}</h4>
          <p className="text-sm text-muted-foreground">
            {new Date(version1.uploadedAt).toLocaleDateString()}
          </p>
        </div>
        <div className="text-center">
          <ArrowRight className="size-4 mx-auto text-muted-foreground" />
        </div>
        <div className="text-center">
          <h4 className="font-medium">Version {version2.version}</h4>
          <p className="text-sm text-muted-foreground">
            {new Date(version2.uploadedAt).toLocaleDateString()}
          </p>
        </div>
      </div>

      {/* Visual Comparison */}
      <div className="grid grid-cols-2 gap-4">
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Version {version1.version}</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="aspect-square bg-muted rounded-lg mb-4 flex items-center justify-center">
              <img
                src={version1.url}
                alt={`Version ${version1.version}`}
                className="max-w-full max-h-full object-contain rounded-lg"
              />
            </div>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span>Size:</span>
                <span>{formatFileSize(version1.size)}</span>
              </div>
              {version1.metadata.width && version1.metadata.height && (
                <div className="flex justify-between">
                  <span>Dimensions:</span>
                  <span>{version1.metadata.width} × {version1.metadata.height}</span>
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Version {version2.version}</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="aspect-square bg-muted rounded-lg mb-4 flex items-center justify-center">
              <img
                src={version2.url}
                alt={`Version ${version2.version}`}
                className="max-w-full max-h-full object-contain rounded-lg"
              />
            </div>
            <div className="space-y-2 text-sm">
              <div className="flex justify-between">
                <span>Size:</span>
                <span>{formatFileSize(version2.size)}</span>
              </div>
              {version2.metadata.width && version2.metadata.height && (
                <div className="flex justify-between">
                  <span>Dimensions:</span>
                  <span>{version2.metadata.width} × {version2.metadata.height}</span>
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Change Summary */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">Changes</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-2">
            {version1.changeNote && (
              <div>
                <span className="font-medium">v{version1.version}:</span> {version1.changeNote}
              </div>
            )}
            {version2.changeNote && (
              <div>
                <span className="font-medium">v{version2.version}:</span> {version2.changeNote}
              </div>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 Bytes'
  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}