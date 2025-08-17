# Journey Builder User Flow

## Overview
Interactive journey visualization and editing system using React Flow with drag-and-drop functionality, custom node types, and stage configuration capabilities.

## Entry Points
- **Primary**: Through campaign creation wizard (step 2 template selection)
- **Secondary**: `/demo/journey` - Standalone demo interface
- **Future**: Campaign edit mode and journey management pages

## User Flow Steps

### 1. Journey Builder Interface Access
- **Action**: Access journey builder component
- **Expected Result**: React Flow canvas loads with initial journey template
- **Components**:
  - Interactive canvas with zoom/pan capabilities
  - Custom journey stage nodes
  - Stage configuration panel (Sheet component)
  - Toolbar with stage management controls
  - Minimap for navigation

### 2. Journey Stage Visualization
- **Default Stages**: 4 main journey stages loaded:
  - **Awareness**: Introduction and discovery
  - **Consideration**: Evaluation and comparison
  - **Conversion**: Decision and purchase
  - **Retention**: Follow-up and loyalty
- **Visual Elements**:
  - Stage-specific styling and icons
  - Connection lines between stages
  - Progress indicators
  - Stage status indicators

### 3. Drag-and-Drop Stage Management
- **Actions**:
  - Drag stages to reposition on canvas
  - Add new stages via toolbar
  - Delete stages with confirmation
  - Reorder stage sequence
- **Expected Results**:
  - Smooth drag interactions
  - Automatic connection updates
  - Real-time position saving
  - Visual feedback during drag operations

### 4. Stage Configuration
- **Actions**:
  - Click stage node to open configuration panel
  - Edit stage properties (name, description, type)
  - Configure content types for stage
  - Set stage triggers and conditions
- **Configuration Panel Fields**:
  - Stage name and description
  - Stage type selection
  - Content type assignments
  - Messaging suggestions
  - Automation triggers

### 5. Journey Flow Connections
- **Actions**:
  - Connect stages with flow lines
  - Configure conditional connections
  - Set connection labels and conditions
- **Expected Results**:
  - Visual connection lines render
  - Connection validation prevents loops
  - Label editing functionality
  - Flow direction indicators

### 6. Canvas Controls and Navigation
- **Toolbar Actions**:
  - Add stage button
  - Zoom in/out controls
  - Fit to view function
  - Canvas reset option
- **Navigation Features**:
  - Minimap for large journeys
  - Pan and zoom functionality
  - Keyboard shortcuts support
  - Full-screen mode option

## Technical Implementation
- **Framework**: React Flow library integration
- **Custom Nodes**: JourneyStageNode components
- **State Management**: Real-time journey state updates
- **UI Components**: Shadcn Sheet, Button, Input components
- **Persistence**: Journey configuration saves to database

## Test Scenarios

### Canvas Interaction Test
1. Load journey builder interface
2. Test pan and zoom functionality
3. Verify minimap navigation
4. Test canvas reset and fit-to-view
5. Verify responsive behavior

### Stage Management Test
1. Test initial stage rendering
2. Drag stages to new positions
3. Add new stages via toolbar
4. Delete stages with confirmation
5. Verify stage connection updates

### Configuration Panel Test
1. Click stage to open configuration
2. Edit stage name and description
3. Change stage type selection
4. Configure content type assignments
5. Test panel close/save functionality

### Connection Management Test
1. Create connections between stages
2. Test connection validation
3. Edit connection labels
4. Test conditional connection setup
5. Verify connection deletion

### Data Persistence Test
1. Make changes to journey structure
2. Verify auto-save functionality
3. Test journey state restoration
4. Validate database updates
5. Test undo/redo if available

### Performance Test
1. Test with large number of stages (10+)
2. Verify smooth drag performance
3. Test rendering performance
4. Validate memory usage
5. Test canvas cleanup on unmount

## Expected Behaviors
- Journey builder loads within 3 seconds
- Drag operations feel responsive (< 16ms frame time)
- Stage configuration opens within 500ms
- Auto-save triggers within 2 seconds of changes
- No memory leaks during extended use
- Smooth animations and transitions
- Proper error handling for invalid configurations

## Journey Data Structure
```typescript
interface JourneyData {
  id: string;
  name: string;
  stages: JourneyStage[];
  connections: Connection[];
  metadata: {
    version: number;
    lastModified: Date;
    author: string;
  };
}

interface JourneyStage {
  id: string;
  name: string;
  type: 'awareness' | 'consideration' | 'conversion' | 'retention';
  position: { x: number; y: number };
  content: ContentConfig[];
  triggers: TriggerConfig[];
  conditions: ConditionConfig[];
}

interface Connection {
  id: string;
  source: string;
  target: string;
  label?: string;
  conditions?: ConditionConfig[];
}
```

## Test Coverage Areas
- **Unit Tests**: Individual component functionality (13 tests currently passing)
- **Integration Tests**: React Flow integration and data flow
- **Visual Tests**: Stage rendering and styling consistency
- **Interaction Tests**: Drag-and-drop behavior validation
- **Performance Tests**: Large journey handling
- **Accessibility Tests**: Keyboard navigation and screen reader support

## Dependencies
- **Task 4.5**: Journey visualization with React Flow ✅
- React Flow library
- Shadcn UI components
- Journey data models from database schema

## Related Components
- `src/components/features/journey/journey-builder.tsx`
- `src/components/features/journey/journey-stage-node.tsx`
- `src/components/features/journey/stage-configuration-panel.tsx`
- `src/components/features/journey/journey-toolbar.tsx`
- `src/app/demo/journey/page.tsx`

## Demo Access
- **URL**: `/demo/journey`
- **Purpose**: Standalone testing and validation of journey builder functionality
- **Features**: Full journey builder with sample data and all interactive features enabled