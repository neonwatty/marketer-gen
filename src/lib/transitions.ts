// Animation and transition utilities for smooth UI state changes

export const transitions = {
  // Standard easing functions
  easing: {
    easeInOut: "cubic-bezier(0.4, 0, 0.2, 1)",
    easeOut: "cubic-bezier(0, 0, 0.2, 1)",
    easeIn: "cubic-bezier(0.4, 0, 1, 1)",
    bounce: "cubic-bezier(0.68, -0.55, 0.265, 1.55)",
  },

  // Duration presets
  duration: {
    fast: 150,
    normal: 300,
    slow: 500,
  },

  // Common transition classes for Tailwind
  classes: {
    fadeIn: "transition-opacity duration-300 ease-in-out",
    fadeOut: "transition-opacity duration-300 ease-in-out opacity-0",
    slideUp: "transition-transform duration-300 ease-out translate-y-2",
    slideDown: "transition-transform duration-300 ease-out -translate-y-2",
    scale: "transition-transform duration-200 ease-out",
    all: "transition-all duration-300 ease-in-out",
  },

  // Stagger delay utilities for list animations
  stagger: {
    delay: (index: number, baseDelay = 50) => index * baseDelay,
    style: (index: number, baseDelay = 50) => ({
      transitionDelay: `${index * baseDelay}ms`,
    }),
  },
}

// Hook-like utility for managing loading states with smooth transitions
export const createLoadingTransition = (initialState = false) => {
  return {
    isLoading: initialState,
    startLoading: () => true,
    stopLoading: () => false,
    className: (isLoading: boolean) =>
      `transition-opacity duration-300 ${isLoading ? "opacity-50" : "opacity-100"}`,
  }
}

// Utility for creating smooth state transitions
export const withTransition = <T extends Record<string, any>>(
  Component: React.ComponentType<T>,
  transitionClass = transitions.classes.all
) => {
  return (props: T) => {
    const className = `${transitionClass} ${props.className || ""}`
    return <Component {...props} className={className} />
  }
}