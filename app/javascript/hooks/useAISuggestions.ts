import { useState, useEffect, useCallback } from 'react';
import type { AISuggestion, JourneyStep } from '../types/journey';

interface AISuggestionsParams {
  stage?: string;
  stepType?: string;
  previousSteps?: JourneyStep[];
  journeyContext?: any;
}

export const useAISuggestions = (params: AISuggestionsParams = {}) => {
  const [suggestions, setSuggestions] = useState<AISuggestion[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchSuggestions = useCallback(async (customParams?: AISuggestionsParams) => {
    const _finalParams = { ...params, ...customParams };
    setIsLoading(true);
    setError(null);

    try {
      const response = await fetch('/api/journey_suggestions', {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
        }
      });

      if (!response.ok) {
        throw new Error('Failed to fetch suggestions');
      }

      const data = await response.json();
      setSuggestions(data.suggestions || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
      setSuggestions([]);
    } finally {
      setIsLoading(false);
    }
  }, [params]);

  const fetchSuggestionsForStage = async (stage: string) => {
    setIsLoading(true);
    setError(null);

    try {
      const response = await fetch(`/api/journey_suggestions/for_stage/${stage}`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
        }
      });

      if (!response.ok) {
        throw new Error('Failed to fetch stage suggestions');
      }

      const data = await response.json();
      setSuggestions(data.suggestions || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
      setSuggestions([]);
    } finally {
      setIsLoading(false);
    }
  };

  const fetchSuggestionsForStep = async (stepData: any) => {
    setIsLoading(true);
    setError(null);

    try {
      const response = await fetch('/api/journey_suggestions/for_step', {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
        },
        body: JSON.stringify(stepData)
      });

      if (!response.ok) {
        throw new Error('Failed to fetch step suggestions');
      }

      const data = await response.json();
      setSuggestions(data.suggestions || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
      setSuggestions([]);
    } finally {
      setIsLoading(false);
    }
  };

  const submitFeedback = async (suggestionId: string, feedbackType: 'positive' | 'negative', rating?: number, comment?: string) => {
    try {
      const response = await fetch('/api/journey_suggestions/feedback', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
        },
        body: JSON.stringify({
          suggestion_id: suggestionId,
          feedback_type: feedbackType,
          rating,
          comment
        })
      });

      if (!response.ok) {
        throw new Error('Failed to submit feedback');
      }

      return await response.json();
    } catch (err) {
      console.error('Error submitting feedback:', err);
      throw err;
    }
  };

  // Auto-fetch suggestions when params change
  useEffect(() => {
    if (params.stage || params.stepType) {
      fetchSuggestions();
    }
  }, [params.stage, params.stepType, fetchSuggestions]);

  return {
    suggestions,
    isLoading,
    error,
    fetchSuggestions,
    fetchSuggestionsForStage,
    fetchSuggestionsForStep,
    submitFeedback,
    refetch: fetchSuggestions
  };
};

export default useAISuggestions;