"use client"

import React, { useState, useRef, useEffect } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog'
import { Badge } from '@/components/ui/badge'
import { Separator } from '@/components/ui/separator'
import { 
  Eye, 
  Download, 
  Edit, 
  Trash2, 
  Share, 
  ZoomIn, 
  ZoomOut, 
  RotateCw,
  Play,
  Pause,
  Volume2,
  VolumeX,
  FileText,
  Image as ImageIcon,
  Video,
  Headphones,
  ExternalLink,
  Copy,
  Tag
} from 'lucide-react'
import { BrandAsset, brandAssetManager } from '@/lib/brand-assets'
import { cn } from '@/lib/utils'

interface AssetPreviewProps {
  asset: BrandAsset
  onEdit?: (asset: BrandAsset) => void
  onDelete?: (asset: BrandAsset) => void
  onShare?: (asset: BrandAsset) => void
  showActions?: boolean
  size?: 'sm' | 'md' | 'lg'
}

export function AssetPreview({ 
  asset, 
  onEdit, 
  onDelete, 
  onShare,
  showActions = true,
  size = 'md'
}: AssetPreviewProps) {
  const [isLoading, setIsLoading] = useState(false)
  const [previewOpen, setPreviewOpen] = useState(false)

  const sizeClasses = {
    sm: 'w-32 h-32',
    md: 'w-48 h-48',
    lg: 'w-64 h-64'
  }

  const handleDownload = async () => {
    try {
      setIsLoading(true)
      const response = await fetch(asset.url)
      const blob = await response.blob()
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.style.display = 'none'
      a.href = url
      a.download = asset.originalName
      document.body.appendChild(a)
      a.click()
      window.URL.revokeObjectURL(url)
      document.body.removeChild(a)
    } catch (error) {
      console.error('Failed to download asset:', error)
    } finally {
      setIsLoading(false)
    }
  }

  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text)
    } catch (error) {
      console.error('Failed to copy to clipboard:', error)
    }
  }

  const renderThumbnail = () => {
    switch (asset.type) {
      case 'image':
        return (
          <div className={cn("relative overflow-hidden rounded-lg bg-muted", sizeClasses[size])}>
            <img
              src={asset.url}
              alt={asset.name}
              className="w-full h-full object-cover"
              loading="lazy"
              onError={(e) => {
                const target = e.target as HTMLImageElement
                target.src = '/placeholder-image.png'
              }}
            />
          </div>
        )

      case 'video':
        return (
          <div className={cn("relative overflow-hidden rounded-lg bg-muted", sizeClasses[size])}>
            <video
              src={asset.url}
              className="w-full h-full object-cover"
              muted
              playsInline
              onError={() => console.error('Video failed to load')}
            />
            <div className="absolute inset-0 flex items-center justify-center bg-black/20">
              <div className="bg-white/90 rounded-full p-3">
                <Video className="size-6 text-gray-700" />
              </div>
            </div>
          </div>
        )

      case 'audio':
        return (
          <div className={cn("relative flex items-center justify-center rounded-lg bg-muted", sizeClasses[size])}>
            <div className="text-center space-y-2">
              <div className="bg-primary/10 rounded-full p-4 mx-auto w-fit">
                <Headphones className="size-8 text-primary" />
              </div>
              <p className="text-sm text-muted-foreground">Audio File</p>
            </div>
          </div>
        )

      case 'document':
        return (
          <div className={cn("relative flex items-center justify-center rounded-lg bg-muted", sizeClasses[size])}>
            <div className="text-center space-y-2">
              <div className="bg-primary/10 rounded-full p-4 mx-auto w-fit">
                <FileText className="size-8 text-primary" />
              </div>
              <p className="text-sm text-muted-foreground">Document</p>
            </div>
          </div>
        )

      default:
        return (
          <div className={cn("relative flex items-center justify-center rounded-lg bg-muted", sizeClasses[size])}>
            <FileText className="size-12 text-muted-foreground" />
          </div>
        )
    }
  }

  return (
    <>
      <Card className="group hover:shadow-md transition-shadow">
        <CardContent className="p-4">
          {/* Thumbnail */}
          <div className="mb-3">
            <Dialog open={previewOpen} onOpenChange={setPreviewOpen}>
              <DialogTrigger asChild>
                <button className="relative w-full">
                  {renderThumbnail()}
                  {/* Hover overlay */}
                  <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors rounded-lg flex items-center justify-center opacity-0 group-hover:opacity-100">
                    <div className="bg-white/90 rounded-full p-2">
                      <Eye className="size-4 text-gray-700" />
                    </div>
                  </div>
                </button>
              </DialogTrigger>
              <DialogContent className="max-w-4xl max-h-[90vh] overflow-auto">
                <DialogHeader>
                  <DialogTitle className="flex items-center gap-2">
                    {asset.type === 'image' && <ImageIcon className="size-5" />}
                    {asset.type === 'video' && <Video className="size-5" />}
                    {asset.type === 'audio' && <Headphones className="size-5" />}
                    {asset.type === 'document' && <FileText className="size-5" />}
                    {asset.name}
                  </DialogTitle>
                </DialogHeader>
                <AssetFullPreview asset={asset} />
              </DialogContent>
            </Dialog>
          </div>

          {/* Asset Info */}
          <div className="space-y-2">
            <h4 className="font-medium text-sm truncate" title={asset.name}>
              {asset.name}
            </h4>
            <div className="flex items-center gap-2">
              <Badge variant="secondary" className="text-xs">
                {asset.type}
              </Badge>
              <span className="text-xs text-muted-foreground">
                {brandAssetManager.formatFileSize(asset.size)}
              </span>
            </div>
            
            {asset.tags.length > 0 && (
              <div className="flex flex-wrap gap-1">
                {asset.tags.slice(0, 3).map((tag) => (
                  <Badge key={tag} variant="outline" className="text-xs">
                    {tag}
                  </Badge>
                ))}
                {asset.tags.length > 3 && (
                  <Badge variant="outline" className="text-xs">
                    +{asset.tags.length - 3}
                  </Badge>
                )}
              </div>
            )}
          </div>

          {/* Actions */}
          {showActions && (
            <div className="mt-3 flex items-center justify-between">
              <div className="flex items-center gap-1">
                <Button 
                  size="sm" 
                  variant="ghost" 
                  onClick={handleDownload}
                  disabled={isLoading}
                >
                  <Download className="size-3" />
                </Button>
                <Button 
                  size="sm" 
                  variant="ghost" 
                  onClick={() => copyToClipboard(asset.url)}
                >
                  <Copy className="size-3" />
                </Button>
                <Button 
                  size="sm" 
                  variant="ghost" 
                  onClick={() => onShare?.(asset)}
                >
                  <Share className="size-3" />
                </Button>
              </div>
              <div className="flex items-center gap-1">
                <Button 
                  size="sm" 
                  variant="ghost" 
                  onClick={() => onEdit?.(asset)}
                >
                  <Edit className="size-3" />
                </Button>
                <Button 
                  size="sm" 
                  variant="ghost" 
                  onClick={() => onDelete?.(asset)}
                >
                  <Trash2 className="size-3" />
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </>
  )
}

interface AssetFullPreviewProps {
  asset: BrandAsset
}

function AssetFullPreview({ asset }: AssetFullPreviewProps) {
  const [zoom, setZoom] = useState(1)
  const [rotation, setRotation] = useState(0)
  const [isPlaying, setIsPlaying] = useState(false)
  const [isMuted, setIsMuted] = useState(false)
  const videoRef = useRef<HTMLVideoElement>(null)
  const audioRef = useRef<HTMLAudioElement>(null)

  const handleZoomIn = () => setZoom(prev => Math.min(prev + 0.25, 3))
  const handleZoomOut = () => setZoom(prev => Math.max(prev - 0.25, 0.25))
  const handleRotate = () => setRotation(prev => (prev + 90) % 360)

  const togglePlayPause = () => {
    if (videoRef.current) {
      if (isPlaying) {
        videoRef.current.pause()
      } else {
        videoRef.current.play()
      }
    }
    if (audioRef.current) {
      if (isPlaying) {
        audioRef.current.pause()
      } else {
        audioRef.current.play()
      }
    }
    setIsPlaying(!isPlaying)
  }

  const toggleMute = () => {
    if (videoRef.current) {
      videoRef.current.muted = !isMuted
    }
    if (audioRef.current) {
      audioRef.current.muted = !isMuted
    }
    setIsMuted(!isMuted)
  }

  const renderFullPreview = () => {
    switch (asset.type) {
      case 'image':
        return (
          <div className="space-y-4">
            {/* Image controls */}
            <div className="flex items-center justify-center gap-2">
              <Button size="sm" variant="outline" onClick={handleZoomOut}>
                <ZoomOut className="size-4" />
              </Button>
              <span className="text-sm text-muted-foreground px-2">
                {Math.round(zoom * 100)}%
              </span>
              <Button size="sm" variant="outline" onClick={handleZoomIn}>
                <ZoomIn className="size-4" />
              </Button>
              <Button size="sm" variant="outline" onClick={handleRotate}>
                <RotateCw className="size-4" />
              </Button>
            </div>
            
            {/* Image */}
            <div className="overflow-auto max-h-[60vh] flex items-center justify-center">
              <img
                src={asset.url}
                alt={asset.name}
                className="max-w-full max-h-full object-contain"
                style={{
                  transform: `scale(${zoom}) rotate(${rotation}deg)`,
                  transition: 'transform 0.2s ease-in-out'
                }}
              />
            </div>
          </div>
        )

      case 'video':
        return (
          <div className="space-y-4">
            {/* Video controls */}
            <div className="flex items-center justify-center gap-2">
              <Button size="sm" variant="outline" onClick={togglePlayPause}>
                {isPlaying ? <Pause className="size-4" /> : <Play className="size-4" />}
              </Button>
              <Button size="sm" variant="outline" onClick={toggleMute}>
                {isMuted ? <VolumeX className="size-4" /> : <Volume2 className="size-4" />}
              </Button>
            </div>
            
            {/* Video */}
            <div className="flex items-center justify-center max-h-[60vh]">
              <video
                ref={videoRef}
                src={asset.url}
                className="max-w-full max-h-full"
                controls
                muted={isMuted}
                onPlay={() => setIsPlaying(true)}
                onPause={() => setIsPlaying(false)}
              />
            </div>
          </div>
        )

      case 'audio':
        return (
          <div className="space-y-4">
            {/* Audio controls */}
            <div className="flex items-center justify-center gap-2">
              <Button size="sm" variant="outline" onClick={togglePlayPause}>
                {isPlaying ? <Pause className="size-4" /> : <Play className="size-4" />}
              </Button>
              <Button size="sm" variant="outline" onClick={toggleMute}>
                {isMuted ? <VolumeX className="size-4" /> : <Volume2 className="size-4" />}
              </Button>
            </div>
            
            {/* Audio visualization */}
            <div className="flex items-center justify-center p-12">
              <div className="bg-primary/10 rounded-full p-8">
                <Headphones className="size-16 text-primary" />
              </div>
            </div>
            
            {/* Audio element */}
            <audio
              ref={audioRef}
              src={asset.url}
              controls
              muted={isMuted}
              onPlay={() => setIsPlaying(true)}
              onPause={() => setIsPlaying(false)}
              className="w-full"
            />
          </div>
        )

      case 'document':
        return (
          <div className="space-y-4">
            <div className="text-center">
              <div className="bg-primary/10 rounded-full p-8 mx-auto w-fit">
                <FileText className="size-16 text-primary" />
              </div>
              <p className="mt-4 text-muted-foreground">
                Document preview not available. Click download to view the file.
              </p>
              <Button className="mt-4" onClick={() => window.open(asset.url, '_blank')}>
                <ExternalLink className="size-4 mr-2" />
                Open in New Tab
              </Button>
            </div>
          </div>
        )

      default:
        return (
          <div className="text-center p-12">
            <FileText className="size-16 text-muted-foreground mx-auto mb-4" />
            <p className="text-muted-foreground">Preview not available for this file type</p>
          </div>
        )
    }
  }

  return (
    <div className="space-y-6">
      {/* Preview area */}
      <div className="border rounded-lg">
        {renderFullPreview()}
      </div>

      {/* Asset metadata */}
      <div className="space-y-4">
        <Separator />
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
          <div>
            <dt className="font-medium text-muted-foreground">Type</dt>
            <dd className="capitalize">{asset.type}</dd>
          </div>
          <div>
            <dt className="font-medium text-muted-foreground">Size</dt>
            <dd>{brandAssetManager.formatFileSize(asset.size)}</dd>
          </div>
          <div>
            <dt className="font-medium text-muted-foreground">Category</dt>
            <dd className="capitalize">{asset.category}</dd>
          </div>
          <div>
            <dt className="font-medium text-muted-foreground">Version</dt>
            <dd>v{asset.version}</dd>
          </div>
        </div>
        
        {asset.tags.length > 0 && (
          <div>
            <dt className="font-medium text-muted-foreground mb-2">Tags</dt>
            <dd className="flex flex-wrap gap-1">
              {asset.tags.map((tag) => (
                <Badge key={tag} variant="outline" className="text-xs">
                  <Tag className="size-3 mr-1" />
                  {tag}
                </Badge>
              ))}
            </dd>
          </div>
        )}
        
        <div>
          <dt className="font-medium text-muted-foreground">Uploaded</dt>
          <dd>{new Date(asset.uploadedAt).toLocaleDateString()}</dd>
        </div>
      </div>
    </div>
  )
}