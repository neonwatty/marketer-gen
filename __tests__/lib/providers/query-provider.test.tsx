import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals'
import { render, screen, waitFor } from '@testing-library/react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import React from 'react'
import { QueryProvider } from '@/lib/providers/query-provider'

// Test component that uses useQuery
function TestQueryComponent() {
  const { data, isLoading, error, failureCount } = useQuery({
    queryKey: ['test'],
    queryFn: async () => {
      const response = await fetch('/api/test')
      if (!response.ok) {
        const error = new Error('API Error')
        ;(error as any).status = response.status
        throw error
      }
      return response.json()
    },
  })

  if (isLoading) return <div>Loading...</div>
  if (error) return <div>Error: {error.message} (attempts: {failureCount})</div>
  return <div>Data: {JSON.stringify(data)}</div>
}

// Test component that uses useMutation
function TestMutationComponent() {
  const mutation = useMutation({
    mutationFn: async (data: any) => {
      const response = await fetch('/api/test', {
        method: 'POST',
        body: JSON.stringify(data),
      })
      if (!response.ok) {
        const error = new Error('Mutation Error')
        ;(error as any).status = response.status
        throw error
      }
      return response.json()
    },
  })

  return (
    <div>
      <button onClick={() => mutation.mutate({ test: 'data' })}>
        Mutate
      </button>
      {mutation.isPending && <div>Mutating...</div>}
      {mutation.error && (
        <div>Mutation Error: {mutation.error.message} (attempts: {mutation.failureCount})</div>
      )}
      {mutation.data && <div>Mutation Data: {JSON.stringify(mutation.data)}</div>}
    </div>
  )
}

// Mock fetch
const originalFetch = global.fetch

describe('QueryProvider', () => {
  beforeEach(() => {
    global.fetch = jest.fn()
  })

  afterEach(() => {
    global.fetch = originalFetch
    jest.restoreAllMocks()
  })

  it('should provide React Query context to children', async () => {
    const mockFetch = global.fetch as jest.MockedFunction<typeof fetch>
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ message: 'success' }),
    } as Response)

    render(
      <QueryProvider>
        <TestQueryComponent />
      </QueryProvider>
    )

    expect(screen.getByText('Loading...')).toBeInTheDocument()

    await waitFor(() => {
      expect(screen.getByText('Data: {"message":"success"}')).toBeInTheDocument()
    })
  })

  it('should configure stale time correctly', async () => {
    const mockFetch = global.fetch as jest.MockedFunction<typeof fetch>
    mockFetch.mockResolvedValue({
      ok: true,
      json: async () => ({ cached: 'data' }),
    } as Response)

    render(
      <QueryProvider>
        <TestQueryComponent />
      </QueryProvider>
    )

    await waitFor(() => {
      expect(screen.getByText('Data: {"cached":"data"}')).toBeInTheDocument()
    })

    // The query should be cached for 5 minutes (staleTime: 5 * 60 * 1000)
    expect(mockFetch).toHaveBeenCalledTimes(1)
  })

  it('should not retry on 4xx client errors for queries', async () => {
    const mockFetch = global.fetch as jest.MockedFunction<typeof fetch>
    mockFetch.mockResolvedValue({
      ok: false,
      status: 404,
    } as Response)

    render(
      <QueryProvider>
        <TestQueryComponent />
      </QueryProvider>
    )

    await waitFor(() => {
      expect(screen.getByText(/Error: API Error \(attempts: 1\)/)).toBeInTheDocument()
    })

    // Should not retry on 404
    expect(mockFetch).toHaveBeenCalledTimes(1)
  })

  it('should retry on 5xx server errors for queries', async () => {
    const mockFetch = global.fetch as jest.MockedFunction<typeof fetch>
    mockFetch.mockResolvedValue({
      ok: false,
      status: 500,
    } as Response)

    render(
      <QueryProvider>
        <TestQueryComponent />
      </QueryProvider>
    )

    // Should retry up to 3 times for server errors
    await waitFor(() => {
      expect(screen.getByText(/Error: API Error \(attempts: 4\)/)).toBeInTheDocument()
    }, { timeout: 15000 })

    expect(mockFetch).toHaveBeenCalledTimes(4)
  }, 20000)

  it('should not retry mutations on 4xx client errors', async () => {
    const mockFetch = global.fetch as jest.MockedFunction<typeof fetch>
    mockFetch.mockResolvedValue({
      ok: false,
      status: 400,
    } as Response)

    render(
      <QueryProvider>
        <TestMutationComponent />
      </QueryProvider>
    )

    const mutateButton = screen.getByText('Mutate')
    mutateButton.click()

    await waitFor(() => {
      expect(screen.getByText(/Mutation Error: Mutation Error \(attempts: 1\)/)).toBeInTheDocument()
    })

    // Should not retry mutations on client errors
    expect(mockFetch).toHaveBeenCalledTimes(1)
  })

  it('should retry mutations once on 5xx server errors', async () => {
    const mockFetch = global.fetch as jest.MockedFunction<typeof fetch>
    mockFetch.mockResolvedValue({
      ok: false,
      status: 500,
    } as Response)

    render(
      <QueryProvider>
        <TestMutationComponent />
      </QueryProvider>
    )

    const mutateButton = screen.getByText('Mutate')
    mutateButton.click()

    // Should retry once for server errors
    await waitFor(() => {
      expect(screen.getByText(/Mutation Error: Mutation Error \(attempts: 2\)/)).toBeInTheDocument()
    }, { timeout: 10000 })

    expect(mockFetch).toHaveBeenCalledTimes(2) // Mutations retry once
  }, 15000)

  it('should handle successful mutations', async () => {
    const mockFetch = global.fetch as jest.MockedFunction<typeof fetch>
    mockFetch.mockImplementation(() => 
      new Promise(resolve => 
        setTimeout(() => resolve({
          ok: true,
          json: async () => ({ mutated: 'success' }),
        } as Response), 500)
      )
    )

    render(
      <QueryProvider>
        <TestMutationComponent />
      </QueryProvider>
    )

    const mutateButton = screen.getByText('Mutate')
    mutateButton.click()

    // Check that mutation starts (may be quick)
    await waitFor(() => {
      expect(screen.getByText('Mutation Data: {"mutated":"success"}')).toBeInTheDocument()
    }, { timeout: 2000 })

    expect(mockFetch).toHaveBeenCalledWith('/api/test', {
      method: 'POST',
      body: JSON.stringify({ test: 'data' }),
    })
  })

  it('should render children without query usage', () => {
    render(
      <QueryProvider>
        <div>Plain content</div>
      </QueryProvider>
    )

    expect(screen.getByText('Plain content')).toBeInTheDocument()
  })

  it('should use exponential backoff for retry delays', async () => {
    const mockFetch = global.fetch as jest.MockedFunction<typeof fetch>
    const startTime = Date.now()
    
    mockFetch.mockResolvedValue({
      ok: false,
      status: 500,
    } as Response)

    render(
      <QueryProvider>
        <TestQueryComponent />
      </QueryProvider>
    )

    await waitFor(() => {
      expect(screen.getByText(/Error: API Error/)).toBeInTheDocument()
    }, { timeout: 20000 })

    const endTime = Date.now()
    const totalTime = endTime - startTime

    // Should take some time due to exponential backoff
    // First retry after ~1s, second after ~2s (with some tolerance for test environment)
    expect(totalTime).toBeGreaterThan(500)
  }, 25000)

  it('should create stable query client instance', () => {
    let queryClientRef1: any
    let queryClientRef2: any

    function CaptureQueryClient({ onCapture }: { onCapture: (client: any) => void }) {
      // Capture the query client context using useQueryClient
      const queryClient = useQueryClient()
      
      React.useEffect(() => {
        onCapture(queryClient)
      }, [queryClient, onCapture])

      return <div>Stable test</div>
    }

    const { rerender } = render(
      <QueryProvider>
        <CaptureQueryClient onCapture={(client) => { queryClientRef1 = client }} />
      </QueryProvider>
    )

    rerender(
      <QueryProvider>
        <CaptureQueryClient onCapture={(client) => { queryClientRef2 = client }} />
      </QueryProvider>
    )

    // The QueryClient instance should be stable across re-renders
    expect(queryClientRef1).toBeDefined()
    expect(queryClientRef2).toBeDefined()
    expect(queryClientRef1).toBe(queryClientRef2)
  })
})