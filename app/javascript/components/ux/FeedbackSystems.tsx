import React, { createContext, useContext, useReducer, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { createPortal } from 'react-dom';

// Types for feedback systems
export interface Toast {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info';
  title: string;
  message?: string;
  duration?: number;
  action?: {
    label: string;
    onClick: () => void;
  };
  dismissible?: boolean;
  icon?: React.ReactNode;
}

export interface OnboardingStep {
  id: string;
  target: string;
  title: string;
  content: string;
  position?: 'top' | 'bottom' | 'left' | 'right';
  showNext?: boolean;
  showPrev?: boolean;
  showSkip?: boolean;
  onNext?: () => void;
  onPrev?: () => void;
  onSkip?: () => void;
}

export interface ContextualHelp {
  id: string;
  target: string;
  title: string;
  content: string;
  trigger?: 'hover' | 'click' | 'focus';
  placement?: 'top' | 'bottom' | 'left' | 'right';
}

// Toast Context and Provider
interface ToastState {
  toasts: Toast[];
}

type ToastAction =
  | { type: 'ADD_TOAST'; payload: Toast }
  | { type: 'REMOVE_TOAST'; payload: string }
  | { type: 'CLEAR_TOASTS' };

const toastReducer = (state: ToastState, action: ToastAction): ToastState => {
  switch (action.type) {
    case 'ADD_TOAST':
      return { ...state, toasts: [...state.toasts, action.payload] };
    case 'REMOVE_TOAST':
      return { ...state, toasts: state.toasts.filter(toast => toast.id !== action.payload) };
    case 'CLEAR_TOASTS':
      return { ...state, toasts: [] };
    default:
      return state;
  }
};

const ToastContext = createContext<{
  toasts: Toast[];
  addToast: (toast: Omit<Toast, 'id'>) => void;
  removeToast: (id: string) => void;
  clearToasts: () => void;
} | null>(null);

export const ToastProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [state, dispatch] = useReducer(toastReducer, { toasts: [] });

  const addToast = (toast: Omit<Toast, 'id'>) => {
    const id = `toast_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    dispatch({ type: 'ADD_TOAST', payload: { ...toast, id } });

    // Auto-remove toast after duration
    if (toast.duration !== 0) {
      setTimeout(() => {
        dispatch({ type: 'REMOVE_TOAST', payload: id });
      }, toast.duration || 5000);
    }
  };

  const removeToast = (id: string) => {
    dispatch({ type: 'REMOVE_TOAST', payload: id });
  };

  const clearToasts = () => {
    dispatch({ type: 'CLEAR_TOASTS' });
  };

  return (
    <ToastContext.Provider value={{ toasts: state.toasts, addToast, removeToast, clearToasts }}>
      {children}
      <ToastContainer />
    </ToastContext.Provider>
  );
};

export const useToast = () => {
  const context = useContext(ToastContext);
  if (!context) {
    throw new Error('useToast must be used within a ToastProvider');
  }
  return context;
};

// Toast Container Component
const ToastContainer: React.FC = () => {
  const { toasts } = useToast();

  return createPortal(
    <div className="fixed top-4 right-4 z-50 space-y-2">
      <AnimatePresence>
        {toasts.map((toast) => (
          <ToastItem key={toast.id} toast={toast} />
        ))}
      </AnimatePresence>
    </div>,
    document.body
  );
};

// Individual Toast Item
const ToastItem: React.FC<{ toast: Toast }> = ({ toast }) => {
  const { removeToast } = useToast();

  const typeStyles = {
    success: 'bg-green-50 dark:bg-green-900/30 border-green-200 dark:border-green-800',
    error: 'bg-red-50 dark:bg-red-900/30 border-red-200 dark:border-red-800',
    warning: 'bg-yellow-50 dark:bg-yellow-900/30 border-yellow-200 dark:border-yellow-800',
    info: 'bg-blue-50 dark:bg-blue-900/30 border-blue-200 dark:border-blue-800'
  };

  const iconColors = {
    success: 'text-green-400',
    error: 'text-red-400',
    warning: 'text-yellow-400',
    info: 'text-blue-400'
  };

  const defaultIcons = {
    success: (
      <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
      </svg>
    ),
    error: (
      <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
      </svg>
    ),
    warning: (
      <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
      </svg>
    ),
    info: (
      <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
        <path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clipRule="evenodd" />
      </svg>
    )
  };

  return (
    <motion.div
      initial={{ opacity: 0, x: 300, scale: 0.3 }}
      animate={{ opacity: 1, x: 0, scale: 1 }}
      exit={{ opacity: 0, x: 300, scale: 0.5, transition: { duration: 0.2 } }}
      className={`max-w-sm w-full shadow-lg rounded-lg pointer-events-auto border ${typeStyles[toast.type]}`}
    >
      <div className="p-4">
        <div className="flex items-start">
          <div className="flex-shrink-0">
            <div className={iconColors[toast.type]}>
              {toast.icon || defaultIcons[toast.type]}
            </div>
          </div>
          <div className="ml-3 w-0 flex-1">
            <p className="text-sm font-medium text-gray-900 dark:text-gray-100">
              {toast.title}
            </p>
            {toast.message && (
              <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
                {toast.message}
              </p>
            )}
            {toast.action && (
              <div className="mt-3">
                <button
                  onClick={toast.action.onClick}
                  className="text-sm font-medium text-blue-600 dark:text-blue-400 hover:text-blue-500 dark:hover:text-blue-300"
                >
                  {toast.action.label}
                </button>
              </div>
            )}
          </div>
          {toast.dismissible !== false && (
            <div className="ml-4 flex-shrink-0 flex">
              <button
                onClick={() => removeToast(toast.id)}
                className="bg-white dark:bg-gray-800 rounded-md inline-flex text-gray-400 dark:text-gray-500 hover:text-gray-500 dark:hover:text-gray-400"
              >
                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
                </svg>
              </button>
            </div>
          )}
        </div>
      </div>
    </motion.div>
  );
};

// Success Confirmation Component
export const SuccessConfirmation: React.FC<{
  isVisible: boolean;
  title: string;
  message?: string;
  onClose?: () => void;
  autoClose?: number;
  showConfetti?: boolean;
}> = ({
  isVisible,
  title,
  message,
  onClose,
  autoClose = 3000,
  showConfetti = false
}) => {
  useEffect(() => {
    if (isVisible && autoClose > 0) {
      const timer = setTimeout(() => {
        onClose?.();
      }, autoClose);
      return () => clearTimeout(timer);
    }
  }, [isVisible, autoClose, onClose]);

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          initial={{ opacity: 0, scale: 0.8 }}
          animate={{ opacity: 1, scale: 1 }}
          exit={{ opacity: 0, scale: 0.8 }}
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black bg-opacity-50"
        >
          <motion.div
            initial={{ y: 20 }}
            animate={{ y: 0 }}
            className="bg-white dark:bg-gray-800 rounded-lg shadow-xl p-8 text-center max-w-md w-full"
          >
            <motion.div
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              transition={{ delay: 0.2, type: "spring", stiffness: 200 }}
              className="w-16 h-16 mx-auto mb-4 bg-green-100 dark:bg-green-900/30 rounded-full flex items-center justify-center"
            >
              <svg className="w-8 h-8 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
            </motion.div>
            
            <h3 className="text-xl font-semibold text-gray-900 dark:text-gray-100 mb-2">
              {title}
            </h3>
            
            {message && (
              <p className="text-gray-600 dark:text-gray-400 mb-6">
                {message}
              </p>
            )}
            
            {onClose && (
              <button
                onClick={onClose}
                className="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
              >
                Continue
              </button>
            )}
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};

// Contextual Help Component
export const ContextualHelp: React.FC<{
  help: ContextualHelp;
  isVisible: boolean;
  onClose: () => void;
}> = ({ help, isVisible, onClose }) => {
  const [position, setPosition] = React.useState({ top: 0, left: 0 });

  useEffect(() => {
    if (isVisible) {
      const targetElement = document.querySelector(help.target);
      if (targetElement) {
        const rect = targetElement.getBoundingClientRect();
        const placement = help.placement || 'bottom';
        
        let top = rect.bottom + 8;
        let left = rect.left;

        switch (placement) {
          case 'top':
            top = rect.top - 8;
            break;
          case 'left':
            top = rect.top;
            left = rect.left - 8;
            break;
          case 'right':
            top = rect.top;
            left = rect.right + 8;
            break;
          case 'bottom':
          default:
            top = rect.bottom + 8;
            break;
        }

        setPosition({ top, left });
      }
    }
  }, [isVisible, help.target, help.placement]);

  if (!isVisible) {return null;}

  return createPortal(
    <motion.div
      initial={{ opacity: 0, scale: 0.9 }}
      animate={{ opacity: 1, scale: 1 }}
      exit={{ opacity: 0, scale: 0.9 }}
      className="fixed z-50 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-lg p-4 max-w-xs"
      style={{ top: position.top, left: position.left }}
    >
      <button
        onClick={onClose}
        className="absolute top-2 right-2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
      >
        <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
          <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
        </svg>
      </button>
      
      <h4 className="font-semibold text-gray-900 dark:text-gray-100 mb-2 pr-6">
        {help.title}
      </h4>
      
      <p className="text-sm text-gray-600 dark:text-gray-400">
        {help.content}
      </p>
    </motion.div>,
    document.body
  );
};

// Onboarding Tour Component
export const OnboardingTour: React.FC<{
  steps: OnboardingStep[];
  isActive: boolean;
  currentStep: number;
  onNext: () => void;
  onPrev: () => void;
  onSkip: () => void;
  onComplete: () => void;
}> = ({
  steps,
  isActive,
  currentStep,
  onNext,
  onPrev,
  onSkip,
  onComplete
}) => {
  const [position, setPosition] = React.useState({ top: 0, left: 0 });
  const currentStepData = steps[currentStep];

  useEffect(() => {
    if (isActive && currentStepData) {
      const targetElement = document.querySelector(currentStepData.target);
      if (targetElement) {
        targetElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
        
        const rect = targetElement.getBoundingClientRect();
        const position = currentStepData.position || 'bottom';
        
        let top = rect.bottom + 16;
        let left = rect.left;

        switch (position) {
          case 'top':
            top = rect.top - 16;
            break;
          case 'left':
            top = rect.top;
            left = rect.left - 16;
            break;
          case 'right':
            top = rect.top;
            left = rect.right + 16;
            break;
          case 'bottom':
          default:
            top = rect.bottom + 16;
            break;
        }

        setPosition({ top, left });

        // Highlight target element
        targetElement.classList.add('onboarding-highlight');
        return () => {
          targetElement.classList.remove('onboarding-highlight');
        };
      }
    }
  }, [isActive, currentStep, currentStepData]);

  if (!isActive || !currentStepData) {return null;}

  const isLastStep = currentStep === steps.length - 1;

  return createPortal(
    <>
      {/* Backdrop */}
      <div className="fixed inset-0 bg-black bg-opacity-50 z-40" />
      
      {/* Tour Step */}
      <motion.div
        initial={{ opacity: 0, scale: 0.9 }}
        animate={{ opacity: 1, scale: 1 }}
        className="fixed z-50 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-xl p-6 max-w-sm"
        style={{ top: position.top, left: position.left }}
      >
        <div className="flex justify-between items-start mb-4">
          <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
            {currentStepData.title}
          </h3>
          <div className="text-sm text-gray-500 dark:text-gray-400">
            {currentStep + 1} of {steps.length}
          </div>
        </div>
        
        <p className="text-gray-600 dark:text-gray-400 mb-6">
          {currentStepData.content}
        </p>
        
        <div className="flex justify-between items-center">
          <div className="flex space-x-2">
            {currentStepData.showPrev !== false && currentStep > 0 && (
              <button
                onClick={currentStepData.onPrev || onPrev}
                className="px-4 py-2 text-sm text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200"
              >
                Previous
              </button>
            )}
            
            {currentStepData.showSkip !== false && (
              <button
                onClick={currentStepData.onSkip || onSkip}
                className="px-4 py-2 text-sm text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200"
              >
                Skip Tour
              </button>
            )}
          </div>
          
          <div className="flex space-x-2">
            {isLastStep ? (
              <button
                onClick={onComplete}
                className="px-4 py-2 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700 transition-colors"
              >
                Complete
              </button>
            ) : (
              currentStepData.showNext !== false && (
                <button
                  onClick={currentStepData.onNext || onNext}
                  className="px-4 py-2 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700 transition-colors"
                >
                  Next
                </button>
              )
            )}
          </div>
        </div>
        
        {/* Progress indicator */}
        <div className="mt-4 bg-gray-200 dark:bg-gray-700 rounded-full h-1">
          <motion.div
            className="bg-blue-600 h-1 rounded-full"
            initial={{ width: 0 }}
            animate={{ width: `${((currentStep + 1) / steps.length) * 100}%` }}
            transition={{ duration: 0.3 }}
          />
        </div>
      </motion.div>
    </>,
    document.body
  );
};

// User Feedback Collection Component
export const FeedbackWidget: React.FC<{
  onSubmit: (feedback: {
    rating: number;
    comment: string;
    category: string;
  }) => void;
}> = ({ onSubmit }) => {
  const [isOpen, setIsOpen] = React.useState(false);
  const [rating, setRating] = React.useState(0);
  const [comment, setComment] = React.useState('');
  const [category, setCategory] = React.useState('general');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit({ rating, comment, category });
    setIsOpen(false);
    setRating(0);
    setComment('');
    setCategory('general');
  };

  return (
    <>
      <button
        onClick={() => setIsOpen(true)}
        className="fixed bottom-4 right-4 bg-blue-600 text-white p-3 rounded-full shadow-lg hover:bg-blue-700 transition-colors z-40"
      >
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-3.582 8-8 8a8.959 8.959 0 01-4.906-1.456L3 21l2.544-5.094A8.959 8.959 0 013 12c0-4.418 3.582-8 8-8s8 3.582 8 8z" />
        </svg>
      </button>

      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.9 }}
            className="fixed bottom-20 right-4 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-xl p-6 w-80 z-50"
          >
            <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-4">
              Share Your Feedback
            </h3>
            
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  How would you rate your experience?
                </label>
                <div className="flex space-x-1">
                  {[1, 2, 3, 4, 5].map((star) => (
                    <button
                      key={star}
                      type="button"
                      onClick={() => setRating(star)}
                      className={`text-2xl ${star <= rating ? 'text-yellow-400' : 'text-gray-300 dark:text-gray-600'} hover:text-yellow-400 transition-colors`}
                    >
                      ★
                    </button>
                  ))}
                </div>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Category
                </label>
                <select
                  value={category}
                  onChange={(e) => setCategory(e.target.value)}
                  className="w-full p-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                >
                  <option value="general">General Feedback</option>
                  <option value="bug">Bug Report</option>
                  <option value="feature">Feature Request</option>
                  <option value="usability">Usability Issue</option>
                </select>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Additional Comments
                </label>
                <textarea
                  value={comment}
                  onChange={(e) => setComment(e.target.value)}
                  rows={3}
                  className="w-full p-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100"
                  placeholder="Tell us more about your experience..."
                />
              </div>
              
              <div className="flex justify-end space-x-2">
                <button
                  type="button"
                  onClick={() => setIsOpen(false)}
                  className="px-4 py-2 text-sm text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={rating === 0}
                  className="px-4 py-2 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50"
                >
                  Submit
                </button>
              </div>
            </form>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
};

// Toast Helper Functions
export const toast = {
  success: (title: string, message?: string, options?: Partial<Toast>) => {
    const { addToast } = useToast();
    addToast({ type: 'success', title, message, ...options });
  },
  error: (title: string, message?: string, options?: Partial<Toast>) => {
    const { addToast } = useToast();
    addToast({ type: 'error', title, message, ...options });
  },
  warning: (title: string, message?: string, options?: Partial<Toast>) => {
    const { addToast } = useToast();
    addToast({ type: 'warning', title, message, ...options });
  },
  info: (title: string, message?: string, options?: Partial<Toast>) => {
    const { addToast } = useToast();
    addToast({ type: 'info', title, message, ...options });
  }
};