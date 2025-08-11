interface ThumbnailOptions {
  width?: number
  height?: number
  quality?: number
  format?: 'webp' | 'jpeg' | 'png'
}

interface ThumbnailResult {
  success: boolean
  thumbnailUrl?: string
  metadata?: {
    width: number
    height: number
    size: number
    format: string
  }
  error?: string
}

export class ThumbnailGenerator {
  private static instance: ThumbnailGenerator
  private canvas: HTMLCanvasElement | null = null
  private ctx: CanvasRenderingContext2D | null = null

  private constructor() {
    if (typeof window !== 'undefined') {
      this.canvas = document.createElement('canvas')
      this.ctx = this.canvas.getContext('2d')
    }
  }

  static getInstance(): ThumbnailGenerator {
    if (!ThumbnailGenerator.instance) {
      ThumbnailGenerator.instance = new ThumbnailGenerator()
    }
    return ThumbnailGenerator.instance
  }

  async generateImageThumbnail(
    file: File, 
    options: ThumbnailOptions = {}
  ): Promise<ThumbnailResult> {
    const { width = 300, height = 300, quality = 0.8, format = 'webp' } = options

    if (!this.canvas || !this.ctx) {
      return { success: false, error: 'Canvas not available' }
    }

    try {
      // Create image from file
      const img = new Image()
      const imageUrl = URL.createObjectURL(file)

      return new Promise((resolve) => {
        img.onload = () => {
          try {
            // Calculate dimensions maintaining aspect ratio
            const aspectRatio = img.width / img.height
            let targetWidth = width
            let targetHeight = height

            if (aspectRatio > 1) {
              // Landscape
              targetHeight = width / aspectRatio
            } else {
              // Portrait
              targetWidth = height * aspectRatio
            }

            // Set canvas size
            this.canvas!.width = targetWidth
            this.canvas!.height = targetHeight

            // Draw image
            this.ctx!.drawImage(img, 0, 0, targetWidth, targetHeight)

            // Get thumbnail as data URL
            const thumbnailDataUrl = this.canvas!.toDataURL(`image/${format}`, quality)

            // Convert data URL to blob for size calculation
            fetch(thumbnailDataUrl)
              .then(res => res.blob())
              .then(blob => {
                resolve({
                  success: true,
                  thumbnailUrl: thumbnailDataUrl,
                  metadata: {
                    width: targetWidth,
                    height: targetHeight,
                    size: blob.size,
                    format: format
                  }
                })
              })
              .catch(error => {
                resolve({ success: false, error: error.message })
              })

            // Clean up
            URL.revokeObjectURL(imageUrl)
          } catch (error) {
            URL.revokeObjectURL(imageUrl)
            resolve({ 
              success: false, 
              error: error instanceof Error ? error.message : 'Unknown error' 
            })
          }
        }

        img.onerror = () => {
          URL.revokeObjectURL(imageUrl)
          resolve({ success: false, error: 'Failed to load image' })
        }

        img.src = imageUrl
      })
    } catch (error) {
      return { 
        success: false, 
        error: error instanceof Error ? error.message : 'Unknown error' 
      }
    }
  }

  async generateVideoThumbnail(
    file: File, 
    options: ThumbnailOptions = {}
  ): Promise<ThumbnailResult> {
    const { width = 300, height = 300, quality = 0.8, format = 'webp' } = options

    if (!this.canvas || !this.ctx) {
      return { success: false, error: 'Canvas not available' }
    }

    try {
      const video = document.createElement('video')
      const videoUrl = URL.createObjectURL(file)

      return new Promise((resolve) => {
        video.onloadeddata = () => {
          try {
            // Seek to 1 second into the video (or 10% of duration)
            const seekTime = Math.min(1, video.duration * 0.1)
            video.currentTime = seekTime
          } catch (error) {
            resolve({ success: false, error: 'Failed to seek video' })
          }
        }

        video.onseeked = () => {
          try {
            // Calculate dimensions maintaining aspect ratio
            const aspectRatio = video.videoWidth / video.videoHeight
            let targetWidth = width
            let targetHeight = height

            if (aspectRatio > 1) {
              targetHeight = width / aspectRatio
            } else {
              targetWidth = height * aspectRatio
            }

            // Set canvas size
            this.canvas!.width = targetWidth
            this.canvas!.height = targetHeight

            // Draw video frame
            this.ctx!.drawImage(video, 0, 0, targetWidth, targetHeight)

            // Get thumbnail as data URL
            const thumbnailDataUrl = this.canvas!.toDataURL(`image/${format}`, quality)

            // Convert data URL to blob for size calculation
            fetch(thumbnailDataUrl)
              .then(res => res.blob())
              .then(blob => {
                resolve({
                  success: true,
                  thumbnailUrl: thumbnailDataUrl,
                  metadata: {
                    width: targetWidth,
                    height: targetHeight,
                    size: blob.size,
                    format: format
                  }
                })
              })
              .catch(error => {
                resolve({ success: false, error: error.message })
              })

            // Clean up
            URL.revokeObjectURL(videoUrl)
          } catch (error) {
            URL.revokeObjectURL(videoUrl)
            resolve({ 
              success: false, 
              error: error instanceof Error ? error.message : 'Unknown error' 
            })
          }
        }

        video.onerror = () => {
          URL.revokeObjectURL(videoUrl)
          resolve({ success: false, error: 'Failed to load video' })
        }

        video.muted = true
        video.src = videoUrl
        video.load()
      })
    } catch (error) {
      return { 
        success: false, 
        error: error instanceof Error ? error.message : 'Unknown error' 
      }
    }
  }

  generateDocumentThumbnail(
    file: File, 
    options: ThumbnailOptions = {}
  ): ThumbnailResult {
    const { width = 300, height = 300 } = options

    if (!this.canvas || !this.ctx) {
      return { success: false, error: 'Canvas not available' }
    }

    try {
      // Set canvas size
      this.canvas.width = width
      this.canvas.height = height

      // Clear canvas with white background
      this.ctx.fillStyle = '#ffffff'
      this.ctx.fillRect(0, 0, width, height)

      // Add document icon placeholder
      this.ctx.fillStyle = '#3b82f6' // Primary blue
      this.ctx.fillRect(width * 0.2, height * 0.1, width * 0.6, height * 0.8)

      // Add document lines
      this.ctx.fillStyle = '#ffffff'
      for (let i = 0; i < 6; i++) {
        const lineY = height * 0.3 + (i * height * 0.08)
        this.ctx.fillRect(width * 0.3, lineY, width * 0.4, 2)
      }

      // Add file extension text if available
      const fileExtension = file.name.split('.').pop()?.toUpperCase()
      if (fileExtension) {
        this.ctx.fillStyle = '#1f2937'
        this.ctx.font = `${Math.floor(width * 0.08)}px Arial, sans-serif`
        this.ctx.textAlign = 'center'
        this.ctx.fillText(fileExtension, width / 2, height * 0.95)
      }

      const thumbnailDataUrl = this.canvas.toDataURL('image/png', 1)

      return {
        success: true,
        thumbnailUrl: thumbnailDataUrl,
        metadata: {
          width: width,
          height: height,
          size: thumbnailDataUrl.length * 0.75, // Rough estimate
          format: 'png'
        }
      }
    } catch (error) {
      return { 
        success: false, 
        error: error instanceof Error ? error.message : 'Unknown error' 
      }
    }
  }

  generateAudioThumbnail(
    file: File, 
    options: ThumbnailOptions = {}
  ): ThumbnailResult {
    const { width = 300, height = 300 } = options

    if (!this.canvas || !this.ctx) {
      return { success: false, error: 'Canvas not available' }
    }

    try {
      // Set canvas size
      this.canvas.width = width
      this.canvas.height = height

      // Create gradient background
      const gradient = this.ctx.createRadialGradient(
        width / 2, height / 2, 0,
        width / 2, height / 2, width / 2
      )
      gradient.addColorStop(0, '#8b5cf6') // Purple center
      gradient.addColorStop(1, '#3b82f6') // Blue edge

      this.ctx.fillStyle = gradient
      this.ctx.fillRect(0, 0, width, height)

      // Draw sound wave visualization
      this.ctx.strokeStyle = '#ffffff'
      this.ctx.lineWidth = 3
      this.ctx.lineCap = 'round'

      const centerY = height / 2
      const waveWidth = width * 0.8
      const startX = (width - waveWidth) / 2

      this.ctx.beginPath()
      for (let x = 0; x < waveWidth; x += 6) {
        const waveHeight = Math.sin((x / waveWidth) * Math.PI * 4) * (height * 0.1) +
                          Math.sin((x / waveWidth) * Math.PI * 8) * (height * 0.05) +
                          Math.sin((x / waveWidth) * Math.PI * 16) * (height * 0.025)
        
        if (x === 0) {
          this.ctx.moveTo(startX + x, centerY + waveHeight)
        } else {
          this.ctx.lineTo(startX + x, centerY + waveHeight)
        }
      }
      this.ctx.stroke()

      // Add music note icon
      this.ctx.fillStyle = '#ffffff'
      this.ctx.beginPath()
      this.ctx.arc(width / 2, height / 2, width * 0.08, 0, Math.PI * 2)
      this.ctx.fill()

      const thumbnailDataUrl = this.canvas.toDataURL('image/png', 1)

      return {
        success: true,
        thumbnailUrl: thumbnailDataUrl,
        metadata: {
          width: width,
          height: height,
          size: thumbnailDataUrl.length * 0.75,
          format: 'png'
        }
      }
    } catch (error) {
      return { 
        success: false, 
        error: error instanceof Error ? error.message : 'Unknown error' 
      }
    }
  }

  async generateThumbnail(file: File, options: ThumbnailOptions = {}): Promise<ThumbnailResult> {
    const mimeType = file.type.toLowerCase()

    try {
      if (mimeType.startsWith('image/')) {
        return await this.generateImageThumbnail(file, options)
      } else if (mimeType.startsWith('video/')) {
        return await this.generateVideoThumbnail(file, options)
      } else if (mimeType.startsWith('audio/')) {
        return this.generateAudioThumbnail(file, options)
      } else {
        return this.generateDocumentThumbnail(file, options)
      }
    } catch (error) {
      return { 
        success: false, 
        error: error instanceof Error ? error.message : 'Thumbnail generation failed' 
      }
    }
  }

  // Utility methods
  static isImageFile(file: File): boolean {
    return file.type.toLowerCase().startsWith('image/')
  }

  static isVideoFile(file: File): boolean {
    return file.type.toLowerCase().startsWith('video/')
  }

  static isAudioFile(file: File): boolean {
    return file.type.toLowerCase().startsWith('audio/')
  }

  static isDocumentFile(file: File): boolean {
    const documentTypes = [
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'text/plain',
      'text/csv'
    ]
    return documentTypes.includes(file.type.toLowerCase())
  }
}

// Export singleton instance
export const thumbnailGenerator = ThumbnailGenerator.getInstance()

// Utility function for easy usage
export async function generateThumbnail(
  file: File, 
  options?: ThumbnailOptions
): Promise<ThumbnailResult> {
  return await thumbnailGenerator.generateThumbnail(file, options)
}