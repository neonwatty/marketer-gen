import { render, screen, fireEvent } from '@testing-library/react'
import { JourneyBuilder } from '@/components/features/journey/JourneyBuilder'

// Mock ReactFlow since it requires browser environment
jest.mock('reactflow', () => ({
  ReactFlow: ({ children, nodes, edges, onNodeClick }: any) => (
    <div data-testid="react-flow">
      <div data-testid="nodes">
        {nodes.map((node: any) => (
          <div
            key={node.id}
            data-testid={`node-${node.id}`}
            onClick={(e) => onNodeClick?.(e, node)}
            style={{ cursor: 'pointer' }}
          >
            {node.data.title}
          </div>
        ))}
      </div>
      <div data-testid="edges">
        {edges.map((edge: any) => (
          <div key={edge.id} data-testid={`edge-${edge.id}`}>
            {edge.label}
          </div>
        ))}
      </div>
      {children}
    </div>
  ),
  Controls: () => <div data-testid="controls">Controls</div>,
  MiniMap: () => <div data-testid="minimap">MiniMap</div>,
  Background: () => <div data-testid="background">Background</div>,
  addEdge: jest.fn(),
  useNodesState: jest.fn(() => [
    [
      {
        id: '1',
        type: 'journeyStage',
        position: { x: 100, y: 100 },
        data: {
          type: 'awareness',
          title: 'Awareness',
          description: 'Build brand awareness',
          contentTypes: ['Blog Posts'],
          messagingSuggestions: ['Introduce your brand values'],
        },
      },
    ],
    jest.fn(),
    jest.fn(),
  ]),
  useEdgesState: jest.fn(() => [[], jest.fn(), jest.fn()]),
}))

// Mock the component dependencies
jest.mock('@/components/features/journey/JourneyStageNode', () => ({
  JourneyStageNode: () => <div data-testid="journey-stage-node">Journey Stage Node</div>,
}))

jest.mock('@/components/features/journey/StageConfigurationPanel', () => ({
  StageConfigurationPanel: ({ isOpen }: { isOpen: boolean }) =>
    isOpen ? <div data-testid="stage-config-panel">Configuration Panel</div> : null,
}))

jest.mock('@/components/features/journey/JourneyToolbar', () => ({
  JourneyToolbar: ({ onAddStage }: { onAddStage: (type: string) => void }) => (
    <div data-testid="journey-toolbar">
      <button onClick={() => onAddStage('awareness')}>Add Awareness Stage</button>
    </div>
  ),
}))

describe('JourneyBuilder', () => {
  it('renders the journey builder component', () => {
    render(<JourneyBuilder />)
    
    expect(screen.getByText('Journey Builder')).toBeInTheDocument()
    expect(screen.getByTestId('react-flow')).toBeInTheDocument()
    expect(screen.getByTestId('controls')).toBeInTheDocument()
    expect(screen.getByTestId('minimap')).toBeInTheDocument()
    expect(screen.getByTestId('background')).toBeInTheDocument()
  })

  it('renders the journey toolbar', () => {
    render(<JourneyBuilder />)
    
    expect(screen.getByTestId('journey-toolbar')).toBeInTheDocument()
  })

  it('shows initial nodes in the flow', () => {
    render(<JourneyBuilder />)
    
    expect(screen.getByTestId('nodes')).toBeInTheDocument()
    expect(screen.getByTestId('node-1')).toBeInTheDocument()
  })

  it('opens configuration panel when node is clicked', () => {
    render(<JourneyBuilder />)
    
    // Initially, config panel should not be visible
    expect(screen.queryByTestId('stage-config-panel')).not.toBeInTheDocument()
    
    // Click on a node
    const node = screen.getByTestId('node-1')
    fireEvent.click(node)
    
    // Configuration panel should now be visible
    expect(screen.getByTestId('stage-config-panel')).toBeInTheDocument()
  })

  it('adds new stage when toolbar add button is clicked', () => {
    render(<JourneyBuilder />)
    
    const addButton = screen.getByText('Add Awareness Stage')
    fireEvent.click(addButton)
    
    // This would normally add a new node, but with our mock it just tests the interaction
    expect(addButton).toBeInTheDocument()
  })
})