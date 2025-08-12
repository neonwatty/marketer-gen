"use client"

import { useState, useCallback } from 'react'
import { ContentApprovalData } from '@/lib/approval-actions'
import { ApprovalAction } from '@/lib/approval-workflow'

interface UseApprovalWorkflowProps {
  userRole?: string
  userId?: string
  userName?: string
  onSuccess?: (contentId: string, action: ApprovalAction) => void
  onError?: (error: string) => void
}

interface UseApprovalWorkflowReturn {
  executeAction: (contentId: string, action: ApprovalAction, comment?: string) => Promise<boolean>
  bulkExecuteAction: (action: string, contentIds: string[], comment?: string) => Promise<boolean>
  getContentApprovalData: (contentId: string) => Promise<ContentApprovalData | null>
  isLoading: boolean
  error: string | null
}

export function useApprovalWorkflow({
  userRole,
  userId,
  userName,
  onSuccess,
  onError
}: UseApprovalWorkflowProps): UseApprovalWorkflowReturn {
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const executeAction = useCallback(async (
    contentId: string, 
    action: ApprovalAction, 
    comment?: string
  ): Promise<boolean> => {
    try {
      setIsLoading(true)
      setError(null)

      const response = await fetch(`/api/content/${contentId}/approve`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          action,
          comment,
          userId,
          userRole,
          userName
        })
      })

      const data = await response.json()

      if (!response.ok) {
        const errorMessage = data.error || `Failed to ${action} content`
        setError(errorMessage)
        onError?.(errorMessage)
        return false
      }

      onSuccess?.(contentId, action)
      return true

    } catch (err) {
      const errorMessage = `Network error while executing ${action}`
      setError(errorMessage)
      onError?.(errorMessage)
      return false
    } finally {
      setIsLoading(false)
    }
  }, [userId, userRole, userName, onSuccess, onError])

  const bulkExecuteAction = useCallback(async (
    action: string,
    contentIds: string[],
    comment?: string
  ): Promise<boolean> => {
    try {
      setIsLoading(true)
      setError(null)

      const response = await fetch('/api/content/approvals', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          action,
          contentIds,
          comment,
          userId,
          userRole,
          userName
        })
      })

      const data = await response.json()

      if (!response.ok) {
        const errorMessage = data.error || `Failed to execute bulk ${action}`
        setError(errorMessage)
        onError?.(errorMessage)
        return false
      }

      // Handle partial success/failure in bulk operations
      if (data.results?.failed?.length > 0) {
        const errorMessage = `${data.results.failed.length} items failed. ${data.results.approved} items succeeded.`
        setError(errorMessage)
        onError?.(errorMessage)
      }

      return true

    } catch (err) {
      const errorMessage = `Network error while executing bulk ${action}`
      setError(errorMessage)
      onError?.(errorMessage)
      return false
    } finally {
      setIsLoading(false)
    }
  }, [userId, userRole, userName, onError])

  const getContentApprovalData = useCallback(async (
    contentId: string
  ): Promise<ContentApprovalData | null> => {
    try {
      setIsLoading(true)
      setError(null)

      const params = new URLSearchParams()
      if (userRole) params.set('userRole', userRole)

      const response = await fetch(`/api/content/${contentId}/approve?${params}`)
      
      if (!response.ok) {
        if (response.status === 404) {
          setError('Content not found')
          return null
        }
        throw new Error('Failed to fetch content approval data')
      }

      const data = await response.json()
      return data

    } catch (err) {
      const errorMessage = 'Failed to load content approval data'
      setError(errorMessage)
      onError?.(errorMessage)
      return null
    } finally {
      setIsLoading(false)
    }
  }, [userRole, onError])

  return {
    executeAction,
    bulkExecuteAction,
    getContentApprovalData,
    isLoading,
    error
  }
}

export type { UseApprovalWorkflowProps, UseApprovalWorkflowReturn }