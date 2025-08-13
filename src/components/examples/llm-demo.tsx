'use client'

import React, { useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { Badge } from '@/components/ui/badge'
import { Progress } from '@/components/ui/progress'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Slider } from '@/components/ui/slider'
import { Switch } from '@/components/ui/switch'
import { Copy, Play, Square, RefreshCw } from 'lucide-react'
import { useLLM } from '@/hooks/useLLM'
import { llmClient } from '@/lib/llm-client'
import type { LLMApiRequest } from '@/types/api'

export default function LLMDemo() {
  const [prompt, setPrompt] = useState('')
  const [model, setModel] = useState('mock-gpt-3.5-turbo')
  const [temperature, setTemperature] = useState([0.7])
  const [maxTokens, setMaxTokens] = useState([500])
  const [useStream, setUseStream] = useState(false)
  const [showAdvanced, setShowAdvanced] = useState(false)
  const [batchVariations, setBatchVariations] = useState(false)
  const [variationCount, setVariationCount] = useState([3])
  const [batchResults, setBatchResults] = useState<string[]>([])
  const [isBatchLoading, setIsBatchLoading] = useState(false)

  const llm = useLLM({
    onSuccess: (response) => {
      console.log('LLM Success:', response)
    },
    onError: (error) => {
      console.error('LLM Error:', error)
    },
    onProgress: (chunk) => {
      console.log('Stream chunk:', chunk)
    }
  })

  const handleGenerate = async () => {
    if (!prompt.trim()) return

    if (batchVariations) {
      setIsBatchLoading(true)
      setBatchResults([])
      
      try {
        const results = await llmClient.generateMultipleVariations(
          prompt,
          variationCount[0],
          'copy'
        )
        setBatchResults(results)
      } catch (error) {
        console.error('Batch generation error:', error)
      } finally {
        setIsBatchLoading(false)
      }
      return
    }

    const request: LLMApiRequest = {
      prompt,
      model,
      temperature: temperature[0],
      maxTokens: maxTokens[0]
    }

    if (useStream) {
      llm.generateContentStream(request)
    } else {
      llm.generateContent(request)
    }
  }

  const handleCancel = () => {
    llm.cancel()
  }

  const handleReset = () => {
    llm.reset()
    setBatchResults([])
    setPrompt('')
  }

  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text)
    } catch (error) {
      console.error('Copy failed:', error)
    }
  }

  const presetPrompts = [
    {
      name: 'Marketing Copy',
      prompt: 'Create compelling marketing copy for a new productivity app that helps remote teams stay organized and collaborate effectively.'
    },
    {
      name: 'Email Subject Line',
      prompt: 'Generate an email subject line for a product launch announcement of eco-friendly packaging solutions.'
    },
    {
      name: 'Social Media Post',
      prompt: 'Write a LinkedIn post about the importance of sustainable business practices in modern companies.'
    },
    {
      name: 'Product Description',
      prompt: 'Create a product description for wireless noise-cancelling headphones with 30-hour battery life.'
    }
  ]

  return (
    <div className="max-w-4xl mx-auto space-y-6 p-6">
      <div className="text-center space-y-2">
        <h1 className="text-3xl font-bold">LLM API Demo</h1>
        <p className="text-muted-foreground">
          Demonstrate the placeholder LLM API with mock responses and realistic features
        </p>
      </div>

      <Tabs defaultValue="generate" className="space-y-4">
        <TabsList className="grid w-full grid-cols-3">
          <TabsTrigger value="generate">Generate Content</TabsTrigger>
          <TabsTrigger value="presets">Quick Presets</TabsTrigger>
          <TabsTrigger value="batch">Batch Generation</TabsTrigger>
        </TabsList>

        <TabsContent value="generate" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center justify-between">
                Content Generation
                <div className="flex items-center space-x-2">
                  <Switch
                    checked={showAdvanced}
                    onCheckedChange={setShowAdvanced}
                  />
                  <Label>Advanced Settings</Label>
                </div>
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="prompt">Prompt</Label>
                <Textarea
                  id="prompt"
                  placeholder="Enter your content generation prompt here..."
                  value={prompt}
                  onChange={(e) => setPrompt(e.target.value)}
                  rows={4}
                />
              </div>

              {showAdvanced && (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 p-4 border rounded-lg bg-muted/20">
                  <div className="space-y-2">
                    <Label>Model</Label>
                    <Select value={model} onValueChange={setModel}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="mock-gpt-3.5-turbo">GPT-3.5 Turbo (Mock)</SelectItem>
                        <SelectItem value="mock-gpt-4">GPT-4 (Mock)</SelectItem>
                        <SelectItem value="mock-claude-3">Claude-3 (Mock)</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>

                  <div className="space-y-2">
                    <Label>Temperature: {temperature[0]}</Label>
                    <Slider
                      value={temperature}
                      onValueChange={setTemperature}
                      max={2}
                      min={0}
                      step={0.1}
                      className="w-full"
                    />
                  </div>

                  <div className="space-y-2">
                    <Label>Max Tokens: {maxTokens[0]}</Label>
                    <Slider
                      value={maxTokens}
                      onValueChange={setMaxTokens}
                      max={2000}
                      min={50}
                      step={50}
                      className="w-full"
                    />
                  </div>

                  <div className="flex items-center space-x-2">
                    <Switch
                      checked={useStream}
                      onCheckedChange={setUseStream}
                    />
                    <Label>Streaming Response</Label>
                  </div>
                </div>
              )}

              <div className="flex space-x-2">
                <Button
                  onClick={handleGenerate}
                  disabled={llm.isLoading || !prompt.trim()}
                  className="flex-1"
                >
                  {llm.isLoading ? (
                    <>
                      <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                      {llm.progress.isStreaming ? 'Streaming...' : 'Generating...'}
                    </>
                  ) : (
                    <>
                      <Play className="w-4 h-4 mr-2" />
                      Generate
                    </>
                  )}
                </Button>

                {llm.isLoading && (
                  <Button onClick={handleCancel} variant="outline">
                    <Square className="w-4 h-4 mr-2" />
                    Cancel
                  </Button>
                )}

                <Button onClick={handleReset} variant="outline">
                  Reset
                </Button>
              </div>

              {/* Progress indicator for streaming */}
              {llm.progress.isStreaming && (
                <div className="space-y-2">
                  <div className="flex justify-between text-sm">
                    <span>Streaming response...</span>
                    <span>{llm.progress.tokenCount} tokens</span>
                  </div>
                  <Progress value={75} className="w-full" />
                </div>
              )}

              {/* Error display */}
              {llm.error && (
                <Alert variant="destructive">
                  <AlertDescription>
                    <strong>{llm.error.code}:</strong> {llm.error.message}
                    {llm.error.retryAfter && (
                      <span className="block mt-1 text-sm">
                        Retry after: {llm.error.retryAfter} seconds
                      </span>
                    )}
                  </AlertDescription>
                </Alert>
              )}

              {/* Response display */}
              {(llm.response || llm.progress.currentContent) && (
                <Card>
                  <CardHeader className="pb-3">
                    <div className="flex items-center justify-between">
                      <CardTitle className="text-lg">Generated Content</CardTitle>
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => copyToClipboard(
                          llm.response?.content || llm.progress.currentContent
                        )}
                      >
                        <Copy className="w-4 h-4" />
                      </Button>
                    </div>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-4">
                      <div className="p-4 bg-muted/20 rounded-lg">
                        <p className="whitespace-pre-wrap">
                          {llm.response?.content || llm.progress.currentContent}
                        </p>
                      </div>

                      {llm.response && (
                        <div className="grid grid-cols-2 md:grid-cols-4 gap-2 text-sm">
                          <div>
                            <Badge variant="outline">
                              Model: {llm.response.model}
                            </Badge>
                          </div>
                          <div>
                            <Badge variant="outline">
                              Tokens: {llm.response.usage.totalTokens}
                            </Badge>
                          </div>
                          <div>
                            <Badge variant="outline">
                              Time: {llm.response.metadata.processingTime}ms
                            </Badge>
                          </div>
                          <div>
                            <Badge variant="outline">
                              Status: {llm.response.finishReason}
                            </Badge>
                          </div>
                        </div>
                      )}
                    </div>
                  </CardContent>
                </Card>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="presets" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Quick Presets</CardTitle>
              <p className="text-sm text-muted-foreground">
                Try these pre-built prompts to test different content types
              </p>
            </CardHeader>
            <CardContent>
              <div className="grid gap-4">
                {presetPrompts.map((preset, index) => (
                  <div
                    key={index}
                    className="p-4 border rounded-lg hover:bg-muted/20 cursor-pointer transition-colors"
                    onClick={() => setPrompt(preset.prompt)}
                  >
                    <h3 className="font-medium mb-2">{preset.name}</h3>
                    <p className="text-sm text-muted-foreground">{preset.prompt}</p>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="batch" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Batch Generation</CardTitle>
              <p className="text-sm text-muted-foreground">
                Generate multiple variations of content at once
              </p>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="batch-prompt">Prompt</Label>
                <Textarea
                  id="batch-prompt"
                  placeholder="Enter your prompt for batch generation..."
                  value={prompt}
                  onChange={(e) => setPrompt(e.target.value)}
                  rows={3}
                />
              </div>

              <div className="space-y-2">
                <Label>Number of Variations: {variationCount[0]}</Label>
                <Slider
                  value={variationCount}
                  onValueChange={setVariationCount}
                  max={5}
                  min={2}
                  step={1}
                  className="w-full"
                />
              </div>

              <Button
                onClick={() => {
                  setBatchVariations(true)
                  handleGenerate()
                }}
                disabled={isBatchLoading || !prompt.trim()}
                className="w-full"
              >
                {isBatchLoading ? (
                  <>
                    <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                    Generating {variationCount[0]} variations...
                  </>
                ) : (
                  `Generate ${variationCount[0]} Variations`
                )}
              </Button>

              {batchResults.length > 0 && (
                <div className="space-y-4">
                  <h3 className="font-medium">Generated Variations</h3>
                  {batchResults.map((result, index) => (
                    <Card key={index}>
                      <CardHeader className="pb-3">
                        <div className="flex items-center justify-between">
                          <CardTitle className="text-base">
                            Variation {index + 1}
                          </CardTitle>
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => copyToClipboard(result)}
                          >
                            <Copy className="w-4 h-4" />
                          </Button>
                        </div>
                      </CardHeader>
                      <CardContent>
                        <p className="whitespace-pre-wrap text-sm">{result}</p>
                      </CardContent>
                    </Card>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}