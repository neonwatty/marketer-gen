"use client"

import * as React from "react"
import { cn } from "@/lib/utils"
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
  CardAction,
} from "./card"
import { Button } from "./button"
import type { Asset, ContentResponse } from "@/types"

interface ContentCardProps extends React.ComponentProps<"div"> {
  title: string
  content: string
  description?: string
  metadata?: {
    type?: string
    createdAt?: Date
    author?: string
    tags?: string[]
    confidence?: number
  }
  actions?: {
    onEdit?: () => void
    onCopy?: () => void
    onDelete?: () => void
    onExport?: () => void
  }
  isLoading?: boolean
  isEmpty?: boolean
}

function ContentCard({
  className,
  title,
  content,
  description,
  metadata,
  actions,
  isLoading = false,
  isEmpty = false,
  ...props
}: ContentCardProps) {
  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(content)
      actions?.onCopy?.()
    } catch (error) {
      console.error("Failed to copy content:", error)
    }
  }

  if (isLoading) {
    return (
      <Card className={cn("animate-pulse", className)} {...props}>
        <CardHeader>
          <div className="h-5 bg-muted rounded w-3/4" />
          <div className="h-4 bg-muted rounded w-1/2" />
        </CardHeader>
        <CardContent>
          <div className="space-y-2">
            <div className="h-4 bg-muted rounded" />
            <div className="h-4 bg-muted rounded w-5/6" />
            <div className="h-4 bg-muted rounded w-3/4" />
          </div>
        </CardContent>
      </Card>
    )
  }

  if (isEmpty) {
    return (
      <Card className={cn("text-center py-12", className)} {...props}>
        <CardContent>
          <div className="text-muted-foreground">
            <svg
              className="mx-auto h-12 w-12 mb-4"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={1}
                d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
              />
            </svg>
            <p className="text-sm font-medium">No content available</p>
            <p className="text-xs mt-1">Generate some content to get started</p>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card className={cn("group transition-all hover:shadow-md", className)} {...props}>
      <CardHeader>
        <div className="flex items-start justify-between">
          <div className="flex-1 min-w-0">
            <CardTitle className="text-lg">{title}</CardTitle>
            {description && (
              <CardDescription className="mt-1">{description}</CardDescription>
            )}
          </div>
          {actions && (
            <CardAction>
              <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                {actions.onCopy && (
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={handleCopy}
                    className="h-8 w-8 p-0"
                  >
                    <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
                      />
                    </svg>
                    <span className="sr-only">Copy content</span>
                  </Button>
                )}
                {actions.onEdit && (
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={actions.onEdit}
                    className="h-8 w-8 p-0"
                  >
                    <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                      />
                    </svg>
                    <span className="sr-only">Edit content</span>
                  </Button>
                )}
                {actions.onDelete && (
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={actions.onDelete}
                    className="h-8 w-8 p-0 text-destructive hover:text-destructive"
                  >
                    <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                      />
                    </svg>
                    <span className="sr-only">Delete content</span>
                  </Button>
                )}
              </div>
            </CardAction>
          )}
        </div>
      </CardHeader>

      <CardContent>
        <div className="prose prose-sm max-w-none">
          <p className="text-sm leading-relaxed whitespace-pre-wrap">{content}</p>
        </div>
      </CardContent>

      {metadata && (
        <CardFooter className="border-t">
          <div className="flex items-center justify-between w-full text-xs text-muted-foreground">
            <div className="flex items-center gap-4">
              {metadata.type && (
                <span className="inline-flex items-center gap-1">
                  <span className="font-medium">Type:</span>
                  <span className="capitalize">{metadata.type}</span>
                </span>
              )}
              {metadata.author && (
                <span className="inline-flex items-center gap-1">
                  <span className="font-medium">Author:</span>
                  <span>{metadata.author}</span>
                </span>
              )}
              {metadata.confidence !== undefined && (
                <span className="inline-flex items-center gap-1">
                  <span className="font-medium">Confidence:</span>
                  <span>{Math.round(metadata.confidence * 100)}%</span>
                </span>
              )}
            </div>
            <div className="flex items-center gap-2">
              {metadata.tags && metadata.tags.length > 0 && (
                <div className="flex items-center gap-1">
                  {metadata.tags.slice(0, 3).map((tag) => (
                    <span
                      key={tag}
                      className="inline-flex items-center px-2 py-1 rounded-full text-xs bg-secondary text-secondary-foreground"
                    >
                      {tag}
                    </span>
                  ))}
                  {metadata.tags.length > 3 && (
                    <span className="text-muted-foreground">+{metadata.tags.length - 3}</span>
                  )}
                </div>
              )}
              {metadata.createdAt && (
                <time dateTime={metadata.createdAt.toISOString()}>
                  {metadata.createdAt.toLocaleDateString()}
                </time>
              )}
            </div>
          </div>
        </CardFooter>
      )}
    </Card>
  )
}

export { ContentCard }
export type { ContentCardProps }