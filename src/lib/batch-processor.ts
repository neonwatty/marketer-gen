// Batch processing system for bulk content generation

import { BulkGenerationRequest, BulkGenerationJob, BulkGenerationProgress } from "./bulk-generation"

export interface BatchProcessorConfig {
  maxConcurrentJobs: number
  retryAttempts: number
  retryDelay: number // milliseconds
  jobTimeout: number // milliseconds
  progressUpdateInterval: number // milliseconds
}

export interface JobResult {
  success: boolean
  data?: any
  error?: string
  duration: number
}

export class BatchProcessor {
  private config: BatchProcessorConfig
  private activeJobs: Map<string, BulkGenerationJob> = new Map()
  private jobQueue: BulkGenerationJob[] = []
  private progressCallbacks: Map<string, (progress: BulkGenerationProgress) => void> = new Map()
  private requestProgress: Map<string, BulkGenerationProgress> = new Map()

  constructor(config: Partial<BatchProcessorConfig> = {}) {
    this.config = {
      maxConcurrentJobs: 5,
      retryAttempts: 3,
      retryDelay: 5000,
      jobTimeout: 60000, // 1 minute per job
      progressUpdateInterval: 1000,
      ...config
    }
  }

  async processRequest(
    request: BulkGenerationRequest,
    jobs: BulkGenerationJob[],
    onProgress?: (progress: BulkGenerationProgress) => void
  ): Promise<BulkGenerationProgress> {
    const requestId = request.id

    // Initialize progress tracking
    const progress: BulkGenerationProgress = {
      requestId,
      totalJobs: jobs.length,
      completedJobs: 0,
      failedJobs: 0,
      inProgressJobs: 0,
      pendingJobs: jobs.length,
      progress: 0,
      startedAt: new Date(),
      status: "initializing"
    }

    this.requestProgress.set(requestId, progress)
    if (onProgress) {
      this.progressCallbacks.set(requestId, onProgress)
    }

    // Add jobs to queue
    this.jobQueue.push(...jobs.map(job => ({ ...job, status: "pending" as const })))

    // Update status and start processing
    progress.status = "processing"
    this.updateProgress(requestId)

    // Process jobs in batches
    await this.processJobQueue(requestId)

    return this.requestProgress.get(requestId)!
  }

  private async processJobQueue(requestId: string) {
    while (this.hasJobsForRequest(requestId)) {
      const availableSlots = this.config.maxConcurrentJobs - this.activeJobs.size
      
      if (availableSlots <= 0) {
        // Wait for active jobs to complete
        await this.waitForJobCompletion()
        continue
      }

      // Start available jobs
      const jobsToStart = this.getNextJobs(requestId, availableSlots)
      
      for (const job of jobsToStart) {
        this.startJob(job)
      }

      // Wait a bit before checking again
      await this.sleep(100)
    }

    // Wait for all active jobs for this request to complete
    while (this.hasActiveJobsForRequest(requestId)) {
      await this.waitForJobCompletion()
    }

    // Finalize progress
    this.finalizeProgress(requestId)
  }

  private async startJob(job: BulkGenerationJob) {
    job.status = "processing"
    job.startedAt = new Date()
    job.progress = 0
    
    this.activeJobs.set(job.id, job)
    this.updateProgress(job.requestId)

    try {
      // Simulate job processing with timeout
      const result = await Promise.race([
        this.executeJob(job),
        this.createTimeoutPromise(this.config.jobTimeout)
      ])

      await this.handleJobCompletion(job, result)
    } catch (error) {
      await this.handleJobFailure(job, error instanceof Error ? error.message : "Unknown error")
    }
  }

  private async executeJob(job: BulkGenerationJob): Promise<JobResult> {
    const startTime = Date.now()
    
    try {
      // Simulate content generation process
      const steps = [
        "Analyzing stage requirements",
        "Generating content outline", 
        "Creating content body",
        "Optimizing for channel",
        "Finalizing and formatting"
      ]

      for (let i = 0; i < steps.length; i++) {
        // Simulate processing time
        await this.sleep(2000 + Math.random() * 3000)
        
        job.progress = Math.round(((i + 1) / steps.length) * 100)
        this.updateProgress(job.requestId)
      }

      // Generate mock content based on job parameters
      const generatedContent = await this.generateMockContent(job)

      return {
        success: true,
        data: generatedContent,
        duration: Date.now() - startTime
      }
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : "Content generation failed",
        duration: Date.now() - startTime
      }
    }
  }

  private async generateMockContent(job: BulkGenerationJob) {
    // Mock content generation based on stage and content type
    const stageTemplates = {
      awareness: {
        title: "Discover the Future of [Industry]",
        content: "In today's rapidly evolving landscape, businesses are looking for innovative solutions..."
      },
      consideration: {
        title: "Why Choose Our Solution?",
        content: "When evaluating options, it's important to consider factors like reliability, scalability..."
      },
      conversion: {
        title: "Special Limited-Time Offer",
        content: "Don't miss this opportunity to transform your business. Act now and save..."
      },
      retention: {
        title: "Welcome to the Family",
        content: "Thank you for choosing us! Here's how to get the most out of your experience..."
      }
    }

    const template = stageTemplates[job.stage as keyof typeof stageTemplates] || stageTemplates.awareness

    return {
      id: `content-${job.id}`,
      title: template.title.replace('[Industry]', 'Technology'),
      content: template.content,
      metadata: {
        stage: job.stage,
        contentType: job.contentType,
        channel: job.channel,
        generatedAt: new Date().toISOString(),
        processingTime: Math.round(Math.random() * 10000), // Mock processing time
      }
    }
  }

  private async handleJobCompletion(job: BulkGenerationJob, result: JobResult) {
    job.status = result.success ? "completed" : "failed"
    job.completedAt = new Date()
    job.progress = 100

    if (result.success) {
      job.generatedContent = result.data
    } else {
      job.error = result.error
      
      // Retry logic
      if (job.retryCount < this.config.retryAttempts) {
        job.retryCount++
        job.status = "pending"
        job.progress = 0
        job.startedAt = undefined
        job.completedAt = undefined
        job.error = undefined
        
        // Add back to queue for retry after delay
        setTimeout(() => {
          this.jobQueue.unshift(job)
        }, this.config.retryDelay)
      }
    }

    this.activeJobs.delete(job.id)
    this.updateProgress(job.requestId)
  }

  private async handleJobFailure(job: BulkGenerationJob, error: string) {
    await this.handleJobCompletion(job, {
      success: false,
      error,
      duration: Date.now() - (job.startedAt?.getTime() || Date.now())
    })
  }

  private updateProgress(requestId: string) {
    const progress = this.requestProgress.get(requestId)
    if (!progress) return

    const allJobs = this.getAllJobsForRequest(requestId)
    const completedJobs = allJobs.filter(j => j.status === "completed").length
    const failedJobs = allJobs.filter(j => j.status === "failed" && j.retryCount >= this.config.retryAttempts).length
    const inProgressJobs = allJobs.filter(j => j.status === "processing").length
    const pendingJobs = allJobs.filter(j => j.status === "pending").length

    progress.completedJobs = completedJobs
    progress.failedJobs = failedJobs
    progress.inProgressJobs = inProgressJobs
    progress.pendingJobs = pendingJobs
    progress.progress = Math.round((completedJobs / progress.totalJobs) * 100)

    // Estimate remaining time
    if (inProgressJobs + pendingJobs > 0) {
      const avgJobTime = this.calculateAverageJobTime(requestId)
      const remainingJobs = inProgressJobs + pendingJobs
      progress.estimatedTimeRemaining = Math.round((remainingJobs / this.config.maxConcurrentJobs) * avgJobTime)
    }

    // Notify callback
    const callback = this.progressCallbacks.get(requestId)
    if (callback) {
      callback(progress)
    }
  }

  private finalizeProgress(requestId: string) {
    const progress = this.requestProgress.get(requestId)
    if (!progress) return

    progress.completedAt = new Date()
    
    if (progress.failedJobs === 0) {
      progress.status = "completed"
    } else if (progress.completedJobs === 0) {
      progress.status = "failed"
    } else {
      progress.status = "completed" // Partial success
    }

    progress.estimatedTimeRemaining = 0

    // Final callback
    const callback = this.progressCallbacks.get(requestId)
    if (callback) {
      callback(progress)
    }
  }

  private hasJobsForRequest(requestId: string): boolean {
    return this.jobQueue.some(job => job.requestId === requestId) ||
           this.hasActiveJobsForRequest(requestId)
  }

  private hasActiveJobsForRequest(requestId: string): boolean {
    return Array.from(this.activeJobs.values()).some(job => job.requestId === requestId)
  }

  private getNextJobs(requestId: string, count: number): BulkGenerationJob[] {
    const jobs = this.jobQueue
      .filter(job => job.requestId === requestId && job.status === "pending")
      .slice(0, count)
    
    // Remove from queue
    jobs.forEach(job => {
      const index = this.jobQueue.findIndex(qJob => qJob.id === job.id)
      if (index !== -1) {
        this.jobQueue.splice(index, 1)
      }
    })

    return jobs
  }

  private getAllJobsForRequest(requestId: string): BulkGenerationJob[] {
    return [
      ...this.jobQueue.filter(job => job.requestId === requestId),
      ...Array.from(this.activeJobs.values()).filter(job => job.requestId === requestId)
    ]
  }

  private calculateAverageJobTime(requestId: string): number {
    const completedJobs = this.getAllJobsForRequest(requestId)
      .filter(job => job.status === "completed" && job.startedAt && job.completedAt)

    if (completedJobs.length === 0) return 30000 // Default 30 seconds

    const totalTime = completedJobs.reduce((sum, job) => {
      return sum + (job.completedAt!.getTime() - job.startedAt!.getTime())
    }, 0)

    return totalTime / completedJobs.length
  }

  private async waitForJobCompletion(): Promise<void> {
    return new Promise(resolve => {
      setTimeout(resolve, this.config.progressUpdateInterval)
    })
  }

  private createTimeoutPromise(timeout: number): Promise<JobResult> {
    return new Promise((_, reject) => {
      setTimeout(() => reject(new Error("Job timeout")), timeout)
    })
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms))
  }

  // Public methods for external control
  pauseRequest(requestId: string) {
    const progress = this.requestProgress.get(requestId)
    if (progress) {
      progress.status = "paused"
    }
  }

  resumeRequest(requestId: string) {
    const progress = this.requestProgress.get(requestId)
    if (progress) {
      progress.status = "processing"
    }
  }

  cancelRequest(requestId: string) {
    const progress = this.requestProgress.get(requestId)
    if (progress) {
      progress.status = "cancelled"
      progress.completedAt = new Date()
    }

    // Remove queued jobs
    this.jobQueue = this.jobQueue.filter(job => job.requestId !== requestId)

    // Mark active jobs as cancelled
    Array.from(this.activeJobs.values())
      .filter(job => job.requestId === requestId)
      .forEach(job => {
        job.status = "failed"
        job.error = "Request cancelled"
        job.completedAt = new Date()
        this.activeJobs.delete(job.id)
      })
  }

  getProgress(requestId: string): BulkGenerationProgress | null {
    return this.requestProgress.get(requestId) || null
  }

  cleanup(requestId: string) {
    this.requestProgress.delete(requestId)
    this.progressCallbacks.delete(requestId)
  }
}

// Singleton instance
export const batchProcessor = new BatchProcessor()