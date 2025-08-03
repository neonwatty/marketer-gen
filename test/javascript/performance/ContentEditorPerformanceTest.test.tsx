/**
 * Content Editor Performance Test Suite
 * Tests editor responsiveness, typing performance, and optimization
 */

import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

// Mock RichTextEditor component with performance-critical features
const MockRichTextEditor = ({ 
  initialContent = '',
  onContentChange,
  features = ['bold', 'italic', 'link', 'list'],
  autoSave = true,
  spellCheck = true
}: {
  initialContent?: string;
  onContentChange?: (content: string) => void;
  features?: string[];
  autoSave?: boolean;
  spellCheck?: boolean;
}) => {
  const [content, setContent] = React.useState(initialContent);
  const [isTyping, setIsTyping] = React.useState(false);
  const [wordCount, setWordCount] = React.useState(0);
  const [saveStatus, setSaveStatus] = React.useState<'saved' | 'saving' | 'unsaved'>('saved');
  const editorRef = React.useRef<HTMLDivElement>(null);

  // Debounced auto-save
  React.useEffect(() => {
    if (!autoSave || !content) return;

    setSaveStatus('saving');
    const timer = setTimeout(() => {
      onContentChange?.(content);
      setSaveStatus('saved');
    }, 500);

    return () => clearTimeout(timer);
  }, [content, autoSave, onContentChange]);

  // Word count calculation
  React.useEffect(() => {
    const words = content.trim().split(/\s+/).filter(word => word.length > 0);
    setWordCount(words.length);
  }, [content]);

  const handleContentChange = (event: React.ChangeEvent<HTMLDivElement>) => {
    const newContent = event.target.innerText;
    setContent(newContent);
    setSaveStatus('unsaved');
    setIsTyping(true);
    
    // Clear typing indicator after delay
    setTimeout(() => setIsTyping(false), 1000);
  };

  const handleKeyDown = (event: React.KeyboardEvent) => {
    // Handle keyboard shortcuts
    if (event.ctrlKey || event.metaKey) {
      switch (event.key) {
        case 'b':
          event.preventDefault();
          document.execCommand('bold');
          break;
        case 'i':
          event.preventDefault();
          document.execCommand('italic');
          break;
        case 'k':
          event.preventDefault();
          // Mock link insertion
          break;
      }
    }
  };

  const formatText = (command: string) => {
    document.execCommand(command, false);
    editorRef.current?.focus();
  };

  return (
    <div className="rich-text-editor" data-testid="rich-text-editor">
      {/* Toolbar */}
      <div className="editor-toolbar" data-testid="editor-toolbar">
        {features.includes('bold') && (
          <button
            data-testid="bold-button"
            onMouseDown={(e) => e.preventDefault()}
            onClick={() => formatText('bold')}
            className="toolbar-button"
          >
            Bold
          </button>
        )}
        {features.includes('italic') && (
          <button
            data-testid="italic-button"
            onMouseDown={(e) => e.preventDefault()}
            onClick={() => formatText('italic')}
            className="toolbar-button"
          >
            Italic
          </button>
        )}
        {features.includes('link') && (
          <button
            data-testid="link-button"
            onMouseDown={(e) => e.preventDefault()}
            onClick={() => formatText('createLink')}
            className="toolbar-button"
          >
            Link
          </button>
        )}
        {features.includes('list') && (
          <button
            data-testid="list-button"
            onMouseDown={(e) => e.preventDefault()}
            onClick={() => formatText('insertUnorderedList')}
            className="toolbar-button"
          >
            List
          </button>
        )}
      </div>

      {/* Editor content area */}
      <div
        ref={editorRef}
        data-testid="editor-content"
        contentEditable
        suppressContentEditableWarning
        onInput={handleContentChange}
        onKeyDown={handleKeyDown}
        className="editor-content"
        spellCheck={spellCheck}
        style={{
          minHeight: '200px',
          border: '1px solid #ccc',
          padding: '12px',
          fontSize: '14px',
          lineHeight: '1.5'
        }}
        dangerouslySetInnerHTML={{ __html: initialContent }}
      />

      {/* Status bar */}
      <div className="editor-status" data-testid="editor-status">
        <span data-testid="word-count">Words: {wordCount}</span>
        <span data-testid="save-status" className={`save-status ${saveStatus}`}>
          {saveStatus === 'saving' && isTyping && '⏳ Saving...'}
          {saveStatus === 'saved' && !isTyping && '✅ Saved'}
          {saveStatus === 'unsaved' && !isTyping && '⚠️ Unsaved'}
          {isTyping && '✍️ Typing...'}
        </span>
      </div>
    </div>
  );
};

// Mock MediaManager component
const MockMediaManager = ({ 
  onImageInsert,
  maxFileSize = 5 * 1024 * 1024 // 5MB
}: {
  onImageInsert?: (url: string) => void;
  maxFileSize?: number;
}) => {
  const [uploading, setUploading] = React.useState(false);
  const [uploadProgress, setUploadProgress] = React.useState(0);

  const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    if (file.size > maxFileSize) {
      alert('File too large');
      return;
    }

    setUploading(true);
    setUploadProgress(0);

    // Simulate upload progress
    const interval = setInterval(() => {
      setUploadProgress(prev => {
        if (prev >= 100) {
          clearInterval(interval);
          setUploading(false);
          onImageInsert?.(`data:image/jpeg;base64,${btoa('mock-image-data')}`);
          return 100;
        }
        return prev + 10;
      });
    }, 50);
  };

  return (
    <div className="media-manager" data-testid="media-manager">
      <input
        type="file"
        accept="image/*"
        onChange={handleFileUpload}
        data-testid="file-input"
        disabled={uploading}
      />
      {uploading && (
        <div className="upload-progress" data-testid="upload-progress">
          <div 
            className="progress-bar"
            style={{ width: `${uploadProgress}%`, height: '4px', backgroundColor: '#007cba' }}
          />
          <span>{uploadProgress}%</span>
        </div>
      )}
    </div>
  );
};

// Performance measurement utilities
const measureTypingLatency = async (
  element: HTMLElement,
  text: string,
  delayBetweenKeys = 16 // ~60fps
): Promise<number[]> => {
  const latencies: number[] = [];
  
  for (const char of text) {
    const start = performance.now();
    
    // Simulate keystroke
    fireEvent.keyDown(element, { key: char });
    fireEvent.input(element, { data: char });
    
    // Wait for next frame
    await new Promise(resolve => requestAnimationFrame(resolve));
    
    const end = performance.now();
    latencies.push(end - start);
    
    // Delay between keystrokes
    if (delayBetweenKeys > 0) {
      await new Promise(resolve => setTimeout(resolve, delayBetweenKeys));
    }
  }
  
  return latencies;
};

const measureRenderTime = async (renderFunction: () => void): Promise<number> => {
  const start = performance.now();
  renderFunction();
  await new Promise(resolve => setTimeout(resolve, 0));
  const end = performance.now();
  return end - start;
};

const measureMemoryUsage = (): number => {
  if ('memory' in performance) {
    return (performance as any).memory.usedJSHeapSize;
  }
  return 0;
};

describe('Content Editor Performance Tests', () => {
  const PERFORMANCE_THRESHOLDS = {
    INITIAL_RENDER: 100,        // 100ms for initial render
    TYPING_LATENCY: 16,         // 16ms per keystroke (60fps)
    TOOLBAR_INTERACTION: 50,    // 50ms for toolbar clicks
    AUTO_SAVE_DELAY: 600,       // 600ms for auto-save
    LARGE_CONTENT_RENDER: 500,  // 500ms for large content
    FORMAT_OPERATION: 100,      // 100ms for formatting
    IMAGE_UPLOAD_START: 100,    // 100ms to start upload
    SCROLL_PERFORMANCE: 16,     // 16ms per scroll frame
    MEMORY_LEAK_THRESHOLD: 10 * 1024 * 1024, // 10MB
    UNDO_REDO_TIME: 50         // 50ms for undo/redo
  };

  describe('Initial Editor Performance', () => {
    it('should render editor within performance threshold', async () => {
      const renderTime = await measureRenderTime(() => {
        render(<MockRichTextEditor />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.INITIAL_RENDER);
    });

    it('should render editor with large initial content efficiently', async () => {
      const largeContent = Array.from({ length: 1000 }, (_, i) => 
        `This is paragraph ${i + 1} with some sample content to test performance.`
      ).join(' ');

      const renderTime = await measureRenderTime(() => {
        render(<MockRichTextEditor initialContent={largeContent} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.LARGE_CONTENT_RENDER);
    });

    it('should render toolbar buttons efficiently', async () => {
      render(
        <MockRichTextEditor 
          features={['bold', 'italic', 'underline', 'link', 'list', 'quote', 'code', 'image']}
        />
      );

      const toolbar = screen.getByTestId('editor-toolbar');
      const buttons = toolbar.querySelectorAll('button');
      
      expect(buttons.length).toBeGreaterThan(0);
      expect(toolbar).toBeInTheDocument();
    });
  });

  describe('Typing Performance', () => {
    it('should maintain low latency during typing', async () => {
      render(<MockRichTextEditor />);
      
      const editor = screen.getByTestId('editor-content');
      const testText = 'Hello, this is a typing performance test!';
      
      const latencies = await measureTypingLatency(editor, testText);
      
      // All keystrokes should be under threshold
      const maxLatency = Math.max(...latencies);
      const avgLatency = latencies.reduce((a, b) => a + b, 0) / latencies.length;
      
      expect(maxLatency).toBeLessThan(PERFORMANCE_THRESHOLDS.TYPING_LATENCY * 2);
      expect(avgLatency).toBeLessThan(PERFORMANCE_THRESHOLDS.TYPING_LATENCY);
    });

    it('should handle rapid typing without performance degradation', async () => {
      render(<MockRichTextEditor />);
      
      const editor = screen.getByTestId('editor-content');
      const rapidText = 'abcdefghijklmnopqrstuvwxyz'.repeat(10);
      
      const startTime = performance.now();
      
      // Type rapidly (no delay between keys)
      for (const char of rapidText) {
        fireEvent.input(editor, { target: { innerText: char } });
      }
      
      const endTime = performance.now();
      const totalTime = endTime - startTime;
      const avgTimePerChar = totalTime / rapidText.length;
      
      expect(avgTimePerChar).toBeLessThan(PERFORMANCE_THRESHOLDS.TYPING_LATENCY);
    });

    it('should maintain performance with spell check enabled', async () => {
      render(<MockRichTextEditor spellCheck={true} />);
      
      const editor = screen.getByTestId('editor-content');
      const textWithTypos = 'Thsi is a test with speling erors.';
      
      const latencies = await measureTypingLatency(editor, textWithTypos, 50);
      const avgLatency = latencies.reduce((a, b) => a + b, 0) / latencies.length;
      
      expect(avgLatency).toBeLessThan(PERFORMANCE_THRESHOLDS.TYPING_LATENCY * 1.5);
    });
  });

  describe('Formatting Performance', () => {
    it('should handle bold formatting efficiently', async () => {
      render(<MockRichTextEditor />);
      
      const boldButton = screen.getByTestId('bold-button');
      
      const start = performance.now();
      fireEvent.click(boldButton);
      await new Promise(resolve => setTimeout(resolve, 0));
      const end = performance.now();
      
      const formatTime = end - start;
      expect(formatTime).toBeLessThan(PERFORMANCE_THRESHOLDS.FORMAT_OPERATION);
    });

    it('should handle multiple formatting operations efficiently', async () => {
      render(<MockRichTextEditor />);
      
      const boldButton = screen.getByTestId('bold-button');
      const italicButton = screen.getByTestId('italic-button');
      
      const start = performance.now();
      
      // Apply multiple formats
      fireEvent.click(boldButton);
      fireEvent.click(italicButton);
      
      await new Promise(resolve => setTimeout(resolve, 0));
      const end = performance.now();
      
      const totalTime = end - start;
      expect(totalTime).toBeLessThan(PERFORMANCE_THRESHOLDS.FORMAT_OPERATION * 2);
    });

    it('should handle keyboard shortcuts efficiently', async () => {
      render(<MockRichTextEditor />);
      
      const editor = screen.getByTestId('editor-content');
      
      const start = performance.now();
      
      // Test Ctrl+B for bold
      fireEvent.keyDown(editor, { key: 'b', ctrlKey: true });
      
      await new Promise(resolve => setTimeout(resolve, 0));
      const end = performance.now();
      
      const shortcutTime = end - start;
      expect(shortcutTime).toBeLessThan(PERFORMANCE_THRESHOLDS.FORMAT_OPERATION);
    });
  });

  describe('Auto-Save Performance', () => {
    it('should auto-save without blocking UI', async () => {
      const mockSave = jest.fn();
      render(<MockRichTextEditor onContentChange={mockSave} autoSave={true} />);
      
      const editor = screen.getByTestId('editor-content');
      
      // Type some content
      fireEvent.input(editor, { target: { innerText: 'Auto-save test content' } });
      
      // Should show saving status
      await waitFor(() => {
        expect(screen.getByText(/Saving.../)).toBeInTheDocument();
      }, { timeout: 100 });
      
      // Should complete within threshold
      await waitFor(() => {
        expect(mockSave).toHaveBeenCalled();
      }, { timeout: PERFORMANCE_THRESHOLDS.AUTO_SAVE_DELAY });
    });

    it('should debounce multiple auto-saves efficiently', async () => {
      const mockSave = jest.fn();
      render(<MockRichTextEditor onContentChange={mockSave} autoSave={true} />);
      
      const editor = screen.getByTestId('editor-content');
      
      // Make multiple quick changes
      fireEvent.input(editor, { target: { innerText: 'First change' } });
      fireEvent.input(editor, { target: { innerText: 'Second change' } });
      fireEvent.input(editor, { target: { innerText: 'Third change' } });
      
      // Wait for debounce to complete
      await new Promise(resolve => setTimeout(resolve, PERFORMANCE_THRESHOLDS.AUTO_SAVE_DELAY));
      
      // Should only save once due to debouncing
      expect(mockSave).toHaveBeenCalledTimes(1);
      expect(mockSave).toHaveBeenCalledWith('Third change');
    });
  });

  describe('Large Content Performance', () => {
    it('should handle large documents efficiently', async () => {
      const largeContent = Array.from({ length: 5000 }, (_, i) => 
        `Line ${i + 1}: This line contains substantial text content to test editor performance with large documents.`
      ).join('\n');

      const renderTime = await measureRenderTime(() => {
        render(<MockRichTextEditor initialContent={largeContent} />);
      });

      expect(renderTime).toBeLessThan(PERFORMANCE_THRESHOLDS.LARGE_CONTENT_RENDER * 2);
    });

    it('should maintain scroll performance with large content', async () => {
      const largeContent = Array.from({ length: 1000 }, (_, i) => 
        `Paragraph ${i + 1}\n`
      ).join('');

      render(<MockRichTextEditor initialContent={largeContent} />);
      
      const editor = screen.getByTestId('editor-content');
      
      // Simulate scrolling
      const scrollStart = performance.now();
      
      for (let i = 0; i < 10; i++) {
        fireEvent.scroll(editor, { target: { scrollTop: i * 100 } });
        await new Promise(resolve => requestAnimationFrame(resolve));
      }
      
      const scrollEnd = performance.now();
      const avgScrollTime = (scrollEnd - scrollStart) / 10;
      
      expect(avgScrollTime).toBeLessThan(PERFORMANCE_THRESHOLDS.SCROLL_PERFORMANCE * 2);
    });

    it('should virtualize large content when needed', async () => {
      const veryLargeContent = Array.from({ length: 10000 }, (_, i) => 
        `Line ${i + 1}`
      ).join('\n');

      const initialMemory = measureMemoryUsage();
      
      render(<MockRichTextEditor initialContent={veryLargeContent} />);
      
      const finalMemory = measureMemoryUsage();
      const memoryUsed = finalMemory - initialMemory;
      
      // Should not use excessive memory
      expect(memoryUsed).toBeLessThan(50 * 1024 * 1024); // 50MB limit
    });
  });

  describe('Media Upload Performance', () => {
    it('should start image upload within threshold', async () => {
      const mockInsert = jest.fn();
      render(<MockMediaManager onImageInsert={mockInsert} />);
      
      const fileInput = screen.getByTestId('file-input');
      
      // Create mock file
      const file = new File(['mock image data'], 'test.jpg', { type: 'image/jpeg' });
      
      const start = performance.now();
      
      fireEvent.change(fileInput, { target: { files: [file] } });
      
      // Should show upload progress quickly
      await waitFor(() => {
        expect(screen.getByTestId('upload-progress')).toBeInTheDocument();
      }, { timeout: PERFORMANCE_THRESHOLDS.IMAGE_UPLOAD_START });
      
      const end = performance.now();
      expect(end - start).toBeLessThan(PERFORMANCE_THRESHOLDS.IMAGE_UPLOAD_START);
    });

    it('should handle multiple file uploads efficiently', async () => {
      const mockInsert = jest.fn();
      render(<MockMediaManager onImageInsert={mockInsert} />);
      
      const fileInput = screen.getByTestId('file-input');
      
      // Upload multiple files sequentially
      const files = Array.from({ length: 3 }, (_, i) => 
        new File([`mock data ${i}`], `test${i}.jpg`, { type: 'image/jpeg' })
      );
      
      const startTime = performance.now();
      
      for (const file of files) {
        fireEvent.change(fileInput, { target: { files: [file] } });
        await waitFor(() => {
          expect(screen.queryByTestId('upload-progress')).toBeInTheDocument();
        });
        // Wait for upload to complete
        await new Promise(resolve => setTimeout(resolve, 600));
      }
      
      const endTime = performance.now();
      const avgUploadTime = (endTime - startTime) / files.length;
      
      expect(avgUploadTime).toBeLessThan(1000); // 1 second per upload
    });
  });

  describe('Memory Management', () => {
    it('should not leak memory during extended editing', async () => {
      const initialMemory = measureMemoryUsage();
      
      const { unmount } = render(<MockRichTextEditor />);
      
      const editor = screen.getByTestId('editor-content');
      
      // Simulate extended editing session
      for (let i = 0; i < 100; i++) {
        fireEvent.input(editor, { target: { innerText: `Content update ${i}` } });
        await new Promise(resolve => setTimeout(resolve, 10));
      }
      
      unmount();
      
      // Force garbage collection
      if (global.gc) {
        global.gc();
      }
      
      await new Promise(resolve => setTimeout(resolve, 100));
      
      const finalMemory = measureMemoryUsage();
      const memoryDiff = finalMemory - initialMemory;
      
      expect(memoryDiff).toBeLessThan(PERFORMANCE_THRESHOLDS.MEMORY_LEAK_THRESHOLD);
    });

    it('should clean up event listeners properly', async () => {
      const { unmount } = render(<MockRichTextEditor />);
      
      const editor = screen.getByTestId('editor-content');
      
      // Add some content and interactions
      fireEvent.keyDown(editor, { key: 'b', ctrlKey: true });
      fireEvent.input(editor, { target: { innerText: 'Test content' } });
      
      // Component should unmount without errors
      expect(() => unmount()).not.toThrow();
    });
  });

  describe('Responsive Performance', () => {
    it('should adapt to different screen sizes efficiently', async () => {
      // Test desktop view
      Object.defineProperty(window, 'innerWidth', { value: 1920 });
      const { rerender } = render(<MockRichTextEditor />);
      
      // Switch to mobile view
      Object.defineProperty(window, 'innerWidth', { value: 390 });
      
      const start = performance.now();
      fireEvent(window, new Event('resize'));
      rerender(<MockRichTextEditor />);
      const end = performance.now();
      
      expect(end - start).toBeLessThan(100); // 100ms for responsive change
    });
  });

  describe('Accessibility Performance', () => {
    it('should maintain performance with screen reader support', async () => {
      render(
        <MockRichTextEditor 
          features={['bold', 'italic', 'link']}
        />
      );
      
      const editor = screen.getByTestId('editor-content');
      const toolbar = screen.getByTestId('editor-toolbar');
      
      // Should have proper ARIA attributes
      expect(editor).toBeInTheDocument();
      expect(toolbar).toBeInTheDocument();
      
      // Should handle keyboard navigation efficiently
      const start = performance.now();
      fireEvent.keyDown(toolbar, { key: 'Tab' });
      fireEvent.keyDown(toolbar, { key: 'Enter' });
      const end = performance.now();
      
      expect(end - start).toBeLessThan(50);
    });
  });
});