import './globals.css'

import { Geist, Geist_Mono } from 'next/font/google'

import { AuthProvider } from '@/lib/auth/AuthContext'
import { SessionProvider } from '@/lib/auth/SessionProvider'

import type { Metadata } from 'next'

const geistSans = Geist({
  variable: '--font-geist-sans',
  subsets: ['latin'],
})

const geistMono = Geist_Mono({
  variable: '--font-geist-mono',
  subsets: ['latin'],
})

export const metadata: Metadata = {
  title: 'Marketer Gen | Marketing Campaign Builder',
  description: 'AI-powered marketing campaign builder with customer journey templates',
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en">
      <body className={`${geistSans.variable} ${geistMono.variable} antialiased`}>
        <SessionProvider>
          <AuthProvider>
            {children}
          </AuthProvider>
        </SessionProvider>
      </body>
    </html>
  )
}
