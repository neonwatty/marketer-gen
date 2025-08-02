import React from 'react';

interface SuggestionsPanelProps {
  suggestions: string[];
  onSuggestionClick: (suggestion: string) => void;
  onClose: () => void;
}

const SuggestionsPanel: React.FC<SuggestionsPanelProps> = ({
  suggestions,
  onSuggestionClick,
  onClose,
}) => {
  if (suggestions.length === 0) {return null;}

  return (
    <div className="mx-4 mb-4 p-3 bg-purple-50 border border-purple-200 rounded-lg">
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center space-x-2">
          <svg className="w-4 h-4 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
          </svg>
          <h4 className="text-sm font-medium text-purple-900">Quick suggestions</h4>
        </div>
        <button
          onClick={onClose}
          className="text-purple-400 hover:text-purple-600 transition-colors"
          aria-label="Close suggestions"
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <div className="grid grid-cols-1 gap-2">
        {suggestions.map((suggestion, index) => (
          <button
            key={index}
            onClick={() => onSuggestionClick(suggestion)}
            className="w-full text-left p-3 bg-white border border-purple-200 rounded-lg hover:border-purple-300 hover:bg-purple-50 transition-colors group"
          >
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-900 group-hover:text-purple-900">
                {suggestion}
              </span>
              <svg className="w-4 h-4 text-purple-400 group-hover:text-purple-600 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4l-1.41 1.41L16.17 11H4v2h12.17l-5.58 5.59L12 20l8-8-8-8z" />
              </svg>
            </div>
          </button>
        ))}
      </div>

      <div className="mt-3 text-xs text-purple-600 text-center">
        Click any suggestion to use it, or type your own response
      </div>
    </div>
  );
};

export default SuggestionsPanel;