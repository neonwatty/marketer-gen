import React from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Toaster } from 'react-hot-toast';
import CampaignIntakeChat from './components/CampaignIntakeChat';

// Create a client
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
      staleTime: 5 * 60 * 1000, // 5 minutes
    },
  },
});

interface CampaignIntakeAppProps {
  isExpanded?: boolean;
  onToggle?: () => void;
  className?: string;
}

const CampaignIntakeApp: React.FC<CampaignIntakeAppProps> = (props) => {
  return (
    <QueryClientProvider client={queryClient}>
      <div className="campaign-intake-app">
        <CampaignIntakeChat {...props} />
        <Toaster
          position="top-right"
          toastOptions={{
            duration: 4000,
            style: {
              background: '#363636',
              color: '#fff',
            },
            success: {
              duration: 3000,
              iconTheme: {
                primary: '#10B981',
                secondary: '#fff',
              },
            },
            error: {
              duration: 5000,
              iconTheme: {
                primary: '#EF4444',
                secondary: '#fff',
              },
            },
          }}
        />
      </div>
    </QueryClientProvider>
  );
};

// Function to mount the app
export const mountCampaignIntakeApp = (elementId: string, props: CampaignIntakeAppProps = {}) => {
  const container = document.getElementById(elementId);
  if (container) {
    const root = createRoot(container);
    root.render(<CampaignIntakeApp {...props} />);
    return root;
  } else {
    // eslint-disable-next-line no-console
    console.error(`Element with id "${elementId}" not found`);
    return null;
  }
};

// Export for global access
window.CampaignIntake = {
  mount: mountCampaignIntakeApp,
  App: CampaignIntakeApp,
};

export default CampaignIntakeApp;