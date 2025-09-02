import { Metadata } from 'next'
import Link from 'next/link'
import { getServerSession } from 'next-auth/next'

import { Plus } from 'lucide-react'

import { JourneyTemplateGallery } from '@/components/features/journey/JourneyTemplateGallery'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { prisma } from '@/lib/db'
import { authOptions } from '@/lib/auth'

export const metadata: Metadata = {
  title: 'Journeys | Dashboard',
  description: 'Manage your customer journeys and templates',
}

async function getUserJourneys() {
  try {
    const session = await getServerSession(authOptions)
    
    if (!session?.user?.id) {
      return []
    }
    
    const journeys = await prisma.journey.findMany({
      where: {
        deletedAt: null,
        campaign: {
          userId: session.user.id,
          deletedAt: null
        }
      },
      select: {
        id: true,
        stages: true,
        status: true,
        createdAt: true,
        updatedAt: true,
        campaign: {
          select: {
            id: true,
            name: true,
            brand: {
              select: {
                name: true
              }
            }
          }
        },
        _count: {
          select: {
            content: { where: { deletedAt: null } }
          }
        }
      },
      orderBy: { updatedAt: 'desc' }
    })

    return journeys
  } catch (error) {
    console.error('Error fetching user journeys:', error)
    return []
  }
}

function getStatusColor(status: string) {
  switch (status.toLowerCase()) {
    case 'active': return 'bg-green-100 text-green-800'
    case 'draft': return 'bg-gray-100 text-gray-800'
    case 'completed': return 'bg-blue-100 text-blue-800'
    case 'paused': return 'bg-yellow-100 text-yellow-800'
    case 'cancelled': return 'bg-red-100 text-red-800'
    default: return 'bg-gray-100 text-gray-800'
  }
}

/**
 * Journey listing page showing both existing journeys and templates
 */
export default async function JourneysPage() {
  const userJourneys = await getUserJourneys()

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Customer Journeys</h1>
          <p className="text-muted-foreground">
            Manage your active journeys and create new ones from templates
          </p>
        </div>
        <div className="flex items-center gap-3">
          <Button variant="outline" asChild>
            <Link href="/dashboard/journeys/templates" className="flex items-center gap-2">
              Browse Templates
            </Link>
          </Button>
          <Button asChild>
            <Link href="/dashboard/journeys/new" className="flex items-center gap-2">
              <Plus className="h-4 w-4" />
              Create Journey
            </Link>
          </Button>
        </div>
      </div>

      {/* Active Journeys */}
      {userJourneys.length > 0 && (
        <div className="space-y-4">
          <div>
            <h2 className="text-xl font-semibold">Your Active Journeys</h2>
            <p className="text-sm text-muted-foreground">
              Journeys currently running in your campaigns
            </p>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {userJourneys.map((journey: any) => {
              const stages = journey.stages?.stages || []
              const metadata = journey.stages?.metadata || {}
              const completedTasks = metadata.completedTasks || 0
              const totalTasks = metadata.totalTasks || 0
              const progressPercentage = totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0

              return (
                <Card key={journey.id} className="hover:shadow-md transition-shadow">
                  <CardHeader className="pb-3">
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <CardTitle className="text-base">
                          <Link 
                            href={`/dashboard/journeys/${journey.id}`}
                            className="text-blue-600 hover:text-blue-800 hover:underline"
                          >
                            {journey.campaign.name}
                          </Link>
                        </CardTitle>
                        <p className="text-xs text-muted-foreground mt-1">
                          {journey.campaign.brand?.name}
                        </p>
                      </div>
                      <Badge className={getStatusColor(journey.status)} variant="outline">
                        {journey.status}
                      </Badge>
                    </div>
                  </CardHeader>
                  <CardContent className="space-y-3">
                    <div className="flex justify-between text-sm">
                      <span>Progress:</span>
                      <span className="font-medium">{progressPercentage}%</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span>Stages:</span>
                      <span>{stages.length}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span>Content:</span>
                      <span>{journey._count.content}</span>
                    </div>
                    <div className="text-xs text-muted-foreground">
                      Updated: {new Date(journey.updatedAt).toLocaleDateString()}
                    </div>
                  </CardContent>
                </Card>
              )
            })}
          </div>
        </div>
      )}

      {/* Journey Templates */}
      <div className="space-y-4">
        <div>
          <h2 className="text-xl font-semibold">Journey Templates</h2>
          <p className="text-sm text-muted-foreground">
            Pre-built templates to quickly create new customer journeys
          </p>
        </div>
        
        <JourneyTemplateGallery />
      </div>
    </div>
  )
}