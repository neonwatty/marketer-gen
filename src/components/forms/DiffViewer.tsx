"use client"

import React from "react"
import * as Diff from "diff"
import { cn } from "@/lib/utils"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"

interface DiffViewerProps {
  oldContent: string
  newContent: string
  oldLabel?: string
  newLabel?: string
  viewType?: 'side-by-side' | 'unified'
  className?: string
}

interface DiffChange {
  type: 'add' | 'remove' | 'normal'
  content: string
  lineNumber?: number
}

export function DiffViewer({
  oldContent,
  newContent,
  oldLabel = "Previous Version",
  newLabel = "Current Version",
  viewType = 'side-by-side',
  className,
}: DiffViewerProps) {
  const generateDiff = () => {
    // Create word-level diff for better granularity
    const changes = Diff.diffWords(oldContent, newContent)
    return changes.map((change, index) => ({
      type: change.added ? 'add' as const : change.removed ? 'remove' as const : 'normal' as const,
      content: change.value,
      index,
    }))
  }

  const generateLineDiff = () => {
    const changes = Diff.diffLines(oldContent, newContent)
    let lineNumber = 1
    const result: Array<{ type: 'add' | 'remove' | 'normal', content: string, oldLineNumber?: number, newLineNumber?: number }> = []
    
    changes.forEach((change) => {
      const lines = change.value.split('\n').filter(line => line.length > 0)
      lines.forEach((line, index) => {
        if (change.added) {
          result.push({
            type: 'add',
            content: line,
            newLineNumber: lineNumber++,
          })
        } else if (change.removed) {
          result.push({
            type: 'remove',
            content: line,
            oldLineNumber: lineNumber++,
          })
        } else {
          result.push({
            type: 'normal',
            content: line,
            oldLineNumber: lineNumber,
            newLineNumber: lineNumber,
          })
          lineNumber++
        }
      })
    })
    
    return result
  }

  const renderWordDiff = () => {
    const changes = generateDiff()
    
    return (
      <div className="space-y-4">
        <div className="prose max-w-none">
          <div className="whitespace-pre-wrap font-mono text-sm leading-relaxed">
            {changes.map((change, index) => (
              <span
                key={index}
                className={cn(
                  "transition-colors",
                  change.type === 'add' && "bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-200",
                  change.type === 'remove' && "bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-200 line-through",
                  change.type === 'normal' && "text-foreground"
                )}
              >
                {change.content}
              </span>
            ))}
          </div>
        </div>
      </div>
    )
  }

  const renderSideBySide = () => {
    const lineDiff = generateLineDiff()
    
    return (
      <div className="grid grid-cols-2 gap-4">
        {/* Old version */}
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-red-600 dark:text-red-400">
              {oldLabel}
            </CardTitle>
          </CardHeader>
          <CardContent className="p-2">
            <div className="font-mono text-xs space-y-1 max-h-96 overflow-y-auto">
              {lineDiff
                .filter(line => line.type !== 'add')
                .map((line, index) => (
                  <div
                    key={index}
                    className={cn(
                      "px-2 py-1 rounded",
                      line.type === 'remove' && "bg-red-50 dark:bg-red-900/20 text-red-800 dark:text-red-200",
                      line.type === 'normal' && "text-foreground/70"
                    )}
                  >
                    <span className="text-muted-foreground mr-2 w-8 inline-block">
                      {line.oldLineNumber || ''}
                    </span>
                    <span>{line.content}</span>
                  </div>
                ))}
            </div>
          </CardContent>
        </Card>

        {/* New version */}
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-green-600 dark:text-green-400">
              {newLabel}
            </CardTitle>
          </CardHeader>
          <CardContent className="p-2">
            <div className="font-mono text-xs space-y-1 max-h-96 overflow-y-auto">
              {lineDiff
                .filter(line => line.type !== 'remove')
                .map((line, index) => (
                  <div
                    key={index}
                    className={cn(
                      "px-2 py-1 rounded",
                      line.type === 'add' && "bg-green-50 dark:bg-green-900/20 text-green-800 dark:text-green-200",
                      line.type === 'normal' && "text-foreground/70"
                    )}
                  >
                    <span className="text-muted-foreground mr-2 w-8 inline-block">
                      {line.newLineNumber || ''}
                    </span>
                    <span>{line.content}</span>
                  </div>
                ))}
            </div>
          </CardContent>
        </Card>
      </div>
    )
  }

  const renderUnified = () => {
    const lineDiff = generateLineDiff()
    
    return (
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-medium">
            Changes: {oldLabel} → {newLabel}
          </CardTitle>
        </CardHeader>
        <CardContent className="p-2">
          <div className="font-mono text-xs space-y-1 max-h-96 overflow-y-auto">
            {lineDiff.map((line, index) => (
              <div
                key={index}
                className={cn(
                  "px-2 py-1 rounded flex",
                  line.type === 'add' && "bg-green-50 dark:bg-green-900/20 text-green-800 dark:text-green-200",
                  line.type === 'remove' && "bg-red-50 dark:bg-red-900/20 text-red-800 dark:text-red-200",
                  line.type === 'normal' && "text-foreground/70"
                )}
              >
                <span className="text-muted-foreground mr-2 w-4 inline-block">
                  {line.type === 'add' ? '+' : line.type === 'remove' ? '-' : ' '}
                </span>
                <span className="text-muted-foreground mr-2 w-8 inline-block">
                  {line.oldLineNumber || line.newLineNumber || ''}
                </span>
                <span className="flex-1">{line.content}</span>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <div className={cn("space-y-4", className)}>
      {viewType === 'side-by-side' ? renderSideBySide() : renderUnified()}
      
      {/* Word-level diff summary */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-medium">Detailed Changes</CardTitle>
          <CardDescription className="text-xs">
            Word-level differences highlighting specific changes
          </CardDescription>
        </CardHeader>
        <CardContent>
          {renderWordDiff()}
        </CardContent>
      </Card>
    </div>
  )
}