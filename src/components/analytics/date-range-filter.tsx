'use client'

import React, { useState, useCallback } from 'react'
import { Button } from '@/components/ui/button'
import { Calendar } from '@/components/ui/calendar'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Badge } from '@/components/ui/badge'
import { Separator } from '@/components/ui/separator'
import { Label } from '@/components/ui/label'
import {
  Calendar as CalendarIcon,
  ChevronDown,
  Clock,
  RotateCcw,
  Filter,
  X
} from 'lucide-react'
import { format, addDays, addWeeks, addMonths, addYears } from 'date-fns'

export interface DateRange {
  from: Date
  to: Date
  label?: string
}

interface DateRangeFilterProps {
  value?: DateRange
  onChange?: (range: DateRange) => void
  presets?: boolean
  customRanges?: boolean
  maxDate?: Date
  minDate?: Date
  className?: string
}

interface PresetRange {
  id: string
  label: string
  getValue: () => DateRange
  category: 'recent' | 'periods' | 'quarters'
}

const getPresetRanges = (): PresetRange[] => {
  const now = new Date()
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  
  const startOfDay = (date: Date) => new Date(date.getFullYear(), date.getMonth(), date.getDate())
  const endOfDay = (date: Date) => new Date(date.getFullYear(), date.getMonth(), date.getDate(), 23, 59, 59, 999)
  
  const startOfWeek = (date: Date) => {
    const d = new Date(date)
    const day = d.getDay()
    const diff = d.getDate() - day + (day === 0 ? -6 : 1) // Adjust when Sunday
    return new Date(d.setDate(diff))
  }
  
  const endOfWeek = (date: Date) => {
    const d = new Date(date)
    const day = d.getDay()
    const diff = d.getDate() - day + (day === 0 ? 0 : 7) // Adjust when Sunday
    return endOfDay(new Date(d.setDate(diff)))
  }
  
  const startOfMonth = (date: Date) => new Date(date.getFullYear(), date.getMonth(), 1)
  const endOfMonth = (date: Date) => new Date(date.getFullYear(), date.getMonth() + 1, 0, 23, 59, 59, 999)
  
  const startOfYear = (date: Date) => new Date(date.getFullYear(), 0, 1)
  const endOfYear = (date: Date) => new Date(date.getFullYear(), 11, 31, 23, 59, 59, 999)
  
  return [
    // Recent periods
    {
      id: 'today',
      label: 'Today',
      category: 'recent',
      getValue: () => ({
        from: today,
        to: endOfDay(now),
        label: 'Today'
      })
    },
    {
      id: 'yesterday',
      label: 'Yesterday',
      category: 'recent',
      getValue: () => {
        const yesterday = addDays(today, -1)
        return {
          from: yesterday,
          to: endOfDay(yesterday),
          label: 'Yesterday'
        }
      }
    },
    {
      id: 'last7days',
      label: 'Last 7 days',
      category: 'recent',
      getValue: () => ({
        from: addDays(today, -7),
        to: endOfDay(now),
        label: 'Last 7 days'
      })
    },
    {
      id: 'last14days',
      label: 'Last 14 days',
      category: 'recent',
      getValue: () => ({
        from: addDays(today, -14),
        to: endOfDay(now),
        label: 'Last 14 days'
      })
    },
    {
      id: 'last30days',
      label: 'Last 30 days',
      category: 'recent',
      getValue: () => ({
        from: addDays(today, -30),
        to: endOfDay(now),
        label: 'Last 30 days'
      })
    },
    {
      id: 'last90days',
      label: 'Last 90 days',
      category: 'recent',
      getValue: () => ({
        from: addDays(today, -90),
        to: endOfDay(now),
        label: 'Last 90 days'
      })
    },
    
    // Standard periods
    {
      id: 'thisweek',
      label: 'This week',
      category: 'periods',
      getValue: () => ({
        from: startOfWeek(now),
        to: endOfWeek(now),
        label: 'This week'
      })
    },
    {
      id: 'lastweek',
      label: 'Last week',
      category: 'periods',
      getValue: () => {
        const lastWeekStart = startOfWeek(addWeeks(now, -1))
        return {
          from: lastWeekStart,
          to: endOfWeek(lastWeekStart),
          label: 'Last week'
        }
      }
    },
    {
      id: 'thismonth',
      label: 'This month',
      category: 'periods',
      getValue: () => ({
        from: startOfMonth(now),
        to: endOfMonth(now),
        label: 'This month'
      })
    },
    {
      id: 'lastmonth',
      label: 'Last month',
      category: 'periods',
      getValue: () => {
        const lastMonthStart = startOfMonth(addMonths(now, -1))
        return {
          from: lastMonthStart,
          to: endOfMonth(lastMonthStart),
          label: 'Last month'
        }
      }
    },
    {
      id: 'thisyear',
      label: 'This year',
      category: 'periods',
      getValue: () => ({
        from: startOfYear(now),
        to: endOfYear(now),
        label: 'This year'
      })
    },
    {
      id: 'lastyear',
      label: 'Last year',
      category: 'periods',
      getValue: () => {
        const lastYearStart = startOfYear(addYears(now, -1))
        return {
          from: lastYearStart,
          to: endOfYear(lastYearStart),
          label: 'Last year'
        }
      }
    },
    
    // Quarters
    {
      id: 'q1',
      label: 'Q1 (Jan-Mar)',
      category: 'quarters',
      getValue: () => {
        const year = now.getFullYear()
        return {
          from: new Date(year, 0, 1),
          to: new Date(year, 2, 31),
          label: `Q1 ${year}`
        }
      }
    },
    {
      id: 'q2',
      label: 'Q2 (Apr-Jun)',
      category: 'quarters',
      getValue: () => {
        const year = now.getFullYear()
        return {
          from: new Date(year, 3, 1),
          to: new Date(year, 5, 30),
          label: `Q2 ${year}`
        }
      }
    },
    {
      id: 'q3',
      label: 'Q3 (Jul-Sep)',
      category: 'quarters',
      getValue: () => {
        const year = now.getFullYear()
        return {
          from: new Date(year, 6, 1),
          to: new Date(year, 8, 30),
          label: `Q3 ${year}`
        }
      }
    },
    {
      id: 'q4',
      label: 'Q4 (Oct-Dec)',
      category: 'quarters',
      getValue: () => {
        const year = now.getFullYear()
        return {
          from: new Date(year, 9, 1),
          to: new Date(year, 11, 31),
          label: `Q4 ${year}`
        }
      }
    }
  ]
}

export const DateRangeFilter: React.FC<DateRangeFilterProps> = ({
  value,
  onChange,
  presets = true,
  customRanges = true,
  maxDate = new Date(),
  minDate = addYears(new Date(), -2),
  className = ''
}) => {
  const [isOpen, setIsOpen] = useState(false)
  const [selectedPreset, setSelectedPreset] = useState<string>('')
  const [customRange, setCustomRange] = useState<{ from?: Date; to?: Date }>({})
  const [activeTab, setActiveTab] = useState<'presets' | 'custom'>('presets')
  
  const presetRanges = getPresetRanges()
  
  const handlePresetSelect = useCallback((preset: PresetRange) => {
    const range = preset.getValue()
    setSelectedPreset(preset.id)
    onChange?.(range)
    setIsOpen(false)
  }, [onChange])
  
  const handleCustomRangeApply = useCallback(() => {
    if (customRange.from && customRange.to) {
      const startOfDay = (date: Date) => new Date(date.getFullYear(), date.getMonth(), date.getDate())
      const endOfDay = (date: Date) => new Date(date.getFullYear(), date.getMonth(), date.getDate(), 23, 59, 59, 999)
      
      const range: DateRange = {
        from: startOfDay(customRange.from),
        to: endOfDay(customRange.to),
        label: `${format(customRange.from, 'MMM d')} - ${format(customRange.to, 'MMM d, yyyy')}`
      }
      onChange?.(range)
      setSelectedPreset('')
      setIsOpen(false)
    }
  }, [customRange, onChange])
  
  const handleReset = useCallback(() => {
    const defaultRange = presetRanges.find(p => p.id === 'last30days')?.getValue()
    if (defaultRange) {
      onChange?.(defaultRange)
      setSelectedPreset('last30days')
    }
    setCustomRange({})
  }, [onChange, presetRanges])
  
  const formatDisplayValue = useCallback((range?: DateRange) => {
    if (!range) return 'Select date range'
    
    if (range.label) {
      return range.label
    }
    
    const fromStr = format(range.from, 'MMM d, yyyy')
    const toStr = format(range.to, 'MMM d, yyyy')
    
    if (format(range.from, 'yyyy-MM-dd') === format(range.to, 'yyyy-MM-dd')) {
      return fromStr
    }
    
    return `${fromStr} - ${toStr}`
  }, [])
  
  const groupedPresets = presetRanges.reduce((groups, preset) => {
    const category = preset.category
    if (!groups[category]) {
      groups[category] = []
    }
    groups[category].push(preset)
    return groups
  }, {} as Record<string, PresetRange[]>)
  
  const getCategoryLabel = (category: string) => {
    switch (category) {
      case 'recent':
        return 'Recent'
      case 'periods':
        return 'Periods'
      case 'quarters':
        return 'Quarters'
      default:
        return category
    }
  }
  
  return (
    <div className={`flex items-center gap-2 ${className}`}>
      <Popover open={isOpen} onOpenChange={setIsOpen}>
        <PopoverTrigger asChild>
          <Button
            variant="outline"
            className="justify-start text-left font-normal min-w-[240px]"
          >
            <CalendarIcon className="mr-2 h-4 w-4" />
            {formatDisplayValue(value)}
            <ChevronDown className="ml-auto h-4 w-4 opacity-50" />
          </Button>
        </PopoverTrigger>
        <PopoverContent className="w-80 p-0" align="start">
          <div className="flex flex-col">
            {/* Tab Headers */}
            {presets && customRanges && (
              <div className="flex border-b">
                <Button
                  variant="ghost"
                  size="sm"
                  className={`flex-1 rounded-none border-b-2 border-transparent ${
                    activeTab === 'presets' ? 'border-primary bg-muted/50' : ''
                  }`}
                  onClick={() => setActiveTab('presets')}
                >
                  <Clock className="mr-2 h-4 w-4" />
                  Presets
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  className={`flex-1 rounded-none border-b-2 border-transparent ${
                    activeTab === 'custom' ? 'border-primary bg-muted/50' : ''
                  }`}
                  onClick={() => setActiveTab('custom')}
                >
                  <CalendarIcon className="mr-2 h-4 w-4" />
                  Custom
                </Button>
              </div>
            )}
            
            {/* Presets Tab */}
            {(presets && activeTab === 'presets') || (!customRanges && presets) && (
              <div className="p-4">
                <div className="space-y-4">
                  {Object.entries(groupedPresets).map(([category, categoryPresets]) => (
                    <div key={category}>
                      <Label className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
                        {getCategoryLabel(category)}
                      </Label>
                      <div className="mt-2 space-y-1">
                        {categoryPresets.map(preset => (
                          <Button
                            key={preset.id}
                            variant="ghost"
                            size="sm"
                            className={`w-full justify-start font-normal ${
                              selectedPreset === preset.id ? 'bg-muted' : ''
                            }`}
                            onClick={() => handlePresetSelect(preset)}
                          >
                            {preset.label}
                            {selectedPreset === preset.id && (
                              <Badge variant="secondary" className="ml-auto text-xs">
                                Selected
                              </Badge>
                            )}
                          </Button>
                        ))}
                      </div>
                      {category !== 'quarters' && <Separator className="mt-3" />}
                    </div>
                  ))}
                </div>
              </div>
            )}
            
            {/* Custom Tab */}
            {(customRanges && activeTab === 'custom') || (!presets && customRanges) && (
              <div className="p-4">
                <div className="space-y-4">
                  <div>
                    <Label className="text-sm font-medium mb-2 block">From Date</Label>
                    <Calendar
                      mode="single"
                      selected={customRange.from}
                      onSelect={(date) => setCustomRange(prev => ({ ...prev, from: date }))}
                      disabled={(date) => 
                        date > maxDate || 
                        date < minDate ||
                        (customRange.to && date > customRange.to)
                      }
                      initialFocus
                    />
                  </div>
                  
                  <div>
                    <Label className="text-sm font-medium mb-2 block">To Date</Label>
                    <Calendar
                      mode="single"
                      selected={customRange.to}
                      onSelect={(date) => setCustomRange(prev => ({ ...prev, to: date }))}
                      disabled={(date) => 
                        date > maxDate || 
                        date < minDate ||
                        (customRange.from && date < customRange.from)
                      }
                    />
                  </div>
                  
                  <div className="flex gap-2">
                    <Button
                      onClick={handleCustomRangeApply}
                      disabled={!customRange.from || !customRange.to}
                      className="flex-1"
                    >
                      Apply Range
                    </Button>
                    <Button
                      variant="outline"
                      onClick={() => setCustomRange({})}
                      disabled={!customRange.from && !customRange.to}
                    >
                      <X className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              </div>
            )}
            
            {/* Footer Actions */}
            <div className="flex items-center justify-between p-4 border-t bg-muted/50">
              <Button
                variant="ghost"
                size="sm"
                onClick={handleReset}
                className="text-muted-foreground"
              >
                <RotateCcw className="mr-2 h-4 w-4" />
                Reset to Default
              </Button>
              
              <div className="text-xs text-muted-foreground">
                {value && (
                  <>
                    {Math.ceil((value.to.getTime() - value.from.getTime()) / (1000 * 60 * 60 * 24))} days selected
                  </>
                )}
              </div>
            </div>
          </div>
        </PopoverContent>
      </Popover>
      
      {/* Quick Actions */}
      {value && (
        <Button
          variant="ghost"
          size="sm"
          onClick={handleReset}
          className="text-muted-foreground"
        >
          <X className="h-4 w-4" />
        </Button>
      )}
    </div>
  )
}

// Comparison date range filter for A/B testing periods
interface ComparisonDateRangeFilterProps extends DateRangeFilterProps {
  comparisonValue?: DateRange
  onComparisonChange?: (range?: DateRange) => void
  enableComparison?: boolean
}

export const ComparisonDateRangeFilter: React.FC<ComparisonDateRangeFilterProps> = ({
  value,
  onChange,
  comparisonValue,
  onComparisonChange,
  enableComparison = true,
  ...props
}) => {
  const [showComparison, setShowComparison] = useState(false)
  
  const handleToggleComparison = useCallback(() => {
    const newShowComparison = !showComparison
    setShowComparison(newShowComparison)
    
    if (!newShowComparison) {
      onComparisonChange?.(undefined)
    } else if (value && !comparisonValue) {
      // Auto-generate comparison period (same duration, shifted back)
      const duration = value.to.getTime() - value.from.getTime()
      const comparisonTo = addDays(value.from, -1)
      const comparisonFrom = new Date(comparisonTo.getTime() - duration)
      
      onComparisonChange?.({
        from: comparisonFrom,
        to: comparisonTo,
        label: `Compare: ${format(comparisonFrom, 'MMM d')} - ${format(comparisonTo, 'MMM d')}`
      })
    }
  }, [showComparison, value, comparisonValue, onComparisonChange])
  
  return (
    <div className="flex items-center gap-2">
      <div className="flex items-center gap-2">
        <Label className="text-sm font-medium text-muted-foreground">Period:</Label>
        <DateRangeFilter
          value={value}
          onChange={onChange}
          {...props}
        />
      </div>
      
      {enableComparison && (
        <>
          <div className="flex items-center gap-2">
            <Button
              variant={showComparison ? 'default' : 'outline'}
              size="sm"
              onClick={handleToggleComparison}
            >
              <Filter className="mr-2 h-4 w-4" />
              Compare
            </Button>
          </div>
          
          {showComparison && (
            <div className="flex items-center gap-2">
              <Label className="text-sm font-medium text-muted-foreground">vs:</Label>
              <DateRangeFilter
                value={comparisonValue}
                onChange={onComparisonChange}
                {...props}
              />
            </div>
          )}
        </>
      )}
    </div>
  )
}

export default DateRangeFilter