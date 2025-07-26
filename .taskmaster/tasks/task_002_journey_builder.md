# Task 2: Guided Customer Journey Builder

## Overview
**Status**: 🔄 In Progress  
**Priority**: High  
**Dependencies**: Task 1 (User Authentication & Account Management System)  

**Description**: Develop the core journey builder functionality that allows marketers to define customer journeys and automatically suggests appropriate journey steps.

**Details**: Create a system that enables marketers to identify campaign purpose and automatically suggests journey steps through stages like Awareness, Consideration, Conversion, and Retention. Include pre-built journey templates for different campaign types and support for multiple journeys per brand or persona.

## Subtasks

### 2.1 Journey Builder Data Models & Architecture
**Status**: ✅ Complete  
**Description**: Design and implement the core data models for customer journeys, journey steps, and templates  
**Details**:
- Create Rails models: Journey, JourneyStep, JourneyTemplate, StepTransition
- Design database schema to support complex journey flows with conditional branching
- Implement model validations and associations
- Support for parallel paths and stage progression

**Implementation Notes**:
- [x] Create Journey model with attributes: name, description, brand_id, status, etc.
- [x] Create JourneyStep model with stage, content_type, channel, conditions
- [x] Create JourneyTemplate model for reusable journey patterns
- [x] Create StepTransition model for flow logic between steps
- [x] Add appropriate indexes for performance
- [x] Write comprehensive model tests
- [x] Use JSON columns for flexible configuration (SQLite compatible)

### 2.2 Journey Stage System & Flow Engine
**Status**: ⏳ Pending  
**Description**: Implement journey stages and flow progression logic  
**Details**:
- Implement journey stages: Awareness, Consideration, Conversion, Retention
- Create flow engine for journey progression logic
- Build state machine for journey step transitions
- Handle conditional logic and branching rules

**Implementation Notes**:
- [ ] Define stage constants and progression rules
- [ ] Implement state machine using AASM or similar gem
- [ ] Create flow evaluation engine
- [ ] Build condition evaluator for branching logic

### 2.3 Journey Template Library & Management
**Status**: ⏳ Pending  
**Description**: Create pre-built journey templates and management system  
**Details**:
- Create pre-built journey templates for common campaigns
- Build template CRUD operations and versioning
- Implement template customization system
- Support template cloning and modification

**Implementation Notes**:
- [ ] Create seed templates for common journey types
- [ ] Build template management interface
- [ ] Implement version control for templates
- [ ] Add template marketplace/sharing functionality

### 2.4 AI-Powered Journey Step Suggestions
**Status**: ⏳ Pending  
**Description**: Integrate LLM for intelligent journey recommendations  
**Details**:
- Integrate LLM for intelligent step recommendations
- Build context-aware suggestion engine
- Implement learning from successful journeys
- Create feedback loop for improving suggestions

**Implementation Notes**:
- [ ] Design prompt templates for journey suggestions
- [ ] Integrate with LLM service (from Task 4)
- [ ] Build suggestion ranking algorithm
- [ ] Implement feedback collection system

### 2.5 Visual Journey Builder Interface
**Status**: ⏳ Pending  
**Description**: Design drag-and-drop journey builder UI  
**Details**:
- Design drag-and-drop journey builder UI
- Create visual flow editor with nodes and connections
- Implement step configuration panels
- Build preview and simulation features

**Implementation Notes**:
- [ ] Select JavaScript library for flow visualization (e.g., React Flow, Cytoscape)
- [ ] Create draggable step components
- [ ] Implement connection logic between steps
- [ ] Build real-time preview system

### 2.6 Multi-Journey & Persona Support
**Status**: ⏳ Pending  
**Description**: Enable multiple journeys per brand/campaign  
**Details**:
- Enable multiple journeys per brand/campaign
- Implement persona-based journey variations
- Create journey comparison and analytics
- Build journey version control

**Implementation Notes**:
- [ ] Add persona association to journeys
- [ ] Create journey variant system
- [ ] Build comparison interface
- [ ] Implement journey merging/splitting

### 2.7 Journey Analytics & Reporting
**Status**: ⏳ Pending  
**Description**: Track journey performance and optimization  
**Details**:
- Track journey performance metrics
- Create conversion funnel analysis
- Build journey optimization recommendations
- Implement A/B testing for journey paths

**Implementation Notes**:
- [ ] Design analytics data model
- [ ] Create metric tracking system
- [ ] Build funnel visualization
- [ ] Implement A/B test framework

### 2.8 Journey Integration & Export
**Status**: ⏳ Pending  
**Description**: Create API and export functionality  
**Details**:
- Create API endpoints for journey data
- Build export functionality for marketing platforms
- Implement journey scheduling and automation
- Support webhook notifications for journey events

**Implementation Notes**:
- [ ] Design RESTful API for journeys
- [ ] Create export adapters for major platforms
- [ ] Build scheduling system with Sidekiq
- [ ] Implement webhook notification system

## Test Strategy
- Unit tests for journey models and flow logic
- Integration tests for journey creation and progression
- UI tests for visual builder functionality
- Performance tests for complex journey evaluation
- A/B testing framework validation

## Technical Considerations
- Use PostgreSQL JSON columns for flexible journey configuration
- Implement caching for journey template suggestions
- Consider using GraphQL for complex journey data fetching
- Ensure journey builder works on mobile devices
- Plan for real-time collaboration features

## Dependencies on Other Tasks
- Task 1: User authentication for journey ownership
- Task 3: Brand identity integration for journey customization
- Task 4: LLM integration for AI suggestions
- Task 11: UI components for visual builder

## Progress Log

### 2024-01-26
- Created comprehensive subtask breakdown
- Defined technical architecture approach
- Identified key dependencies and integrations
- Completed Task 2.1: Journey Builder Data Models & Architecture
  - Created Journey model with status management, publishing, and archiving features
  - Created JourneyStep model with position management and transition support
  - Created StepTransition model for managing flow logic between steps
  - Created JourneyTemplate model for reusable journey patterns
  - All models use JSON columns for flexible configuration (SQLite compatible)
  - Added comprehensive indexes for performance
  - Wrote complete test coverage for all models (28 tests, all passing)

---

*Last Updated: 2024-01-26*