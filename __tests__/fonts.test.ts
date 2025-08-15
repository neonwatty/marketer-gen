describe('Font Configuration', () => {
  it('should have font imports in layout', () => {
    // Read the layout file content to verify font imports exist
    const fs = require('fs')
    const path = require('path')
    const layoutPath = path.join(process.cwd(), 'src/app/layout.tsx')
    const layoutContent = fs.readFileSync(layoutPath, 'utf8')

    expect(layoutContent).toContain('Geist')
    expect(layoutContent).toContain('Geist_Mono')
    expect(layoutContent).toContain('next/font/google')
  })

  it('should configure font variables', () => {
    const fs = require('fs')
    const path = require('path')
    const layoutPath = path.join(process.cwd(), 'src/app/layout.tsx')
    const layoutContent = fs.readFileSync(layoutPath, 'utf8')

    expect(layoutContent).toContain('--font-geist-sans')
    expect(layoutContent).toContain('--font-geist-mono')
    expect(layoutContent).toContain("subsets: ['latin']")
  })
})
