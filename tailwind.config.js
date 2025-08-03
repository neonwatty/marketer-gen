/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.js'
  ],
  theme: {
    // Mobile-first responsive breakpoints (320px to 2560px)
    screens: {
      'xs': '320px',     // Extra small mobile devices
      'sm': '640px',     // Small devices (landscape phones)
      'md': '768px',     // Medium devices (tablets)
      'lg': '1024px',    // Large devices (laptops)
      'xl': '1280px',    // Extra large devices (desktops)
      '2xl': '1536px',   // 2X large devices (large desktops)
      '3xl': '2048px',   // 3X large devices (ultra-wide)
      '4xl': '2560px',   // 4X large devices (ultra-wide+)
      // Custom breakpoints for touch devices
      'touch': {'raw': '(hover: none) and (pointer: coarse)'},
      'no-touch': {'raw': '(hover: hover) and (pointer: fine)'},
      // Height-based breakpoints for mobile devices
      'h-sm': {'raw': '(min-height: 640px)'},
      'h-md': {'raw': '(min-height: 768px)'},
      'h-lg': {'raw': '(min-height: 1024px)'},
    },
    extend: {
      colors: {
        // Journey stage colors
        'journey-awareness': {
          50: '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
          800: '#1e40af',
          900: '#1e3a8a',
        },
        'journey-consideration': {
          50: '#ecfdf5',
          100: '#d1fae5',
          200: '#a7f3d0',
          300: '#6ee7b7',
          400: '#34d399',
          500: '#10b981',
          600: '#059669',
          700: '#047857',
          800: '#065f46',
          900: '#064e3b',
        },
        'journey-conversion': {
          50: '#fffbeb',
          100: '#fef3c7',
          200: '#fde68a',
          300: '#fcd34d',
          400: '#fbbf24',
          500: '#f59e0b',
          600: '#d97706',
          700: '#b45309',
          800: '#92400e',
          900: '#78350f',
        },
        'journey-retention': {
          50: '#f5f3ff',
          100: '#ede9fe',
          200: '#ddd6fe',
          300: '#c4b5fd',
          400: '#a78bfa',
          500: '#8b5cf6',
          600: '#7c3aed',
          700: '#6d28d9',
          800: '#5b21b6',
          900: '#4c1d95',
        }
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'sans-serif'],
        mono: ['SF Mono', 'Monaco', 'Inconsolata', 'Roboto Mono', 'Consolas', 'monospace'],
      },
      fontSize: {
        // Fluid typography using clamp() - these work with our CSS custom properties
        'xs': ['clamp(0.75rem, 0.9vw, 0.875rem)', { lineHeight: '1.5' }],
        'sm': ['clamp(0.875rem, 1vw, 1rem)', { lineHeight: '1.5' }],
        'base': ['clamp(0.875rem, 1vw, 1rem)', { lineHeight: '1.625' }],
        'lg': ['clamp(1rem, 1.2vw, 1.125rem)', { lineHeight: '1.625' }],
        'xl': ['clamp(1.125rem, 1.5vw, 1.25rem)', { lineHeight: '1.625' }],
        '2xl': ['clamp(1.25rem, 2vw, 1.5rem)', { lineHeight: '1.375' }],
        '3xl': ['clamp(1.5rem, 2.5vw, 1.875rem)', { lineHeight: '1.375' }],
        '4xl': ['clamp(1.875rem, 3vw, 2.25rem)', { lineHeight: '1.25' }],
        '5xl': ['clamp(2.25rem, 4vw, 3rem)', { lineHeight: '1.25' }],
        '6xl': ['clamp(3rem, 5vw, 3.75rem)', { lineHeight: '1.25' }],
        // Heading-specific sizes with better scaling
        'heading-h1': ['clamp(1.875rem, 4vw, 3.75rem)', { lineHeight: '1.25', letterSpacing: '-0.025em' }],
        'heading-h2': ['clamp(1.5rem, 3vw, 3rem)', { lineHeight: '1.25', letterSpacing: '-0.025em' }],
        'heading-h3': ['clamp(1.25rem, 2.5vw, 2.25rem)', { lineHeight: '1.375' }],
        'heading-h4': ['clamp(1.125rem, 2vw, 1.875rem)', { lineHeight: '1.375' }],
        'heading-h5': ['clamp(1rem, 1.5vw, 1.5rem)', { lineHeight: '1.5' }],
        'heading-h6': ['clamp(0.875rem, 1.2vw, 1.25rem)', { lineHeight: '1.5', letterSpacing: '0.025em' }],
      },
      lineHeight: {
        'none': '1',
        'tight': '1.25',
        'snug': '1.375',
        'normal': '1.5',
        'relaxed': '1.625',
        'loose': '2',
      },
      letterSpacing: {
        'tighter': '-0.05em',
        'tight': '-0.025em',
        'normal': '0em',
        'wide': '0.025em',
        'wider': '0.05em',
        'widest': '0.1em',
      },
      spacing: {
        '18': '4.5rem',
        '88': '22rem',
        '112': '28rem',
        // Touch-optimized spacing
        'touch-xs': '0.5rem',    // 8px
        'touch-sm': '0.75rem',   // 12px
        'touch-md': '1rem',      // 16px
        'touch-lg': '1.5rem',    // 24px
        'touch-xl': '2rem',      // 32px
        'touch-2xl': '3rem',     // 48px
        // Minimum touch target sizes (44px recommended)
        'touch-target': '2.75rem', // 44px minimum
        'touch-target-lg': '3rem', // 48px comfortable
        'touch-target-xl': '3.5rem', // 56px spacious
      },
      minHeight: {
        'touch': '2.75rem',     // 44px minimum touch target
        'touch-lg': '3rem',     // 48px comfortable touch target
        'touch-xl': '3.5rem',   // 56px spacious touch target
        'screen-sm': '100vh',   // Full viewport height
      },
      minWidth: {
        'touch': '2.75rem',     // 44px minimum touch target
        'touch-lg': '3rem',     // 48px comfortable touch target
        'touch-xl': '3.5rem',   // 56px spacious touch target
      },
      borderRadius: {
        'xl': '1rem',
        '2xl': '1.5rem',
      },
      boxShadow: {
        'journey-step': '0 4px 12px rgba(0, 0, 0, 0.1)',
        'journey-step-hover': '0 8px 25px rgba(0, 0, 0, 0.15)',
        'journey-selected': '0 0 0 3px rgba(59, 130, 246, 0.5)',
      },
      animation: {
        'fade-in': 'fadeIn 0.2s ease-in-out',
        'slide-up': 'slideUp 0.3s ease-out',
        'bounce-gentle': 'bounceGentle 0.6s ease-in-out',
        // Mobile-specific animations
        'slide-in-right': 'slideInRight 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
        'slide-out-right': 'slideOutRight 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
        'slide-in-left': 'slideInLeft 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
        'slide-out-left': 'slideOutLeft 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
        'slide-in-up': 'slideInUp 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
        'slide-out-down': 'slideOutDown 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
        'scale-in': 'scaleIn 0.2s cubic-bezier(0.4, 0, 0.2, 1)',
        'scale-out': 'scaleOut 0.2s cubic-bezier(0.4, 0, 0.2, 1)',
        'pull-to-refresh': 'pullToRefresh 1s linear infinite',
        'loading-dots': 'loadingDots 1.5s ease-in-out infinite',
        'touch-feedback': 'touchFeedback 0.15s ease-out',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%': { transform: 'translateY(10px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        bounceGentle: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-4px)' },
        },
        // Mobile slide animations
        slideInRight: {
          '0%': { transform: 'translateX(100%)', opacity: '0' },
          '100%': { transform: 'translateX(0)', opacity: '1' },
        },
        slideOutRight: {
          '0%': { transform: 'translateX(0)', opacity: '1' },
          '100%': { transform: 'translateX(100%)', opacity: '0' },
        },
        slideInLeft: {
          '0%': { transform: 'translateX(-100%)', opacity: '0' },
          '100%': { transform: 'translateX(0)', opacity: '1' },
        },
        slideOutLeft: {
          '0%': { transform: 'translateX(0)', opacity: '1' },
          '100%': { transform: 'translateX(-100%)', opacity: '0' },
        },
        slideInUp: {
          '0%': { transform: 'translateY(100%)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        slideOutDown: {
          '0%': { transform: 'translateY(0)', opacity: '1' },
          '100%': { transform: 'translateY(100%)', opacity: '0' },
        },
        scaleIn: {
          '0%': { transform: 'scale(0.9)', opacity: '0' },
          '100%': { transform: 'scale(1)', opacity: '1' },
        },
        scaleOut: {
          '0%': { transform: 'scale(1)', opacity: '1' },
          '100%': { transform: 'scale(0.9)', opacity: '0' },
        },
        pullToRefresh: {
          '0%': { transform: 'rotate(0deg)' },
          '100%': { transform: 'rotate(360deg)' },
        },
        loadingDots: {
          '0%, 20%': { opacity: '0', transform: 'scale(1)' },
          '50%': { opacity: '1', transform: 'scale(1.2)' },
          '100%': { opacity: '0', transform: 'scale(1)' },
        },
        touchFeedback: {
          '0%': { transform: 'scale(1)' },
          '50%': { transform: 'scale(0.95)' },
          '100%': { transform: 'scale(1)' },
        },
      },
      gridTemplateColumns: {
        'journey-layout': '320px 1fr 320px',
        'journey-compact': '280px 1fr 280px',
        // Mobile-first responsive grid templates
        'mobile-single': '1fr',
        'mobile-double': 'repeat(2, 1fr)',
        'tablet-triple': 'repeat(3, 1fr)',
        'desktop-quad': 'repeat(4, 1fr)',
        'desktop-six': 'repeat(6, 1fr)',
        // Dashboard specific layouts
        'dashboard-mobile': '1fr',
        'dashboard-tablet': 'repeat(2, minmax(300px, 1fr))',
        'dashboard-desktop': 'repeat(auto-fit, minmax(300px, 1fr))',
        'dashboard-wide': 'repeat(auto-fit, minmax(280px, 1fr))',
        // Content layouts
        'content-mobile': '1fr',
        'content-tablet': '250px 1fr',
        'content-desktop': '280px 1fr 280px',
        // Navigation layouts
        'nav-mobile': '1fr auto',
        'nav-desktop': 'auto 1fr auto',
      },
      zIndex: {
        'journey-canvas': '10',
        'journey-step': '20',
        'journey-step-hover': '25',
        'journey-step-selected': '30',
        'journey-step-dragging': '40',
        'journey-header': '50',
        // Mobile-specific z-index layers
        'mobile-nav': '1000',
        'mobile-overlay': '999',
        'mobile-drawer': '998',
        'mobile-header': '997',
        'bottom-nav': '996',
        'toast': '995',
        'modal': '994',
        'dropdown': '993',
        'tooltip': '992',
        'loading': '1001',
      }
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    // Custom plugin for mobile-first responsive utilities
    function({ addUtilities, addComponents, theme }) {
      const newUtilities = {
        // Mobile-first touch optimizations
        '.touch-manipulation': {
          touchAction: 'manipulation',
        },
        '.touch-pan-x': {
          touchAction: 'pan-x',
        },
        '.touch-pan-y': {
          touchAction: 'pan-y',
        },
        '.touch-none': {
          touchAction: 'none',
        },
        
        // Touch feedback utilities
        '.touch-feedback': {
          transition: 'transform 0.15s ease-out',
          '&:active': {
            transform: 'scale(0.95)',
          },
        },
        
        // Tap highlighting removal for mobile
        '.tap-transparent': {
          '-webkit-tap-highlight-color': 'transparent',
        },
        
        // Safe area utilities for mobile devices
        '.safe-top': {
          paddingTop: 'env(safe-area-inset-top)',
        },
        '.safe-bottom': {
          paddingBottom: 'env(safe-area-inset-bottom)',
        },
        '.safe-left': {
          paddingLeft: 'env(safe-area-inset-left)',
        },
        '.safe-right': {
          paddingRight: 'env(safe-area-inset-right)',
        },
        '.safe-x': {
          paddingLeft: 'env(safe-area-inset-left)',
          paddingRight: 'env(safe-area-inset-right)',
        },
        '.safe-y': {
          paddingTop: 'env(safe-area-inset-top)',
          paddingBottom: 'env(safe-area-inset-bottom)',
        },
        '.safe-all': {
          padding: 'env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)',
        },
        
        // Mobile viewport units
        '.h-screen-mobile': {
          height: '100vh',
          height: '100dvh', // Dynamic viewport height for mobile
        },
        '.min-h-screen-mobile': {
          minHeight: '100vh',
          minHeight: '100dvh',
        },
        
        // Scrollable containers for mobile
        '.scroll-smooth-mobile': {
          scrollBehavior: 'smooth',
          '-webkit-overflow-scrolling': 'touch',
        },
        
        // Hide scrollbars on mobile
        '.scrollbar-hide': {
          scrollbarWidth: 'none',
          '&::-webkit-scrollbar': {
            display: 'none',
          },
        },
        
        // Pull-to-refresh indicator
        '.pull-to-refresh': {
          overscrollBehavior: 'contain',
          overscrollBehaviorY: 'contain',
        },
        
        // Mobile-optimized focus styles
        '.focus-mobile': {
          '&:focus-visible': {
            outline: '2px solid #3b82f6',
            outlineOffset: '2px',
            borderRadius: '4px',
          },
          '@media (hover: none) and (pointer: coarse)': {
            '&:focus': {
              outline: '2px solid #3b82f6',
              outlineOffset: '2px',
              borderRadius: '4px',
            },
          },
        },
        
        // Line clamp utilities
        '.line-clamp-1': {
          display: '-webkit-box',
          '-webkit-line-clamp': '1',
          '-webkit-box-orient': 'vertical',
          overflow: 'hidden',
        },
        '.line-clamp-2': {
          display: '-webkit-box',
          '-webkit-line-clamp': '2',
          '-webkit-box-orient': 'vertical',
          overflow: 'hidden',
        },
        '.line-clamp-3': {
          display: '-webkit-box',
          '-webkit-line-clamp': '3',
          '-webkit-box-orient': 'vertical',
          overflow: 'hidden',
        },
        '.line-clamp-4': {
          display: '-webkit-box',
          '-webkit-line-clamp': '4',
          '-webkit-box-orient': 'vertical',
          overflow: 'hidden',
        },
        // Typography component classes
        '.text-heading-h1': {
          fontSize: 'clamp(1.875rem, 4vw, 3.75rem)',
          lineHeight: '1.25',
          letterSpacing: '-0.025em',
          fontWeight: '700',
          color: theme('colors.gray.900'),
        },
        '.text-heading-h2': {
          fontSize: 'clamp(1.5rem, 3vw, 3rem)',
          lineHeight: '1.25',
          letterSpacing: '-0.025em',
          fontWeight: '600',
          color: theme('colors.gray.900'),
        },
        '.text-heading-h3': {
          fontSize: 'clamp(1.25rem, 2.5vw, 2.25rem)',
          lineHeight: '1.375',
          fontWeight: '600',
          color: theme('colors.gray.800'),
        },
        '.text-heading-h4': {
          fontSize: 'clamp(1.125rem, 2vw, 1.875rem)',
          lineHeight: '1.375',
          fontWeight: '500',
          color: theme('colors.gray.800'),
        },
        '.text-heading-h5': {
          fontSize: 'clamp(1rem, 1.5vw, 1.5rem)',
          lineHeight: '1.5',
          fontWeight: '500',
          color: theme('colors.gray.700'),
        },
        '.text-heading-h6': {
          fontSize: 'clamp(0.875rem, 1.2vw, 1.25rem)',
          lineHeight: '1.5',
          letterSpacing: '0.025em',
          fontWeight: '500',
          color: theme('colors.gray.700'),
          textTransform: 'uppercase',
        },
        // Typography color utilities with proper contrast
        '.text-primary': { color: theme('colors.gray.900') },
        '.text-secondary': { color: theme('colors.gray.700') },
        '.text-tertiary': { color: theme('colors.gray.600') },
        '.text-muted': { color: theme('colors.gray.500') },
        '.text-subtle': { color: theme('colors.gray.400') },
        // Interactive text
        '.text-interactive': {
          color: theme('colors.blue.500'),
          '&:hover': {
            color: theme('colors.blue.600'),
          },
          '&:active': {
            color: theme('colors.blue.700'),
          },
        },
        // Status colors
        '.text-success': { color: theme('colors.emerald.600') },
        '.text-warning': { color: theme('colors.amber.600') },
        '.text-error': { color: theme('colors.red.600') },
        '.text-info': { color: theme('colors.sky.600') },
        '.journey-stage-awareness': {
          '--journey-color': theme('colors.journey-awareness.500'),
          '--journey-color-light': theme('colors.journey-awareness.100'),
          '--journey-color-bg': theme('colors.journey-awareness.50'),
        },
        '.journey-stage-consideration': {
          '--journey-color': theme('colors.journey-consideration.500'),
          '--journey-color-light': theme('colors.journey-consideration.100'),
          '--journey-color-bg': theme('colors.journey-consideration.50'),
        },
        '.journey-stage-conversion': {
          '--journey-color': theme('colors.journey-conversion.500'),
          '--journey-color-light': theme('colors.journey-conversion.100'),
          '--journey-color-bg': theme('colors.journey-conversion.50'),
        },
        '.journey-stage-retention': {
          '--journey-color': theme('colors.journey-retention.500'),
          '--journey-color-light': theme('colors.journey-retention.100'),
          '--journey-color-bg': theme('colors.journey-retention.50'),
        },
        '.canvas-grid': {
          'background-image': 'radial-gradient(circle, #d1d5db 1px, transparent 1px)',
          'background-size': '20px 20px',
        },
        '.drag-ghost': {
          opacity: '0.5',
          transform: 'rotate(5deg)',
        },
      }
      
      // Mobile-first component utilities
      const mobileComponents = {
        // Bottom navigation component
        '.bottom-nav': {
          position: 'fixed',
          bottom: '0',
          left: '0',
          right: '0',
          zIndex: theme('zIndex.bottom-nav'),
          backgroundColor: 'white',
          borderTop: '1px solid #e5e7eb',
          paddingBottom: 'env(safe-area-inset-bottom)',
          backdropFilter: 'blur(8px)',
          backgroundColor: 'rgba(255, 255, 255, 0.95)',
        },
        
        // Mobile drawer component
        '.mobile-drawer': {
          position: 'fixed',
          top: '0',
          bottom: '0',
          width: '80vw',
          maxWidth: '320px',
          backgroundColor: 'white',
          boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1)',
          zIndex: theme('zIndex.mobile-drawer'),
          transform: 'translateX(-100%)',
          transition: 'transform 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
          
          '&.open': {
            transform: 'translateX(0)',
          },
        },
        
        // Mobile overlay
        '.mobile-overlay': {
          position: 'fixed',
          inset: '0',
          backgroundColor: 'rgba(0, 0, 0, 0.5)',
          zIndex: theme('zIndex.mobile-overlay'),
          opacity: '0',
          visibility: 'hidden',
          transition: 'opacity 0.3s ease, visibility 0.3s ease',
          
          '&.open': {
            opacity: '1',
            visibility: 'visible',
          },
        },
        
        // Touch button component
        '.btn-touch': {
          minHeight: theme('minHeight.touch-lg'),
          minWidth: theme('minWidth.touch-lg'),
          padding: theme('spacing.touch-md'),
          borderRadius: theme('borderRadius.lg'),
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          transition: 'all 0.15s ease-out',
          touchAction: 'manipulation',
          '-webkit-tap-highlight-color': 'transparent',
          
          '&:active': {
            transform: 'scale(0.95)',
          },
          
          '@media (hover: hover)': {
            '&:hover': {
              transform: 'translateY(-1px)',
            },
          },
        },
        
        // Swipeable container
        '.swipeable': {
          overflowX: 'auto',
          scrollSnapType: 'x mandatory',
          scrollbarWidth: 'none',
          '-webkit-overflow-scrolling': 'touch',
          
          '&::-webkit-scrollbar': {
            display: 'none',
          },
          
          '& > *': {
            scrollSnapAlign: 'start',
            flexShrink: '0',
          },
        },
        
        // Sticky header for mobile
        '.sticky-header-mobile': {
          position: 'sticky',
          top: '0',
          zIndex: theme('zIndex.mobile-header'),
          backgroundColor: 'rgba(255, 255, 255, 0.95)',
          backdropFilter: 'blur(8px)',
          borderBottom: '1px solid rgba(229, 231, 235, 0.8)',
        },
      }
      
      addUtilities(newUtilities)
      addComponents(mobileComponents)
    }
  ],
}