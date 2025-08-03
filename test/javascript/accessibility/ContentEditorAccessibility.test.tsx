import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { axe, toHaveNoViolations } from 'jest-axe';

expect.extend(toHaveNoViolations);

// Content editor accessibility testing
describe('Content Editor Accessibility', () => {
  const wcagConfig = {
    rules: {
      'color-contrast': { enabled: true },
      'aria-allowed-attr': { enabled: true },
      'aria-required-attr': { enabled: true },
      'aria-roles': { enabled: true },
      'aria-valid-attr': { enabled: true },
      'aria-valid-attr-value': { enabled: true },
      'button-name': { enabled: true },
      'image-alt': { enabled: true },
      'label': { enabled: true },
      'form-field-multiple-labels': { enabled: true },
      'tabindex': { enabled: true },
      'focus-order-semantics': { enabled: true }
    },
    tags: ['wcag2a', 'wcag2aa', 'wcag21aa']
  };

  it('should provide accessible rich text editor', async () => {
    const RichTextEditor = () => {
      const [content, setContent] = React.useState('');
      const [isBold, setIsBold] = React.useState(false);
      const [isItalic, setIsItalic] = React.useState(false);
      const [isUnderline, setIsUnderline] = React.useState(false);

      return (
        <div role="region" aria-labelledby="editor-title">
          <h2 id="editor-title">Rich Text Editor</h2>
          
          {/* Toolbar */}
          <div role="toolbar" aria-label="Text formatting" aria-controls="editor-content">
            <div role="group" aria-label="Text styling">
              <button
                type="button"
                aria-pressed={isBold}
                aria-label="Bold"
                title="Bold (Ctrl+B)"
                onClick={() => setIsBold(!isBold)}
              >
                <strong aria-hidden="true">B</strong>
              </button>
              
              <button
                type="button"
                aria-pressed={isItalic}
                aria-label="Italic"
                title="Italic (Ctrl+I)"
                onClick={() => setIsItalic(!isItalic)}
              >
                <em aria-hidden="true">I</em>
              </button>
              
              <button
                type="button"
                aria-pressed={isUnderline}
                aria-label="Underline"
                title="Underline (Ctrl+U)"
                onClick={() => setIsUnderline(!isUnderline)}
              >
                <span aria-hidden="true" style={{ textDecoration: 'underline' }}>U</span>
              </button>
            </div>

            <div role="separator" aria-orientation="vertical"></div>

            <div role="group" aria-label="Text alignment">
              <button
                type="button"
                aria-label="Align left"
                title="Align left (Ctrl+Shift+L)"
              >
                <span aria-hidden="true">⬅</span>
              </button>
              
              <button
                type="button"
                aria-label="Align center"
                title="Align center (Ctrl+Shift+E)"
              >
                <span aria-hidden="true">↔</span>
              </button>
              
              <button
                type="button"
                aria-label="Align right"
                title="Align right (Ctrl+Shift+R)"
              >
                <span aria-hidden="true">➡</span>
              </button>
            </div>

            <div role="separator" aria-orientation="vertical"></div>

            <div role="group" aria-label="Lists">
              <button
                type="button"
                aria-label="Bulleted list"
                title="Bulleted list (Ctrl+Shift+8)"
              >
                <span aria-hidden="true">•</span>
              </button>
              
              <button
                type="button"
                aria-label="Numbered list"
                title="Numbered list (Ctrl+Shift+7)"
              >
                <span aria-hidden="true">1.</span>
              </button>
            </div>

            <div role="separator" aria-orientation="vertical"></div>

            <div role="group" aria-label="Insert content">
              <button
                type="button"
                aria-label="Insert link"
                title="Insert link (Ctrl+K)"
              >
                <span aria-hidden="true">🔗</span>
              </button>
              
              <button
                type="button"
                aria-label="Insert image"
                title="Insert image"
              >
                <span aria-hidden="true">🖼</span>
              </button>
              
              <button
                type="button"
                aria-label="Insert table"
                title="Insert table"
              >
                <span aria-hidden="true">⊞</span>
              </button>
            </div>
          </div>

          {/* Editor content area */}
          <div
            id="editor-content"
            role="textbox"
            aria-multiline="true"
            aria-label="Content editor"
            aria-describedby="editor-help"
            contentEditable
            tabIndex={0}
            style={{
              minHeight: '200px',
              border: '1px solid #ccc',
              padding: '10px',
              backgroundColor: '#fff'
            }}
            onInput={(e) => setContent(e.currentTarget.textContent || '')}
            onKeyDown={(e) => {
              // Handle keyboard shortcuts
              if (e.ctrlKey) {
                switch (e.key) {
                  case 'b':
                    e.preventDefault();
                    setIsBold(!isBold);
                    break;
                  case 'i':
                    e.preventDefault();
                    setIsItalic(!isItalic);
                    break;
                  case 'u':
                    e.preventDefault();
                    setIsUnderline(!isUnderline);
                    break;
                }
              }
            }}
          >
            {!content && (
              <span style={{ color: '#999', pointerEvents: 'none' }}>
                Start typing here...
              </span>
            )}
          </div>

          <div id="editor-help" className="sr-only">
            Use the toolbar buttons above to format text, or use keyboard shortcuts. 
            Press Ctrl+B for bold, Ctrl+I for italic, Ctrl+U for underline.
          </div>

          {/* Status bar */}
          <div role="status" aria-live="polite" aria-label="Editor status">
            <span>Characters: {content.length}</span>
            <span>Words: {content.split(/\s+/).filter(word => word.length > 0).length}</span>
          </div>
        </div>
      );
    };

    const { container } = render(<RichTextEditor />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test toolbar buttons
    const boldButton = screen.getByRole('button', { name: 'Bold' });
    const italicButton = screen.getByRole('button', { name: 'Italic' });
    
    expect(boldButton).toHaveAttribute('aria-pressed', 'false');
    
    await userEvent.click(boldButton);
    expect(boldButton).toHaveAttribute('aria-pressed', 'true');

    // Test editor content area
    const editor = screen.getByRole('textbox', { name: 'Content editor' });
    expect(editor).toHaveAttribute('aria-multiline', 'true');
    expect(editor).toHaveAttribute('contenteditable', 'true');

    await userEvent.click(editor);
    expect(editor).toHaveFocus();

    // Test keyboard shortcuts
    await userEvent.keyboard('Hello world');
    await userEvent.keyboard('{Control>}b{/Control}');
    expect(boldButton).toHaveAttribute('aria-pressed', 'true');
  });

  it('should provide accessible media management interface', async () => {
    const MediaManager = () => {
      const [selectedFiles, setSelectedFiles] = React.useState<File[]>([]);
      const [uploadProgress, setUploadProgress] = React.useState(0);
      const [isUploading, setIsUploading] = React.useState(false);

      const handleFileSelect = (files: FileList | null) => {
        if (files) {
          setSelectedFiles(Array.from(files));
        }
      };

      const handleUpload = async () => {
        setIsUploading(true);
        setUploadProgress(0);
        
        // Simulate upload progress
        const interval = setInterval(() => {
          setUploadProgress(prev => {
            if (prev >= 100) {
              clearInterval(interval);
              setIsUploading(false);
              return 100;
            }
            return prev + 10;
          });
        }, 200);
      };

      return (
        <div role="region" aria-labelledby="media-title">
          <h2 id="media-title">Media Manager</h2>
          
          {/* File upload area */}
          <div>
            <label htmlFor="file-upload" className="upload-label">
              Choose files to upload
            </label>
            <input
              type="file"
              id="file-upload"
              multiple
              accept="image/*,video/*,.pdf"
              onChange={(e) => handleFileSelect(e.target.files)}
              aria-describedby="file-help"
            />
            <div id="file-help">
              Accepted formats: Images (JPG, PNG, GIF), Videos (MP4, MOV), PDF documents
            </div>
          </div>

          {/* Drag and drop area */}
          <div
            role="button"
            tabIndex={0}
            aria-label="Drag and drop files here, or click to select files"
            className="drop-zone"
            style={{
              border: '2px dashed #ccc',
              padding: '40px',
              textAlign: 'center',
              backgroundColor: '#f9f9f9'
            }}
            onDragOver={(e) => e.preventDefault()}
            onDrop={(e) => {
              e.preventDefault();
              handleFileSelect(e.dataTransfer.files);
            }}
            onKeyDown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                document.getElementById('file-upload')?.click();
              }
            }}
          >
            <span aria-hidden="true">📁</span>
            <p>Drag files here or click to browse</p>
          </div>

          {/* Selected files list */}
          {selectedFiles.length > 0 && (
            <div role="region" aria-labelledby="selected-files-title">
              <h3 id="selected-files-title">Selected Files ({selectedFiles.length})</h3>
              <ul role="list">
                {selectedFiles.map((file, index) => (
                  <li key={index} role="listitem">
                    <div>
                      <span>{file.name}</span>
                      <span aria-label={`File size: ${(file.size / 1024).toFixed(1)} KB`}>
                        ({(file.size / 1024).toFixed(1)} KB)
                      </span>
                      <button
                        type="button"
                        aria-label={`Remove ${file.name} from selection`}
                        onClick={() => {
                          const newFiles = [...selectedFiles];
                          newFiles.splice(index, 1);
                          setSelectedFiles(newFiles);
                        }}
                      >
                        Remove
                      </button>
                    </div>
                  </li>
                ))}
              </ul>

              {/* Upload button and progress */}
              <div>
                <button
                  type="button"
                  onClick={handleUpload}
                  disabled={isUploading}
                  aria-describedby="upload-status"
                >
                  {isUploading ? 'Uploading...' : 'Upload Files'}
                </button>

                {isUploading && (
                  <div>
                    <progress
                      value={uploadProgress}
                      max="100"
                      aria-label="Upload progress"
                    >
                      {uploadProgress}%
                    </progress>
                    <div id="upload-status" role="status" aria-live="polite">
                      Upload progress: {uploadProgress}% complete
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Media library */}
          <div role="region" aria-labelledby="library-title">
            <h3 id="library-title">Media Library</h3>
            
            <div role="grid" aria-label="Media files grid">
              <div role="row">
                <div role="columnheader" aria-sort="none">
                  <button type="button" aria-label="Sort by filename">
                    Filename
                  </button>
                </div>
                <div role="columnheader">Type</div>
                <div role="columnheader">Size</div>
                <div role="columnheader">Date</div>
                <div role="columnheader">Actions</div>
              </div>

              <div role="row">
                <div role="gridcell">
                  <img 
                    src="/sample-image.jpg" 
                    alt="Sample marketing banner" 
                    width="50" 
                    height="30"
                  />
                  <span>marketing-banner.jpg</span>
                </div>
                <div role="gridcell">Image</div>
                <div role="gridcell">245 KB</div>
                <div role="gridcell">
                  <time dateTime="2024-01-15">Jan 15, 2024</time>
                </div>
                <div role="gridcell">
                  <div role="group" aria-label="Actions for marketing-banner.jpg">
                    <button type="button" aria-label="Edit marketing-banner.jpg">
                      Edit
                    </button>
                    <button type="button" aria-label="Download marketing-banner.jpg">
                      Download
                    </button>
                    <button type="button" aria-label="Delete marketing-banner.jpg">
                      Delete
                    </button>
                  </div>
                </div>
              </div>

              <div role="row">
                <div role="gridcell">
                  <div role="img" aria-label="Video thumbnail">
                    <span aria-hidden="true">🎥</span>
                  </div>
                  <span>product-demo.mp4</span>
                </div>
                <div role="gridcell">Video</div>
                <div role="gridcell">15.2 MB</div>
                <div role="gridcell">
                  <time dateTime="2024-01-12">Jan 12, 2024</time>
                </div>
                <div role="gridcell">
                  <div role="group" aria-label="Actions for product-demo.mp4">
                    <button type="button" aria-label="Preview product-demo.mp4">
                      Preview
                    </button>
                    <button type="button" aria-label="Download product-demo.mp4">
                      Download
                    </button>
                    <button type="button" aria-label="Delete product-demo.mp4">
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      );
    };

    const { container } = render(<MediaManager />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test file input
    const fileInput = screen.getByLabelText('Choose files to upload');
    expect(fileInput).toHaveAttribute('accept', 'image/*,video/*,.pdf');
    expect(fileInput).toHaveAttribute('multiple');

    // Test drag and drop area
    const dropZone = screen.getByRole('button', { name: /drag and drop files/i });
    dropZone.focus();
    expect(dropZone).toHaveFocus();

    await userEvent.keyboard('{Enter}');
    // Should trigger file selection

    // Test media grid
    const mediaGrid = screen.getByRole('grid', { name: 'Media files grid' });
    expect(mediaGrid).toBeInTheDocument();

    const sortButton = screen.getByRole('button', { name: 'Sort by filename' });
    expect(sortButton).toBeInTheDocument();
  });

  it('should provide accessible form validation and error handling', async () => {
    const ContentForm = () => {
      const [title, setTitle] = React.useState('');
      const [content, setContent] = React.useState('');
      const [category, setCategory] = React.useState('');
      const [tags, setTags] = React.useState('');
      const [errors, setErrors] = React.useState<Record<string, string>>({});
      const [isSubmitting, setIsSubmitting] = React.useState(false);

      const validateForm = () => {
        const newErrors: Record<string, string> = {};
        
        if (!title.trim()) {
          newErrors.title = 'Title is required';
        } else if (title.length < 3) {
          newErrors.title = 'Title must be at least 3 characters long';
        }
        
        if (!content.trim()) {
          newErrors.content = 'Content is required';
        } else if (content.length < 10) {
          newErrors.content = 'Content must be at least 10 characters long';
        }
        
        if (!category) {
          newErrors.category = 'Please select a category';
        }
        
        setErrors(newErrors);
        return Object.keys(newErrors).length === 0;
      };

      const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        
        if (!validateForm()) {
          // Focus first error field
          const firstErrorField = Object.keys(errors)[0];
          if (firstErrorField) {
            document.getElementById(firstErrorField)?.focus();
          }
          return;
        }

        setIsSubmitting(true);
        
        // Simulate API call
        setTimeout(() => {
          setIsSubmitting(false);
          alert('Content saved successfully!');
        }, 2000);
      };

      return (
        <div role="region" aria-labelledby="form-title">
          <h2 id="form-title">Create Content</h2>
          
          {Object.keys(errors).length > 0 && (
            <div role="alert" aria-atomic="true" className="error-summary">
              <h3>Please correct the following errors:</h3>
              <ul>
                {Object.entries(errors).map(([field, message]) => (
                  <li key={field}>
                    <a href={`#${field}`} onClick={() => document.getElementById(field)?.focus()}>
                      {message}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          )}

          <form onSubmit={handleSubmit} noValidate>
            <div>
              <label htmlFor="title">
                Content Title <span aria-label="required">*</span>
              </label>
              <input
                type="text"
                id="title"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                onBlur={validateForm}
                aria-required="true"
                aria-invalid={errors.title ? 'true' : 'false'}
                aria-describedby={errors.title ? 'title-error' : 'title-help'}
              />
              <div id="title-help">Enter a descriptive title for your content</div>
              {errors.title && (
                <div id="title-error" role="alert" aria-live="polite">
                  {errors.title}
                </div>
              )}
            </div>

            <div>
              <label htmlFor="content">
                Content Body <span aria-label="required">*</span>
              </label>
              <textarea
                id="content"
                value={content}
                onChange={(e) => setContent(e.target.value)}
                onBlur={validateForm}
                rows={6}
                aria-required="true"
                aria-invalid={errors.content ? 'true' : 'false'}
                aria-describedby={errors.content ? 'content-error' : 'content-help'}
              />
              <div id="content-help">Enter the main content text</div>
              {errors.content && (
                <div id="content-error" role="alert" aria-live="polite">
                  {errors.content}
                </div>
              )}
            </div>

            <fieldset>
              <legend>
                Category <span aria-label="required">*</span>
              </legend>
              <div role="radiogroup" aria-required="true" aria-invalid={errors.category ? 'true' : 'false'}>
                <label>
                  <input
                    type="radio"
                    name="category"
                    value="blog"
                    checked={category === 'blog'}
                    onChange={(e) => setCategory(e.target.value)}
                  />
                  Blog Post
                </label>
                <label>
                  <input
                    type="radio"
                    name="category"
                    value="social"
                    checked={category === 'social'}
                    onChange={(e) => setCategory(e.target.value)}
                  />
                  Social Media
                </label>
                <label>
                  <input
                    type="radio"
                    name="category"
                    value="email"
                    checked={category === 'email'}
                    onChange={(e) => setCategory(e.target.value)}
                  />
                  Email Campaign
                </label>
              </div>
              {errors.category && (
                <div role="alert" aria-live="polite">
                  {errors.category}
                </div>
              )}
            </fieldset>

            <div>
              <label htmlFor="tags">Tags (optional)</label>
              <input
                type="text"
                id="tags"
                value={tags}
                onChange={(e) => setTags(e.target.value)}
                aria-describedby="tags-help"
                placeholder="Enter tags separated by commas"
              />
              <div id="tags-help">
                Add relevant tags to help categorize your content (comma-separated)
              </div>
            </div>

            <div>
              <button
                type="submit"
                disabled={isSubmitting}
                aria-describedby={isSubmitting ? 'submit-status' : undefined}
              >
                {isSubmitting ? 'Saving...' : 'Save Content'}
              </button>
              
              <button type="button">
                Save as Draft
              </button>
              
              <button type="button">
                Cancel
              </button>
            </div>

            {isSubmitting && (
              <div id="submit-status" role="status" aria-live="polite">
                <span className="sr-only">Saving content, please wait...</span>
                <div aria-hidden="true">Saving...</div>
              </div>
            )}
          </form>
        </div>
      );
    };

    const { container } = render(<ContentForm />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test form validation
    const submitButton = screen.getByRole('button', { name: /save content/i });
    const titleInput = screen.getByLabelText(/content title/i);
    
    await userEvent.click(submitButton);
    
    // Should show error summary
    const errorSummary = screen.getByRole('alert');
    expect(errorSummary).toHaveTextContent('Please correct the following errors:');
    
    // Should mark fields as invalid
    expect(titleInput).toHaveAttribute('aria-invalid', 'true');
    
    // Test error correction
    await userEvent.type(titleInput, 'My Content Title');
    await userEvent.tab(); // Trigger onBlur validation
    
    expect(titleInput).toHaveAttribute('aria-invalid', 'false');
  });

  it('should handle keyboard shortcuts and accessibility features', async () => {
    const AccessibleEditor = () => {
      const [showShortcuts, setShowShortcuts] = React.useState(false);
      
      return (
        <div role="region" aria-labelledby="accessible-editor-title">
          <h2 id="accessible-editor-title">Accessible Content Editor</h2>
          
          {/* Keyboard shortcuts help */}
          <button
            type="button"
            aria-expanded={showShortcuts}
            aria-controls="shortcuts-panel"
            onClick={() => setShowShortcuts(!showShortcuts)}
          >
            {showShortcuts ? 'Hide' : 'Show'} Keyboard Shortcuts
          </button>
          
          <div id="shortcuts-panel" hidden={!showShortcuts}>
            <h3>Available Keyboard Shortcuts</h3>
            <dl>
              <dt><kbd>Ctrl+B</kbd></dt>
              <dd>Toggle bold formatting</dd>
              
              <dt><kbd>Ctrl+I</kbd></dt>
              <dd>Toggle italic formatting</dd>
              
              <dt><kbd>Ctrl+U</kbd></dt>
              <dd>Toggle underline formatting</dd>
              
              <dt><kbd>Ctrl+K</kbd></dt>
              <dd>Insert link</dd>
              
              <dt><kbd>Ctrl+S</kbd></dt>
              <dd>Save content</dd>
              
              <dt><kbd>Ctrl+Z</kbd></dt>
              <dd>Undo last action</dd>
              
              <dt><kbd>Ctrl+Y</kbd></dt>
              <dd>Redo last action</dd>
              
              <dt><kbd>F1</kbd></dt>
              <dd>Show this help dialog</dd>
            </dl>
          </div>

          {/* Editor with accessibility features */}
          <div
            role="textbox"
            aria-multiline="true"
            aria-label="Content editor with keyboard shortcuts"
            contentEditable
            tabIndex={0}
            style={{
              minHeight: '300px',
              border: '2px solid #007bff',
              padding: '15px',
              backgroundColor: '#fff'
            }}
            onKeyDown={(e) => {
              // Handle keyboard shortcuts
              if (e.ctrlKey) {
                switch (e.key) {
                  case 's':
                    e.preventDefault();
                    alert('Content saved! (Demo)');
                    break;
                  case 'k':
                    e.preventDefault();
                    alert('Insert link dialog would open here');
                    break;
                }
              } else if (e.key === 'F1') {
                e.preventDefault();
                setShowShortcuts(true);
              }
            }}
          />

          {/* Status and word count */}
          <div role="status" aria-live="polite" aria-label="Editor statistics">
            <span>Ready to edit</span>
          </div>
        </div>
      );
    };

    const { container } = render(<AccessibleEditor />);
    
    const results = await axe(container, wcagConfig);
    expect(results).toHaveNoViolations();

    // Test shortcuts panel
    const shortcutsButton = screen.getByRole('button', { name: /show keyboard shortcuts/i });
    expect(shortcutsButton).toHaveAttribute('aria-expanded', 'false');
    
    await userEvent.click(shortcutsButton);
    expect(shortcutsButton).toHaveAttribute('aria-expanded', 'true');
    
    // Test editor focus
    const editor = screen.getByRole('textbox', { name: /content editor with keyboard shortcuts/i });
    editor.focus();
    expect(editor).toHaveFocus();
    
    // Test keyboard shortcuts
    await userEvent.keyboard('{Control>}s{/Control}');
    // Should trigger save action (mocked as alert)
  });
});