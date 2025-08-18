import '@testing-library/jest-dom'

// Polyfill for Request/Response in Node.js environment
require('whatwg-fetch')

// Also add undici for Node.js 18+ compatibility
if (!global.Request) {
  const { Request, Response, Headers, FormData } = require('undici')
  global.Request = Request
  
  // Extend Response to include static json method
  class ExtendedResponse extends Response {
    static json(data, init) {
      return new ExtendedResponse(JSON.stringify(data), {
        ...init,
        headers: {
          'content-type': 'application/json',
          ...init?.headers,
        },
      })
    }
  }
  
  global.Response = ExtendedResponse
  global.Headers = Headers
  global.FormData = FormData
}

// Mock Next.js Image component
jest.mock('next/image', () => ({
  __esModule: true,
  default: (props) => {
    // eslint-disable-next-line @next/next/no-img-element, jsx-a11y/alt-text
    return <img {...props} />
  },
}))

// Mock React
import React from 'react'
global.React = React

// Mock NextResponse for all tests
jest.mock('next/server', () => ({
  NextResponse: {
    json: (data, init) => {
      const response = new global.Response(JSON.stringify(data), {
        ...init,
        headers: {
          'content-type': 'application/json',
          ...init?.headers,
        },
      })
      // Add status property for compatibility
      response.status = init?.status || 200
      return response
    },
    redirect: jest.fn(),
    rewrite: jest.fn(),
  },
}))

// Mock URL.createObjectURL for file uploads
global.URL.createObjectURL = jest.fn(() => 'mocked-object-url')
global.URL.revokeObjectURL = jest.fn()

// Mock PDF and document parsing libraries to prevent file system access
jest.mock('pdf-parse', () => jest.fn((buffer) => {
  // Simulate real pdf-parse behavior - throw error for invalid PDF data
  const bufferString = buffer.toString('utf-8')
  if (!bufferString.startsWith('%PDF-')) {
    throw new Error('Invalid PDF structure')
  }
  return Promise.resolve({ text: '' })
}))
jest.mock('mammoth', () => ({
  extractRawText: jest.fn()
}))

// Mock hasPointerCapture for Radix UI Select component (only in DOM environment)
if (typeof Element !== 'undefined') {
  Element.prototype.hasPointerCapture = jest.fn(() => false)
  Element.prototype.setPointerCapture = jest.fn()
  Element.prototype.releasePointerCapture = jest.fn()
  
  // Mock scrollIntoView for jsdom compatibility
  Element.prototype.scrollIntoView = jest.fn()
}
