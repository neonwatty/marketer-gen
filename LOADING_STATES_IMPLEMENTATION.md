# Loading States Implementation

This document describes the comprehensive loading states system implemented throughout the Marketer Gen Rails application.

## Overview

The loading states system provides consistent user feedback during asynchronous operations using:
- **Stimulus Controller**: `loading_controller.js` for managing loading state logic
- **Reusable Partials**: Pre-built loading components with consistent styling
- **Turbo Integration**: Automatic loading states for page transitions
- **Form Integration**: Seamless loading states for form submissions

## Components

### 1. Loading Controller (`app/javascript/controllers/loading_controller.js`)

A comprehensive Stimulus controller that handles different types of loading states:

#### Supported Types:
- `button` - Loading states for individual buttons
- `form` - Loading states for entire forms
- `content` - Loading states for content areas with skeleton screens
- `page` - Full-page loading overlays

#### Key Features:
- Configurable delays and minimum durations
- Turbo event integration
- Progress tracking for multi-step processes
- Accessibility support (ARIA attributes, screen reader announcements)
- Auto-cleanup and memory management

#### Usage:
```html
<div data-controller="loading" data-loading-type-value="form">
  <!-- Your content -->
</div>
```

### 2. Loading Partials

#### Loading Spinner (`app/views/shared/_loading_spinner.html.erb`)
Configurable spinner component with multiple sizes and colors.

```erb
<%= render "shared/loading_spinner", 
    size: "md",           # xs, sm, md, lg, xl
    color: "blue",        # blue, gray, white, green, red, yellow
    text: "Loading...",   # Custom text
    show_text: true,      # Show/hide text
    inline: false %>      # Inline vs block display
```

#### Loading Button (`app/views/shared/_loading_button.html.erb`)
Smart button component that automatically shows loading state during form submissions.

```erb
<%= render "shared/loading_button", 
    text: "Save",
    loading_text: "Saving...",
    type: "submit",       # submit, button
    variant: "primary",   # primary, secondary, success, danger, outline, ghost
    size: "md",          # xs, sm, md, lg, xl
    classes: "w-full" %>
```

#### Skeleton Card (`app/views/shared/_skeleton_card.html.erb`)
Placeholder content for loading states.

```erb
<%= render "shared/skeleton_card", 
    lines: 3,            # Number of content lines
    avatar: true,        # Show avatar placeholder
    width: "full" %>     # full, 1/2, 1/3, 2/3, etc.
```

#### Page Loader (`app/views/shared/_page_loader.html.erb`)
Full-page loading overlay with optional progress tracking.

```erb
<%= render "shared/page_loader", 
    message: "Loading...",
    progress: true,
    progress_steps: ["Step 1", "Step 2", "Step 3"] %>
```

#### Progress Indicator (`app/views/shared/_progress_indicator.html.erb`)
Multi-step progress visualization.

```erb
<%= render "shared/progress_indicator", 
    steps: ["Setup", "Configure", "Complete"],
    current: 2,
    completed: [1],
    size: "md" %>
```

## Implementation Examples

### 1. Form Loading States

```erb
<div class="relative" data-controller="loading" data-loading-type-value="form">
  <%= form_with model: @user do |form| %>
    <!-- Form fields -->
    
    <%= render "shared/loading_button", 
        text: "Create Account",
        loading_text: "Creating...",
        type: "submit" %>
  <% end %>
  
  <!-- Loading overlay -->
  <div class="absolute inset-0 bg-white bg-opacity-75 hidden"
       data-loading-target="overlay">
    <%= render "shared/loading_spinner", 
        size: "lg", 
        text: "Creating your account..." %>
  </div>
</div>
```

### 2. Content Loading with Skeleton

```erb
<div data-controller="loading" data-loading-type-value="content">
  <!-- Skeleton loading state -->
  <div class="hidden" data-loading-target="skeleton">
    <% 3.times do %>
      <%= render "shared/skeleton_card", lines: 2, avatar: true %>
    <% end %>
  </div>
  
  <!-- Actual content -->
  <div data-loading-target="content">
    <% @items.each do |item| %>
      <!-- Real content -->
    <% end %>
  </div>
</div>
```

### 3. Page-Level Loading

```erb
<!-- In application.html.erb -->
<body data-controller="loading" data-loading-type-value="page">
  <div data-loading-target="overlay">
    <%= render "shared/page_loader", hidden: true %>
  </div>
  
  <!-- Page content -->
</body>
```

### 4. Progress Tracking

```erb
<div data-controller="loading" 
     data-loading-type-value="page"
     data-loading-progress-steps-value='["Upload", "Process", "Complete"]'>
  
  <div data-loading-target="progress">
    <%= render "shared/progress_indicator", 
        steps: ["Upload", "Process", "Complete"],
        current: 1 %>
  </div>
</div>
```

## JavaScript API

### Manual Control

```javascript
// Get controller instance
const controller = application.getControllerForElementAndIdentifier(element, 'loading')

// Show/hide loading
controller.show()
controller.hide()
controller.toggle()

// Update progress (for multi-step processes)
controller.updateProgress(2, 5)  // Step 2 of 5
controller.nextStep()
controller.resetProgress()

// Check loading state
controller.isLoading()
```

### Event Handling

The controller automatically handles:
- Turbo navigation events
- Form submission events
- Custom triggers via data attributes

## Styling and Theming

### CSS Classes

Loading states use Tailwind CSS classes for styling:

```css
/* Loading animations */
.animate-spin       /* Spinner rotation */
.animate-pulse      /* Skeleton pulsing */

/* Transitions */
.transition-opacity
.duration-200
.duration-300

/* Loading overlays */
.bg-opacity-75
.backdrop-blur-sm
```

### Customization

Override default classes by passing custom `classes` parameter:

```erb
<%= render "shared/loading_spinner", 
    classes: "custom-spinner my-special-loading" %>
```

## Accessibility

### Features Included:
- ARIA live regions for screen reader announcements
- Proper role and aria-label attributes
- Keyboard navigation support
- Focus management during loading states
- Semantic HTML structure

### Screen Reader Support:
```html
<div role="status" aria-live="polite" aria-label="Loading content">
  <span class="sr-only">Loading, please wait...</span>
</div>
```

## Performance Considerations

### Optimizations:
- Configurable delays to prevent flashing on fast operations
- Minimum duration enforcement for better UX
- Automatic cleanup of event listeners
- Efficient DOM manipulation
- CSS transforms for smooth animations

### Configuration:
```html
<div data-controller="loading"
     data-loading-delay-value="200"        <!-- Delay showing loader -->
     data-loading-min-duration-value="500"> <!-- Minimum show time -->
```

## Browser Support

- **Modern browsers**: Full support with CSS transforms and animations
- **Legacy browsers**: Graceful degradation with basic loading states
- **Mobile**: Touch-optimized with appropriate sizing

## Testing

### Automated Tests
Location: `test/javascript/loading_controller_test.js`

### Manual Testing
Visit `/loading_demo` to test all loading state variations.

### System Tests
Loading states are tested as part of integration tests for:
- Form submissions
- Page navigation
- Content loading
- User workflows

## Migration Guide

### Existing Buttons
Replace existing buttons with loading buttons:

```erb
<!-- Old -->
<%= form.submit "Save", class: "btn btn-primary" %>

<!-- New -->
<%= render "shared/loading_button", 
    text: "Save",
    loading_text: "Saving...",
    variant: "primary" %>
```

### Existing Forms
Add loading controller to form containers:

```erb
<!-- Old -->
<div class="form-container">

<!-- New -->
<div class="form-container relative" 
     data-controller="loading" 
     data-loading-type-value="form">
```

## Troubleshooting

### Common Issues:

1. **Loading state not showing**
   - Check data-controller is properly set
   - Verify loading targets exist
   - Ensure CSS classes are loaded

2. **Button not restoring state**
   - Check for JavaScript errors
   - Verify Turbo events are firing
   - Check button structure matches expected format

3. **Skeleton not showing**
   - Verify skeleton target is present
   - Check CSS classes for `hidden`
   - Ensure content target exists

### Debug Mode:
Add `data-loading-debug="true"` to enable console logging.

## Future Enhancements

- [ ] Progress indicators with real-time updates
- [ ] Loading state persistence across page reloads
- [ ] Custom animation library integration
- [ ] A/B testing for loading UX variations
- [ ] Performance monitoring and analytics

## Files Created/Modified

### New Files:
- `app/javascript/controllers/loading_controller.js`
- `app/views/shared/_loading_spinner.html.erb`
- `app/views/shared/_skeleton_card.html.erb`
- `app/views/shared/_page_loader.html.erb`
- `app/views/shared/_progress_indicator.html.erb`
- `app/views/shared/_loading_button.html.erb`
- `app/views/shared/_loading_demo.html.erb`

### Modified Files:
- `app/views/sessions/new.html.erb` - Added form loading states
- `app/views/registrations/new.html.erb` - Added form loading states
- `app/views/layouts/application.html.erb` - Added page loading
- `app/views/activities/index.html.erb` - Added content loading states
- `app/views/journeys/builder.html.erb` - Added button loading states

This comprehensive loading states system provides a consistent, accessible, and performant user experience throughout the Marketer Gen application.