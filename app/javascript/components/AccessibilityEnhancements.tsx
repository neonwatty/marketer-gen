import React, { useEffect, useCallback, useState, useRef } from 'react';

// TypeScript DOM types
declare global {
  interface NodeListOf<TNode extends Node = Node> extends NodeList {
    length: number;
    item(index: number): TNode;
    [index: number]: TNode;
  }
}

// ARIA Live Region for Screen Reader Announcements
export const AriaLiveRegion = () => {
  return (
    <>
      <div
        id="aria-live-polite"
        aria-live="polite"
        aria-atomic="true"
        className="sr-only"
        role="status"
      />
      <div
        id="aria-live-assertive"
        aria-live="assertive"
        aria-atomic="true"
        className="sr-only"
        role="alert"
      />
    </>
  );
};

// Screen Reader Announcement Utility
export const announceToScreenReader = (message: string, priority: 'polite' | 'assertive' = 'polite') => {
  const liveRegion = document.getElementById(`aria-live-${priority}`);
  if (liveRegion) {
    liveRegion.textContent = message;
    
    // Clear after announcement to allow repeated messages
    setTimeout(() => {
      liveRegion.textContent = '';
    }, 1000);
  }
};

// Skip Links Component
export const SkipLinks = () => {
  return (
    <div className="sr-only focus:not-sr-only focus:absolute focus:top-0 focus:left-0 z-50">
      <a
        href="#main-content"
        className="bg-blue-600 text-white px-4 py-2 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        Skip to main content
      </a>
      <a
        href="#navigation"
        className="bg-blue-600 text-white px-4 py-2 rounded ml-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        Skip to navigation
      </a>
    </div>
  );
};

// Focus Management Hook
export const useFocusManagement = () => {
  const previousFocusRef = useRef<HTMLElement | null>(null);

  const saveFocus = useCallback(() => {
    previousFocusRef.current = document.activeElement as HTMLElement;
  }, []);

  const restoreFocus = useCallback(() => {
    if (previousFocusRef.current && previousFocusRef.current.focus) {
      previousFocusRef.current.focus();
    }
  }, []);

  const trapFocus = useCallback((containerElement: HTMLElement) => {
    const focusableElements = containerElement.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    ) as NodeListOf<HTMLElement>;

    const firstElement = focusableElements[0];
    const lastElement = focusableElements[focusableElements.length - 1];

    const handleTabKey = (e: KeyboardEvent) => {
      if (e.key === 'Tab') {
        if (e.shiftKey) {
          if (document.activeElement === firstElement) {
            lastElement.focus();
            e.preventDefault();
          }
        } else {
          if (document.activeElement === lastElement) {
            firstElement.focus();
            e.preventDefault();
          }
        }
      }

      if (e.key === 'Escape') {
        restoreFocus();
      }
    };

    containerElement.addEventListener('keydown', handleTabKey);
    firstElement?.focus();

    return () => {
      containerElement.removeEventListener('keydown', handleTabKey);
    };
  }, [restoreFocus]);

  return {
    saveFocus,
    restoreFocus,
    trapFocus
  };
};

// Keyboard Navigation Hook
export const useKeyboardNavigation = (
  onArrowUp?: () => void,
  onArrowDown?: () => void,
  onArrowLeft?: () => void,
  onArrowRight?: () => void,
  onEnter?: () => void,
  onEscape?: () => void
) => {
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      switch (event.key) {
        case 'ArrowUp':
          event.preventDefault();
          onArrowUp?.();
          break;
        case 'ArrowDown':
          event.preventDefault();
          onArrowDown?.();
          break;
        case 'ArrowLeft':
          event.preventDefault();
          onArrowLeft?.();
          break;
        case 'ArrowRight':
          event.preventDefault();
          onArrowRight?.();
          break;
        case 'Enter':
          onEnter?.();
          break;
        case 'Escape':
          onEscape?.();
          break;
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [onArrowUp, onArrowDown, onArrowLeft, onArrowRight, onEnter, onEscape]);
};

// High Contrast Mode Detection
export const useHighContrastMode = () => {
  const [isHighContrast, setIsHighContrast] = useState(false);

  useEffect(() => {
    const checkHighContrast = () => {
      // Check if user prefers high contrast
      const highContrastMediaQuery = window.matchMedia('(prefers-contrast: high)');
      setIsHighContrast(highContrastMediaQuery.matches);
    };

    checkHighContrast();

    const highContrastMediaQuery = window.matchMedia('(prefers-contrast: high)');
    highContrastMediaQuery.addEventListener('change', checkHighContrast);

    return () => {
      highContrastMediaQuery.removeEventListener('change', checkHighContrast);
    };
  }, []);

  return isHighContrast;
};

// Reduced Motion Detection
export const useReducedMotion = () => {
  const [prefersReducedMotion, setPrefersReducedMotion] = useState(false);

  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    setPrefersReducedMotion(mediaQuery.matches);

    const handleChange = (e: MediaQueryListEvent) => {
      setPrefersReducedMotion(e.matches);
    };

    mediaQuery.addEventListener('change', handleChange);
    return () => mediaQuery.removeEventListener('change', handleChange);
  }, []);

  return prefersReducedMotion;
};

// Accessible Modal Component
export const AccessibleModal = ({
  isOpen,
  onClose,
  title,
  children,
  className = ''
}: {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
  className?: string;
}) => {
  const modalRef = useRef<HTMLDivElement>(null);
  const { saveFocus, restoreFocus, trapFocus } = useFocusManagement();

  useEffect(() => {
    if (isOpen) {
      saveFocus();
      document.body.style.overflow = 'hidden';
      
      if (modalRef.current) {
        const cleanup = trapFocus(modalRef.current);
        return cleanup;
      }
    } else {
      document.body.style.overflow = '';
      restoreFocus();
    }
    return undefined;
  }, [isOpen, saveFocus, restoreFocus, trapFocus]);

  useKeyboardNavigation(
    undefined,
    undefined,
    undefined,
    undefined,
    undefined,
    onClose
  );

  if (!isOpen) {return null;}

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center"
      role="dialog"
      aria-modal="true"
      aria-labelledby="modal-title"
    >
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black bg-opacity-50"
        onClick={onClose}
        aria-hidden="true"
      />
      
      {/* Modal */}
      <div
        ref={modalRef}
        className={`relative bg-white rounded-lg shadow-xl max-w-md w-full mx-4 p-6 ${className}`}
      >
        <div className="flex items-center justify-between mb-4">
          <h2 id="modal-title" className="text-lg font-semibold">
            {title}
          </h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-blue-500 rounded"
            aria-label="Close modal"
          >
            <span aria-hidden="true">&times;</span>
          </button>
        </div>
        
        <div className="modal-content">
          {children}
        </div>
      </div>
    </div>
  );
};

// Accessible Tooltip Component
export const AccessibleTooltip = ({
  content,
  children,
  position = 'top'
}: {
  content: string;
  children: React.ReactNode;
  position?: 'top' | 'bottom' | 'left' | 'right';
}) => {
  const [isVisible, setIsVisible] = useState(false);
  const tooltipId = `tooltip-${Math.random().toString(36).substr(2, 9)}`;

  const positionClasses = {
    top: 'bottom-full left-1/2 transform -translate-x-1/2 mb-2',
    bottom: 'top-full left-1/2 transform -translate-x-1/2 mt-2',
    left: 'right-full top-1/2 transform -translate-y-1/2 mr-2',
    right: 'left-full top-1/2 transform -translate-y-1/2 ml-2'
  };

  return (
    <div className="relative inline-block">
      <div
        onMouseEnter={() => setIsVisible(true)}
        onMouseLeave={() => setIsVisible(false)}
        onFocus={() => setIsVisible(true)}
        onBlur={() => setIsVisible(false)}
        aria-describedby={isVisible ? tooltipId : undefined}
      >
        {children}
      </div>
      
      {isVisible && (
        <div
          id={tooltipId}
          role="tooltip"
          className={`absolute z-10 px-2 py-1 text-sm text-white bg-gray-900 rounded shadow-lg ${positionClasses[position]}`}
        >
          {content}
          <div
            className={`absolute w-0 h-0 border-4 border-solid ${
              position === 'top' ? 'top-full left-1/2 transform -translate-x-1/2 border-gray-900 border-b-transparent border-l-transparent border-r-transparent' :
              position === 'bottom' ? 'bottom-full left-1/2 transform -translate-x-1/2 border-gray-900 border-t-transparent border-l-transparent border-r-transparent' :
              position === 'left' ? 'left-full top-1/2 transform -translate-y-1/2 border-gray-900 border-r-transparent border-t-transparent border-b-transparent' :
              'right-full top-1/2 transform -translate-y-1/2 border-gray-900 border-l-transparent border-t-transparent border-b-transparent'
            }`}
          />
        </div>
      )}
    </div>
  );
};

// Screen Reader Only Text Component
export const ScreenReaderOnly = ({ children }: { children: React.ReactNode }) => {
  return (
    <span className="sr-only">
      {children}
    </span>
  );
};

// Focus Visible Indicator
export const FocusVisibleIndicator = () => {
  useEffect(() => {
    // Add focus-visible polyfill behavior
    const style = document.createElement('style');
    style.textContent = `
      .focus-visible:focus {
        outline: 2px solid #3B82F6;
        outline-offset: 2px;
      }
      
      .focus-visible:focus:not(.focus-visible) {
        outline: none;
      }
    `;
    document.head.appendChild(style);

    return () => {
      document.head.removeChild(style);
    };
  }, []);

  return null;
};

// Color Contrast Utilities
export const getContrastRatio = (color1: string, color2: string): number => {
  const getLuminance = (color: string): number => {
    const hex = color.replace('#', '');
    const r = parseInt(hex.substr(0, 2), 16) / 255;
    const g = parseInt(hex.substr(2, 2), 16) / 255;
    const b = parseInt(hex.substr(4, 2), 16) / 255;

    const sRGB = [r, g, b].map(c => {
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    });

    return 0.2126 * sRGB[0] + 0.7152 * sRGB[1] + 0.0722 * sRGB[2];
  };

  const lum1 = getLuminance(color1);
  const lum2 = getLuminance(color2);
  const brightest = Math.max(lum1, lum2);
  const darkest = Math.min(lum1, lum2);

  return (brightest + 0.05) / (darkest + 0.05);
};

export const meetsWCAGContrast = (foreground: string, background: string, level: 'AA' | 'AAA' = 'AA'): boolean => {
  const ratio = getContrastRatio(foreground, background);
  return level === 'AA' ? ratio >= 4.5 : ratio >= 7;
};

// Text Size Hook for Responsive Text
export const useResponsiveText = () => {
  const [textScale, setTextScale] = useState(1);

  useEffect(() => {
    const updateTextScale = () => {
      const fontSize = parseInt(getComputedStyle(document.documentElement).fontSize);
      setTextScale(fontSize / 16); // Relative to default 16px
    };

    updateTextScale();
    window.addEventListener('resize', updateTextScale);
    
    return () => window.removeEventListener('resize', updateTextScale);
  }, []);

  return textScale;
};

// Export all accessibility utilities
export const AccessibilityUtils = {
  announceToScreenReader,
  getContrastRatio,
  meetsWCAGContrast
};