"use client"

import * as React from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import { Input } from "@/components/ui/input"
import { Badge } from "@/components/ui/badge"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { Progress } from "@/components/ui/progress"
import { Checkbox } from "@/components/ui/checkbox"
import { Separator } from "@/components/ui/separator"
import {
  Download,
  Upload,
  FileText,
  FileJson,
  Image,
  LayoutTemplate,
  AlertTriangle,
  CheckCircle,
  XCircle,
  Info,
  RefreshCw,
  Loader2,
  FileX,
  Package
} from "lucide-react"
import { cn } from "@/lib/utils"
import type { Journey } from "@prisma/client"
import type { ExportValidationResult } from "@/lib/journey-export-import"

interface JourneyExportImportProps {
  journeys?: Journey[]
  campaignId?: string
  onJourneyImported?: (journey: Journey) => void
  onJourneysImported?: (journeys: Journey[]) => void
  className?: string
}

type ExportFormat = "json" | "pdf-data" | "diagram" | "template"
type ExportType = "full" | "template" | "stages-only"

interface ExportState {
  format: ExportFormat
  type: ExportType
  selectedJourneys: string[]
  isExporting: boolean
}

interface ImportState {
  importData: string
  isImporting: boolean
  validation?: ExportValidationResult
  importResults?: any
}

// Export Dialog Component
function ExportDialog({ 
  journeys, 
  campaignId, 
  trigger 
}: { 
  journeys?: Journey[]
  campaignId?: string
  trigger: React.ReactNode 
}) {
  const [exportState, setExportState] = React.useState<ExportState>({
    format: "json",
    type: "full",
    selectedJourneys: [],
    isExporting: false,
  })

  const handleExport = async () => {
    try {
      setExportState(prev => ({ ...prev, isExporting: true }))

      const isBatchExport = exportState.selectedJourneys.length > 1
      
      if (isBatchExport) {
        // Batch export
        const response = await fetch("/api/journeys/batch-export", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            journeyIds: exportState.selectedJourneys,
            campaignId,
            format: exportState.format,
            exportFormat: exportState.type,
            exportedBy: "user", // Could be dynamic based on auth
          }),
        })

        if (response.ok) {
          const filename = response.headers.get('Content-Disposition')?.match(/filename="(.+)"/)?.[1] || 'export.json'
          const blob = await response.blob()
          
          const url = window.URL.createObjectURL(blob)
          const a = document.createElement('a')
          a.href = url
          a.download = filename
          document.body.appendChild(a)
          a.click()
          window.URL.revokeObjectURL(url)
          document.body.removeChild(a)
        }
      } else if (exportState.selectedJourneys.length === 1) {
        // Single journey export
        const journeyId = exportState.selectedJourneys[0]
        const response = await fetch(`/api/journeys/${journeyId}/export?format=${exportState.format}&exportFormat=${exportState.type}&exportedBy=user`)

        if (response.ok) {
          if (exportState.format === "pdf-data") {
            // Handle PDF data response
            const data = await response.json()
            console.log("PDF Export Data:", data)
            // Here you would typically send this to a PDF generation service
            alert("PDF data generated successfully. Check console for details.")
          } else {
            const filename = response.headers.get('Content-Disposition')?.match(/filename="(.+)"/)?.[1] || 'export.json'
            const blob = await response.blob()
            
            const url = window.URL.createObjectURL(blob)
            const a = document.createElement('a')
            a.href = url
            a.download = filename
            document.body.appendChild(a)
            a.click()
            window.URL.revokeObjectURL(url)
            document.body.removeChild(a)
          }
        } else {
          const errorData = await response.json()
          throw new Error(errorData.error || "Export failed")
        }
      }
    } catch (error) {
      console.error("Export error:", error)
      alert(`Export failed: ${error instanceof Error ? error.message : "Unknown error"}`)
    } finally {
      setExportState(prev => ({ ...prev, isExporting: false }))
    }
  }

  const toggleJourneySelection = (journeyId: string) => {
    setExportState(prev => ({
      ...prev,
      selectedJourneys: prev.selectedJourneys.includes(journeyId)
        ? prev.selectedJourneys.filter(id => id !== journeyId)
        : [...prev.selectedJourneys, journeyId]
    }))
  }

  const selectAllJourneys = () => {
    setExportState(prev => ({
      ...prev,
      selectedJourneys: journeys?.map(j => j.id) || []
    }))
  }

  const clearSelection = () => {
    setExportState(prev => ({
      ...prev,
      selectedJourneys: []
    }))
  }

  return (
    <Dialog>
      <DialogTrigger asChild>
        {trigger}
      </DialogTrigger>
      <DialogContent className="sm:max-w-[600px]">
        <DialogHeader>
          <DialogTitle>Export Journeys</DialogTitle>
          <DialogDescription>
            Export your customer journeys in various formats
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-6">
          {/* Journey Selection */}
          {journeys && journeys.length > 0 && (
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <Label>Select Journeys to Export</Label>
                <div className="flex gap-2">
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onClick={selectAllJourneys}
                    disabled={exportState.selectedJourneys.length === journeys.length}
                  >
                    Select All
                  </Button>
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onClick={clearSelection}
                    disabled={exportState.selectedJourneys.length === 0}
                  >
                    Clear
                  </Button>
                </div>
              </div>

              <div className="max-h-40 overflow-y-auto border rounded-md p-3 space-y-2">
                {journeys.map(journey => (
                  <div key={journey.id} className="flex items-center space-x-2">
                    <Checkbox
                      id={journey.id}
                      checked={exportState.selectedJourneys.includes(journey.id)}
                      onCheckedChange={() => toggleJourneySelection(journey.id)}
                    />
                    <Label htmlFor={journey.id} className="flex-1 cursor-pointer">
                      <span className="font-medium">{journey.name}</span>
                      {journey.description && (
                        <span className="text-sm text-gray-500 block">
                          {journey.description}
                        </span>
                      )}
                    </Label>
                    <Badge variant="outline">{journey.status}</Badge>
                  </div>
                ))}
              </div>
              
              <div className="text-sm text-gray-500">
                {exportState.selectedJourneys.length} of {journeys.length} journeys selected
              </div>
            </div>
          )}

          {/* Export Format */}
          <div className="space-y-2">
            <Label htmlFor="export-format">Export Format</Label>
            <Select
              value={exportState.format}
              onValueChange={(value: ExportFormat) =>
                setExportState(prev => ({ ...prev, format: value }))
              }
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="json">
                  <div className="flex items-center gap-2">
                    <FileJson className="h-4 w-4" />
                    JSON Configuration
                  </div>
                </SelectItem>
                <SelectItem value="pdf-data">
                  <div className="flex items-center gap-2">
                    <FileText className="h-4 w-4" />
                    PDF Summary Data
                  </div>
                </SelectItem>
                <SelectItem value="diagram">
                  <div className="flex items-center gap-2">
                    <Image className="h-4 w-4" />
                    Visual Diagram
                  </div>
                </SelectItem>
                <SelectItem value="template">
                  <div className="flex items-center gap-2">
                    <LayoutTemplate className="h-4 w-4" />
                    Journey Template
                  </div>
                </SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Export Type */}
          {exportState.format === "json" && (
            <div className="space-y-2">
              <Label htmlFor="export-type">Export Detail Level</Label>
              <Select
                value={exportState.type}
                onValueChange={(value: ExportType) =>
                  setExportState(prev => ({ ...prev, type: value }))
                }
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="full">Full Journey (all data)</SelectItem>
                  <SelectItem value="template">Template (no IDs)</SelectItem>
                  <SelectItem value="stages-only">Stages Only</SelectItem>
                </SelectContent>
              </Select>
            </div>
          )}

          {/* Format Description */}
          <div className="text-sm text-gray-600 bg-gray-50 p-3 rounded-md">
            {exportState.format === "json" && "Export journey configuration as JSON file for backup or sharing"}
            {exportState.format === "pdf-data" && "Generate data structure for PDF summary reports"}
            {exportState.format === "diagram" && "Export visual flow diagram data for external visualization"}
            {exportState.format === "template" && "Create reusable journey template from existing journey"}
          </div>
        </div>

        <DialogFooter>
          <Button
            onClick={handleExport}
            disabled={exportState.isExporting || exportState.selectedJourneys.length === 0}
            className="flex items-center gap-2"
          >
            {exportState.isExporting ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" />
                Exporting...
              </>
            ) : (
              <>
                <Download className="h-4 w-4" />
                Export {exportState.selectedJourneys.length > 1 ? "Batch" : "Journey"}
              </>
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// Import Dialog Component
function ImportDialog({ 
  campaignId, 
  onJourneyImported, 
  onJourneysImported, 
  trigger 
}: { 
  campaignId?: string
  onJourneyImported?: (journey: Journey) => void
  onJourneysImported?: (journeys: Journey[]) => void
  trigger: React.ReactNode 
}) {
  const [importState, setImportState] = React.useState<ImportState>({
    importData: "",
    isImporting: false,
  })

  const fileInputRef = React.useRef<HTMLInputElement>(null)

  const handleFileUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    if (file) {
      const reader = new FileReader()
      reader.onload = (e) => {
        const content = e.target?.result as string
        setImportState(prev => ({ ...prev, importData: content }))
        validateImportData(content)
      }
      reader.readAsText(file)
    }
  }

  const validateImportData = async (data: string) => {
    try {
      const parsedData = JSON.parse(data)
      // You could call a validation API endpoint here
      // For now, just basic JSON validation
      setImportState(prev => ({ 
        ...prev, 
        validation: { isValid: true, errors: [], warnings: [] } 
      }))
    } catch (error) {
      setImportState(prev => ({ 
        ...prev, 
        validation: { 
          isValid: false, 
          errors: ["Invalid JSON format"], 
          warnings: [] 
        } 
      }))
    }
  }

  const handleImport = async () => {
    if (!campaignId) {
      alert("Campaign ID is required")
      return
    }

    try {
      setImportState(prev => ({ ...prev, isImporting: true }))

      const importData = JSON.parse(importState.importData)
      
      const response = await fetch(`/api/journeys/import?campaignId=${campaignId}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          importData,
          changeNote: "Imported journey",
          importedBy: "user", // Could be dynamic based on auth
        }),
      })

      const result = await response.json()

      if (response.ok) {
        setImportState(prev => ({ ...prev, importResults: result }))
        
        if (result.success && result.journey) {
          onJourneyImported?.(result.journey)
        } else if (result.results) {
          const importedJourneys = result.results.filter((r: any) => r.success)
          onJourneysImported?.(importedJourneys.map((r: any) => r.journey))
        }
      } else {
        setImportState(prev => ({ 
          ...prev, 
          validation: result.validation || { 
            isValid: false, 
            errors: [result.error || "Import failed"], 
            warnings: [] 
          } 
        }))
      }
    } catch (error) {
      setImportState(prev => ({ 
        ...prev, 
        validation: { 
          isValid: false, 
          errors: [error instanceof Error ? error.message : "Unknown error"], 
          warnings: [] 
        } 
      }))
    } finally {
      setImportState(prev => ({ ...prev, isImporting: false }))
    }
  }

  const resetImport = () => {
    setImportState({
      importData: "",
      isImporting: false,
    })
    if (fileInputRef.current) {
      fileInputRef.current.value = ""
    }
  }

  return (
    <Dialog>
      <DialogTrigger asChild>
        {trigger}
      </DialogTrigger>
      <DialogContent className="sm:max-w-[600px]">
        <DialogHeader>
          <DialogTitle>Import Journeys</DialogTitle>
          <DialogDescription>
            Import customer journeys from JSON files or templates
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-6">
          {/* File Upload */}
          <div className="space-y-2">
            <Label>Upload Journey File</Label>
            <div className="flex gap-2">
              <Input
                ref={fileInputRef}
                type="file"
                accept=".json"
                onChange={handleFileUpload}
                className="flex-1"
              />
              <Button
                type="button"
                variant="outline"
                onClick={() => fileInputRef.current?.click()}
              >
                Browse
              </Button>
            </div>
          </div>

          <Separator />

          {/* Manual Input */}
          <div className="space-y-2">
            <Label htmlFor="import-data">Or Paste JSON Data</Label>
            <Textarea
              id="import-data"
              placeholder="Paste your journey JSON data here..."
              value={importState.importData}
              onChange={(e) => {
                setImportState(prev => ({ ...prev, importData: e.target.value }))
                validateImportData(e.target.value)
              }}
              className="min-h-[200px] font-mono text-sm"
            />
          </div>

          {/* Validation Results */}
          {importState.validation && (
            <div className="space-y-2">
              {!importState.validation.isValid && (
                <Alert variant="destructive">
                  <XCircle className="h-4 w-4" />
                  <AlertTitle>Validation Errors</AlertTitle>
                  <AlertDescription>
                    <ul className="list-disc list-inside space-y-1">
                      {importState.validation.errors.map((error, index) => (
                        <li key={index}>{error}</li>
                      ))}
                    </ul>
                  </AlertDescription>
                </Alert>
              )}

              {importState.validation.warnings.length > 0 && (
                <Alert>
                  <AlertTriangle className="h-4 w-4" />
                  <AlertTitle>Warnings</AlertTitle>
                  <AlertDescription>
                    <ul className="list-disc list-inside space-y-1">
                      {importState.validation.warnings.map((warning, index) => (
                        <li key={index}>{warning}</li>
                      ))}
                    </ul>
                  </AlertDescription>
                </Alert>
              )}

              {importState.validation.isValid && (
                <Alert>
                  <CheckCircle className="h-4 w-4" />
                  <AlertTitle>Validation Passed</AlertTitle>
                  <AlertDescription>
                    The import data is valid and ready to be imported.
                  </AlertDescription>
                </Alert>
              )}
            </div>
          )}

          {/* Import Results */}
          {importState.importResults && (
            <div className="space-y-2">
              {importState.importResults.success && (
                <Alert>
                  <CheckCircle className="h-4 w-4" />
                  <AlertTitle>Import Successful</AlertTitle>
                  <AlertDescription>
                    Journey has been imported successfully.
                  </AlertDescription>
                </Alert>
              )}

              {importState.importResults.partialSuccess && (
                <Alert>
                  <Info className="h-4 w-4" />
                  <AlertTitle>Partial Success</AlertTitle>
                  <AlertDescription>
                    {importState.importResults.successCount} of {importState.importResults.totalProcessed} journeys imported successfully.
                  </AlertDescription>
                </Alert>
              )}

              {importState.importResults.errors && (
                <Alert variant="destructive">
                  <XCircle className="h-4 w-4" />
                  <AlertTitle>Import Errors</AlertTitle>
                  <AlertDescription>
                    <ul className="list-disc list-inside space-y-1">
                      {importState.importResults.errors.map((error: any, index: number) => (
                        <li key={index}>
                          {error.journeyName ? `${error.journeyName}: ` : ""}{error.error}
                        </li>
                      ))}
                    </ul>
                  </AlertDescription>
                </Alert>
              )}
            </div>
          )}
        </div>

        <DialogFooter>
          <Button
            variant="outline"
            onClick={resetImport}
            disabled={importState.isImporting}
          >
            Reset
          </Button>
          <Button
            onClick={handleImport}
            disabled={
              importState.isImporting || 
              !importState.importData.trim() || 
              (importState.validation && !importState.validation.isValid)
            }
            className="flex items-center gap-2"
          >
            {importState.isImporting ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin" />
                Importing...
              </>
            ) : (
              <>
                <Upload className="h-4 w-4" />
                Import
              </>
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// Main Export/Import Component
export function JourneyExportImport({ 
  journeys, 
  campaignId, 
  onJourneyImported, 
  onJourneysImported, 
  className 
}: JourneyExportImportProps) {
  return (
    <Card className={cn("", className)}>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Package className="h-5 w-5" />
          Export & Import
        </CardTitle>
        <CardDescription>
          Export journeys to various formats or import existing journey configurations
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="flex flex-col sm:flex-row gap-4">
          <ExportDialog
            journeys={journeys}
            campaignId={campaignId}
            trigger={
              <Button className="flex-1 flex items-center gap-2">
                <Download className="h-4 w-4" />
                Export Journeys
              </Button>
            }
          />
          
          <ImportDialog
            campaignId={campaignId}
            onJourneyImported={onJourneyImported}
            onJourneysImported={onJourneysImported}
            trigger={
              <Button variant="outline" className="flex-1 flex items-center gap-2">
                <Upload className="h-4 w-4" />
                Import Journey
              </Button>
            }
          />
        </div>

        {/* Quick Stats */}
        {journeys && journeys.length > 0 && (
          <div className="pt-4 border-t">
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div>
                <span className="font-medium">{journeys.length}</span>
                <span className="text-gray-500 ml-1">journeys available</span>
              </div>
              <div>
                <span className="font-medium">
                  {journeys.filter(j => j.status === 'active').length}
                </span>
                <span className="text-gray-500 ml-1">active journeys</span>
              </div>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  )
}