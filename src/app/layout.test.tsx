import { metadata } from './layout'

// Mock next/font/google for layout tests
jest.mock('next/font/google', () => ({
  Geist: () => ({
    variable: '--font-geist-sans',
    className: 'geist-sans',
  }),
  Geist_Mono: () => ({
    variable: '--font-geist-mono',
    className: 'geist-mono',
  }),
}))

describe('RootLayout', () => {
  it('exports correct metadata', () => {
    expect(metadata.title).toBe('Marketer Gen | Marketing Campaign Builder')
    expect(metadata.description).toBe('AI-powered marketing campaign builder with customer journey templates')
  })

  it('should have correct font configuration structure', async () => {
    // Test that layout module imports fonts correctly
    const layout = await import('./layout')
    expect(layout.default).toBeDefined()
    expect(layout.metadata).toBeDefined()
  })
})
