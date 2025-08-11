"use client"

import React, { useState } from 'react'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { BrandAssetUpload } from '@/components/ui/brand-asset-upload'
import { Badge } from '@/components/ui/badge'
import { Separator } from '@/components/ui/separator'
import { 
  Save, 
  Plus, 
  Trash2, 
  Edit3, 
  Palette, 
  FileText, 
  MessageSquare, 
  Users,
  Upload,
  CheckCircle2
} from 'lucide-react'
import { FileWithPreview } from '@/components/ui/file-upload'

interface BrandProfile {
  id?: string
  name: string
  description?: string
  logoUrl?: string
  primaryColor?: string
  secondaryColor?: string
  fontFamily?: string
  brandGuidelines?: BrandGuidelines
  voiceAndTone?: VoiceAndTone
  targetAudience?: TargetAudience
  brandAssets?: BrandAsset[]
}

interface BrandGuidelines {
  overview?: string
  logoUsage?: string[]
  colorPalette?: ColorPalette[]
  typography?: Typography[]
  imagery?: string
  doAndDonts?: DoAndDont[]
}

interface VoiceAndTone {
  overview?: string
  personality?: string[]
  toneAttributes?: ToneAttribute[]
  messagingPillars?: MessagingPillar[]
  examples?: MessageExample[]
}

interface TargetAudience {
  primaryAudience?: AudienceSegment[]
  secondaryAudience?: AudienceSegment[]
  personas?: Persona[]
}

interface ColorPalette {
  name: string
  hex: string
  usage: string
}

interface Typography {
  name: string
  fontFamily: string
  usage: string
}

interface DoAndDont {
  category: string
  do: string[]
  dont: string[]
}

interface ToneAttribute {
  attribute: string
  description: string
  scale: number // 1-10 scale
}

interface MessagingPillar {
  pillar: string
  description: string
  examples: string[]
}

interface MessageExample {
  context: string
  goodExample: string
  poorExample: string
  explanation: string
}

interface AudienceSegment {
  name: string
  demographics: string
  psychographics: string
  painPoints: string[]
  goals: string[]
}

interface Persona {
  name: string
  age: string
  occupation: string
  goals: string[]
  frustrations: string[]
  preferredChannels: string[]
}

interface BrandAsset {
  id: string
  name: string
  type: 'logo' | 'image' | 'document' | 'video'
  url: string
  category: string
  tags: string[]
  version: number
}

interface BrandProfileManagementProps {
  brandProfile?: BrandProfile
  onSave?: (profile: BrandProfile) => void
  onCancel?: () => void
  mode?: 'create' | 'edit'
}

export function BrandProfileManagement({ 
  brandProfile, 
  onSave, 
  onCancel, 
  mode = 'create' 
}: BrandProfileManagementProps) {
  const [profile, setProfile] = useState<BrandProfile>(brandProfile || {
    name: '',
    description: '',
    primaryColor: '#000000',
    secondaryColor: '#666666',
    fontFamily: 'Inter',
    brandGuidelines: {
      overview: '',
      logoUsage: [],
      colorPalette: [],
      typography: [],
      imagery: '',
      doAndDonts: []
    },
    voiceAndTone: {
      overview: '',
      personality: [],
      toneAttributes: [],
      messagingPillars: [],
      examples: []
    },
    targetAudience: {
      primaryAudience: [],
      secondaryAudience: [],
      personas: []
    },
    brandAssets: []
  })

  const [activeTab, setActiveTab] = useState('overview')
  const [uploadedAssets, setUploadedAssets] = useState<FileWithPreview[]>([])
  const [isUploading, setIsUploading] = useState(false)

  const handleSave = () => {
    onSave?.(profile)
  }

  const handleAssetUpload = async (files: FileWithPreview[]) => {
    setIsUploading(true)
    try {
      // In a real app, upload files to storage service and get URLs
      const newAssets: BrandAsset[] = files.map(file => ({
        id: file.id,
        name: file.name,
        type: file.type.startsWith('image/') ? 'image' : 
              file.type === 'application/pdf' ? 'document' :
              file.type.startsWith('video/') ? 'video' : 'image',
        url: file.preview || '#',
        category: 'general',
        tags: [],
        version: 1
      }))

      setProfile(prev => ({
        ...prev,
        brandAssets: [...(prev.brandAssets || []), ...newAssets]
      }))
    } catch (error) {
      console.error('Asset upload failed:', error)
    } finally {
      setIsUploading(false)
    }
  }

  const addColorToPalette = () => {
    const newColor: ColorPalette = {
      name: 'New Color',
      hex: '#000000',
      usage: 'Describe usage context'
    }
    setProfile(prev => ({
      ...prev,
      brandGuidelines: {
        ...prev.brandGuidelines,
        colorPalette: [...(prev.brandGuidelines?.colorPalette || []), newColor]
      }
    }))
  }

  const addMessagingPillar = () => {
    const newPillar: MessagingPillar = {
      pillar: 'New Pillar',
      description: 'Describe this messaging pillar',
      examples: ['Example message']
    }
    setProfile(prev => ({
      ...prev,
      voiceAndTone: {
        ...prev.voiceAndTone,
        messagingPillars: [...(prev.voiceAndTone?.messagingPillars || []), newPillar]
      }
    }))
  }

  const addPersona = () => {
    const newPersona: Persona = {
      name: 'New Persona',
      age: '25-35',
      occupation: 'Professional',
      goals: ['Goal 1'],
      frustrations: ['Frustration 1'],
      preferredChannels: ['Email', 'Social Media']
    }
    setProfile(prev => ({
      ...prev,
      targetAudience: {
        ...prev.targetAudience,
        personas: [...(prev.targetAudience?.personas || []), newPersona]
      }
    }))
  }

  return (
    <div className="max-w-6xl mx-auto p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">
            {mode === 'create' ? 'Create Brand Profile' : 'Edit Brand Profile'}
          </h1>
          <p className="text-muted-foreground mt-1">
            Define your brand guidelines, voice, and assets for consistent marketing
          </p>
        </div>
        <div className="flex gap-2">
          {onCancel && (
            <Button variant="outline" onClick={onCancel}>
              Cancel
            </Button>
          )}
          <Button onClick={handleSave} className="flex items-center gap-2">
            <Save className="size-4" />
            {mode === 'create' ? 'Create Profile' : 'Save Changes'}
          </Button>
        </div>
      </div>

      <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-6">
        <TabsList className="grid w-full grid-cols-5">
          <TabsTrigger value="overview" className="flex items-center gap-2">
            <Edit3 className="size-4" />
            Overview
          </TabsTrigger>
          <TabsTrigger value="guidelines" className="flex items-center gap-2">
            <Palette className="size-4" />
            Guidelines
          </TabsTrigger>
          <TabsTrigger value="voice" className="flex items-center gap-2">
            <MessageSquare className="size-4" />
            Voice & Tone
          </TabsTrigger>
          <TabsTrigger value="audience" className="flex items-center gap-2">
            <Users className="size-4" />
            Audience
          </TabsTrigger>
          <TabsTrigger value="assets" className="flex items-center gap-2">
            <Upload className="size-4" />
            Assets
          </TabsTrigger>
        </TabsList>

        {/* Overview Tab */}
        <TabsContent value="overview" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Edit3 className="size-5" />
                Basic Information
              </CardTitle>
              <CardDescription>
                Set up the fundamental details of your brand
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="brand-name">Brand Name *</Label>
                  <Input
                    id="brand-name"
                    value={profile.name}
                    onChange={(e) => setProfile(prev => ({ ...prev, name: e.target.value }))}
                    placeholder="Enter your brand name"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="font-family">Primary Font</Label>
                  <Select 
                    value={profile.fontFamily} 
                    onValueChange={(value) => setProfile(prev => ({ ...prev, fontFamily: value }))}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select font family" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="Inter">Inter</SelectItem>
                      <SelectItem value="Roboto">Roboto</SelectItem>
                      <SelectItem value="Open Sans">Open Sans</SelectItem>
                      <SelectItem value="Lato">Lato</SelectItem>
                      <SelectItem value="Montserrat">Montserrat</SelectItem>
                      <SelectItem value="Poppins">Poppins</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>

              <div className="space-y-2">
                <Label htmlFor="description">Brand Description</Label>
                <Textarea
                  id="description"
                  value={profile.description}
                  onChange={(e) => setProfile(prev => ({ ...prev, description: e.target.value }))}
                  placeholder="Describe your brand's mission, values, and what makes it unique"
                  rows={3}
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="primary-color">Primary Color</Label>
                  <div className="flex gap-2">
                    <Input
                      id="primary-color"
                      type="color"
                      value={profile.primaryColor}
                      onChange={(e) => setProfile(prev => ({ ...prev, primaryColor: e.target.value }))}
                      className="w-16 h-10 p-1"
                    />
                    <Input
                      value={profile.primaryColor}
                      onChange={(e) => setProfile(prev => ({ ...prev, primaryColor: e.target.value }))}
                      placeholder="#000000"
                      className="flex-1"
                    />
                  </div>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="secondary-color">Secondary Color</Label>
                  <div className="flex gap-2">
                    <Input
                      id="secondary-color"
                      type="color"
                      value={profile.secondaryColor}
                      onChange={(e) => setProfile(prev => ({ ...prev, secondaryColor: e.target.value }))}
                      className="w-16 h-10 p-1"
                    />
                    <Input
                      value={profile.secondaryColor}
                      onChange={(e) => setProfile(prev => ({ ...prev, secondaryColor: e.target.value }))}
                      placeholder="#666666"
                      className="flex-1"
                    />
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Brand Guidelines Tab */}
        <TabsContent value="guidelines" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Palette className="size-5" />
                Brand Guidelines
              </CardTitle>
              <CardDescription>
                Define your visual identity and usage guidelines
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="space-y-2">
                <Label htmlFor="guidelines-overview">Overview</Label>
                <Textarea
                  id="guidelines-overview"
                  value={profile.brandGuidelines?.overview}
                  onChange={(e) => setProfile(prev => ({
                    ...prev,
                    brandGuidelines: {
                      ...prev.brandGuidelines,
                      overview: e.target.value
                    }
                  }))}
                  placeholder="Provide an overview of your brand guidelines and visual identity"
                  rows={3}
                />
              </div>

              <Separator />

              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <h4 className="font-medium">Color Palette</h4>
                  <Button onClick={addColorToPalette} size="sm" variant="outline">
                    <Plus className="size-4 mr-2" />
                    Add Color
                  </Button>
                </div>
                {profile.brandGuidelines?.colorPalette?.map((color, index) => (
                  <div key={index} className="grid grid-cols-3 gap-4 p-4 border rounded-lg">
                    <div className="space-y-2">
                      <Label>Color Name</Label>
                      <Input
                        value={color.name}
                        onChange={(e) => {
                          const newPalette = [...(profile.brandGuidelines?.colorPalette || [])]
                          newPalette[index] = { ...color, name: e.target.value }
                          setProfile(prev => ({
                            ...prev,
                            brandGuidelines: {
                              ...prev.brandGuidelines,
                              colorPalette: newPalette
                            }
                          }))
                        }}
                      />
                    </div>
                    <div className="space-y-2">
                      <Label>Hex Code</Label>
                      <div className="flex gap-2">
                        <Input
                          type="color"
                          value={color.hex}
                          onChange={(e) => {
                            const newPalette = [...(profile.brandGuidelines?.colorPalette || [])]
                            newPalette[index] = { ...color, hex: e.target.value }
                            setProfile(prev => ({
                              ...prev,
                              brandGuidelines: {
                                ...prev.brandGuidelines,
                                colorPalette: newPalette
                              }
                            }))
                          }}
                          className="w-16 h-10 p-1"
                        />
                        <Input
                          value={color.hex}
                          onChange={(e) => {
                            const newPalette = [...(profile.brandGuidelines?.colorPalette || [])]
                            newPalette[index] = { ...color, hex: e.target.value }
                            setProfile(prev => ({
                              ...prev,
                              brandGuidelines: {
                                ...prev.brandGuidelines,
                                colorPalette: newPalette
                              }
                            }))
                          }}
                          className="flex-1"
                        />
                      </div>
                    </div>
                    <div className="space-y-2">
                      <Label>Usage</Label>
                      <Input
                        value={color.usage}
                        onChange={(e) => {
                          const newPalette = [...(profile.brandGuidelines?.colorPalette || [])]
                          newPalette[index] = { ...color, usage: e.target.value }
                          setProfile(prev => ({
                            ...prev,
                            brandGuidelines: {
                              ...prev.brandGuidelines,
                              colorPalette: newPalette
                            }
                          }))
                        }}
                        placeholder="When to use this color"
                      />
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Voice & Tone Tab */}
        <TabsContent value="voice" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <MessageSquare className="size-5" />
                Voice & Tone
              </CardTitle>
              <CardDescription>
                Define how your brand communicates and sounds
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="space-y-2">
                <Label htmlFor="voice-overview">Voice Overview</Label>
                <Textarea
                  id="voice-overview"
                  value={profile.voiceAndTone?.overview}
                  onChange={(e) => setProfile(prev => ({
                    ...prev,
                    voiceAndTone: {
                      ...prev.voiceAndTone,
                      overview: e.target.value
                    }
                  }))}
                  placeholder="Describe your brand's overall voice and communication style"
                  rows={3}
                />
              </div>

              <Separator />

              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <h4 className="font-medium">Messaging Pillars</h4>
                  <Button onClick={addMessagingPillar} size="sm" variant="outline">
                    <Plus className="size-4 mr-2" />
                    Add Pillar
                  </Button>
                </div>
                {profile.voiceAndTone?.messagingPillars?.map((pillar, index) => (
                  <div key={index} className="p-4 border rounded-lg space-y-4">
                    <div className="grid grid-cols-2 gap-4">
                      <div className="space-y-2">
                        <Label>Pillar Name</Label>
                        <Input
                          value={pillar.pillar}
                          onChange={(e) => {
                            const newPillars = [...(profile.voiceAndTone?.messagingPillars || [])]
                            newPillars[index] = { ...pillar, pillar: e.target.value }
                            setProfile(prev => ({
                              ...prev,
                              voiceAndTone: {
                                ...prev.voiceAndTone,
                                messagingPillars: newPillars
                              }
                            }))
                          }}
                          placeholder="e.g., Innovation, Trust, Excellence"
                        />
                      </div>
                      <div className="space-y-2">
                        <Label>Description</Label>
                        <Textarea
                          value={pillar.description}
                          onChange={(e) => {
                            const newPillars = [...(profile.voiceAndTone?.messagingPillars || [])]
                            newPillars[index] = { ...pillar, description: e.target.value }
                            setProfile(prev => ({
                              ...prev,
                              voiceAndTone: {
                                ...prev.voiceAndTone,
                                messagingPillars: newPillars
                              }
                            }))
                          }}
                          placeholder="Describe this messaging pillar"
                          rows={2}
                        />
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Target Audience Tab */}
        <TabsContent value="audience" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Users className="size-5" />
                Target Audience
              </CardTitle>
              <CardDescription>
                Define your target audience and customer personas
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <h4 className="font-medium">Customer Personas</h4>
                  <Button onClick={addPersona} size="sm" variant="outline">
                    <Plus className="size-4 mr-2" />
                    Add Persona
                  </Button>
                </div>
                {profile.targetAudience?.personas?.map((persona, index) => (
                  <div key={index} className="p-4 border rounded-lg space-y-4">
                    <div className="grid grid-cols-3 gap-4">
                      <div className="space-y-2">
                        <Label>Persona Name</Label>
                        <Input
                          value={persona.name}
                          onChange={(e) => {
                            const newPersonas = [...(profile.targetAudience?.personas || [])]
                            newPersonas[index] = { ...persona, name: e.target.value }
                            setProfile(prev => ({
                              ...prev,
                              targetAudience: {
                                ...prev.targetAudience,
                                personas: newPersonas
                              }
                            }))
                          }}
                          placeholder="e.g., Marketing Mary"
                        />
                      </div>
                      <div className="space-y-2">
                        <Label>Age Range</Label>
                        <Input
                          value={persona.age}
                          onChange={(e) => {
                            const newPersonas = [...(profile.targetAudience?.personas || [])]
                            newPersonas[index] = { ...persona, age: e.target.value }
                            setProfile(prev => ({
                              ...prev,
                              targetAudience: {
                                ...prev.targetAudience,
                                personas: newPersonas
                              }
                            }))
                          }}
                          placeholder="e.g., 25-35"
                        />
                      </div>
                      <div className="space-y-2">
                        <Label>Occupation</Label>
                        <Input
                          value={persona.occupation}
                          onChange={(e) => {
                            const newPersonas = [...(profile.targetAudience?.personas || [])]
                            newPersonas[index] = { ...persona, occupation: e.target.value }
                            setProfile(prev => ({
                              ...prev,
                              targetAudience: {
                                ...prev.targetAudience,
                                personas: newPersonas
                              }
                            }))
                          }}
                          placeholder="e.g., Marketing Manager"
                        />
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Assets Tab */}
        <TabsContent value="assets" className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Upload className="size-5" />
                Brand Assets
              </CardTitle>
              <CardDescription>
                Upload and manage your brand assets, logos, and marketing materials
              </CardDescription>
            </CardHeader>
            <CardContent>
              <BrandAssetUpload
                onFilesChange={setUploadedAssets}
                onUpload={handleAssetUpload}
                disabled={isUploading}
                cardWrapper={false}
                title=""
                description=""
              />
              
              {profile.brandAssets && profile.brandAssets.length > 0 && (
                <div className="mt-6 space-y-4">
                  <h4 className="font-medium">Uploaded Assets</h4>
                  <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                    {profile.brandAssets.map((asset) => (
                      <div key={asset.id} className="border rounded-lg p-3 space-y-2">
                        <div className="aspect-square bg-muted rounded flex items-center justify-center">
                          {asset.type === 'image' ? (
                            <img src={asset.url} alt={asset.name} className="w-full h-full object-cover rounded" />
                          ) : (
                            <FileText className="size-8 text-muted-foreground" />
                          )}
                        </div>
                        <div className="space-y-1">
                          <p className="text-sm font-medium truncate">{asset.name}</p>
                          <Badge variant="secondary" className="text-xs">
                            {asset.type}
                          </Badge>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}