"use client"

import * as React from "react"
import { ChevronLeft, ChevronRight, AlertCircle, CheckCircle } from "lucide-react"

import { cn } from "@/lib/utils"
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"

export interface EnhancedTabItem {
  id: string
  label: string
  content: React.ReactNode
  icon?: React.ReactNode
  disabled?: boolean
  hasError?: boolean
  isCompleted?: boolean
  badge?: string | number | undefined
  description?: string
}

export interface EnhancedTabsProps {
  items: EnhancedTabItem[]
  defaultValue?: string
  value?: string
  onValueChange?: (value: string) => void
  variant?: "default" | "pills" | "cards" | "underline"
  size?: "sm" | "md" | "lg"
  orientation?: "horizontal" | "vertical"
  showNavigation?: boolean
  allowTabSwitching?: boolean
  className?: string
  tabsListClassName?: string
  tabsTriggerClassName?: string
  tabsContentClassName?: string
}

function EnhancedTabs({
  items,
  defaultValue,
  value,
  onValueChange,
  variant = "default",
  size = "md",
  orientation = "horizontal",
  showNavigation = false,
  allowTabSwitching = true,
  className,
  tabsListClassName,
  tabsTriggerClassName,
  tabsContentClassName,
}: EnhancedTabsProps) {
  const [currentValue, setCurrentValue] = React.useState(value || defaultValue || items[0]?.id || "")

  React.useEffect(() => {
    if (value) {
      setCurrentValue(value)
    }
  }, [value])

  const handleValueChange = (newValue: string) => {
    if (allowTabSwitching) {
      setCurrentValue(newValue)
      onValueChange?.(newValue)
    }
  }

  const currentIndex = items.findIndex(item => item.id === currentValue)
  const canGoPrevious = currentIndex > 0
  const canGoNext = currentIndex < items.length - 1

  const goToPrevious = () => {
    if (canGoPrevious && allowTabSwitching) {
      const previousItem = items[currentIndex - 1]
      if (previousItem) {
        handleValueChange(previousItem.id)
      }
    }
  }

  const goToNext = () => {
    if (canGoNext && allowTabSwitching) {
      const nextItem = items[currentIndex + 1]
      if (nextItem) {
        handleValueChange(nextItem.id)
      }
    }
  }

  const variantStyles = {
    default: "",
    pills: "bg-transparent p-0 gap-2",
    cards: "bg-transparent p-0 gap-1",
    underline: "bg-transparent border-b border-border p-0 gap-6",
  }

  const triggerVariantStyles = {
    default: "",
    pills: "bg-muted/50 hover:bg-muted rounded-full px-4 py-2 data-[state=active]:bg-primary data-[state=active]:text-primary-foreground",
    cards: "bg-background border border-border rounded-lg px-4 py-2 data-[state=active]:bg-primary data-[state=active]:text-primary-foreground shadow-sm",
    underline: "bg-transparent border-b-2 border-transparent rounded-none px-1 pb-2 data-[state=active]:border-primary data-[state=active]:bg-transparent",
  }

  const sizeStyles = {
    sm: "h-7 text-xs px-2 py-1",
    md: "h-9 text-sm px-3 py-1.5",
    lg: "h-11 text-base px-4 py-2",
  }

  const orientationClass = orientation === "vertical" ? "flex-col" : "flex-row"

  return (
    <div className={cn("w-full", className)}>
      <Tabs
        value={currentValue}
        onValueChange={handleValueChange}
        orientation={orientation}
        className={cn(
          "flex gap-4",
          orientation === "vertical" ? "flex-row" : "flex-col"
        )}
      >
        <TabsList
          className={cn(
            variantStyles[variant],
            orientation === "vertical" ? "flex-col h-auto w-fit" : "w-full",
            tabsListClassName
          )}
        >
          {items.map((item) => (
            <TabsTrigger
              key={item.id}
              value={item.id}
              disabled={item.disabled || (!allowTabSwitching && item.id !== currentValue)}
              className={cn(
                triggerVariantStyles[variant],
                sizeStyles[size],
                "relative flex items-center gap-2",
                item.hasError && "text-destructive",
                item.isCompleted && "text-green-600",
                tabsTriggerClassName
              )}
            >
              {/* Status Icons */}
              {item.hasError && (
                <AlertCircle className="w-4 h-4" />
              )}
              {item.isCompleted && !item.hasError && (
                <CheckCircle className="w-4 h-4" />
              )}
              
              {/* Custom Icon */}
              {item.icon && !item.hasError && !item.isCompleted && (
                <span className="w-4 h-4">{item.icon}</span>
              )}

              {/* Label */}
              <span className="flex-1 text-left">{item.label}</span>

              {/* Badge */}
              {item.badge && (
                <Badge
                  variant={item.hasError ? "destructive" : "secondary"}
                  className="ml-2"
                >
                  {item.badge}
                </Badge>
              )}

              {/* Description (vertical only) */}
              {orientation === "vertical" && item.description && (
                <div className="text-xs text-muted-foreground mt-1 text-left">
                  {item.description}
                </div>
              )}
            </TabsTrigger>
          ))}
        </TabsList>

        <div className={cn(
          "flex-1",
          orientation === "vertical" ? "min-h-0" : "min-w-0"
        )}>
          {items.map((item) => (
            <TabsContent
              key={item.id}
              value={item.id}
              className={cn(
                "outline-none focus-visible:ring-2 focus-visible:ring-ring rounded-md",
                tabsContentClassName
              )}
            >
              {/* Content Header */}
              <div className="mb-4">
                <div className="flex items-center gap-2 mb-2">
                  <h3 className="text-lg font-semibold">{item.label}</h3>
                  {item.hasError && (
                    <Badge variant="destructive" className="text-xs">
                      Error
                    </Badge>
                  )}
                  {item.isCompleted && (
                    <Badge variant="secondary" className="text-xs bg-green-100 text-green-800">
                      Completed
                    </Badge>
                  )}
                </div>
                {item.description && (
                  <p className="text-sm text-muted-foreground">
                    {item.description}
                  </p>
                )}
              </div>

              {/* Content */}
              <div className="mb-6">
                {item.content}
              </div>

              {/* Navigation Controls */}
              {showNavigation && (
                <div className="flex justify-between items-center pt-4 border-t">
                  <Button
                    type="button"
                    variant="outline"
                    onClick={goToPrevious}
                    disabled={!canGoPrevious}
                    className="flex items-center gap-2"
                  >
                    <ChevronLeft className="w-4 h-4" />
                    Previous
                  </Button>

                  <div className="flex items-center gap-2">
                    <span className="text-sm text-muted-foreground">
                      {currentIndex + 1} of {items.length}
                    </span>
                  </div>

                  <Button
                    type="button"
                    onClick={goToNext}
                    disabled={!canGoNext}
                    className="flex items-center gap-2"
                  >
                    Next
                    <ChevronRight className="w-4 h-4" />
                  </Button>
                </div>
              )}
            </TabsContent>
          ))}
        </div>
      </Tabs>
    </div>
  )
}

export { EnhancedTabs }