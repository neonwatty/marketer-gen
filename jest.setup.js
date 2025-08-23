import '@testing-library/jest-dom'

// Polyfill for Request/Response in Node.js environment
require('whatwg-fetch')

// Polyfill for Web Streams API in Node.js environment
if (!global.TransformStream) {
  const { ReadableStream, WritableStream, TransformStream } = require('node:stream/web')
  global.ReadableStream = ReadableStream
  global.WritableStream = WritableStream  
  global.TransformStream = TransformStream
}

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

// Mock NextResponse and NextRequest for all tests
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
  NextRequest: class MockNextRequest extends global.Request {
    constructor(input, init) {
      super(input, init)
      this.nextUrl = new URL(input)
      this.geo = {}
      this.ip = '127.0.0.1'
    }
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

// Mock next-auth globally to avoid ES module issues
jest.mock('next-auth', () => ({
  getServerSession: jest.fn(),
  NextAuth: jest.fn().mockReturnValue({
    handlers: { GET: jest.fn(), POST: jest.fn() },
    auth: jest.fn(),
    signIn: jest.fn(),
    signOut: jest.fn(),
  }),
  AuthError: class AuthError extends Error {
    constructor(message) {
      super(message)
      this.name = 'AuthError'
    }
  },
}))

// Mock next-auth/next
jest.mock('next-auth/next', () => ({
  withAuth: jest.fn((handler) => handler),
}))

// Mock auth lib
jest.mock('@/lib/auth', () => ({
  authOptions: {
    providers: [],
    adapter: {},
    session: { strategy: 'jwt' },
    callbacks: {
      jwt: jest.fn(),
      session: jest.fn(),
    },
  },
}))
