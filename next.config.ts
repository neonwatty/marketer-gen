import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  eslint: {
    // Only check for linting errors during development
    ignoreDuringBuilds: true
  }
}

export default nextConfig
