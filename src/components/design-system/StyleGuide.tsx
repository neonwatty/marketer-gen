"use client"

import * as React from "react"
import { useTheme } from "@/components/providers/theme-provider"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"

export function StyleGuide() {
  const { resolvedTheme } = useTheme()

  return (
    <div className="max-w-7xl mx-auto p-6 space-y-12">
      {/* Header */}
      <div className="text-center space-y-4">
        <h1 className="text-4xl font-bold text-gradient-primary">Design System</h1>
        <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
          A comprehensive design system for the Marketer Gen application with consistent theming, 
          typography, and component patterns.
        </p>
        <div className="flex items-center justify-center gap-2">
          <Badge variant="outline">Current theme: {resolvedTheme}</Badge>
          <Badge variant="secondary">v1.0.0</Badge>
        </div>
      </div>

      {/* Color System */}
      <section className="space-y-6">
        <h2 className="text-3xl font-semibold">Color System</h2>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <ColorPalette
            title="Primary Colors"
            colors={[
              { name: "Primary", value: "hsl(var(--primary))", textColor: "hsl(var(--primary-foreground))" },
              { name: "Primary Foreground", value: "hsl(var(--primary-foreground))", textColor: "hsl(var(--primary))" },
              { name: "Secondary", value: "hsl(var(--secondary))", textColor: "hsl(var(--secondary-foreground))" },
              { name: "Secondary Foreground", value: "hsl(var(--secondary-foreground))", textColor: "hsl(var(--secondary))" },
            ]}
          />
          
          <ColorPalette
            title="Neutral Colors"
            colors={[
              { name: "Background", value: "hsl(var(--background))", textColor: "hsl(var(--foreground))" },
              { name: "Foreground", value: "hsl(var(--foreground))", textColor: "hsl(var(--background))" },
              { name: "Muted", value: "hsl(var(--muted))", textColor: "hsl(var(--muted-foreground))" },
              { name: "Muted Foreground", value: "hsl(var(--muted-foreground))", textColor: "hsl(var(--muted))" },
            ]}
          />
          
          <ColorPalette
            title="Status Colors"
            colors={[
              { name: "Success", value: "hsl(var(--success))", textColor: "hsl(var(--success-foreground))" },
              { name: "Warning", value: "hsl(var(--warning))", textColor: "hsl(var(--warning-foreground))" },
              { name: "Destructive", value: "hsl(var(--destructive))", textColor: "hsl(var(--destructive-foreground))" },
              { name: "Info", value: "hsl(var(--info))", textColor: "hsl(var(--info-foreground))" },
            ]}
          />
        </div>
      </section>

      {/* Typography */}
      <section className="space-y-6">
        <h2 className="text-3xl font-semibold">Typography</h2>
        
        <Card>
          <CardContent className="p-6">
            <div className="space-y-4">
              <div>
                <h1 className="text-5xl font-bold">Heading 1</h1>
                <p className="text-sm text-muted-foreground mt-1">text-5xl font-bold</p>
              </div>
              <div>
                <h2 className="text-4xl font-semibold">Heading 2</h2>
                <p className="text-sm text-muted-foreground mt-1">text-4xl font-semibold</p>
              </div>
              <div>
                <h3 className="text-3xl font-semibold">Heading 3</h3>
                <p className="text-sm text-muted-foreground mt-1">text-3xl font-semibold</p>
              </div>
              <div>
                <h4 className="text-2xl font-semibold">Heading 4</h4>
                <p className="text-sm text-muted-foreground mt-1">text-2xl font-semibold</p>
              </div>
              <div>
                <h5 className="text-xl font-semibold">Heading 5</h5>
                <p className="text-sm text-muted-foreground mt-1">text-xl font-semibold</p>
              </div>
              <div>
                <h6 className="text-lg font-semibold">Heading 6</h6>
                <p className="text-sm text-muted-foreground mt-1">text-lg font-semibold</p>
              </div>
              <div>
                <p className="text-base">Body text - Regular paragraph text with good readability and appropriate line height.</p>
                <p className="text-sm text-muted-foreground mt-1">text-base</p>
              </div>
              <div>
                <p className="text-sm text-muted-foreground">Small text - Used for captions, labels, and secondary information.</p>
                <p className="text-sm text-muted-foreground mt-1">text-sm text-muted-foreground</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </section>

      {/* Button Components */}
      <section className="space-y-6">
        <h2 className="text-3xl font-semibold">Button Variants</h2>
        
        <Card>
          <CardContent className="p-6">
            <div className="space-y-4">
              <div className="flex flex-wrap gap-4">
                <Button>Primary</Button>
                <Button variant="secondary">Secondary</Button>
                <Button variant="destructive">Destructive</Button>
                <Button variant="outline">Outline</Button>
                <Button variant="ghost">Ghost</Button>
                <Button variant="link">Link</Button>
              </div>
              
              <div className="flex flex-wrap gap-4 items-center">
                <Button size="sm">Small</Button>
                <Button size="default">Default</Button>
                <Button size="lg">Large</Button>
                <Button size="icon">⭐</Button>
              </div>
              
              <div className="flex flex-wrap gap-4">
                <Button disabled>Disabled</Button>
                <Button variant="outline" disabled>Disabled Outline</Button>
              </div>
            </div>
          </CardContent>
        </Card>
      </section>

      {/* Badge Components */}
      <section className="space-y-6">
        <h2 className="text-3xl font-semibold">Badge Variants</h2>
        
        <Card>
          <CardContent className="p-6">
            <div className="flex flex-wrap gap-4">
              <Badge>Default</Badge>
              <Badge variant="secondary">Secondary</Badge>
              <Badge variant="destructive">Destructive</Badge>
              <Badge variant="outline">Outline</Badge>
            </div>
          </CardContent>
        </Card>
      </section>

      {/* Form Components */}
      <section className="space-y-6">
        <h2 className="text-3xl font-semibold">Form Components</h2>
        
        <Card>
          <CardContent className="p-6">
            <form className="space-y-4 max-w-md">
              <div>
                <Label htmlFor="email">Email</Label>
                <Input id="email" type="email" placeholder="Enter your email" />
              </div>
              
              <div>
                <Label htmlFor="message">Message</Label>
                <Textarea id="message" placeholder="Enter your message" />
              </div>
              
              <Button type="submit">Submit</Button>
            </form>
          </CardContent>
        </Card>
      </section>

      {/* Spacing System */}
      <section className="space-y-6">
        <h2 className="text-3xl font-semibold">Spacing System</h2>
        
        <Card>
          <CardContent className="p-6">
            <div className="space-y-4">
              {[
                { size: "xs", value: "0.5rem", class: "p-2" },
                { size: "sm", value: "0.75rem", class: "p-3" },
                { size: "md", value: "1rem", class: "p-4" },
                { size: "lg", value: "1.5rem", class: "p-6" },
                { size: "xl", value: "2rem", class: "p-8" },
                { size: "2xl", value: "2.5rem", class: "p-10" },
              ].map(({ size, value, class: className }) => (
                <div key={size} className="flex items-center gap-4">
                  <div className="w-16 text-sm font-medium">{size}</div>
                  <div className="text-sm text-muted-foreground w-20">{value}</div>
                  <div className={`bg-primary/20 ${className}`}>
                    <div className="bg-primary/40 w-8 h-8 rounded"></div>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </section>

      {/* Border Radius */}
      <section className="space-y-6">
        <h2 className="text-3xl font-semibold">Border Radius</h2>
        
        <Card>
          <CardContent className="p-6">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              {[
                { size: "sm", class: "rounded-sm" },
                { size: "md", class: "rounded-md" },
                { size: "lg", class: "rounded-lg" },
                { size: "xl", class: "rounded-xl" },
                { size: "2xl", class: "rounded-2xl" },
                { size: "full", class: "rounded-full" },
              ].map(({ size, class: className }) => (
                <div key={size} className="text-center space-y-2">
                  <div className={`w-16 h-16 bg-primary mx-auto ${className}`}></div>
                  <p className="text-sm font-medium">{size}</p>
                  <p className="text-xs text-muted-foreground">{className}</p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </section>

      {/* Shadows */}
      <section className="space-y-6">
        <h2 className="text-3xl font-semibold">Shadow System</h2>
        
        <Card>
          <CardContent className="p-6">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {[
                { size: "sm", class: "shadow-sm" },
                { size: "md", class: "shadow-md" },
                { size: "lg", class: "shadow-lg" },
                { size: "xl", class: "shadow-xl" },
                { size: "2xl", class: "shadow-2xl" },
              ].map(({ size, class: className }) => (
                <div key={size} className="text-center space-y-2">
                  <div className={`w-20 h-20 bg-card mx-auto rounded-lg ${className}`}></div>
                  <p className="text-sm font-medium">{size}</p>
                  <p className="text-xs text-muted-foreground">{className}</p>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </section>

      {/* Utility Classes */}
      <section className="space-y-6">
        <h2 className="text-3xl font-semibold">Utility Classes</h2>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <Card>
            <CardHeader>
              <CardTitle>Animation Classes</CardTitle>
              <CardDescription>Pre-built animation utilities</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-2">
                <div className="p-4 bg-muted rounded animate-fade-in">animate-fade-in</div>
                <div className="p-4 bg-muted rounded animate-slide-up">animate-slide-up</div>
                <div className="p-4 bg-muted rounded animate-scale-in">animate-scale-in</div>
              </div>
            </CardContent>
          </Card>
          
          <Card>
            <CardHeader>
              <CardTitle>Status Classes</CardTitle>
              <CardDescription>Status indicator utilities</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-2">
                <div className="p-2 rounded status-success">status-success</div>
                <div className="p-2 rounded status-warning">status-warning</div>
                <div className="p-2 rounded status-info">status-info</div>
                <div className="p-2 rounded status-error">status-error</div>
              </div>
            </CardContent>
          </Card>
        </div>
      </section>
    </div>
  )
}

function ColorPalette({ title, colors }: { title: string; colors: Array<{ name: string; value: string; textColor: string }> }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-lg">{title}</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-2">
          {colors.map(({ name, value, textColor }) => (
            <div
              key={name}
              className="flex items-center justify-between p-3 rounded-md"
              style={{ backgroundColor: value, color: textColor }}
            >
              <span className="font-medium text-sm">{name}</span>
              <code className="text-xs opacity-75">{value}</code>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}