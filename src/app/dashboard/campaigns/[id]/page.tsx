import { Metadata } from 'next'
import { notFound } from 'next/navigation'

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { prisma } from '@/lib/database'

interface CampaignPageProps {
  params: Promise<{
    id: string
  }>
}

async function getCampaign(id: string) {
  try {
    const campaign = await prisma.campaign.findFirst({
      where: {
        id,
        deletedAt: null
      },
      select: {
        id: true,
        name: true,
        purpose: true,
        goals: true,
        status: true,
        startDate: true,
        endDate: true,
        createdAt: true,
        updatedAt: true,
        brand: {
          select: {
            id: true,
            name: true,
            description: true,
            tagline: true,
            mission: true,
            vision: true,
            industry: true,
          }
        },
        journeys: {
          select: {
            id: true,
            stages: true,
            status: true,
            createdAt: true,
            updatedAt: true,
            content: {
              select: {
                id: true,
                type: true,
                status: true,
                createdAt: true,
              },
              where: { deletedAt: null },
              take: 20,
              orderBy: { updatedAt: 'desc' }
            },
            _count: {
              select: {
                content: { where: { deletedAt: null } }
              }
            }
          },
          where: { deletedAt: null },
          orderBy: { updatedAt: 'desc' },
          take: 20
        },
        analytics: {
          select: {
            id: true,
            eventType: true,
            metrics: true,
            timestamp: true,
            source: true,
          },
          where: { deletedAt: null },
          orderBy: { timestamp: 'desc' },
          take: 50
        },
        _count: {
          select: {
            journeys: { where: { deletedAt: null } },
            analytics: { where: { deletedAt: null } }
          }
        }
      }
    })

    return campaign
  } catch (error) {
    console.error('Error fetching campaign:', error)
    return null
  }
}

export async function generateMetadata({ params }: CampaignPageProps): Promise<Metadata> {
  const { id } = await params
  const campaign = await getCampaign(id)
  
  return {
    title: `${campaign?.name || `Campaign ${id}`} | Dashboard`,
    description: `Campaign details and management for ${campaign?.name || `campaign ${id}`}`,
  }
}

/**
 * Individual campaign detail page with journey builder and analytics
 */
export default async function CampaignPage({ params }: CampaignPageProps) {
  const { id } = await params
  const campaign = await getCampaign(id)
  
  if (!campaign) {
    return (
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Campaign Not Found</h1>
            <p className="text-muted-foreground">
              The campaign with ID {id} could not be found or you don't have access to it.
            </p>
          </div>
        </div>
      </div>
    )
  }

  const getStatusColor = (status: string) => {
    switch (status.toLowerCase()) {
      case 'active': return 'bg-green-100 text-green-800'
      case 'draft': return 'bg-gray-100 text-gray-800'
      case 'completed': return 'bg-blue-100 text-blue-800'
      case 'paused': return 'bg-yellow-100 text-yellow-800'
      case 'archived': return 'bg-red-100 text-red-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">{campaign.name}</h1>
          <p className="text-muted-foreground">
            {campaign.purpose || 'Campaign details, journey builder, and performance analytics'}
          </p>
        </div>
        <Badge className={getStatusColor(campaign.status)}>
          {campaign.status.toUpperCase()}
        </Badge>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Campaign Overview */}
        <Card>
          <CardHeader>
            <CardTitle>Campaign Overview</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <p className="text-sm font-medium">Brand</p>
              <p className="text-sm text-muted-foreground">{campaign.brand?.name}</p>
            </div>
            <div>
              <p className="text-sm font-medium">Industry</p>
              <p className="text-sm text-muted-foreground">{campaign.brand?.industry}</p>
            </div>
            {campaign.brand?.tagline && (
              <div>
                <p className="text-sm font-medium">Tagline</p>
                <p className="text-sm text-muted-foreground">"{campaign.brand.tagline}"</p>
              </div>
            )}
            <div>
              <p className="text-sm font-medium">Created</p>
              <p className="text-sm text-muted-foreground">
                {new Date(campaign.createdAt).toLocaleDateString()}
              </p>
            </div>
            {campaign.startDate && (
              <div>
                <p className="text-sm font-medium">Start Date</p>
                <p className="text-sm text-muted-foreground">
                  {new Date(campaign.startDate).toLocaleDateString()}
                </p>
              </div>
            )}
            {campaign.endDate && (
              <div>
                <p className="text-sm font-medium">End Date</p>
                <p className="text-sm text-muted-foreground">
                  {new Date(campaign.endDate).toLocaleDateString()}
                </p>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Goals & Metrics */}
        <Card>
          <CardHeader>
            <CardTitle>Goals & Metrics</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {campaign.goals?.primary && (
              <div>
                <p className="text-sm font-medium">Primary Goal</p>
                <p className="text-sm text-muted-foreground">{campaign.goals.primary}</p>
              </div>
            )}
            {campaign.goals?.secondary && campaign.goals.secondary.length > 0 && (
              <div>
                <p className="text-sm font-medium">Secondary Goals</p>
                <ul className="text-sm text-muted-foreground space-y-1">
                  {campaign.goals.secondary.map((goal: string, index: number) => (
                    <li key={index}>• {goal}</li>
                  ))}
                </ul>
              </div>
            )}
            {campaign.goals?.metrics && (
              <div>
                <p className="text-sm font-medium">Key Metrics</p>
                <div className="text-sm text-muted-foreground space-y-1">
                  {Object.entries(campaign.goals.metrics).map(([key, value]) => (
                    <div key={key} className="flex justify-between">
                      <span>{key.replace(/_/g, ' ').toUpperCase()}:</span>
                      <span>{typeof value === 'number' ? value.toLocaleString() : String(value)}</span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Journey & Content Stats */}
        <Card>
          <CardHeader>
            <CardTitle>Activity</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex justify-between">
              <p className="text-sm font-medium">Journeys</p>
              <p className="text-sm text-muted-foreground">{campaign._count?.journeys || 0}</p>
            </div>
            <div className="flex justify-between">
              <p className="text-sm font-medium">Analytics Events</p>
              <p className="text-sm text-muted-foreground">{campaign._count?.analytics || 0}</p>
            </div>
            {campaign.journeys && campaign.journeys.length > 0 && (
              <div>
                <p className="text-sm font-medium">Recent Journeys</p>
                <div className="space-y-2">
                  {campaign.journeys.slice(0, 3).map((journey: any) => (
                    <div key={journey.id} className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground">Journey {journey.id.slice(-6)}</span>
                      <Badge variant="outline" className="text-xs">
                        {journey.status}
                      </Badge>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Recent Analytics */}
      {campaign.analytics && campaign.analytics.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle>Recent Analytics</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {campaign.analytics.slice(0, 5).map((analytic: any) => (
                <div key={analytic.id} className="flex items-center justify-between p-3 border rounded">
                  <div>
                    <p className="text-sm font-medium">{analytic.eventType}</p>
                    <p className="text-xs text-muted-foreground">
                      {new Date(analytic.timestamp).toLocaleDateString()} from {analytic.source}
                    </p>
                  </div>
                  <div className="text-right">
                    {Object.entries(analytic.metrics).map(([key, value]) => (
                      <div key={key} className="text-sm">
                        <span className="text-muted-foreground">{key}: </span>
                        <span className="font-medium">{String(value)}</span>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}