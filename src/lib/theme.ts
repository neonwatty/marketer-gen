export interface ThemeColors {
  background: string
  foreground: string
  card: string
  cardForeground: string
  popover: string
  popoverForeground: string
  primary: string
  primaryForeground: string
  secondary: string
  secondaryForeground: string
  muted: string
  mutedForeground: string
  accent: string
  accentForeground: string
  destructive: string
  destructiveForeground: string
  border: string
  input: string
  ring: string
  success: string
  successForeground: string
  warning: string
  warningForeground: string
  info: string
  infoForeground: string
  brandPrimary: string
  brandSecondary: string
  brandAccent: string
}

export interface ThemeRadius {
  default: string
  sm: string
  md: string
  lg: string
  xl: string
  '2xl': string
  full: string
}

export interface ThemeSpacing {
  xs: string
  sm: string
  md: string
  lg: string
  xl: string
  '2xl': string
  '3xl': string
}

export interface ThemeTypography {
  fontSizes: {
    xs: string
    sm: string
    base: string
    lg: string
    xl: string
    '2xl': string
    '3xl': string
    '4xl': string
    '5xl': string
  }
  lineHeights: {
    none: number
    tight: number
    snug: number
    normal: number
    relaxed: number
    loose: number
  }
  fontWeights: {
    thin: number
    light: number
    normal: number
    medium: number
    semibold: number
    bold: number
    extrabold: number
    black: number
  }
}

export interface ThemeShadows {
  xs: string
  sm: string
  md: string
  lg: string
  xl: string
  '2xl': string
}

export interface ThemeAnimations {
  durations: {
    75: string
    100: string
    150: string
    200: string
    300: string
    500: string
    700: string
    1000: string
  }
  easings: {
    linear: string
    in: string
    out: string
    inOut: string
  }
}

export interface Theme {
  colors: ThemeColors
  radius: ThemeRadius
  spacing: ThemeSpacing
  typography: ThemeTypography
  shadows: ThemeShadows
  animations: ThemeAnimations
}

export interface ThemeConfig {
  light: Theme
  dark: Theme
  default: 'light' | 'dark'
}

// Theme tokens that map to CSS variables
export const themeTokens = {
  colors: {
    background: 'hsl(var(--background))',
    foreground: 'hsl(var(--foreground))',
    card: 'hsl(var(--card))',
    cardForeground: 'hsl(var(--card-foreground))',
    popover: 'hsl(var(--popover))',
    popoverForeground: 'hsl(var(--popover-foreground))',
    primary: 'hsl(var(--primary))',
    primaryForeground: 'hsl(var(--primary-foreground))',
    secondary: 'hsl(var(--secondary))',
    secondaryForeground: 'hsl(var(--secondary-foreground))',
    muted: 'hsl(var(--muted))',
    mutedForeground: 'hsl(var(--muted-foreground))',
    accent: 'hsl(var(--accent))',
    accentForeground: 'hsl(var(--accent-foreground))',
    destructive: 'hsl(var(--destructive))',
    destructiveForeground: 'hsl(var(--destructive-foreground))',
    border: 'hsl(var(--border))',
    input: 'hsl(var(--input))',
    ring: 'hsl(var(--ring))',
    success: 'hsl(var(--success))',
    successForeground: 'hsl(var(--success-foreground))',
    warning: 'hsl(var(--warning))',
    warningForeground: 'hsl(var(--warning-foreground))',
    info: 'hsl(var(--info))',
    infoForeground: 'hsl(var(--info-foreground))',
    brandPrimary: 'hsl(var(--brand-primary))',
    brandSecondary: 'hsl(var(--brand-secondary))',
    brandAccent: 'hsl(var(--brand-accent))',
  },
  radius: {
    default: 'var(--radius)',
    sm: 'var(--radius-sm)',
    md: 'var(--radius-md)',
    lg: 'var(--radius-lg)',
    xl: 'var(--radius-xl)',
    '2xl': 'var(--radius-2xl)',
    full: 'var(--radius-full)',
  },
  spacing: {
    xs: 'var(--spacing-xs)',
    sm: 'var(--spacing-sm)',
    md: 'var(--spacing-md)',
    lg: 'var(--spacing-lg)',
    xl: 'var(--spacing-xl)',
    '2xl': 'var(--spacing-2xl)',
    '3xl': 'var(--spacing-3xl)',
  },
  typography: {
    fontSizes: {
      xs: 'var(--font-size-xs)',
      sm: 'var(--font-size-sm)',
      base: 'var(--font-size-base)',
      lg: 'var(--font-size-lg)',
      xl: 'var(--font-size-xl)',
      '2xl': 'var(--font-size-2xl)',
      '3xl': 'var(--font-size-3xl)',
      '4xl': 'var(--font-size-4xl)',
      '5xl': 'var(--font-size-5xl)',
    },
    lineHeights: {
      none: 'var(--line-height-none)',
      tight: 'var(--line-height-tight)',
      snug: 'var(--line-height-snug)',
      normal: 'var(--line-height-normal)',
      relaxed: 'var(--line-height-relaxed)',
      loose: 'var(--line-height-loose)',
    },
    fontWeights: {
      thin: 'var(--font-weight-thin)',
      light: 'var(--font-weight-light)',
      normal: 'var(--font-weight-normal)',
      medium: 'var(--font-weight-medium)',
      semibold: 'var(--font-weight-semibold)',
      bold: 'var(--font-weight-bold)',
      extrabold: 'var(--font-weight-extrabold)',
      black: 'var(--font-weight-black)',
    },
  },
  shadows: {
    xs: 'var(--shadow-xs)',
    sm: 'var(--shadow-sm)',
    md: 'var(--shadow-md)',
    lg: 'var(--shadow-lg)',
    xl: 'var(--shadow-xl)',
    '2xl': 'var(--shadow-2xl)',
  },
  animations: {
    durations: {
      75: 'var(--duration-75)',
      100: 'var(--duration-100)',
      150: 'var(--duration-150)',
      200: 'var(--duration-200)',
      300: 'var(--duration-300)',
      500: 'var(--duration-500)',
      700: 'var(--duration-700)',
      1000: 'var(--duration-1000)',
    },
    easings: {
      linear: 'var(--ease-linear)',
      in: 'var(--ease-in)',
      out: 'var(--ease-out)',
      inOut: 'var(--ease-in-out)',
    },
  },
} as const

// Component variants type definitions
export type ButtonVariant = 'default' | 'destructive' | 'outline' | 'secondary' | 'ghost' | 'link'
export type ButtonSize = 'default' | 'sm' | 'lg' | 'xl' | 'icon'

export type CardVariant = 'default' | 'elevated' | 'outlined' | 'filled'

export type BadgeVariant = 'default' | 'secondary' | 'destructive' | 'outline' | 'success' | 'warning' | 'info'

export type AlertVariant = 'default' | 'destructive' | 'success' | 'warning' | 'info'

// Theme provider configuration
export interface ThemeProviderProps {
  children: React.ReactNode
  defaultTheme?: 'light' | 'dark' | 'system'
  storageKey?: string
  enableSystem?: boolean
  disableTransitionOnChange?: boolean
}

// Utility functions for theme management
export const getThemeValue = (path: keyof typeof themeTokens) => {
  return themeTokens[path]
}

export const getColorValue = (colorName: keyof typeof themeTokens.colors) => {
  return themeTokens.colors[colorName]
}

export const getRadiusValue = (radius: keyof typeof themeTokens.radius) => {
  return themeTokens.radius[radius]
}

export const getSpacingValue = (spacing: keyof typeof themeTokens.spacing) => {
  return themeTokens.spacing[spacing]
}

// CSS-in-JS theme object for runtime usage
export const createTheme = (mode: 'light' | 'dark' = 'light') => ({
  mode,
  colors: themeTokens.colors,
  radius: themeTokens.radius,
  spacing: themeTokens.spacing,
  typography: themeTokens.typography,
  shadows: themeTokens.shadows,
  animations: themeTokens.animations,
})

export type RuntimeTheme = ReturnType<typeof createTheme>