import React, { useState } from 'react';
import { Question } from '../../types/campaign-intake';
import { useForm, Controller } from 'react-hook-form';
import { yupResolver } from '@hookform/resolvers/yup';
import * as yup from 'yup';

interface QuestionCardProps {
  question: Question;
  onResponse: (response: string | number | string[]) => void;
  isLoading?: boolean;
}

const QuestionCard: React.FC<QuestionCardProps> = ({
  question,
  onResponse,
  isLoading = false,
}) => {
  const [selectedOptions, setSelectedOptions] = useState<string[]>([]);

  // Build validation schema based on question
  const getValidationSchema = () => {
    let schema = yup.string();
    
    if (question.required) {
      schema = schema.required('This field is required');
    }
    
    if (question.validation) {
      const { min, max, minLength, maxLength, pattern } = question.validation;
      
      if (minLength) {schema = schema.min(minLength, `Minimum ${minLength} characters required`);}
      if (maxLength) {schema = schema.max(maxLength, `Maximum ${maxLength} characters allowed`);}
      if (pattern) {schema = schema.matches(new RegExp(pattern), 'Invalid format');}
      
      if (question.type === 'number') {
        let numSchema = yup.number();
        if (question.required) {numSchema = numSchema.required('This field is required');}
        if (min !== undefined) {numSchema = numSchema.min(min, `Minimum value is ${min}`);}
        if (max !== undefined) {numSchema = numSchema.max(max, `Maximum value is ${max}`);}
        return yup.object({ response: numSchema });
      }
    }
    
    return yup.object({ response: schema });
  };

  const { control, handleSubmit, formState: { errors }, watch } = useForm({
    resolver: yupResolver(getValidationSchema()),
    defaultValues: { response: question.type === 'multiselect' ? [] : '' }
  });

  const watchedValue = watch('response');

  const onSubmit = (data: { response: string | number | string[] }) => {
    let response = data.response;
    
    if (question.type === 'multiselect') {
      response = selectedOptions;
    }
    
    onResponse(response);
  };

  const handleMultiSelectChange = (option: string, checked: boolean) => {
    const newSelection = checked 
      ? [...selectedOptions, option]
      : selectedOptions.filter(item => item !== option);
    
    setSelectedOptions(newSelection);
  };

  const renderQuestionInput = () => {
    switch (question.type) {
      case 'select':
        return (
          <Controller
            name="response"
            control={control}
            render={({ field }) => (
              <select
                {...field}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                disabled={isLoading}
              >
                <option value="">Choose an option...</option>
                {question.options?.map((option) => (
                  <option key={option} value={option}>
                    {option}
                  </option>
                ))}
              </select>
            )}
          />
        );

      case 'multiselect':
        return (
          <div className="space-y-2">
            {question.options?.map((option) => (
              <label key={option} className="flex items-center space-x-3 cursor-pointer">
                <input
                  type="checkbox"
                  checked={selectedOptions.includes(option)}
                  onChange={(e) => handleMultiSelectChange(option, e.target.checked)}
                  disabled={isLoading}
                  className="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                />
                <span className="text-sm text-gray-700">{option}</span>
              </label>
            ))}
          </div>
        );

      case 'number':
        return (
          <Controller
            name="response"
            control={control}
            render={({ field }) => (
              <input
                {...field}
                type="number"
                min={question.validation?.min}
                max={question.validation?.max}
                placeholder="Enter a number..."
                disabled={isLoading}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            )}
          />
        );

      case 'date':
        return (
          <Controller
            name="response"
            control={control}
            render={({ field }) => (
              <input
                {...field}
                type="date"
                disabled={isLoading}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            )}
          />
        );

      case 'textarea':
        return (
          <Controller
            name="response"
            control={control}
            render={({ field }) => (
              <textarea
                {...field}
                rows={4}
                placeholder="Enter your response..."
                disabled={isLoading}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
              />
            )}
          />
        );

      default:
        return (
          <Controller
            name="response"
            control={control}
            render={({ field }) => (
              <input
                {...field}
                type="text"
                placeholder="Enter your response..."
                disabled={isLoading}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            )}
          />
        );
    }
  };

  const isFormValid = () => {
    if (question.type === 'multiselect') {
      return question.required ? selectedOptions.length > 0 : true;
    }
    return question.required ? watchedValue && watchedValue.toString().trim() : true;
  };

  return (
    <div className="mx-4 mb-4 p-4 bg-blue-50 border border-blue-200 rounded-lg">
      <form onSubmit={handleSubmit(onSubmit)}>
        <div className="mb-4">
          <div className="flex items-start space-x-2 mb-3">
            <div className="flex-shrink-0 w-6 h-6 bg-blue-600 text-white rounded-full flex items-center justify-center text-sm font-medium">
              ?
            </div>
            <div className="flex-1">
              <h3 className="text-sm font-medium text-gray-900 mb-1">
                {question.text}
                {question.required && <span className="text-red-500 ml-1">*</span>}
              </h3>
              {question.type === 'multiselect' && (
                <p className="text-xs text-gray-600">You can select multiple options</p>
              )}
            </div>
          </div>

          {renderQuestionInput()}

          {errors.response && (
            <p className="mt-1 text-sm text-red-600">{errors.response.message}</p>
          )}
        </div>

        <div className="flex items-center justify-between">
          <div className="text-xs text-gray-500">
            {question.required ? 'Required field' : 'Optional'}
          </div>
          
          <button
            type="submit"
            disabled={!isFormValid() || isLoading}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              isFormValid() && !isLoading
                ? 'bg-blue-600 text-white hover:bg-blue-700'
                : 'bg-gray-300 text-gray-500 cursor-not-allowed'
            }`}
          >
            {isLoading ? (
              <div className="flex items-center space-x-2">
                <svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                </svg>
                <span>Submitting...</span>
              </div>
            ) : (
              'Submit Answer'
            )}
          </button>
        </div>
      </form>
    </div>
  );
};

export default QuestionCard;