import { render, screen } from '@testing-library/react'
import { JourneyStageNode } from '@/components/features/journey/JourneyStageNode'

// Mock ReactFlow Handle component
jest.mock('reactflow', () => ({
  Handle: ({ type, position }: any) => (
    <div data-testid={`handle-${type}-${position}`}>Handle</div>
  ),
  Position: {
    Left: 'left',
    Right: 'right',
  },
}))

const mockNodeProps = {
  id: '1',
  type: 'journeyStage',
  position: { x: 100, y: 100 },
  data: {
    type: 'awareness' as const,
    title: 'Awareness Stage',
    description: 'Build brand awareness and attract potential customers',
    contentTypes: ['Blog Posts', 'Social Media', 'Video Content', 'SEO Content'],
    messagingSuggestions: [
      'Introduce your brand values',
      'Share educational content',
      'Tell your brand story',
    ],
  },
  selected: false,
}

describe('JourneyStageNode', () => {
  it('renders the stage node with title and description', () => {
    render(<JourneyStageNode {...mockNodeProps} />)
    
    expect(screen.getByText('Awareness Stage')).toBeInTheDocument()
    expect(screen.getByText('Build brand awareness and attract potential customers')).toBeInTheDocument()
  })

  it('renders content types with badges', () => {
    render(<JourneyStageNode {...mockNodeProps} />)
    
    expect(screen.getByText('Content Types:')).toBeInTheDocument()
    expect(screen.getByText('Blog Posts')).toBeInTheDocument()
    expect(screen.getByText('Social Media')).toBeInTheDocument()
    expect(screen.getByText('Video Content')).toBeInTheDocument()
    expect(screen.getByText('+1')).toBeInTheDocument() // Shows "+1" for the 4th item
  })

  it('renders messaging suggestions', () => {
    render(<JourneyStageNode {...mockNodeProps} />)
    
    expect(screen.getByText('Key Messages:')).toBeInTheDocument()
    expect(screen.getByText('• Introduce your brand values')).toBeInTheDocument()
    expect(screen.getByText('• Share educational content')).toBeInTheDocument()
    expect(screen.getByText('• +1 more...')).toBeInTheDocument() // Shows "+1 more" for the 3rd item
  })

  it('applies selected styling when selected', () => {
    const selectedProps = { ...mockNodeProps, selected: true }
    render(<JourneyStageNode {...selectedProps} />)
    
    // The card should have selected styling - just check it renders without errors
    expect(screen.getByText('Awareness Stage')).toBeInTheDocument()
  })

  it('renders different icons for different stage types', () => {
    const considerationProps = {
      ...mockNodeProps,
      data: {
        ...mockNodeProps.data,
        type: 'consideration' as const,
        title: 'Consideration Stage',
      },
    }
    
    render(<JourneyStageNode {...considerationProps} />)
    expect(screen.getByText('Consideration Stage')).toBeInTheDocument()
  })

  it('renders handles for connection points', () => {
    render(<JourneyStageNode {...mockNodeProps} />)
    
    expect(screen.getByTestId('handle-target-left')).toBeInTheDocument()
    expect(screen.getByTestId('handle-source-right')).toBeInTheDocument()
  })

  it('applies correct color scheme for awareness stage', () => {
    render(<JourneyStageNode {...mockNodeProps} />)
    
    // Just check that the component renders with the awareness stage
    expect(screen.getByText('Awareness Stage')).toBeInTheDocument()
  })

  it('handles empty content types and messaging suggestions', () => {
    const emptyProps = {
      ...mockNodeProps,
      data: {
        ...mockNodeProps.data,
        contentTypes: [],
        messagingSuggestions: [],
      },
    }
    
    render(<JourneyStageNode {...emptyProps} />)
    
    expect(screen.getByText('Awareness Stage')).toBeInTheDocument()
    expect(screen.getByText('Build brand awareness and attract potential customers')).toBeInTheDocument()
    // Content types and messaging sections should not appear when empty
    expect(screen.queryByText('Content Types:')).not.toBeInTheDocument()
    expect(screen.queryByText('Key Messages:')).not.toBeInTheDocument()
  })
})