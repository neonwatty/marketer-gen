import React from 'react';
import ReactDOM from 'react-dom/client';
import { JourneyBuilderFlow } from './components/JourneyBuilderFlow';
import PropertiesPanel from './components/PropertiesPanel';
import AISuggestionsPanel from './components/AISuggestionsPanel';
import JourneyPreviewModal from './components/JourneyPreviewModal';
import { useJourneyStore } from './stores/journeyStore';

interface JourneyBuilderAppProps {
  templateId?: string;
  journeyData?: any;
}

const JourneyBuilderApp: React.FC<JourneyBuilderAppProps> = ({ 
  templateId: _templateId, 
  journeyData 
}) => {
  const { loadJourney, journey } = useJourneyStore();
  const [isPreviewOpen, setIsPreviewOpen] = React.useState(false);

  // Load initial journey data if provided
  React.useEffect(() => {
    if (journeyData) {
      loadJourney(journeyData);
    }
  }, [journeyData, loadJourney]);

  const handleSave = async () => {
    try {
      await useJourneyStore.getState().saveJourney();
      // Show success message
      console.log('Journey saved successfully');
    } catch (error) {
      console.error('Failed to save journey:', error);
      // Show error message
    }
  };

  const handlePreview = () => {
    setIsPreviewOpen(true);
  };

  return (
    <div className="journey-builder-app">
      <AISuggestionsPanel />
      <div className="builder-main">
        <JourneyBuilderFlow 
          onSave={handleSave}
          onPreview={handlePreview}
        />
      </div>
      <PropertiesPanel />
      
      <JourneyPreviewModal
        isOpen={isPreviewOpen}
        onClose={() => setIsPreviewOpen(false)}
        journey={journey}
      />

      <style jsx>{`
        .journey-builder-app {
          display: flex;
          height: 100vh;
          background: #f9fafb;
        }

        .builder-main {
          flex: 1;
          position: relative;
        }
      `}</style>
    </div>
  );
};

// Initialize the React app when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  const container = document.getElementById('react-journey-builder');
  if (container) {
    const root = ReactDOM.createRoot(container);
    
    // Get initial data from data attributes
    const templateId = container.dataset.templateId;
    const journeyDataStr = container.dataset.journeyData;
    const journeyData = journeyDataStr ? JSON.parse(journeyDataStr) : null;
    
    root.render(
      <JourneyBuilderApp 
        templateId={templateId}
        journeyData={journeyData}
      />
    );
  }
});

export default JourneyBuilderApp;