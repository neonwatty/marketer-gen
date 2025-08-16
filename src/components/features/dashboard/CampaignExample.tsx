'use client'

import { useState } from 'react'
import { CampaignGrid } from './CampaignGrid'
import { type Campaign } from './CampaignCard'

// Mock data for demonstration
const mockCampaigns: Campaign[] = [
  {
    id: '1',
    title: 'Summer Product Launch',
    description: 'Comprehensive marketing campaign for our new summer collection featuring social media, email, and content marketing.',
    status: 'active',
    metrics: {
      engagementRate: 4.2,
      conversionRate: 2.8,
      contentPieces: 24,
      totalReach: 125000,
      activeUsers: 8900,
    },
    progress: 68,
    createdAt: new Date('2024-01-15'),
    updatedAt: new Date('2024-01-20'),
  },
  {
    id: '2',
    title: 'Q1 Newsletter Campaign',
    description: 'Monthly newsletter series targeting existing customers with product updates and exclusive offers.',
    status: 'completed',
    metrics: {
      engagementRate: 6.1,
      conversionRate: 4.5,
      contentPieces: 12,
      totalReach: 45000,
      activeUsers: 3200,
    },
    progress: 100,
    createdAt: new Date('2024-01-01'),
    updatedAt: new Date('2024-01-18'),
  },
  {
    id: '3',
    title: 'Brand Awareness Initiative',
    description: 'Multi-channel brand awareness campaign focusing on increasing visibility among target demographics.',
    status: 'draft',
    metrics: {
      engagementRate: 0,
      conversionRate: 0,
      contentPieces: 8,
    },
    progress: 15,
    createdAt: new Date('2024-01-22'),
    updatedAt: new Date('2024-01-22'),
  },
  {
    id: '4',
    title: 'Customer Retention Program',
    description: 'Ongoing loyalty program with personalized content and exclusive rewards for repeat customers.',
    status: 'paused',
    metrics: {
      engagementRate: 3.7,
      conversionRate: 5.2,
      contentPieces: 16,
      totalReach: 28000,
      activeUsers: 2100,
    },
    progress: 42,
    createdAt: new Date('2023-12-10'),
    updatedAt: new Date('2024-01-15'),
  },
  {
    id: '5',
    title: 'Social Media Boost',
    description: 'Intensive social media campaign with daily posts, stories, and engagement activities across platforms.',
    status: 'active',
    metrics: {
      engagementRate: 8.3,
      conversionRate: 1.9,
      contentPieces: 45,
      totalReach: 89000,
      activeUsers: 12500,
    },
    progress: 85,
    createdAt: new Date('2024-01-08'),
    updatedAt: new Date('2024-01-21'),
  },
  {
    id: '6',
    title: 'Holiday Retrospective',
    description: 'Analysis and follow-up campaign based on holiday season performance and customer feedback.',
    status: 'archived',
    metrics: {
      engagementRate: 5.4,
      conversionRate: 3.1,
      contentPieces: 18,
      totalReach: 67000,
      activeUsers: 4800,
    },
    progress: 100,
    createdAt: new Date('2023-11-20'),
    updatedAt: new Date('2024-01-05'),
  },
]

export function CampaignExample() {
  const [isLoading, setIsLoading] = useState(false)

  const handleView = (id: string) => {
    console.log('View campaign:', id)
  }

  const handleEdit = (id: string) => {
    console.log('Edit campaign:', id)
  }

  const handleDuplicate = (id: string) => {
    console.log('Duplicate campaign:', id)
  }

  const handleArchive = (id: string) => {
    console.log('Archive campaign:', id)
  }

  const toggleLoading = () => {
    setIsLoading(!isLoading)
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold">Campaign Overview</h2>
          <p className="text-muted-foreground">
            Manage and monitor your marketing campaigns
          </p>
        </div>
        <button
          onClick={toggleLoading}
          className="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700"
        >
          Toggle Loading State
        </button>
      </div>

      <CampaignGrid
        campaigns={mockCampaigns}
        isLoading={isLoading}
        onView={handleView}
        onEdit={handleEdit}
        onDuplicate={handleDuplicate}
        onArchive={handleArchive}
      />
    </div>
  )
}