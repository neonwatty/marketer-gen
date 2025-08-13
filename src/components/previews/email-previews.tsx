"use client"

import * as React from "react"
import { cn } from "@/lib/utils"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Separator } from "@/components/ui/separator"
import BasePreview from "./base-preview"
import { PreviewContent, getChannelConfig } from "@/lib/channel-previews"
import { 
  Mail, 
  ExternalLink, 
  Facebook, 
  Twitter, 
  Instagram,
  Linkedin,
  Globe,
  Phone,
  MapPin,
  Unsubscribe
} from "lucide-react"

interface EmailPreviewProps {
  content: PreviewContent
  configId: string
  className?: string
  showValidation?: boolean
  showExport?: boolean
  onExport?: (format: string) => void
}

// Email Newsletter Preview
export function EmailNewsletterPreview({ 
  content, 
  configId,
  className,
  showValidation,
  showExport,
  onExport
}: EmailPreviewProps) {
  const config = getChannelConfig(configId)
  if (!config) return null

  const mockCompanyInfo = {
    address: "123 Business St, City, State 12345",
    phone: "(555) 123-4567",
    website: "www.company.com"
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
      <div className="bg-gray-50 min-h-[600px]">
        <div className="max-w-[600px] mx-auto bg-white shadow-lg">
          {/* Email Header */}
          <div className="bg-gray-100 px-4 py-2 text-xs text-gray-600 border-b">
            <div className="flex justify-between items-center">
              <span>
                From: {content.branding?.companyName || 'Your Company'} &lt;noreply@company.com&gt;
              </span>
              <span>
                {content.metadata?.timestamp ? 
                  new Date(content.metadata.timestamp).toLocaleDateString() : 
                  new Date().toLocaleDateString()
                }
              </span>
            </div>
            <div className="mt-1">
              Subject: {content.headline || content.text?.split('\n')[0]?.substring(0, 50) + '...' || 'Newsletter Subject'}
            </div>
          </div>

          {/* Email Header Banner */}
          <div className="bg-gradient-to-r from-blue-600 to-purple-600 text-white px-6 py-8">
            <div className="flex items-center justify-center mb-4">
              {content.branding?.logoUrl ? (
                <img 
                  src={content.branding.logoUrl} 
                  alt="Company Logo"
                  className="h-12 w-auto"
                />
              ) : (
                <div className="bg-white text-blue-600 px-4 py-2 rounded text-lg font-bold">
                  {content.branding?.companyName || 'LOGO'}
                </div>
              )}
            </div>
            <h1 className="text-2xl font-bold text-center mb-2">
              {content.headline || 'Newsletter Title'}
            </h1>
            <p className="text-center text-blue-100">
              {content.subtext || 'Stay updated with our latest news and insights'}
            </p>
          </div>

          {/* Main Content */}
          <div className="px-6 py-8">
            {content.text && (
              <div className="prose prose-sm max-w-none mb-6">
                <div className="whitespace-pre-wrap leading-relaxed text-gray-700">
                  {content.text.split('\n\n').map((paragraph, index) => (
                    <p key={index} className="mb-4">
                      {paragraph}
                    </p>
                  ))}
                </div>
              </div>
            )}

            {/* Featured Image */}
            {content.images && content.images.length > 0 && (
              <div className="mb-6">
                <img 
                  src={content.images[0].url}
                  alt={content.images[0].alt}
                  className="w-full h-64 object-cover rounded-lg"
                />
              </div>
            )}

            {/* Call to Action */}
            {content.callToAction && (
              <div className="text-center py-6">
                <Button 
                  size="lg" 
                  className="bg-blue-600 hover:bg-blue-700 text-white px-8 py-3 text-lg"
                >
                  <ExternalLink className="w-4 h-4 mr-2" />
                  {content.callToAction}
                </Button>
              </div>
            )}

            {/* Additional Images Grid */}
            {content.images && content.images.length > 1 && (
              <div className="grid grid-cols-2 gap-4 mb-6">
                {content.images.slice(1, 5).map((image, index) => (
                  <div key={index} className="relative">
                    <img 
                      src={image.url}
                      alt={image.alt}
                      className="w-full h-32 object-cover rounded"
                    />
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Newsletter Sections */}
          <div className="bg-gray-50 px-6 py-6">
            <h2 className="text-lg font-semibold mb-4 text-center">Featured Content</h2>
            <div className="space-y-4">
              <div className="bg-white p-4 rounded-lg shadow-sm">
                <h3 className="font-medium text-gray-900 mb-2">Latest Updates</h3>
                <p className="text-sm text-gray-600 mb-3">
                  Discover what's new in our latest product updates and feature releases.
                </p>
                <Button variant="outline" size="sm">Read More</Button>
              </div>
              
              <div className="bg-white p-4 rounded-lg shadow-sm">
                <h3 className="font-medium text-gray-900 mb-2">Industry Insights</h3>
                <p className="text-sm text-gray-600 mb-3">
                  Expert analysis and trends shaping the future of your industry.
                </p>
                <Button variant="outline" size="sm">Learn More</Button>
              </div>
            </div>
          </div>

          {/* Social Links */}
          <div className="bg-gray-100 px-6 py-4">
            <div className="text-center">
              <p className="text-sm text-gray-600 mb-4">Follow us on social media</p>
              <div className="flex justify-center space-x-4">
                <Button variant="ghost" size="sm" className="p-2">
                  <Facebook className="w-5 h-5 text-blue-600" />
                </Button>
                <Button variant="ghost" size="sm" className="p-2">
                  <Twitter className="w-5 h-5 text-blue-400" />
                </Button>
                <Button variant="ghost" size="sm" className="p-2">
                  <Instagram className="w-5 h-5 text-pink-600" />
                </Button>
                <Button variant="ghost" size="sm" className="p-2">
                  <Linkedin className="w-5 h-5 text-blue-700" />
                </Button>
              </div>
            </div>
          </div>

          {/* Footer */}
          <div className="bg-gray-800 text-gray-300 px-6 py-6 text-xs">
            <div className="text-center space-y-2">
              <p className="font-medium">
                {content.branding?.companyName || 'Your Company Name'}
              </p>
              <p className="flex items-center justify-center gap-1">
                <MapPin className="w-3 h-3" />
                {mockCompanyInfo.address}
              </p>
              <p className="flex items-center justify-center gap-1">
                <Phone className="w-3 h-3" />
                {mockCompanyInfo.phone}
              </p>
              <p className="flex items-center justify-center gap-1">
                <Globe className="w-3 h-3" />
                {mockCompanyInfo.website}
              </p>
              
              <Separator className="my-4 bg-gray-600" />
              
              <div className="flex justify-center space-x-4 text-gray-400">
                <a href="#" className="hover:text-white">Privacy Policy</a>
                <a href="#" className="hover:text-white">Terms of Service</a>
                <a href="#" className="hover:text-white flex items-center gap-1">
                  <Unsubscribe className="w-3 h-3" />
                  Unsubscribe
                </a>
              </div>
              
              <p className="mt-4 text-gray-500">
                You received this email because you subscribed to our newsletter.
              </p>
            </div>
          </div>
        </div>
      </div>
    </BasePreview>
  )
}

// Promotional Email Preview
export function EmailPromotionalPreview({ 
  content, 
  configId,
  className,
  showValidation,
  showExport,
  onExport
}: EmailPreviewProps) {
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
      <div className="bg-gray-50 min-h-[600px]">
        <div className="max-w-[600px] mx-auto bg-white shadow-lg">
          {/* Email Header */}
          <div className="bg-gray-100 px-4 py-2 text-xs text-gray-600 border-b">
            <div className="flex justify-between items-center">
              <span>
                From: {content.branding?.companyName || 'Your Store'} &lt;offers@store.com&gt;
              </span>
              <span>
                {content.metadata?.timestamp ? 
                  new Date(content.metadata.timestamp).toLocaleDateString() : 
                  new Date().toLocaleDateString()
                }
              </span>
            </div>
            <div className="mt-1">
              Subject: {content.headline || '🔥 Special Offer - Limited Time Only!'}
            </div>
          </div>

          {/* Promotional Header */}
          <div className="relative bg-gradient-to-r from-red-600 via-pink-600 to-purple-600 text-white overflow-hidden">
            {/* Background Pattern */}
            <div className="absolute inset-0 opacity-10">
              <div className="absolute top-0 left-0 w-32 h-32 bg-white rounded-full -translate-x-16 -translate-y-16"></div>
              <div className="absolute bottom-0 right-0 w-24 h-24 bg-white rounded-full translate-x-12 translate-y-12"></div>
            </div>
            
            <div className="relative px-6 py-8 text-center">
              {/* Logo */}
              {content.branding?.logoUrl ? (
                <img 
                  src={content.branding.logoUrl} 
                  alt="Company Logo"
                  className="h-10 w-auto mx-auto mb-4"
                />
              ) : (
                <div className="bg-white text-red-600 px-4 py-2 rounded mx-auto inline-block text-lg font-bold mb-4">
                  {content.branding?.companyName || 'STORE'}
                </div>
              )}

              {/* Promotional Badge */}
              <Badge className="bg-yellow-400 text-black font-bold text-sm px-3 py-1 mb-4">
                ⚡ LIMITED TIME OFFER
              </Badge>

              <h1 className="text-3xl font-bold mb-2">
                {content.headline || 'HUGE SALE!'}
              </h1>
              <p className="text-xl text-pink-100">
                {content.subtext || 'Up to 50% Off Everything'}
              </p>
            </div>
          </div>

          {/* Main Content */}
          <div className="px-6 py-8">
            {/* Hero Image */}
            {content.images && content.images.length > 0 && (
              <div className="mb-6 relative">
                <img 
                  src={content.images[0].url}
                  alt={content.images[0].alt}
                  className="w-full h-64 object-cover rounded-lg"
                />
                <div className="absolute top-4 right-4 bg-red-600 text-white px-3 py-1 rounded-full text-sm font-bold">
                  SAVE 50%
                </div>
              </div>
            )}

            {/* Promotional Text */}
            {content.text && (
              <div className="text-center mb-6">
                <div className="text-lg text-gray-700 leading-relaxed">
                  {content.text}
                </div>
              </div>
            )}

            {/* Call to Action */}
            {content.callToAction && (
              <div className="text-center py-6">
                <Button 
                  size="lg" 
                  className="bg-gradient-to-r from-red-600 to-pink-600 hover:from-red-700 hover:to-pink-700 text-white px-12 py-4 text-xl font-bold rounded-full shadow-lg transform hover:scale-105 transition-all"
                >
                  {content.callToAction}
                </Button>
                <p className="text-sm text-gray-600 mt-2">
                  * Offer expires in 48 hours
                </p>
              </div>
            )}

            {/* Product Grid */}
            {content.images && content.images.length > 1 && (
              <div className="grid grid-cols-2 gap-4 mb-6">
                {content.images.slice(1, 5).map((image, index) => (
                  <div key={index} className="relative bg-white border rounded-lg p-4 hover:shadow-md transition-shadow">
                    <img 
                      src={image.url}
                      alt={image.alt}
                      className="w-full h-24 object-cover rounded mb-2"
                    />
                    <div className="text-center">
                      <p className="text-sm font-medium text-gray-900 mb-1">Product {index + 1}</p>
                      <p className="text-xs text-gray-500 line-through">$99.99</p>
                      <p className="text-sm font-bold text-red-600">$49.99</p>
                    </div>
                    <Badge className="absolute top-2 right-2 bg-red-600 text-white text-xs">
                      50% OFF
                    </Badge>
                  </div>
                ))}
              </div>
            )}

            {/* Urgency Bar */}
            <div className="bg-yellow-50 border-l-4 border-yellow-400 p-4 mb-6">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <span className="text-2xl">⏰</span>
                </div>
                <div className="ml-3">
                  <p className="text-sm font-medium text-yellow-800">
                    Hurry! Sale ends in 2 days
                  </p>
                  <p className="text-xs text-yellow-700">
                    Don't miss out on these incredible savings
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Footer */}
          <div className="bg-gray-100 px-6 py-6">
            <div className="text-center">
              <p className="text-sm text-gray-600 mb-4">
                Questions? Contact us at support@store.com
              </p>
              
              <div className="flex justify-center space-x-4 mb-4">
                <Button variant="ghost" size="sm" className="p-2">
                  <Facebook className="w-4 h-4 text-blue-600" />
                </Button>
                <Button variant="ghost" size="sm" className="p-2">
                  <Instagram className="w-4 h-4 text-pink-600" />
                </Button>
              </div>
              
              <Separator className="my-4" />
              
              <div className="text-xs text-gray-500 space-y-1">
                <p>{content.branding?.companyName || 'Your Store Name'}</p>
                <p>123 Commerce St, Business City, BC 12345</p>
                <div className="flex justify-center space-x-4 mt-2">
                  <a href="#" className="hover:text-gray-700">Privacy Policy</a>
                  <a href="#" className="hover:text-gray-700">Unsubscribe</a>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </BasePreview>
  )
}

// Mobile Email Preview Wrapper
export function MobileEmailPreview({ 
  content, 
  configId,
  className,
  showValidation,
  showExport,
  onExport
}: EmailPreviewProps) {
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
      <div className="bg-black p-4 rounded-lg mx-auto max-w-sm">
        <div className="bg-gray-900 rounded-t-xl px-4 py-2 flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <div className="w-3 h-3 bg-red-500 rounded-full"></div>
            <div className="w-3 h-3 bg-yellow-500 rounded-full"></div>
            <div className="w-3 h-3 bg-green-500 rounded-full"></div>
          </div>
          <div className="text-white text-xs">📧 Mail</div>
          <div className="w-8"></div>
        </div>
        
        <div className="bg-white rounded-b-xl overflow-hidden">
          <div className="p-4 border-b border-gray-200">
            <div className="flex items-center space-x-3 mb-2">
              <Avatar className="w-8 h-8">
                <AvatarFallback>
                  {content.branding?.companyName?.charAt(0) || 'C'}
                </AvatarFallback>
              </Avatar>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-gray-900 truncate">
                  {content.branding?.companyName || 'Company Name'}
                </p>
                <p className="text-xs text-gray-500">
                  {content.metadata?.timestamp ? 
                    new Date(content.metadata.timestamp).toLocaleDateString() : 
                    'Today'
                  }
                </p>
              </div>
            </div>
            <h3 className="text-sm font-semibold text-gray-900">
              {content.headline || content.text?.substring(0, 50) + '...' || 'Email Subject'}
            </h3>
          </div>
          
          <div className="p-4 max-h-96 overflow-y-auto">
            {content.text && (
              <p className="text-sm text-gray-700 leading-relaxed mb-4">
                {content.text.length > 200 ? content.text.substring(0, 200) + '...' : content.text}
              </p>
            )}
            
            {content.images && content.images.length > 0 && (
              <img 
                src={content.images[0].url}
                alt={content.images[0].alt}
                className="w-full h-32 object-cover rounded mb-4"
              />
            )}
            
            {content.callToAction && (
              <Button className="w-full mb-4">
                {content.callToAction}
              </Button>
            )}
          </div>
        </div>
      </div>
    </BasePreview>
  )
}