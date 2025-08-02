import React from 'react';

interface ProgressIndicatorProps {
  progress: number; // 0-100
  estimatedTimeRemaining: number; // in minutes
  currentStep: string;
}

const ProgressIndicator: React.FC<ProgressIndicatorProps> = ({
  progress,
  estimatedTimeRemaining,
  currentStep,
}) => {
  const formatTime = (minutes: number) => {
    if (minutes < 1) {return '< 1 min';}
    if (minutes < 60) {return `${Math.round(minutes)} min`;}
    
    const hours = Math.floor(minutes / 60);
    const remainingMins = Math.round(minutes % 60);
    
    if (remainingMins === 0) {return `${hours}h`;}
    return `${hours}h ${remainingMins}m`;
  };

  const getStepDisplayName = (step: string) => {
    const stepNames: Record<string, string> = {
      'welcome': 'Getting Started',
      'campaign_type': 'Campaign Type',
      'target_audience': 'Target Audience',
      'goals': 'Campaign Goals',
      'budget': 'Budget & Timeline',
      'channels': 'Marketing Channels',
      'content': 'Content Strategy',
      'metrics': 'Success Metrics',
      'review': 'Final Review',
      'complete': 'Complete'
    };
    
    return stepNames[step] || step.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase());
  };

  return (
    <div className="px-4 py-3 bg-gradient-to-r from-blue-50 to-purple-50 border-b border-gray-200">
      <div className="flex items-center justify-between mb-2">
        <div className="flex items-center space-x-2">
          <svg className="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span className="text-sm font-medium text-gray-900">
            {getStepDisplayName(currentStep)}
          </span>
        </div>
        
        <div className="flex items-center space-x-4 text-sm text-gray-600">
          <span>{progress}% complete</span>
          {estimatedTimeRemaining > 0 && (
            <span className="flex items-center">
              <svg className="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              {formatTime(estimatedTimeRemaining)} left
            </span>
          )}
        </div>
      </div>
      
      {/* Progress Bar */}
      <div className="w-full bg-gray-200 rounded-full h-2">
        <div 
          className="bg-gradient-to-r from-blue-600 to-purple-600 h-2 rounded-full transition-all duration-500 ease-out"
          style={{ width: `${Math.min(progress, 100)}%` }}
        />
      </div>
      
      {/* Step indicators */}
      <div className="flex justify-between mt-2 text-xs text-gray-500">
        {['Getting Started', 'Details', 'Strategy', 'Review'].map((step, index) => {
          const stepProgress = (index + 1) * 25;
          const isActive = progress >= stepProgress - 12.5;
          const isCompleted = progress >= stepProgress;
          
          let dotColor = 'bg-gray-300';
          if (isCompleted) {
            dotColor = 'bg-blue-600';
          } else if (isActive) {
            dotColor = 'bg-blue-300';
          }
          
          return (
            <div key={step} className={`flex items-center ${isActive ? 'text-blue-600' : 'text-gray-400'}`}>
              <div className={`w-2 h-2 rounded-full mr-1 ${dotColor}`} />
              {step}
            </div>
          );
        })}
      </div>
    </div>
  );
};

export default ProgressIndicator;