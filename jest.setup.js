import '@testing-library/jest-dom'

// Polyfill for Request/Response in Node.js environment
require('whatwg-fetch')

// Also add undici for Node.js 18+ compatibility
if (!global.Request) {
  const { Request, Response, Headers, FormData } = require('undici')
  global.Request = Request
  global.Response = Response
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
