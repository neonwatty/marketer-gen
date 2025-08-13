"use client"

import * as React from "react"
import { cn } from "@/lib/utils"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Separator } from "@/components/ui/separator"
import BasePreview from "./base-preview"
import { PreviewContent, getChannelConfig } from "@/lib/channel-previews"
import { 
  ArrowRight,
  CheckCircle,
  Star,
  Users,
  Award,
  Shield,
  Zap,
  Heart,
  TrendingUp,
  Play,
  ChevronDown,
  Mail,
  Phone,
  MapPin,
  Clock
} from "lucide-react"

interface LandingPagePreviewProps {
  content: PreviewContent
  configId: string
  className?: string
  showValidation?: boolean
  showExport?: boolean
  onExport?: (format: string) => void
}

// Landing Page Hero Section Preview
export function LandingPageHeroPreview({ 
  content, 
  configId,
  className,
  showValidation,
  showExport,
  onExport
}: LandingPagePreviewProps) {
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
      <div className="relative min-h-[600px] bg-gradient-to-br from-blue-600 via-purple-600 to-indigo-800 text-white overflow-hidden">
        {/* Background Pattern */}
        <div className="absolute inset-0 bg-[url('data:image/svg+xml,%3Csvg%20width%3D%2260%22%20height%3D%2260%22%20viewBox%3D%220%200%2060%2060%22%20xmlns%3D%22http%3A//www.w3.org/2000/svg%22%3E%3Cg%20fill%3D%22none%22%20fill-rule%3D%22evenodd%22%3E%3Cg%20fill%3D%22%239C92AC%22%20fill-opacity%3D%220.1%22%3E%3Ccircle%20cx%3D%2230%22%20cy%3D%2230%22%20r%3D%224%22/%3E%3C/g%3E%3C/g%3E%3C/svg%3E')] opacity-30"></div>
        
        {/* Navigation Header */}
        <nav className="relative z-10 flex items-center justify-between px-6 py-4">
          <div className="flex items-center space-x-2">
            {content.branding?.logoUrl ? (
              <img 
                src={content.branding.logoUrl}
                alt="Logo"
                className="h-8 w-auto"
              />
            ) : (
              <div className="bg-white text-blue-600 px-3 py-1 rounded font-bold">
                {content.branding?.companyName || 'BRAND'}
              </div>
            )}
          </div>
          <div className="hidden md:flex items-center space-x-6">
            <a href="#" className="hover:text-blue-200">Features</a>
            <a href="#" className="hover:text-blue-200">Pricing</a>
            <a href="#" className="hover:text-blue-200">About</a>
            <Button variant="secondary" size="sm">
              Sign In
            </Button>
          </div>
        </nav>

        {/* Hero Content */}
        <div className="relative z-10 px-6 py-16 max-w-6xl mx-auto">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
            {/* Left Column - Content */}
            <div className="text-center lg:text-left">
              <Badge className="bg-white/20 text-white border-white/30 mb-6">
                ✨ New Feature Launch
              </Badge>
              
              <h1 className="text-4xl lg:text-6xl font-bold mb-6 leading-tight">
                {content.headline || content.text?.split('.')[0] || 'Transform Your Business Today'}
              </h1>
              
              <p className="text-xl text-blue-100 mb-8 leading-relaxed">
                {content.text || 'Join thousands of successful businesses who have revolutionized their workflow with our innovative solution.'}
              </p>

              <div className="flex flex-col sm:flex-row gap-4 mb-8">
                {content.callToAction && (
                  <Button size="lg" className="bg-white text-blue-600 hover:bg-gray-100 font-semibold px-8 py-4 text-lg">
                    {content.callToAction}
                    <ArrowRight className="w-5 h-5 ml-2" />
                  </Button>
                )}
                <Button size="lg" variant="outline" className="border-white text-white hover:bg-white/10 px-8 py-4 text-lg">
                  <Play className="w-5 h-5 mr-2" />
                  Watch Demo
                </Button>
              </div>

              {/* Social Proof */}
              <div className="flex items-center justify-center lg:justify-start space-x-6 text-sm text-blue-200">
                <div className="flex items-center">
                  <Users className="w-4 h-4 mr-1" />
                  50k+ Users
                </div>
                <div className="flex items-center">
                  <Star className="w-4 h-4 mr-1 text-yellow-400" />
                  4.9/5 Rating
                </div>
                <div className="flex items-center">
                  <Award className="w-4 h-4 mr-1" />
                  #1 Solution
                </div>
              </div>
            </div>

            {/* Right Column - Visual */}
            <div className="relative">
              {content.images && content.images.length > 0 ? (
                <div className="relative">
                  <img 
                    src={content.images[0].url}
                    alt={content.images[0].alt}
                    className="w-full rounded-lg shadow-2xl"
                  />
                  {/* Floating elements */}
                  <div className="absolute -top-4 -right-4 bg-green-500 text-white px-3 py-2 rounded-full text-sm font-medium">
                    ✓ Verified
                  </div>
                  <div className="absolute -bottom-4 -left-4 bg-white text-gray-800 px-4 py-3 rounded-lg shadow-lg">
                    <div className="flex items-center space-x-2">
                      <TrendingUp className="w-4 h-4 text-green-500" />
                      <span className="text-sm font-medium">+127% Growth</span>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="bg-white/10 backdrop-blur-sm rounded-lg p-8 text-center">
                  <div className="w-24 h-24 bg-white/20 rounded-full mx-auto mb-4 flex items-center justify-center">
                    <Zap className="w-12 h-12" />
                  </div>
                  <h3 className="text-xl font-semibold mb-2">Powerful Features</h3>
                  <p className="text-blue-200">Experience the future of business automation</p>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Bottom wave */}
        <div className="absolute bottom-0 left-0 right-0 h-16 bg-white" 
             style={{
               clipPath: 'polygon(0 100%, 100% 100%, 100% 60%, 0 100%)'
             }}>
        </div>
      </div>
    </BasePreview>
  )
}

// Features Section Preview
export function LandingPageFeaturesPreview({ 
  content, 
  configId,
  className,
  showValidation,
  showExport,
  onExport
}: LandingPagePreviewProps) {
  const config = getChannelConfig(configId)
  if (!config) return null

  const features = [
    {
      icon: <Shield className="w-8 h-8 text-blue-600" />,
      title: "Enterprise Security",
      description: "Bank-level security with 256-bit encryption"
    },
    {
      icon: <Zap className="w-8 h-8 text-yellow-500" />,
      title: "Lightning Fast",
      description: "99.9% uptime with global CDN network"
    },
    {
      icon: <Users className="w-8 h-8 text-green-600" />,
      title: "Team Collaboration",
      description: "Seamless teamwork with real-time sync"
    }
  ]

  return (
    <BasePreview 
      content={content}
      config={config}
      className={className}
      showValidation={showValidation}
      showExport={showExport}
      onExport={onExport}
    >
      <section className="py-16 px-6 bg-white">
        <div className="max-w-6xl mx-auto">
          {/* Section Header */}
          <div className="text-center mb-16">
            <Badge className="bg-blue-100 text-blue-800 mb-4">
              Features
            </Badge>
            <h2 className="text-4xl font-bold text-gray-900 mb-4">
              {content.headline || 'Everything You Need to Succeed'}
            </h2>
            <p className="text-xl text-gray-600 max-w-3xl mx-auto">
              {content.text || 'Our comprehensive platform provides all the tools and features your business needs to thrive in today\'s competitive market.'}
            </p>
          </div>

          {/* Features Grid */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-16">
            {features.map((feature, index) => (
              <Card key={index} className="text-center p-8 hover:shadow-lg transition-shadow border-0 bg-gray-50">
                <CardContent className="p-0">
                  <div className="mb-6 flex justify-center">
                    <div className="w-16 h-16 bg-white rounded-full flex items-center justify-center shadow-md">
                      {feature.icon}
                    </div>
                  </div>
                  <h3 className="text-xl font-semibold text-gray-900 mb-3">
                    {feature.title}
                  </h3>
                  <p className="text-gray-600">
                    {feature.description}
                  </p>
                </CardContent>
              </Card>
            ))}
          </div>

          {/* Feature Image */}
          {content.images && content.images.length > 0 && (
            <div className="relative">
              <img 
                src={content.images[0].url}
                alt={content.images[0].alt}
                className="w-full rounded-xl shadow-2xl"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent rounded-xl"></div>
            </div>
          )}

          {/* CTA */}
          {content.callToAction && (
            <div className="text-center mt-12">
              <Button size="lg" className="bg-blue-600 hover:bg-blue-700 px-8 py-4 text-lg">
                {content.callToAction}
                <ArrowRight className="w-5 h-5 ml-2" />
              </Button>
            </div>
          )}
        </div>
      </section>
    </BasePreview>
  )
}

// Testimonials Section Preview
export function LandingPageTestimonialsPreview({ 
  content, 
  configId,
  className,
  showValidation,
  showExport,
  onExport
}: LandingPagePreviewProps) {
  const config = getChannelConfig(configId)
  if (!config) return null

  const testimonials = [
    {
      quote: "This platform transformed our business operations completely. The ROI has been incredible!",
      author: "Sarah Johnson",
      role: "CEO, TechStart Inc.",
      avatar: "https://images.unsplash.com/photo-1494790108755-2616b612b786?w=60&h=60&fit=crop&crop=face"
    },
    {
      quote: "Best investment we've made. The support team is amazing and the features are top-notch.",
      author: "Michael Chen",
      role: "Founder, GrowthCo",
      avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=60&h=60&fit=crop&crop=face"
    },
    {
      quote: "Streamlined our workflow and increased productivity by 300%. Highly recommended!",
      author: "Emily Davis",
      role: "Operations Manager",
      avatar: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=60&h=60&fit=crop&crop=face"
    }
  ]

  return (
    <BasePreview 
      content={content}
      config={config}
      className={className}
      showValidation={showValidation}
      showExport={showExport}
      onExport={onExport}
    >
      <section className="py-16 px-6 bg-gray-50">
        <div className="max-w-6xl mx-auto">
          {/* Section Header */}
          <div className="text-center mb-16">
            <Badge className="bg-green-100 text-green-800 mb-4">
              Testimonials
            </Badge>
            <h2 className="text-4xl font-bold text-gray-900 mb-4">
              {content.headline || 'Loved by Thousands of Businesses'}
            </h2>
            <p className="text-xl text-gray-600">
              {content.text || 'See what our customers are saying about their experience with our platform.'}
            </p>
          </div>

          {/* Testimonials Grid */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {testimonials.map((testimonial, index) => (
              <Card key={index} className="p-8 hover:shadow-lg transition-shadow bg-white">
                <CardContent className="p-0">
                  {/* Stars */}
                  <div className="flex mb-4">
                    {[...Array(5)].map((_, i) => (
                      <Star key={i} className="w-5 h-5 text-yellow-400 fill-current" />
                    ))}
                  </div>
                  
                  {/* Quote */}
                  <p className="text-gray-700 mb-6 leading-relaxed">
                    "{testimonial.quote}"
                  </p>
                  
                  {/* Author */}
                  <div className="flex items-center">
                    <Avatar className="w-12 h-12 mr-4">
                      <AvatarImage src={testimonial.avatar} />
                      <AvatarFallback>{testimonial.author.split(' ').map(n => n[0]).join('')}</AvatarFallback>
                    </Avatar>
                    <div>
                      <p className="font-semibold text-gray-900">{testimonial.author}</p>
                      <p className="text-sm text-gray-600">{testimonial.role}</p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>

          {/* Call to Action */}
          {content.callToAction && (
            <div className="text-center mt-12">
              <Button size="lg" className="bg-green-600 hover:bg-green-700 px-8 py-4 text-lg">
                {content.callToAction}
                <Heart className="w-5 h-5 ml-2" />
              </Button>
            </div>
          )}
        </div>
      </section>
    </BasePreview>
  )
}

// Contact Section Preview
export function LandingPageContactPreview({ 
  content, 
  configId,
  className,
  showValidation,
  showExport,
  onExport
}: LandingPagePreviewProps) {
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
      <section className="py-16 px-6 bg-white">
        <div className="max-w-6xl mx-auto">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-12">
            {/* Contact Info */}
            <div>
              <Badge className="bg-purple-100 text-purple-800 mb-4">
                Get in Touch
              </Badge>
              <h2 className="text-4xl font-bold text-gray-900 mb-6">
                {content.headline || 'Ready to Get Started?'}
              </h2>
              <p className="text-xl text-gray-600 mb-8">
                {content.text || 'Contact our team today and discover how we can help transform your business.'}
              </p>

              <div className="space-y-6 mb-8">
                <div className="flex items-center">
                  <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mr-4">
                    <Phone className="w-6 h-6 text-purple-600" />
                  </div>
                  <div>
                    <p className="font-semibold text-gray-900">Phone</p>
                    <p className="text-gray-600">+1 (555) 123-4567</p>
                  </div>
                </div>

                <div className="flex items-center">
                  <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mr-4">
                    <Mail className="w-6 h-6 text-purple-600" />
                  </div>
                  <div>
                    <p className="font-semibold text-gray-900">Email</p>
                    <p className="text-gray-600">hello@company.com</p>
                  </div>
                </div>

                <div className="flex items-center">
                  <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mr-4">
                    <MapPin className="w-6 h-6 text-purple-600" />
                  </div>
                  <div>
                    <p className="font-semibold text-gray-900">Address</p>
                    <p className="text-gray-600">123 Business St, City, State 12345</p>
                  </div>
                </div>

                <div className="flex items-center">
                  <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mr-4">
                    <Clock className="w-6 h-6 text-purple-600" />
                  </div>
                  <div>
                    <p className="font-semibold text-gray-900">Hours</p>
                    <p className="text-gray-600">Mon - Fri: 9AM - 6PM</p>
                  </div>
                </div>
              </div>
            </div>

            {/* Contact Form */}
            <Card className="p-8 bg-gray-50">
              <CardHeader className="p-0 pb-6">
                <CardTitle className="text-2xl">Send us a message</CardTitle>
              </CardHeader>
              <CardContent className="p-0 space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      First Name *
                    </label>
                    <Input placeholder="John" />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Last Name *
                    </label>
                    <Input placeholder="Doe" />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Email Address *
                  </label>
                  <Input type="email" placeholder="john@company.com" />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Company
                  </label>
                  <Input placeholder="Your Company Name" />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Message *
                  </label>
                  <textarea 
                    className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                    rows={4}
                    placeholder="Tell us about your project..."
                  />
                </div>

                {content.callToAction ? (
                  <Button className="w-full bg-purple-600 hover:bg-purple-700 py-3">
                    {content.callToAction}
                  </Button>
                ) : (
                  <Button className="w-full bg-purple-600 hover:bg-purple-700 py-3">
                    Send Message
                    <ArrowRight className="w-4 h-4 ml-2" />
                  </Button>
                )}

                <p className="text-xs text-gray-500 text-center">
                  We'll get back to you within 24 hours
                </p>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>
    </BasePreview>
  )
}