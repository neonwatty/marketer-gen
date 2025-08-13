"use client"

import * as React from "react"
import { cn } from "@/lib/utils"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import BasePreview from "./base-preview"
import { PreviewContent, getChannelConfig } from "@/lib/channel-previews"
import { 
  Heart, 
  MessageCircle, 
  Share, 
  Bookmark,
  MoreHorizontal,
  Play,
  Volume2,
  Verified,
  ThumbsUp,
  Repeat2,
  Send
} from "lucide-react"

interface SocialMediaPreviewProps {
  content: PreviewContent
  configId: string
  className?: string
  showValidation?: boolean
  showExport?: boolean
  onExport?: (format: string) => void
}

// Facebook Post Preview
export function FacebookPostPreview({ 
  content, 
  configId,
  className,
  showValidation,
  showExport,
  onExport
}: SocialMediaPreviewProps) {
  const config = getChannelConfig(configId)
  if (!config) return null

  const mockProfileImage = "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=40&h=40&fit=crop&crop=face"

  return (
    <BasePreview 
      content={content}
      config={config}
      className={className}
      showValidation={showValidation}
      showExport={showExport}
      onExport={onExport}
    >
      <div className="bg-white">
        {/* Post Header */}
        <div className="flex items-center gap-3 p-4 pb-3">
          <Avatar className="w-10 h-10">
            <AvatarImage src={content.branding?.logoUrl || mockProfileImage} />
            <AvatarFallback>
              {content.branding?.companyName?.charAt(0) || 'B'}
            </AvatarFallback>
          </Avatar>
          <div className="flex-1">
            <div className="flex items-center gap-1">
              <span className="font-semibold text-sm">
                {content.branding?.companyName || 'Brand Name'}
              </span>
              <Verified className="w-4 h-4 text-blue-500" />
            </div>
            <div className="flex items-center gap-1 text-xs text-gray-500">
              <span>{content.metadata?.timestamp ? 
                new Date(content.metadata.timestamp).toLocaleDateString() : 
                '2 hours ago'
              }</span>
              <span>•</span>
              <span>🌐</span>
            </div>
          </div>
          <MoreHorizontal className="w-5 h-5 text-gray-400" />
        </div>

        {/* Post Content */}
        {content.text && (
          <div className="px-4 pb-3">
            <div className="text-sm leading-relaxed whitespace-pre-wrap">
              {content.text}
              {content.hashtags && content.hashtags.length > 0 && (
                <div className="mt-2">
                  {content.hashtags.map((tag, index) => (
                    <span key={index} className="text-blue-600 hover:underline cursor-pointer">
                      #{tag}{index < content.hashtags!.length - 1 ? ' ' : ''}
                    </span>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}

        {/* Media Content */}
        {content.images && content.images.length > 0 && (
          <div className="bg-gray-100">
            {content.images.length === 1 ? (
              <div className="relative">
                <img 
                  src={content.images[0].url} 
                  alt={content.images[0].alt}
                  className="w-full object-cover max-h-96"
                />
                {content.video && (
                  <div className="absolute inset-0 flex items-center justify-center bg-black bg-opacity-30">
                    <div className="w-16 h-16 bg-white bg-opacity-90 rounded-full flex items-center justify-center">
                      <Play className="w-6 h-6 text-gray-800 ml-1" />
                    </div>
                  </div>
                )}
              </div>
            ) : (
              <div className="grid grid-cols-2 gap-0.5">
                {content.images.slice(0, 4).map((image, index) => (
                  <div key={index} className="relative aspect-square">
                    <img 
                      src={image.url} 
                      alt={image.alt}
                      className="w-full h-full object-cover"
                    />
                    {index === 3 && content.images!.length > 4 && (
                      <div className="absolute inset-0 bg-black bg-opacity-60 flex items-center justify-center">
                        <span className="text-white text-xl font-semibold">
                          +{content.images!.length - 4}
                        </span>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Call to Action */}
        {content.callToAction && (
          <div className="px-4 py-3 border-t border-gray-100">
            <Button className="w-full bg-blue-600 hover:bg-blue-700">
              {content.callToAction}
            </Button>
          </div>
        )}

        {/* Engagement Stats */}
        {content.metadata?.engagement && (
          <div className="px-4 py-2 border-t border-gray-100 text-xs text-gray-500">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-4">
                <span>❤️ {content.metadata.engagement.likes || 0}</span>
                <span>{content.metadata.engagement.comments || 0} comments</span>
                <span>{content.metadata.engagement.shares || 0} shares</span>
              </div>
            </div>
          </div>
        )}

        {/* Action Buttons */}
        <div className="border-t border-gray-100 px-2 py-1">
          <div className="flex">
            <Button variant="ghost" className="flex-1 text-gray-600 hover:bg-gray-50">
              <ThumbsUp className="w-4 h-4 mr-2" />
              Like
            </Button>
            <Button variant="ghost" className="flex-1 text-gray-600 hover:bg-gray-50">
              <MessageCircle className="w-4 h-4 mr-2" />
              Comment
            </Button>
            <Button variant="ghost" className="flex-1 text-gray-600 hover:bg-gray-50">
              <Share className="w-4 h-4 mr-2" />
              Share
            </Button>
          </div>
        </div>
      </div>
    </BasePreview>
  )
}

// Instagram Post Preview
export function InstagramPostPreview({ 
  content, 
  configId,
  className,
  showValidation,
  showExport,
  onExport
}: SocialMediaPreviewProps) {
  const config = getChannelConfig(configId)
  if (!config) return null

  const mockProfileImage = "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=40&h=40&fit=crop&crop=face"

  return (
    <BasePreview 
      content={content}
      config={config}
      className={className}
      showValidation={showValidation}
      showExport={showExport}
      onExport={onExport}
    >
      <div className="bg-white max-w-sm mx-auto">
        {/* Post Header */}
        <div className="flex items-center gap-3 p-3">
          <Avatar className="w-8 h-8">
            <AvatarImage src={content.branding?.logoUrl || mockProfileImage} />
            <AvatarFallback>
              {content.branding?.companyName?.charAt(0) || 'B'}
            </AvatarFallback>
          </Avatar>
          <div className="flex-1">
            <div className="flex items-center gap-1">
              <span className="font-semibold text-sm">
                {content.branding?.companyName?.toLowerCase().replace(/\s+/g, '') || 'brandname'}
              </span>
              <Verified className="w-3 h-3 text-blue-500" />
            </div>
            <span className="text-xs text-gray-500">
              {content.metadata?.timestamp ? 
                new Date(content.metadata.timestamp).toLocaleDateString() : 
                'Los Angeles, CA'
              }
            </span>
          </div>
          <MoreHorizontal className="w-5 h-5 text-gray-400" />
        </div>

        {/* Media Content */}
        {content.images && content.images.length > 0 && (
          <div className="relative aspect-square bg-gray-100">
            {content.images.length === 1 ? (
              <img 
                src={content.images[0].url} 
                alt={content.images[0].alt}
                className="w-full h-full object-cover"
              />
            ) : (
              <div className="relative w-full h-full">
                <img 
                  src={content.images[0].url} 
                  alt={content.images[0].alt}
                  className="w-full h-full object-cover"
                />
                {/* Carousel indicators */}
                <div className="absolute top-2 right-2 bg-black bg-opacity-60 text-white text-xs px-2 py-1 rounded-full">
                  1/{content.images.length}
                </div>
              </div>
            )}
            
            {content.video && (
              <div className="absolute top-2 right-2">
                <Volume2 className="w-5 h-5 text-white drop-shadow-lg" />
              </div>
            )}
          </div>
        )}

        {/* Action Buttons */}
        <div className="flex items-center justify-between p-3 pb-2">
          <div className="flex items-center gap-4">
            <Heart className="w-6 h-6 hover:text-red-500 cursor-pointer" />
            <MessageCircle className="w-6 h-6 hover:text-gray-600 cursor-pointer" />
            <Send className="w-6 h-6 hover:text-gray-600 cursor-pointer" />
          </div>
          <Bookmark className="w-6 h-6 hover:text-gray-600 cursor-pointer" />
        </div>

        {/* Engagement Stats */}
        {content.metadata?.engagement && (
          <div className="px-3 pb-2">
            <span className="font-semibold text-sm">
              {content.metadata.engagement.likes || 0} likes
            </span>
          </div>
        )}

        {/* Post Caption */}
        {content.text && (
          <div className="px-3 pb-2">
            <div className="text-sm">
              <span className="font-semibold mr-2">
                {content.branding?.companyName?.toLowerCase().replace(/\s+/g, '') || 'brandname'}
              </span>
              <span className="whitespace-pre-wrap">
                {content.text.length > 125 ? (
                  <>
                    {content.text.substring(0, 125)}...
                    <button className="text-gray-500 ml-1">more</button>
                  </>
                ) : content.text}
              </span>
            </div>
            
            {/* Hashtags */}
            {content.hashtags && content.hashtags.length > 0 && (
              <div className="mt-1">
                {content.hashtags.slice(0, 5).map((tag, index) => (
                  <span key={index} className="text-blue-900 text-sm mr-1">
                    #{tag}
                  </span>
                ))}
                {content.hashtags.length > 5 && (
                  <button className="text-gray-500 text-sm">
                    ... view all {content.hashtags.length} hashtags
                  </button>
                )}
              </div>
            )}
          </div>
        )}

        {/* View Comments */}
        {content.metadata?.engagement?.comments && (
          <div className="px-3 pb-2">
            <button className="text-gray-500 text-sm">
              View all {content.metadata.engagement.comments} comments
            </button>
          </div>
        )}

        {/* Timestamp */}
        <div className="px-3 pb-3">
          <span className="text-gray-400 text-xs uppercase tracking-wide">
            {content.metadata?.timestamp ? 
              new Date(content.metadata.timestamp).toLocaleDateString() : 
              '2 hours ago'
            }
          </span>
        </div>
      </div>
    </BasePreview>
  )
}

// Instagram Story Preview
export function InstagramStoryPreview({ 
  content, 
  configId,
  className,
  showValidation,
  showExport,
  onExport
}: SocialMediaPreviewProps) {
  const config = getChannelConfig(configId)
  if (!config) return null

  const mockProfileImage = "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=40&h=40&fit=crop&crop=face"

  return (
    <BasePreview 
      content={content}
      config={config}
      className={className}
      showValidation={showValidation}
      showExport={showExport}
      onExport={onExport}
    >
      <div className="relative bg-black aspect-[9/16] max-w-sm mx-auto overflow-hidden">
        {/* Background Image/Video */}
        {content.images && content.images.length > 0 && (
          <img 
            src={content.images[0].url} 
            alt={content.images[0].alt}
            className="absolute inset-0 w-full h-full object-cover"
          />
        )}
        
        {/* Gradient Overlay */}
        <div className="absolute inset-0 bg-gradient-to-t from-black/50 via-transparent to-black/30" />

        {/* Story Header */}
        <div className="absolute top-4 left-4 right-4 flex items-center gap-2 z-10">
          <div className="flex-1 h-0.5 bg-white/30 rounded-full">
            <div className="h-full w-3/4 bg-white rounded-full" />
          </div>
        </div>

        <div className="absolute top-8 left-4 right-4 flex items-center gap-3 z-10">
          <Avatar className="w-8 h-8 ring-2 ring-white/60">
            <AvatarImage src={content.branding?.logoUrl || mockProfileImage} />
            <AvatarFallback className="text-xs">
              {content.branding?.companyName?.charAt(0) || 'B'}
            </AvatarFallback>
          </Avatar>
          <div className="flex-1">
            <span className="text-white text-sm font-medium drop-shadow-sm">
              {content.branding?.companyName?.toLowerCase().replace(/\s+/g, '') || 'brandname'}
            </span>
            <div className="text-white/80 text-xs">
              {content.metadata?.timestamp ? 
                new Date(content.metadata.timestamp).toLocaleDateString() : 
                '2h'
              }
            </div>
          </div>
          <MoreHorizontal className="w-5 h-5 text-white/80" />
        </div>

        {/* Story Content */}
        <div className="absolute inset-x-4 top-1/2 transform -translate-y-1/2 z-10">
          {content.text && (
            <div className="text-center">
              <h2 className="text-white text-xl font-bold drop-shadow-lg leading-tight mb-4">
                {content.text}
              </h2>
            </div>
          )}

          {/* Hashtags as stickers */}
          {content.hashtags && content.hashtags.length > 0 && (
            <div className="flex flex-wrap gap-2 justify-center mt-4">
              {content.hashtags.slice(0, 3).map((tag, index) => (
                <div 
                  key={index} 
                  className="bg-white/20 backdrop-blur-sm text-white text-sm px-3 py-1 rounded-full"
                >
                  #{tag}
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Call to Action */}
        {content.callToAction && (
          <div className="absolute bottom-20 left-4 right-4 z-10">
            <Button className="w-full bg-white text-black hover:bg-gray-100 rounded-full font-medium">
              {content.callToAction}
            </Button>
          </div>
        )}

        {/* Story Actions */}
        <div className="absolute bottom-4 left-4 right-4 flex items-center justify-between z-10">
          <div className="flex items-center gap-4">
            <Heart className="w-6 h-6 text-white/80" />
            <Send className="w-6 h-6 text-white/80" />
          </div>
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center">
              <span className="text-white text-xs">Aa</span>
            </div>
          </div>
        </div>
      </div>
    </BasePreview>
  )
}

// Twitter/X Post Preview
export function TwitterPostPreview({ 
  content, 
  configId,
  className,
  showValidation,
  showExport,
  onExport
}: SocialMediaPreviewProps) {
  const config = getChannelConfig(configId)
  if (!config) return null

  const mockProfileImage = "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=40&h=40&fit=crop&crop=face"

  return (
    <BasePreview 
      content={content}
      config={config}
      className={className}
      showValidation={showValidation}
      showExport={showExport}
      onExport={onExport}
    >
      <div className="bg-white border border-gray-200 hover:bg-gray-50 transition-colors">
        <div className="flex gap-3 p-4">
          {/* Profile Avatar */}
          <Avatar className="w-10 h-10 flex-shrink-0">
            <AvatarImage src={content.branding?.logoUrl || mockProfileImage} />
            <AvatarFallback>
              {content.branding?.companyName?.charAt(0) || 'B'}
            </AvatarFallback>
          </Avatar>

          {/* Tweet Content */}
          <div className="flex-1 min-w-0">
            {/* Tweet Header */}
            <div className="flex items-center gap-1 text-sm mb-1">
              <span className="font-bold text-gray-900">
                {content.branding?.companyName || 'Brand Name'}
              </span>
              <Verified className="w-4 h-4 text-blue-500" />
              <span className="text-gray-500">
                @{content.branding?.companyName?.toLowerCase().replace(/\s+/g, '') || 'brandname'}
              </span>
              <span className="text-gray-500">·</span>
              <span className="text-gray-500">
                {content.metadata?.timestamp ? 
                  new Date(content.metadata.timestamp).toLocaleDateString() : 
                  '2h'
                }
              </span>
            </div>

            {/* Tweet Text */}
            {content.text && (
              <div className="text-gray-900 text-sm leading-normal mb-3 whitespace-pre-wrap">
                {content.text}
                {content.hashtags && content.hashtags.length > 0 && (
                  <span className="block mt-2">
                    {content.hashtags.map((tag, index) => (
                      <span key={index} className="text-blue-500 hover:underline cursor-pointer">
                        #{tag}{index < content.hashtags!.length - 1 ? ' ' : ''}
                      </span>
                    ))}
                  </span>
                )}
              </div>
            )}

            {/* Media Content */}
            {content.images && content.images.length > 0 && (
              <div className="mb-3 rounded-2xl overflow-hidden border border-gray-200">
                {content.images.length === 1 ? (
                  <div className="relative">
                    <img 
                      src={content.images[0].url} 
                      alt={content.images[0].alt}
                      className="w-full max-h-80 object-cover"
                    />
                    {content.video && (
                      <div className="absolute inset-0 flex items-center justify-center bg-black bg-opacity-30">
                        <div className="w-16 h-16 bg-blue-500 rounded-full flex items-center justify-center">
                          <Play className="w-6 h-6 text-white ml-1" />
                        </div>
                      </div>
                    )}
                  </div>
                ) : (
                  <div className={cn(
                    "grid gap-0.5",
                    content.images.length === 2 ? "grid-cols-2" : "grid-cols-2"
                  )}>
                    {content.images.slice(0, 4).map((image, index) => (
                      <div key={index} className="relative aspect-video">
                        <img 
                          src={image.url} 
                          alt={image.alt}
                          className="w-full h-full object-cover"
                        />
                        {index === 3 && content.images!.length > 4 && (
                          <div className="absolute inset-0 bg-black bg-opacity-70 flex items-center justify-center">
                            <span className="text-white text-lg font-semibold">
                              +{content.images!.length - 4}
                            </span>
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* Call to Action Link */}
            {content.callToAction && (
              <div className="mb-3 p-3 border border-gray-200 rounded-2xl hover:bg-gray-50 cursor-pointer">
                <div className="text-sm text-blue-500 font-medium">
                  {content.callToAction}
                </div>
                <div className="text-xs text-gray-500 mt-1">
                  {content.branding?.companyName?.toLowerCase().replace(/\s+/g, '') || 'brandname'}.com
                </div>
              </div>
            )}

            {/* Tweet Actions */}
            <div className="flex items-center justify-between max-w-md">
              <Button variant="ghost" size="sm" className="text-gray-500 hover:text-blue-500 hover:bg-blue-50 -ml-2">
                <MessageCircle className="w-4 h-4 mr-1" />
                <span className="text-sm">{content.metadata?.engagement?.comments || 0}</span>
              </Button>
              
              <Button variant="ghost" size="sm" className="text-gray-500 hover:text-green-500 hover:bg-green-50">
                <Repeat2 className="w-4 h-4 mr-1" />
                <span className="text-sm">{content.metadata?.engagement?.shares || 0}</span>
              </Button>
              
              <Button variant="ghost" size="sm" className="text-gray-500 hover:text-red-500 hover:bg-red-50">
                <Heart className="w-4 h-4 mr-1" />
                <span className="text-sm">{content.metadata?.engagement?.likes || 0}</span>
              </Button>
              
              <Button variant="ghost" size="sm" className="text-gray-500 hover:text-blue-500 hover:bg-blue-50">
                <Share className="w-4 h-4" />
              </Button>
            </div>
          </div>
        </div>
      </div>
    </BasePreview>
  )
}