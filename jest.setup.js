import '@testing-library/jest-dom'
import { toHaveNoViolations } from 'jest-axe'

// Extend Jest matchers to include jest-axe accessibility testing
expect.extend(toHaveNoViolations)

// Set up test environment variables
process.env.OPENAI_API_KEY = 'test-api-key-for-testing'
process.env.NODE_ENV = 'test'

// Polyfill for Request/Response in Node.js environment
require('whatwg-fetch')

// Polyfill for Web Streams API in Node.js environment
if (!global.TransformStream) {
  const { ReadableStream, WritableStream, TransformStream } = require('node:stream/web')
  global.ReadableStream = ReadableStream
  global.WritableStream = WritableStream  
  global.TransformStream = TransformStream
}

// Add setImmediate polyfill for Node.js compatibility
if (!global.setImmediate) {
  global.setImmediate = setTimeout
}

// Also add undici for Node.js 18+ compatibility
if (!global.Request || !global.Response) {
  const { Request, Response, Headers, FormData } = require('undici')
  
  // Extend Response to include static json method
  class ExtendedResponse extends Response {
    static json(data, init) {
      return new ExtendedResponse(JSON.stringify(data), {
        ...init,
        headers: {
          'content-type': 'application/json',
          ...init?.headers,
        },
      })
    }
  }
  
  global.Request = Request
  global.Response = ExtendedResponse
  global.Headers = Headers
  global.FormData = FormData
}

// Mock Next.js Image component
jest.mock('next/image', () => ({
  __esModule: true,
  default: (props) => {
    // eslint-disable-next-line @next/next/no-img-element, jsx-a11y/alt-text
    return <img {...props} />
  },
}))

// Mock React
import React from 'react'
global.React = React

// Mock NextResponse and NextRequest for all tests
jest.mock('next/server', () => ({
  NextResponse: {
    json: (data, init) => {
      // Create a mock response object instead of using global.Response
      const mockResponse = {
        json: () => Promise.resolve(data),
        text: () => Promise.resolve(JSON.stringify(data)),
        status: init?.status || 200,
        statusText: 'OK',
        ok: (init?.status || 200) >= 200 && (init?.status || 200) < 300,
        headers: new Map(Object.entries({
          'content-type': 'application/json',
          ...init?.headers,
        })),
        body: JSON.stringify(data),
        clone: jest.fn(),
        arrayBuffer: jest.fn(),
        blob: jest.fn(),
        formData: jest.fn(),
      }
      return mockResponse
    },
    redirect: jest.fn(),
    rewrite: jest.fn(),
  },
  NextRequest: class MockNextRequest {
    constructor(input, init) {
      this.url = typeof input === 'string' ? input : input.url
      this.method = init?.method || 'GET'
      this.headers = new Map(Object.entries(init?.headers || {}))
      this.nextUrl = new URL(this.url)
      this.geo = {}
      this.ip = '127.0.0.1'
      this.body = init?.body
    }
    
    json() {
      return Promise.resolve(this.body ? JSON.parse(this.body) : {})
    }
    
    text() {
      return Promise.resolve(this.body || '')
    }
    
    clone() {
      return new MockNextRequest(this.url, { 
        method: this.method, 
        headers: Object.fromEntries(this.headers),
        body: this.body 
      })
    }
  },
}))

// Mock URL.createObjectURL for file uploads
global.URL.createObjectURL = jest.fn(() => 'mocked-object-url')
global.URL.revokeObjectURL = jest.fn()

// Mock PDF and document parsing libraries to prevent file system access
jest.mock('pdf-parse', () => jest.fn((buffer) => {
  // Simulate real pdf-parse behavior - throw error for invalid PDF data
  const bufferString = buffer.toString('utf-8')
  if (!bufferString.startsWith('%PDF-')) {
    throw new Error('Invalid PDF structure')
  }
  return Promise.resolve({ text: '' })
}))
jest.mock('mammoth', () => ({
  extractRawText: jest.fn()
}))

// Mock hasPointerCapture for Radix UI Select component (only in DOM environment)
if (typeof Element !== 'undefined') {
  Element.prototype.hasPointerCapture = jest.fn(() => false)
  Element.prototype.setPointerCapture = jest.fn()
  Element.prototype.releasePointerCapture = jest.fn()
  
  // Mock scrollIntoView for jsdom compatibility
  Element.prototype.scrollIntoView = jest.fn()
}

// Mock next-auth globally to avoid ES module issues
jest.mock('next-auth', () => ({
  getServerSession: jest.fn(),
  NextAuth: jest.fn().mockReturnValue({
    handlers: { GET: jest.fn(), POST: jest.fn() },
    auth: jest.fn(),
    signIn: jest.fn(),
    signOut: jest.fn(),
  }),
  AuthError: class AuthError extends Error {
    constructor(message) {
      super(message)
      this.name = 'AuthError'
    }
  },
}))

// Mock next-auth/next
jest.mock('next-auth/next', () => ({
  withAuth: jest.fn((handler) => handler),
}))

// Mock auth lib
jest.mock('@/lib/auth', () => ({
  authOptions: {
    providers: [],
    adapter: {},
    session: { strategy: 'jwt' },
    callbacks: {
      jwt: jest.fn(),
      session: jest.fn(),
    },
  },
}))

// Mock use-mobile hook
jest.mock('@/hooks/use-mobile', () => ({
  useIsMobile: () => false,
}))

// Mock Recharts components for testing
jest.mock('recharts', () => ({
  ResponsiveContainer: ({ children }) => <div data-testid="recharts-responsive-container">{children}</div>,
  AreaChart: ({ children }) => <div data-testid="recharts-area-chart">{children}</div>,
  Area: () => <div data-testid="recharts-area" />,
  XAxis: () => <div data-testid="recharts-x-axis" />,
  YAxis: () => <div data-testid="recharts-y-axis" />,
  Tooltip: () => <div data-testid="recharts-tooltip" />,
  PieChart: ({ children }) => <div data-testid="recharts-pie-chart">{children}</div>,
  Pie: () => <div data-testid="recharts-pie" />,
  Cell: () => <div data-testid="recharts-cell" />,
  BarChart: ({ children }) => <div data-testid="recharts-bar-chart">{children}</div>,
  Bar: () => <div data-testid="recharts-bar" />,
  LineChart: ({ children }) => <div data-testid="recharts-line-chart">{children}</div>,
  Line: () => <div data-testid="recharts-line" />,
  Legend: () => <div data-testid="recharts-legend" />,
}))

// Mock Radix UI components for better test compatibility
const forwardRef = React.forwardRef

// Mock our custom UI Dialog components directly
jest.mock('@/components/ui/dialog', () => ({
  Dialog: ({ children, onOpenChange, open, ...props }) => {
    React.useEffect(() => {
      if (!open) return
      
      const handleKeyDown = (e) => {
        if (e.key === 'Escape' && onOpenChange) {
          onOpenChange(false)
        }
      }
      
      document.addEventListener('keydown', handleKeyDown)
      return () => document.removeEventListener('keydown', handleKeyDown)
    }, [open, onOpenChange])
    
    return <div data-testid="ui-dialog" data-open={open} {...props}>{open ? children : null}</div>
  },
  DialogContent: ({ children, ...props }) => <div data-testid="ui-dialog-content" {...props}>{children}</div>,
  DialogDescription: ({ children, ...props }) => <p data-testid="ui-dialog-description" {...props}>{children}</p>,
  DialogFooter: ({ children, ...props }) => <div data-testid="ui-dialog-footer" {...props}>{children}</div>,
  DialogHeader: ({ children, ...props }) => <div data-testid="ui-dialog-header" {...props}>{children}</div>,
  DialogTitle: ({ children, ...props }) => <h2 data-testid="ui-dialog-title" {...props}>{children}</h2>,
  DialogTrigger: ({ children, asChild, ...props }) => {
    if (asChild && React.isValidElement(children)) {
      return React.cloneElement(children, { 'data-testid': 'ui-dialog-trigger', ...props })
    }
    return <button data-testid="ui-dialog-trigger" {...props}>{children}</button>
  },
}))

// Mock our custom UI Select components directly
jest.mock('@/components/ui/select', () => ({
  Select: ({ children, onValueChange, value, ...props }) => <div data-testid="ui-select" data-value={value} {...props}>{children}</div>,
  SelectContent: ({ children, ...props }) => <div data-testid="ui-select-content" {...props}>{children}</div>,
  SelectItem: ({ children, value, ...props }) => <div data-testid="ui-select-item" data-value={value} {...props} onClick={() => {}}>{children}</div>,
  SelectTrigger: ({ children, ...props }) => (
    <button 
      data-testid="ui-select-trigger" 
      role="combobox" 
      aria-expanded={false}
      aria-controls="select-content"
      aria-label="Select an option"
      {...props}
    >
      {children}
    </button>
  ),
  SelectValue: ({ children, placeholder, ...props }) => <span data-testid="ui-select-value" {...props}>{children || placeholder}</span>,
}))

// Mock other UI components that might be missing
jest.mock('@/components/ui/avatar', () => ({
  Avatar: ({ children, ...props }) => <div data-testid="ui-avatar" {...props}>{children}</div>,
  AvatarFallback: ({ children, ...props }) => <div data-testid="ui-avatar-fallback" {...props}>{children}</div>,
  AvatarImage: ({ src, alt, ...props }) => <img data-testid="ui-avatar-image" src={src} alt={alt} {...props} />,
}))

jest.mock('@/components/ui/alert', () => ({
  Alert: ({ children, variant = 'default', className, ...props }) => (
    <div 
      data-testid="ui-alert" 
      role="alert"
      className={`relative w-full rounded-lg border px-4 py-3 text-sm grid has-[>svg]:grid-cols-[calc(var(--spacing)*4)_1fr] grid-cols-[0_1fr] has-[>svg]:gap-x-3 gap-y-0.5 items-start [&>svg]:size-4 [&>svg]:translate-y-0.5 [&>svg]:text-current ${
        variant === 'destructive' 
          ? 'text-destructive bg-card [&>svg]:text-current *:data-[slot=alert-description]:text-destructive/90' 
          : 'bg-card text-card-foreground'
      } ${className || ''}`}
      {...props}
    >
      {children}
    </div>
  ),
  AlertDescription: ({ children, className, ...props }) => (
    <div 
      data-testid="ui-alert-description" 
      className={`text-muted-foreground col-start-2 grid justify-items-start gap-1 text-sm [&_p]:leading-relaxed ${className || ''}`}
      {...props}
    >
      {children}
    </div>
  ),
  AlertTitle: ({ children, className, ...props }) => (
    <div 
      data-testid="ui-alert-title" 
      className={`col-start-2 line-clamp-1 min-h-4 font-medium tracking-tight ${className || ''}`}
      {...props}
    >
      {children}
    </div>
  ),
}))

jest.mock('@/components/ui/badge', () => ({
  Badge: ({ children, variant = 'default', className, ...props }) => {
    const getVariantClasses = (variant) => {
      switch (variant) {
        case 'secondary':
          return 'border-transparent bg-secondary text-secondary-foreground [a&]:hover:bg-secondary/90'
        case 'destructive':
          return 'border-transparent bg-destructive text-white [a&]:hover:bg-destructive/90 focus-visible:ring-destructive/20 dark:focus-visible:ring-destructive/40 dark:bg-destructive/60'
        case 'outline':
          return 'text-foreground [a&]:hover:bg-accent [a&]:hover:text-accent-foreground'
        default:
          return 'border-transparent bg-primary text-primary-foreground [a&]:hover:bg-primary/90'
      }
    }
    
    return (
      <span 
        data-testid="ui-badge" 
        data-variant={variant}
        className={`inline-flex items-center justify-center rounded-md border px-2 py-0.5 text-xs font-medium w-fit whitespace-nowrap shrink-0 [&>svg]:size-3 gap-1 [&>svg]:pointer-events-none focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px] aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive transition-[color,box-shadow] overflow-hidden ${getVariantClasses(variant)} ${className || ''}`}
        {...props}
      >
        {children}
      </span>
    )
  },
}))

jest.mock('@/components/ui/button', () => ({
  Button: ({ children, variant, size, asChild, ...props }) => {
    if (asChild && React.isValidElement(children)) {
      return React.cloneElement(children, { 'data-testid': 'ui-button', 'data-variant': variant, 'data-size': size, ...props })
    }
    return <button data-testid="ui-button" data-variant={variant} data-size={size} {...props}>{children}</button>
  },
}))

jest.mock('@/components/ui/card', () => ({
  Card: ({ children, className, ...props }) => (
    <div 
      data-slot="card"
      data-testid="ui-card" 
      className={`bg-card text-card-foreground flex flex-col gap-6 rounded-xl border py-6 shadow-sm ${className || ''}`}
      {...props}
    >
      {children}
    </div>
  ),
  CardAction: ({ children, className, ...props }) => (
    <div 
      data-testid="ui-card-action" 
      className={`col-start-2 row-span-2 row-start-1 self-start justify-self-end ${className || ''}`}
      {...props}
    >
      {children}
    </div>
  ),
  CardContent: ({ children, className, ...props }) => (
    <div 
      data-testid="ui-card-content" 
      className={`px-6 ${className || ''}`}
      {...props}
    >
      {children}
    </div>
  ),
  CardDescription: ({ children, className, ...props }) => (
    <div 
      data-testid="ui-card-description" 
      className={`text-muted-foreground text-sm ${className || ''}`}
      {...props}
    >
      {children}
    </div>
  ),
  CardFooter: ({ children, className, ...props }) => (
    <div 
      data-testid="ui-card-footer" 
      className={`flex items-center px-6 [.border-t]:pt-6 ${className || ''}`}
      {...props}
    >
      {children}
    </div>
  ),
  CardHeader: ({ children, className, ...props }) => (
    <div 
      data-testid="ui-card-header" 
      className={`@container/card-header grid auto-rows-min grid-rows-[auto_auto] items-start gap-1.5 px-6 has-data-[slot=card-action]:grid-cols-[1fr_auto] [.border-b]:pb-6 ${className || ''}`}
      {...props}
    >
      {children}
    </div>
  ),
  CardTitle: ({ children, className, ...props }) => (
    <h3 
      data-testid="ui-card-title" 
      className={`leading-none font-semibold ${className || ''}`}
      {...props}
    >
      {children}
    </h3>
  ),
}))

jest.mock('@/components/ui/input', () => ({
  Input: ({ className, ...props }) => (
    <input 
      data-testid="ui-input" 
      className={`flex h-9 w-full rounded-md border bg-transparent px-3 py-1 text-base shadow-xs transition-[color,box-shadow] outline-none file:inline-flex file:h-7 file:border-0 file:bg-transparent file:text-sm file:font-medium disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 md:text-sm focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px] aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive ${className || ''}`}
      {...props} 
    />
  ),
}))

jest.mock('@/components/ui/label', () => ({
  Label: ({ children, className, ...props }) => (
    <label 
      data-testid="ui-label" 
      className={`flex items-center gap-2 text-sm leading-none font-medium select-none group-data-[disabled=true]:pointer-events-none group-data-[disabled=true]:opacity-50 peer-disabled:cursor-not-allowed peer-disabled:opacity-50 ${className || ''}`}
      {...props}
    >
      {children}
    </label>
  ),
}))

jest.mock('@/components/ui/textarea', () => ({
  Textarea: ({ ...props }) => <textarea data-testid="ui-textarea" {...props} />,
}))

// Mock ReactFlow for journey builder tests
jest.mock('reactflow', () => ({
  ReactFlow: ({ children, ...props }) => <div data-testid="react-flow" {...props}>{children}</div>,
  Background: ({ variant, gap, size, ...props }) => <div data-testid="react-flow-background" data-variant={variant} {...props} />,
  BackgroundVariant: {
    Dots: 'dots',
    Lines: 'lines',
    Cross: 'cross',
  },
  Controls: ({ ...props }) => <div data-testid="react-flow-controls" {...props} />,
  MiniMap: ({ ...props }) => <div data-testid="react-flow-minimap" {...props} />,
  addEdge: jest.fn((newConnection, edges) => [...edges, newConnection]),
  useEdgesState: jest.fn(() => [[], jest.fn(), jest.fn()]),
  useNodesState: jest.fn(() => [[], jest.fn(), jest.fn()]),
  Handle: ({ type, position, ...props }) => <div data-testid="react-flow-handle" data-type={type} data-position={position} {...props} />,
  Position: {
    Top: 'top',
    Right: 'right',
    Bottom: 'bottom',
    Left: 'left',
  },
}))

jest.mock('@/components/ui/progress', () => ({
  Progress: ({ value, ...props }) => (
    <div 
      data-testid="ui-progress" 
      data-value={value} 
      role="progressbar" 
      aria-valuenow={value} 
      aria-valuemin={0} 
      aria-valuemax={100}
      {...props} 
    />
  ),
}))

jest.mock('@/components/ui/skeleton', () => ({
  Skeleton: ({ className, ...props }) => <div data-slot="skeleton" data-testid="ui-skeleton" className={className} {...props} />,
}))

jest.mock('@/components/ui/sidebar', () => ({
  SidebarTrigger: ({ children, className, ...props }) => (
    <button 
      data-testid="sidebar-trigger" 
      className={className}
      {...props}
    >
      {children || 'Menu'}
    </button>
  ),
  Sidebar: ({ children, ...props }) => <div data-testid="ui-sidebar" {...props}>{children}</div>,
  SidebarContent: ({ children, ...props }) => <div data-testid="ui-sidebar-content" {...props}>{children}</div>,
  SidebarGroup: ({ children, ...props }) => <div data-testid="ui-sidebar-group" {...props}>{children}</div>,
  SidebarGroupContent: ({ children, ...props }) => <div data-testid="ui-sidebar-group-content" {...props}>{children}</div>,
  SidebarGroupLabel: ({ children, ...props }) => <div data-testid="ui-sidebar-group-label" {...props}>{children}</div>,
  SidebarHeader: ({ children, ...props }) => <div data-testid="ui-sidebar-header" {...props}>{children}</div>,
  SidebarFooter: ({ children, ...props }) => <div data-testid="ui-sidebar-footer" {...props}>{children}</div>,
  SidebarMenu: ({ children, ...props }) => <div data-testid="ui-sidebar-menu" {...props}>{children}</div>,
  SidebarMenuItem: ({ children, ...props }) => <div data-testid="ui-sidebar-menu-item" {...props}>{children}</div>,
  SidebarMenuButton: ({ children, ...props }) => <button data-testid="ui-sidebar-menu-button" {...props}>{children}</button>,
  SidebarProvider: ({ children, ...props }) => <div data-testid="ui-sidebar-provider" {...props}>{children}</div>,
  SidebarInset: ({ children, ...props }) => <div data-testid="ui-sidebar-inset" {...props}>{children}</div>,
  useSidebar: () => ({
    state: 'expanded',
    open: true,
    setOpen: jest.fn(),
    openMobile: false,
    setOpenMobile: jest.fn(),
    isMobile: false,
    toggleSidebar: jest.fn(),
  }),
}))

jest.mock('@/components/ui/dropdown-menu', () => ({
  DropdownMenu: ({ children, open, onOpenChange, ...props }) => <div data-testid="ui-dropdown-menu" data-open={open} {...props}>{children}</div>,
  DropdownMenuContent: ({ children, forceMount, ...props }) => <div data-testid="ui-dropdown-menu-content" {...props}>{children}</div>,
  DropdownMenuItem: ({ children, onClick, variant, disabled, ...props }) => (
    <div 
      data-testid="ui-dropdown-menu-item" 
      data-variant={variant}
      data-disabled={disabled}
      onClick={disabled ? undefined : onClick}
      {...props}
    >
      {children}
    </div>
  ),
  DropdownMenuLabel: ({ children, className, ...props }) => (
    <div 
      data-testid="ui-dropdown-menu-label" 
      className={className}
      {...props}
    >
      {children}
    </div>
  ),
  DropdownMenuSeparator: ({ ...props }) => <div data-testid="ui-dropdown-menu-separator" {...props} />,
  DropdownMenuTrigger: ({ children, asChild, ...props }) => {
    if (asChild && React.isValidElement(children)) {
      return React.cloneElement(children, { 'data-testid': 'ui-dropdown-menu-trigger', 'aria-expanded': 'false', 'aria-haspopup': 'menu', ...props })
    }
    return <button data-testid="ui-dropdown-menu-trigger" aria-expanded="false" aria-haspopup="menu" {...props}>{children}</button>
  },
}))

jest.mock('@radix-ui/react-dialog', () => ({
  Root: forwardRef(({ children, ...props }, ref) => {
    const { asChild, ...otherProps } = props
    return <div ref={ref} data-testid="dialog-root" {...otherProps}>{children}</div>
  }),
  Portal: forwardRef(({ children, ...props }, ref) => {
    const { asChild, ...otherProps } = props
    return <div ref={ref} data-testid="dialog-portal" {...otherProps}>{children}</div>
  }),
  Overlay: forwardRef(({ children, ...props }, ref) => {
    const { asChild, ...otherProps } = props
    return <div ref={ref} data-testid="dialog-overlay" {...otherProps}>{children}</div>
  }),
  Content: forwardRef(({ children, ...props }, ref) => {
    const { asChild, ...otherProps } = props
    return <div ref={ref} data-testid="dialog-content" {...otherProps}>{children}</div>
  }),
  Trigger: forwardRef(({ children, asChild, ...props }, ref) => {
    if (asChild && React.isValidElement(children)) {
      return React.cloneElement(children, { ref, 'data-testid': 'dialog-trigger', ...props })
    }
    return <button ref={ref} data-testid="dialog-trigger" {...props}>{children}</button>
  }),
  Close: forwardRef(({ children, asChild, ...props }, ref) => {
    if (asChild && React.isValidElement(children)) {
      return React.cloneElement(children, { ref, 'data-testid': 'dialog-close', ...props })
    }
    return <button ref={ref} data-testid="dialog-close" {...props}>{children}</button>
  }),
  Title: forwardRef(({ children, ...props }, ref) => {
    const { asChild, ...otherProps } = props
    return <h2 ref={ref} data-testid="dialog-title" {...otherProps}>{children}</h2>
  }),
  Description: forwardRef(({ children, ...props }, ref) => {
    const { asChild, ...otherProps } = props
    return <p ref={ref} data-testid="dialog-description" {...otherProps}>{children}</p>
  }),
}))

jest.mock('@radix-ui/react-avatar', () => ({
  Root: forwardRef(({ children, ...props }, ref) => {
    const { asChild, ...otherProps } = props
    return <div ref={ref} data-testid="avatar-root" {...otherProps}>{children}</div>
  }),
  Image: forwardRef(({ children, ...props }, ref) => {
    const { asChild, ...otherProps } = props
    return <img ref={ref} data-testid="avatar-image" alt={props.alt || 'avatar'} {...otherProps} />
  }),
  Fallback: forwardRef(({ children, ...props }, ref) => {
    const { asChild, ...otherProps } = props
    return <div ref={ref} data-testid="avatar-fallback" {...otherProps}>{children}</div>
  }),
}))

jest.mock('@radix-ui/react-select', () => ({
  Root: forwardRef(({ children, ...props }, ref) => {
    const { asChild, ...otherProps } = props
    return <div ref={ref} data-testid="select-root" {...otherProps}>{children}</div>
  }),
  Trigger: forwardRef(({ children, asChild, ...props }, ref) => {
    if (asChild && React.isValidElement(children)) {
      return React.cloneElement(children, { ref, 'data-testid': 'select-trigger', role: 'combobox', 'aria-expanded': 'false', 'aria-controls': 'select-content', ...props })
    }
    return <button ref={ref} data-testid="select-trigger" role="combobox" aria-expanded="false" aria-controls="select-content" {...props}>{children}</button>
  }),
  Content: forwardRef(({ children, ...props }, ref) => {
    const { asChild, ...otherProps } = props
    return <div ref={ref} data-testid="select-content" {...otherProps}>{children}</div>
  }),
  Item: forwardRef(({ children, value, asChild, ...props }, ref) => {
    const { asChild: _, ...otherProps } = props
    return <div ref={ref} data-testid="select-item" data-value={value} {...otherProps}>{children}</div>
  }),
  Value: forwardRef(({ children, placeholder, ...props }, ref) => {
    const { asChild, ...otherProps } = props
    return <span ref={ref} data-testid="select-value" {...otherProps}>{children || placeholder}</span>
  }),
  Portal: forwardRef(({ children, ...props }, ref) => {
    const { asChild, ...otherProps } = props
    return <div ref={ref} data-testid="select-portal" {...otherProps}>{children}</div>
  }),
  Viewport: forwardRef(({ children, ...props }, ref) => {
    const { asChild, ...otherProps } = props
    return <div ref={ref} data-testid="select-viewport" {...otherProps}>{children}</div>
  }),
}))
