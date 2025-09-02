import { NextRequest, NextResponse } from 'next/server'
import { cookies } from 'next/headers'

export async function GET(request: NextRequest) {
  const cookieStore = await cookies()
  
  // Clear all NextAuth cookies
  const response = NextResponse.json({ message: 'Session cleared' })
  
  response.cookies.delete('next-auth.session-token')
  response.cookies.delete('next-auth.csrf-token')
  response.cookies.delete('next-auth.callback-url')
  response.cookies.delete('__Secure-next-auth.session-token')
  response.cookies.delete('__Secure-next-auth.csrf-token')
  response.cookies.delete('__Secure-next-auth.callback-url')
  
  return response
}