"use client"

import * as React from "react"
import { useState, useEffect } from "react"
import { cn } from "@/lib/utils"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { 
  PreviewContent, 
  ChannelPreviewConfig, 
  ValidationResult,
  ExportOptions,
  validateContent,
  exportContent
} from "@/lib/channel-previews"
import { 
  AlertTriangle, 
  CheckCircle, 
  Info, 
  Download, 
  Copy,
  RefreshCw,
  Eye
} from "lucide-react"

export interface BasePreviewProps {
  content: PreviewContent
  config: ChannelPreviewConfig
  className?: string
  showValidation?: boolean
  showExport?: boolean
  showDeviceFrame?: boolean
  onExport?: (format: ExportOptions['format']) => void
  onCopy?: () => void
  onRefresh?: () => void
  children: React.ReactNode
}

export function BasePreview({
  content,
  config,
  className,
  showValidation = true,
  showExport = true,
  showDeviceFrame = true,
  onExport,
  onCopy,
  onRefresh,
  children
}: BasePreviewProps) {
  const [validation, setValidation] = useState<ValidationResult | null>(null)
  const [isExporting, setIsExporting] = useState(false)

  // Validate content whenever it changes
  useEffect(() => {
    if (showValidation) {
      const result = validateContent(content, config)
      setValidation(result)
    }
  }, [content, config, showValidation])

  const handleExport = async (format: ExportOptions['format']) => {
    if (!onExport) return
    
    try {
      setIsExporting(true)
      onExport(format)
    } finally {
      setIsExporting(false)
    }
  }

  const handleCopy = () => {
    if (content.text) {
      navigator.clipboard.writeText(content.text)
      onCopy?.()
    }
  }

  const getDeviceFrame = () => {
    if (!showDeviceFrame || config.deviceFrame === 'none') return null

    const frameClasses = {
      mobile: "w-[375px] mx-auto bg-black rounded-[2.5rem] p-2",
      tablet: "w-[768px] mx-auto bg-gray-800 rounded-[1.5rem] p-4", 
      desktop: "w-full max-w-4xl mx-auto bg-gray-100 rounded-lg p-4"
    }

    return frameClasses[config.deviceFrame] || frameClasses.desktop
  }

  const getSeverityIcon = (severity: ValidationResult['warnings'][0]['severity']) => {
    switch (severity) {
      case 'error':
        return <AlertTriangle className="w-4 h-4 text-red-500" />
      case 'warning':
        return <AlertTriangle className="w-4 h-4 text-yellow-500" />
      case 'info':
        return <Info className="w-4 h-4 text-blue-500" />
      default:
        return <Info className="w-4 h-4 text-gray-500" />
    }
  }

  const frameClass = getDeviceFrame()

  return (
    <div className={cn("space-y-4", className)}>
      {/* Preview Header */}
      <div className="flex items-center justify-between">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <h3 className="text-lg font-semibold">{config.name}</h3>
            <Badge variant="outline" className="text-xs">
              {config.dimensions.width} × {config.dimensions.height}
            </Badge>
            <Badge variant="secondary" className="text-xs">
              {config.channel}
            </Badge>
          </div>
          <p className="text-sm text-muted-foreground">{config.description}</p>
        </div>

        {/* Action Buttons */}
        <div className="flex items-center gap-2">
          {onRefresh && (
            <Button variant="outline" size="sm" onClick={onRefresh}>
              <RefreshCw className="w-4 h-4 mr-2" />
              Refresh
            </Button>
          )}
          
          {content.text && (
            <Button variant="outline" size="sm" onClick={handleCopy}>
              <Copy className="w-4 h-4 mr-2" />
              Copy Text
            </Button>
          )}

          {showExport && (
            <div className="flex gap-1">
              <Button 
                variant="outline" 
                size="sm" 
                onClick={() => handleExport('json')}
                disabled={isExporting}
              >
                <Download className="w-4 h-4 mr-1" />
                JSON
              </Button>
              <Button 
                variant="outline" 
                size="sm" 
                onClick={() => handleExport('html')}
                disabled={isExporting}
              >
                <Download className="w-4 h-4 mr-1" />
                HTML
              </Button>
            </div>
          )}
        </div>
      </div>

      {/* Validation Results */}
      {showValidation && validation && (
        <div className="space-y-2">
          {/* Overall Status */}
          <div className="flex items-center gap-2">
            {validation.isValid ? (
              <CheckCircle className="w-5 h-5 text-green-500" />
            ) : (
              <AlertTriangle className="w-5 h-5 text-red-500" />
            )}
            <span className="text-sm font-medium">
              {validation.isValid ? 'Content is valid' : 'Content has issues'}
            </span>
            {validation.characterLimit && (
              <Badge variant={
                (validation.characterCount || 0) > validation.characterLimit ? 'destructive' : 'secondary'
              }>
                {validation.characterCount || 0}/{validation.characterLimit} characters
              </Badge>
            )}
          </div>

          {/* Warnings and Errors */}
          {validation.warnings.length > 0 && (
            <div className="space-y-1">
              {validation.warnings.map((warning, index) => (
                <Alert key={index} className={cn(
                  warning.severity === 'error' && 'border-red-200 bg-red-50',
                  warning.severity === 'warning' && 'border-yellow-200 bg-yellow-50',
                  warning.severity === 'info' && 'border-blue-200 bg-blue-50'
                )}>
                  {getSeverityIcon(warning.severity)}
                  <AlertDescription className="text-sm">
                    {warning.message}
                  </AlertDescription>
                </Alert>
              ))}
            </div>
          )}

          {/* Suggestions */}
          {validation.suggestions.length > 0 && (
            <div className="bg-blue-50 border border-blue-200 rounded-md p-3">
              <div className="flex items-start gap-2">
                <Info className="w-4 h-4 text-blue-500 mt-0.5 flex-shrink-0" />
                <div className="space-y-1">
                  <p className="text-sm font-medium text-blue-800">Suggestions</p>
                  <ul className="text-sm text-blue-700 space-y-1">
                    {validation.suggestions.map((suggestion, index) => (
                      <li key={index} className="flex items-start gap-1">
                        <span className="text-blue-400">•</span>
                        <span>{suggestion}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Preview Container */}
      <Card className="overflow-hidden">
        <CardContent className="p-0">
          <div 
            className={cn(frameClass)}
            style={{ 
              minHeight: config.dimensions.height,
              backgroundColor: config.deviceFrame === 'mobile' ? '#000' : undefined
            }}
          >
            <div 
              className={cn(
                config.containerClassName,
                "overflow-hidden relative"
              )}
              style={{
                width: config.deviceFrame === 'none' ? config.dimensions.width : '100%',
                minHeight: config.dimensions.height,
                aspectRatio: config.deviceFrame === 'mobile' || config.deviceFrame === 'tablet' 
                  ? config.dimensions.aspectRatio 
                  : undefined
              }}
            >
              {children}
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Format Information */}
      <div className="text-xs text-muted-foreground space-y-1">
        <div className="flex items-center justify-between">
          <span>Dimensions: {config.dimensions.width} × {config.dimensions.height} ({config.dimensions.aspectRatio})</span>
          <span>Device: {config.deviceFrame || 'responsive'}</span>
        </div>
        
        {/* Supported Features */}
        <div className="flex items-center gap-4 flex-wrap">
          <span>Supported:</span>
          {Object.entries(config.supportedFeatures)
            .filter(([, supported]) => supported)
            .map(([feature]) => (
              <Badge key={feature} variant="outline" className="text-xs">
                {feature}
              </Badge>
            ))}
        </div>

        {/* Limits */}
        {(config.limits.maxTextLength || config.limits.maxHashtags || config.limits.maxImages) && (
          <div className="flex items-center gap-4 flex-wrap">
            <span>Limits:</span>
            {config.limits.maxTextLength && (
              <span>Text: {config.limits.maxTextLength} chars</span>
            )}
            {config.limits.maxHashtags && (
              <span>Hashtags: {config.limits.maxHashtags}</span>
            )}
            {config.limits.maxImages && (
              <span>Images: {config.limits.maxImages}</span>
            )}
            {config.limits.videoMaxDuration && (
              <span>Video: {config.limits.videoMaxDuration}s</span>
            )}
          </div>
        )}
      </div>
    </div>
  )
}

export default BasePreview