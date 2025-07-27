/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.js'
  ],
  theme: {
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
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      spacing: {
        '18': '4.5rem',
        '88': '22rem',
        '112': '28rem',
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
      },
      gridTemplateColumns: {
        'journey-layout': '320px 1fr 320px',
        'journey-compact': '280px 1fr 280px',
      },
      zIndex: {
        'journey-canvas': '10',
        'journey-step': '20',
        'journey-step-hover': '25',
        'journey-step-selected': '30',
        'journey-step-dragging': '40',
        'journey-header': '50',
      }
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    // Custom plugin for journey builder utilities
    function({ addUtilities, theme }) {
      const newUtilities = {
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
      addUtilities(newUtilities)
    }
  ],
}