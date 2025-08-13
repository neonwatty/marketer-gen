"use client"

import * as React from "react"
import { cn } from "@/lib/utils"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import BasePreview from "./base-preview"
import { PreviewContent, getChannelConfig } from "@/lib/channel-previews"
import { 
  ExternalLink, 
  Star,
  MapPin,
  Phone,
  Clock,
  ChevronRight,
  Play,
  ShoppingCart,
  Heart,
  Share2
} from "lucide-react"

interface AdPreviewProps {
  content: PreviewContent
  configId: string
  className?: string
  showValidation?: boolean
  showExport?: boolean
  onExport?: (format: string) => void
}

// Google Search Ad Preview
export function GoogleSearchAdPreview({ 
  content, 
  configId,
  className,
  showValidation,
  showExport,
  onExport
}: AdPreviewProps) {
  const config = getChannelConfig(configId)
  if (!config) return null

  const adUrl = content.branding?.companyName?.toLowerCase().replace(/\s+/g, '') + '.com' || 'yoursite.com'
  const businessInfo = {
    rating: 4.8,
    reviews: 127,
    phone: '(555) 123-4567',
    address: 'City, State'
  }

  return (
    <BasePreview 
      content={content}
      config={config}
      className={className}
      showValidation={showValidation}
      showExport={showExport}
      onExport={onExport}
    >
      <div className="bg-white border-l-4 border-blue-600 pl-4 py-2">
        {/* Ad Label */}
        <div className="flex items-center mb-1">
          <Badge variant="outline" className="text-xs px-2 py-0.5 mr-2 border-green-600 text-green-600">
            Ad
          </Badge>
          <div className="text-green-700 text-sm font-medium">
            {adUrl}
          </div>
        </div>

        {/* Headline */}
        <h3 className="text-blue-600 text-lg font-medium hover:underline cursor-pointer mb-1">
          {content.headline || content.text?.split('.')[0] || 'Your Business - Get Started Today'}
        </h3>

        {/* Description */}
        <p className="text-gray-700 text-sm leading-relaxed mb-2">
          {content.text || 'Professional services and solutions for your business needs. Contact us today for a free consultation.'}
        </p>

        {/* Extensions */}
        <div className="space-y-1">
          {/* Sitelinks */}
          <div className="flex flex-wrap gap-4 text-xs">
            <a href="#" className="text-blue-600 hover:underline">Services</a>
            <a href="#" className="text-blue-600 hover:underline">About Us</a>
            <a href="#" className="text-blue-600 hover:underline">Contact</a>
            <a href="#" className="text-blue-600 hover:underline">Get Quote</a>
          </div>

          {/* Call Extension */}
          <div className="flex items-center text-xs text-gray-600">
            <Phone className="w-3 h-3 mr-1" />
            <span className="text-blue-600 hover:underline">{businessInfo.phone}</span>
          </div>

          {/* Location Extension */}
          <div className="flex items-center text-xs text-gray-600">
            <MapPin className="w-3 h-3 mr-1" />
            <span>{businessInfo.address}</span>
            <span className="mx-2">•</span>
            <div className="flex items-center">
              <Star className="w-3 h-3 text-yellow-500 mr-1" />
              <span>{businessInfo.rating}</span>
              <span className="text-gray-500 ml-1">({businessInfo.reviews} reviews)</span>
            </div>
          </div>

          {/* Callout Extension */}
          {content.callToAction && (
            <div className="text-xs text-gray-700">
              ✓ {content.callToAction} • Free Consultation Available
            </div>
          )}
        </div>
      </div>
    </BasePreview>
  )
}

// Facebook Ad Preview
export function FacebookAdPreview({ 
  content, 
  configId,
  className,
  showValidation,
  showExport,
  onExport
}: AdPreviewProps) {
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
      <div className="bg-white border border-gray-200 rounded-lg shadow-sm max-w-sm mx-auto">
        {/* Sponsored Label */}
        <div className="px-3 py-2 text-xs text-gray-500 bg-gray-50 rounded-t-lg">
          <span className="font-medium">Sponsored</span>
        </div>

        {/* Ad Header */}
        <div className="flex items-center gap-3 p-3 pb-2">
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
              <Badge variant="secondary" className="text-xs px-1.5 py-0.5">
                Ad
              </Badge>
            </div>
            <div className="flex items-center gap-1 text-xs text-gray-500">
              <span>Promoted</span>
            </div>
          </div>
        </div>

        {/* Ad Text */}
        {content.text && (
          <div className="px-3 pb-2">
            <p className="text-sm leading-relaxed">
              {content.text}
            </p>
          </div>
        )}

        {/* Ad Image */}
        {content.images && content.images.length > 0 && (
          <div className="relative">
            <img 
              src={content.images[0].url}
              alt={content.images[0].alt}
              className="w-full aspect-square object-cover"
            />
            {content.video && (
              <div className="absolute inset-0 flex items-center justify-center bg-black bg-opacity-30">
                <div className="w-16 h-16 bg-white bg-opacity-90 rounded-full flex items-center justify-center">
                  <Play className="w-6 h-6 text-gray-800 ml-1" />
                </div>
              </div>
            )}
          </div>
        )}

        {/* Ad Footer with CTA */}
        <div className="p-3 border-t border-gray-100">
          <div className="mb-3">
            <h3 className="font-semibold text-sm text-gray-900 mb-1">
              {content.headline || 'Shop Our Latest Collection'}
            </h3>
            <p className="text-xs text-gray-600">
              {content.branding?.companyName?.toLowerCase().replace(/\s+/g, '') + '.com' || 'yourstore.com'}
            </p>
          </div>
          
          {content.callToAction && (
            <Button className="w-full bg-blue-600 hover:bg-blue-700 text-sm py-2">
              {content.callToAction}
            </Button>
          )}
        </div>

        {/* Engagement Actions */}
        <div className="flex items-center justify-between px-3 pb-3 text-gray-500">
          <div className="flex items-center space-x-6">
            <button className="flex items-center space-x-1 hover:text-red-500">
              <Heart className="w-4 h-4" />
              <span className="text-xs">Like</span>
            </button>
            <button className="flex items-center space-x-1 hover:text-blue-500">
              <Share2 className="w-4 h-4" />
              <span className="text-xs">Share</span>
            </button>
          </div>
        </div>
      </div>
    </BasePreview>
  )
}

// Display Banner Ad Preview
export function DisplayBannerAdPreview({ 
  content, 
  configId,
  className,
  showValidation,
  showExport,
  onExport
}: AdPreviewProps) {
  const config = getChannelConfig(configId)
  if (!config) return null

  return (
    <BasePreview 
      content={content}
      config={config}
      className={className}
      showValidation={showValidation}
      showExport={showExport}
      onExport={onExport}
    >
      <div className="relative bg-gradient-to-r from-blue-600 to-purple-600 text-white rounded-lg overflow-hidden shadow-lg">
        {/* Background Pattern */}
        <div className="absolute inset-0 opacity-10">
          <div className="absolute top-0 right-0 w-32 h-32 bg-white rounded-full -translate-y-16 translate-x-16"></div>
          <div className="absolute bottom-0 left-0 w-24 h-24 bg-white rounded-full translate-y-12 -translate-x-12"></div>
        </div>

        {/* Ad Label */}
        <div className="absolute top-2 right-2 bg-black bg-opacity-50 text-white text-xs px-2 py-1 rounded">
          Ad
        </div>

        <div className="relative p-6 flex items-center justify-between">
          {/* Content Side */}
          <div className="flex-1 pr-6">
            {/* Logo */}
            {content.branding?.logoUrl ? (
              <img 
                src={content.branding.logoUrl}
                alt="Company Logo"
                className="h-8 w-auto mb-3"
              />
            ) : (
              <div className="bg-white text-blue-600 px-3 py-1 rounded text-lg font-bold mb-3 inline-block">
                {content.branding?.companyName || 'BRAND'}
              </div>
            )}

            {/* Headline */}
            <h2 className="text-2xl font-bold mb-2 leading-tight">
              {content.headline || content.text?.split('.')[0] || 'Amazing Deals Await!'}
            </h2>

            {/* Description */}
            <p className="text-blue-100 mb-4 text-sm">
              {content.text || 'Discover incredible savings on our premium products. Limited time offer!'}
            </p>

            {/* CTA Button */}
            {content.callToAction && (
              <Button className="bg-white text-blue-600 hover:bg-gray-100 font-semibold px-6 py-2 rounded-full">
                {content.callToAction}
                <ChevronRight className="w-4 h-4 ml-1" />
              </Button>
            )}
          </div>

          {/* Image Side */}
          {content.images && content.images.length > 0 && (
            <div className="flex-shrink-0">
              <img 
                src={content.images[0].url}
                alt={content.images[0].alt}
                className="w-32 h-32 object-cover rounded-lg"
              />
            </div>
          )}
        </div>

        {/* Bottom accent */}
        <div className="absolute bottom-0 left-0 right-0 h-1 bg-gradient-to-r from-yellow-400 to-orange-500"></div>
      </div>
    </BasePreview>
  )
}

// Shopping Ad Preview (Google Shopping)
export function ShoppingAdPreview({ 
  content, 
  configId,
  className,
  showValidation,
  showExport,
  onExport
}: AdPreviewProps) {
  const config = getChannelConfig(configId)
  if (!config) return null

  const productInfo = {
    price: '$99.99',
    originalPrice: '$149.99',
    store: content.branding?.companyName || 'Your Store',
    shipping: 'Free shipping',
    rating: 4.5,
    reviews: 234
  }

  return (
    <BasePreview 
      content={content}
      config={config}
      className={className}
      showValidation={showValidation}
      showExport={showExport}
      onExport={onExport}
    >
      <Card className="max-w-sm">
        <CardContent className="p-0">
          {/* Product Image */}
          {content.images && content.images.length > 0 && (
            <div className="relative">
              <img 
                src={content.images[0].url}
                alt={content.images[0].alt}
                className="w-full h-48 object-cover"
              />
              {/* Sale Badge */}
              <Badge className="absolute top-2 left-2 bg-red-600 text-white">
                Sale
              </Badge>
              {/* Ad Label */}
              <Badge variant="outline" className="absolute top-2 right-2 bg-white text-xs">
                Ad
              </Badge>
            </div>
          )}

          <div className="p-4">
            {/* Product Title */}
            <h3 className="font-medium text-sm text-gray-900 mb-2 leading-tight">
              {content.headline || content.text?.substring(0, 60) || 'Premium Product Name'}
            </h3>

            {/* Rating */}
            <div className="flex items-center mb-2">
              <div className="flex items-center">
                {[...Array(5)].map((_, i) => (
                  <Star 
                    key={i} 
                    className={`w-3 h-3 ${i < Math.floor(productInfo.rating) 
                      ? 'text-yellow-400 fill-current' 
                      : 'text-gray-300'
                    }`} 
                  />
                ))}
              </div>
              <span className="text-xs text-gray-600 ml-1">
                {productInfo.rating} ({productInfo.reviews})
              </span>
            </div>

            {/* Price */}
            <div className="flex items-center mb-2">
              <span className="text-lg font-bold text-gray-900">
                {productInfo.price}
              </span>
              <span className="text-sm text-gray-500 line-through ml-2">
                {productInfo.originalPrice}
              </span>
            </div>

            {/* Store Info */}
            <div className="text-xs text-gray-600 mb-2">
              <p>{productInfo.store}</p>
              <p className="text-green-600">{productInfo.shipping}</p>
            </div>

            {/* CTA Button */}
            {content.callToAction && (
              <Button className="w-full bg-blue-600 hover:bg-blue-700 text-sm">
                <ShoppingCart className="w-4 h-4 mr-2" />
                {content.callToAction}
              </Button>
            )}
          </div>
        </CardContent>
      </Card>
    </BasePreview>
  )
}

// Video Ad Preview
export function VideoAdPreview({ 
  content, 
  configId,
  className,
  showValidation,
  showExport,
  onExport
}: AdPreviewProps) {
  const config = getChannelConfig(configId)
  if (!config) return null

  return (
    <BasePreview 
      content={content}
      config={config}
      className={className}
      showValidation={showValidation}
      showExport={showExport}
      onExport={onExport}
    >
      <div className="relative bg-black rounded-lg overflow-hidden shadow-lg max-w-md mx-auto">
        {/* Video Container */}
        <div className="relative aspect-video bg-gray-900">
          {content.images && content.images.length > 0 ? (
            <img 
              src={content.images[0].url}
              alt={content.images[0].alt}
              className="w-full h-full object-cover"
            />
          ) : (
            <div className="w-full h-full bg-gradient-to-br from-blue-600 to-purple-700 flex items-center justify-center">
              <div className="text-white text-center">
                <h3 className="text-xl font-bold mb-2">
                  {content.headline || 'Your Video Ad'}
                </h3>
                <p className="text-sm opacity-75">
                  {content.text || 'Compelling video content here'}
                </p>
              </div>
            </div>
          )}
          
          {/* Play Button Overlay */}
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="w-16 h-16 bg-white bg-opacity-90 rounded-full flex items-center justify-center hover:bg-opacity-100 cursor-pointer transition-all transform hover:scale-110">
              <Play className="w-6 h-6 text-gray-800 ml-1" />
            </div>
          </div>

          {/* Ad Duration */}
          <div className="absolute bottom-2 right-2 bg-black bg-opacity-75 text-white text-xs px-2 py-1 rounded">
            0:30
          </div>

          {/* Skip Ad Button */}
          <div className="absolute top-2 right-2 bg-black bg-opacity-75 text-white text-xs px-2 py-1 rounded">
            Ad • Skip in 5s
          </div>
        </div>

        {/* Video Ad Info */}
        <div className="bg-gray-900 text-white p-4">
          <div className="flex items-start space-x-3">
            {/* Logo */}
            <Avatar className="w-10 h-10 flex-shrink-0">
              <AvatarImage src={content.branding?.logoUrl} />
              <AvatarFallback>
                {content.branding?.companyName?.charAt(0) || 'B'}
              </AvatarFallback>
            </Avatar>
            
            <div className="flex-1 min-w-0">
              <h4 className="font-medium text-sm mb-1">
                {content.branding?.companyName || 'Your Brand'}
              </h4>
              <p className="text-xs text-gray-400 mb-2">
                {content.text || 'Discover our amazing products and services'}
              </p>
              
              {content.callToAction && (
                <Button size="sm" className="bg-blue-600 hover:bg-blue-700">
                  {content.callToAction}
                </Button>
              )}
            </div>
          </div>
        </div>
      </div>
    </BasePreview>
  )
}