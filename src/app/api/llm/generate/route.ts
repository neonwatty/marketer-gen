import { NextRequest, NextResponse } from 'next/server'
import { llmService, LLMError } from '@/lib/llm-service'
import type { LLMApiRequest, LLMApiResponse } from '@/types/api'

export async function POST(request: NextRequest) {
  try {
    const body: LLMApiRequest = await request.json()
    
    // Extract client IP for rate limiting
    const clientIp = request.headers.get('x-forwarded-for') || 
                    request.headers.get('x-real-ip') || 
                    'unknown'

    // Generate content using the service
    const response = await llmService.generateContentWithRetry(
      {
        prompt: body.prompt,
        model: body.model,
        maxTokens: body.maxTokens,
        temperature: body.temperature,
        systemPrompt: body.systemPrompt,
        context: body.context
      },
      clientIp
    )

    // Transform response for API
    const apiResponse: LLMApiResponse = {
      ...response,
      metadata: {
        ...response.metadata,
        timestamp: response.metadata.timestamp.toISOString()
      }
    }

    return NextResponse.json({
      success: true,
      data: apiResponse
    })

  } catch (error) {
    console.error('LLM API Error:', error)

    if (error instanceof LLMError) {
      const statusCode = getStatusCodeForError(error.type)
      
      return NextResponse.json({
        success: false,
        error: error.code,
        message: error.message,
        ...(error.retryAfter && { retryAfter: error.retryAfter })
      }, { 
        status: statusCode,
        headers: error.retryAfter ? {
          'Retry-After': error.retryAfter.toString()
        } : undefined
      })
    }

    // Handle unexpected errors
    return NextResponse.json({
      success: false,
      error: 'INTERNAL_SERVER_ERROR',
      message: 'An unexpected error occurred while processing your request.'
    }, { status: 500 })
  }
}

// Stream endpoint for real-time generation
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const prompt = searchParams.get('prompt')
    
    if (!prompt) {
      return NextResponse.json({
        success: false,
        error: 'MISSING_PROMPT',
        message: 'Prompt parameter is required for streaming.'
      }, { status: 400 })
    }

    const clientIp = request.headers.get('x-forwarded-for') || 
                    request.headers.get('x-real-ip') || 
                    'unknown'

    // Create a readable stream
    const stream = new ReadableStream({
      async start(controller) {
        try {
          const streamGenerator = llmService.generateContentStream({
            prompt,
            model: searchParams.get('model') || undefined,
            maxTokens: searchParams.get('maxTokens') ? 
              parseInt(searchParams.get('maxTokens')!) : undefined,
            temperature: searchParams.get('temperature') ? 
              parseFloat(searchParams.get('temperature')!) : undefined,
            context: searchParams.get('context')?.split(',') || undefined
          }, clientIp)

          for await (const chunk of streamGenerator) {
            const data = JSON.stringify(chunk) + '\n'
            controller.enqueue(new TextEncoder().encode(data))
          }
          
          controller.close()
        } catch (error) {
          console.error('Stream error:', error)
          
          if (error instanceof LLMError) {
            const errorData = JSON.stringify({
              error: error.code,
              message: error.message,
              type: error.type
            }) + '\n'
            controller.enqueue(new TextEncoder().encode(errorData))
          } else {
            const errorData = JSON.stringify({
              error: 'STREAM_ERROR',
              message: 'An error occurred during streaming.'
            }) + '\n'
            controller.enqueue(new TextEncoder().encode(errorData))
          }
          
          controller.close()
        }
      }
    })

    return new Response(stream, {
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive'
      }
    })

  } catch (error) {
    console.error('Stream setup error:', error)
    
    return NextResponse.json({
      success: false,
      error: 'STREAM_SETUP_ERROR',
      message: 'Failed to initialize streaming response.'
    }, { status: 500 })
  }
}

function getStatusCodeForError(errorType: string): number {
  switch (errorType) {
    case 'rate_limit':
      return 429
    case 'invalid_request':
      return 400
    case 'auth_error':
      return 401
    case 'server_error':
    default:
      return 500
  }
}