import { type CampaignSummaryData } from '@/components/features/campaigns/CampaignSummary'
import { type Campaign } from '@/components/features/dashboard/CampaignCard'

import { openAIService } from './openai-service'

export interface CampaignSummaryRequest {
  campaign: Campaign
  includeProjections?: boolean
  includeStakeholderBrief?: boolean
  customPrompt?: string
}

export interface CampaignSummaryResponse extends CampaignSummaryData {
  generatedAt: Date
  campaignId: string
}

/**
 * Service for generating AI-powered campaign summaries and strategic plans
 */
export class CampaignSummaryService {
  constructor(private aiService = openAIService.instance) {}

  /**
   * Generate comprehensive campaign summary with strategic insights
   */
  async generateCampaignSummary(request: CampaignSummaryRequest): Promise<CampaignSummaryResponse> {
    const { campaign, includeProjections = true, includeStakeholderBrief = true, customPrompt } = request

    const systemPrompt = this.buildSystemPrompt(includeProjections, includeStakeholderBrief)
    const userPrompt = customPrompt || this.buildUserPrompt(campaign)

    try {
      const result = await this.aiService.generateText({
        system: systemPrompt,
        prompt: userPrompt,
        temperature: 0.7,
        maxTokens: 3000
      })

      const summaryData = this.parseAIResponse(result.text)
      
      return {
        ...summaryData,
        generatedAt: new Date(),
        campaignId: campaign.id
      }
    } catch (error) {
      console.error('Failed to generate campaign summary:', error)
      throw new Error('Failed to generate campaign summary. Please try again.')
    }
  }

  /**
   * Generate executive summary only (lighter version)
   */
  async generateExecutiveSummary(campaign: Campaign): Promise<string> {
    const systemPrompt = `You are a marketing strategy expert. Generate a concise executive summary for a marketing campaign. Focus on key objectives, target audience, main strategies, and expected outcomes. Keep it under 200 words.`
    
    const userPrompt = `Campaign: ${campaign.title}
Description: ${campaign.description}
Status: ${campaign.status}
Progress: ${campaign.progress}%
Engagement Rate: ${campaign.metrics.engagementRate}%
Conversion Rate: ${campaign.metrics.conversionRate}%
Content Pieces: ${campaign.metrics.contentPieces}`

    try {
      const result = await this.aiService.generateText({
        system: systemPrompt,
        prompt: userPrompt,
        temperature: 0.6,
        maxTokens: 300
      })

      return result.text
    } catch (error) {
      console.error('Failed to generate executive summary:', error)
      throw new Error('Failed to generate executive summary. Please try again.')
    }
  }

  /**
   * Generate performance projections based on current metrics
   */
  async generatePerformanceProjections(campaign: Campaign): Promise<CampaignSummaryData['performanceProjections']> {
    const systemPrompt = `You are a data analyst specializing in marketing performance. Based on current campaign metrics, generate realistic performance projections. Return only a JSON object with: estimatedReach (number), expectedEngagement (number as percentage), targetConversions (number), projectedROI (string with percentage).`
    
    const userPrompt = `Current metrics:
- Engagement Rate: ${campaign.metrics.engagementRate}%
- Conversion Rate: ${campaign.metrics.conversionRate}%
- Content Pieces: ${campaign.metrics.contentPieces}
- Progress: ${campaign.progress}%
- Total Reach: ${campaign.metrics.totalReach || 'Unknown'}
- Active Users: ${campaign.metrics.activeUsers || 'Unknown'}`

    try {
      const result = await this.aiService.generateText({
        system: systemPrompt,
        prompt: userPrompt,
        temperature: 0.5,
        maxTokens: 200
      })

      return JSON.parse(result.text)
    } catch (error) {
      console.error('Failed to generate performance projections:', error)
      // Return fallback projections
      return this.getFallbackProjections(campaign)
    }
  }

  private buildSystemPrompt(includeProjections: boolean, includeStakeholderBrief: boolean): string {
    return `You are a senior marketing strategist and consultant. Generate a comprehensive campaign summary that includes:

1. Executive Summary: Concise overview of the campaign's purpose, strategy, and expected impact
2. Strategic Rationale: Detailed explanation of why this approach was chosen, target audience insights, and competitive positioning
3. Content Overview: Analysis of content strategy, distribution channels, and content types
4. Timeline: Realistic project phases with deliverables and duration estimates
${includeProjections ? '5. Performance Projections: Data-driven forecasts for reach, engagement, conversions, and ROI' : ''}
${includeStakeholderBrief ? '6. Stakeholder Brief: Key messages, success metrics, and risk assessment' : ''}

Return the response as a JSON object with the following structure:
{
  "executiveSummary": "string",
  "strategicRationale": "string",
  "contentOverview": {
    "totalPieces": number,
    "byType": {"blog": number, "social": number, "email": number, "video": number},
    "channels": ["string array"]
  },
  "timeline": [
    {
      "phase": "string",
      "description": "string", 
      "duration": "string",
      "deliverables": ["string array"]
    }
  ],
  ${includeProjections ? `"performanceProjections": {
    "estimatedReach": number,
    "expectedEngagement": number,
    "targetConversions": number,
    "projectedROI": "string"
  },` : ''}
  ${includeStakeholderBrief ? `"stakeholderBrief": {
    "keyMessages": ["string array"],
    "successMetrics": ["string array"],
    "risksAndMitigation": ["string array"]
  }` : ''}
}

Make the content professional, actionable, and data-driven. Use industry best practices and realistic projections.`
  }

  private buildUserPrompt(campaign: Campaign): string {
    return `Generate a comprehensive summary for this marketing campaign:

Campaign Details:
- Name: ${campaign.title}
- Description: ${campaign.description}
- Status: ${campaign.status}
- Current Progress: ${campaign.progress}%
- Created: ${campaign.createdAt.toLocaleDateString()}
- Last Updated: ${campaign.updatedAt.toLocaleDateString()}

Current Metrics:
- Engagement Rate: ${campaign.metrics.engagementRate}%
- Conversion Rate: ${campaign.metrics.conversionRate}%
- Content Pieces: ${campaign.metrics.contentPieces}
${campaign.metrics.totalReach ? `- Total Reach: ${campaign.metrics.totalReach.toLocaleString()}` : ''}
${campaign.metrics.activeUsers ? `- Active Users: ${campaign.metrics.activeUsers.toLocaleString()}` : ''}

Please provide strategic insights, realistic projections, and actionable recommendations based on this information.`
  }

  private parseAIResponse(text: string): CampaignSummaryData {
    try {
      // Clean the response to extract JSON
      const cleanText = text.replace(/```json\n?|\n?```/g, '').trim()
      const parsed = JSON.parse(cleanText)
      
      // Validate required fields and provide defaults if missing
      return {
        executiveSummary: parsed.executiveSummary || 'Executive summary not available.',
        strategicRationale: parsed.strategicRationale || 'Strategic rationale not available.',
        contentOverview: {
          totalPieces: parsed.contentOverview?.totalPieces || 0,
          byType: parsed.contentOverview?.byType || { blog: 0, social: 0, email: 0, video: 0 },
          channels: parsed.contentOverview?.channels || ['Email', 'Social Media', 'Website']
        },
        timeline: parsed.timeline || this.getDefaultTimeline(),
        performanceProjections: parsed.performanceProjections || {
          estimatedReach: 10000,
          expectedEngagement: 3.5,
          targetConversions: 250,
          projectedROI: '250%'
        },
        stakeholderBrief: parsed.stakeholderBrief || {
          keyMessages: ['Increase brand awareness', 'Drive qualified leads', 'Improve customer engagement'],
          successMetrics: ['Reach target', 'Engagement rate', 'Conversion rate', 'ROI'],
          risksAndMitigation: ['Budget constraints - Monitor spending closely', 'Market changes - Regular performance reviews']
        }
      }
    } catch (error) {
      console.error('Failed to parse AI response:', error)
      // Return fallback data
      return this.getFallbackSummaryData()
    }
  }

  private getDefaultTimeline() {
    return [
      {
        phase: 'Planning & Strategy',
        description: 'Finalize campaign strategy, content planning, and resource allocation',
        duration: '1-2 weeks',
        deliverables: ['Campaign strategy document', 'Content calendar', 'Asset requirements']
      },
      {
        phase: 'Content Creation',
        description: 'Develop all campaign assets including copy, visuals, and multimedia content',
        duration: '2-3 weeks',
        deliverables: ['Blog posts', 'Social media content', 'Email templates', 'Landing pages']
      },
      {
        phase: 'Launch & Activation',
        description: 'Deploy campaign across all channels and begin audience engagement',
        duration: '1 week',
        deliverables: ['Campaign launch', 'Channel activation', 'Initial monitoring setup']
      },
      {
        phase: 'Optimization & Monitoring',
        description: 'Monitor performance, optimize based on data, and adjust tactics as needed',
        duration: '4-6 weeks',
        deliverables: ['Performance reports', 'Optimization recommendations', 'A/B test results']
      }
    ]
  }

  private getFallbackProjections(campaign: Campaign): CampaignSummaryData['performanceProjections'] {
    // Use current metrics to extrapolate projections
    const baseReach = campaign.metrics.totalReach || 10000
    const currentEngagement = campaign.metrics.engagementRate
    const currentConversion = campaign.metrics.conversionRate

    return {
      estimatedReach: Math.round(baseReach * 1.3), // 30% increase assumption
      expectedEngagement: Math.round(currentEngagement * 1.1 * 10) / 10, // 10% improvement
      targetConversions: Math.round(baseReach * 1.3 * (currentConversion / 100)),
      projectedROI: `${Math.round(currentConversion * 80)}%` // Rough ROI estimate
    }
  }

  private getFallbackSummaryData(): CampaignSummaryData {
    return {
      executiveSummary: 'This campaign aims to increase brand awareness and drive customer engagement through a multi-channel approach. The strategy focuses on delivering targeted content to qualified audiences across digital touchpoints.',
      strategicRationale: 'Based on market analysis and audience insights, this integrated campaign approach will maximize reach while maintaining cost efficiency. The content-first strategy ensures consistent messaging across all channels.',
      contentOverview: {
        totalPieces: 15,
        byType: { blog: 3, social: 8, email: 3, video: 1 },
        channels: ['Email', 'Social Media', 'Website', 'Blog']
      },
      timeline: this.getDefaultTimeline(),
      performanceProjections: {
        estimatedReach: 15000,
        expectedEngagement: 4.2,
        targetConversions: 300,
        projectedROI: '280%'
      },
      stakeholderBrief: {
        keyMessages: [
          'Increase brand visibility in target market',
          'Drive qualified traffic to conversion points',
          'Build customer relationships through valuable content'
        ],
        successMetrics: [
          'Reach 15,000+ prospects',
          'Achieve 4%+ engagement rate',
          'Generate 300+ qualified leads',
          'Maintain cost per lead under $15'
        ],
        risksAndMitigation: [
          'Content saturation - Focus on unique value propositions',
          'Audience fatigue - Regular creative refreshes',
          'Platform changes - Diversified channel strategy'
        ]
      }
    }
  }

  /**
   * Test the service connection and AI availability
   */
  async testService(): Promise<boolean> {
    try {
      const result = await this.aiService.generateText({
        prompt: 'Generate a brief test summary for a marketing campaign. Respond with just "Test successful".',
        maxTokens: 10
      })
      
      return result.text.toLowerCase().includes('test')
    } catch (error) {
      console.error('Campaign summary service test failed:', error)
      return false
    }
  }
}

// Export singleton instance
export const campaignSummaryService = new CampaignSummaryService()

// Types are already exported above