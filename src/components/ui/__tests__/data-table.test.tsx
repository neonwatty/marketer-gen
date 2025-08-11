import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { userEvent } from '@testing-library/user-event'
import { DataTable } from '../data-table'
import { ColumnDef } from '@tanstack/react-table'

// Mock data for testing
interface TestData {
  id: string
  name: string
  status: string
  count: number
}

const mockData: TestData[] = [
  { id: '1', name: 'Item One', status: 'active', count: 10 },
  { id: '2', name: 'Item Two', status: 'inactive', count: 5 },
  { id: '3', name: 'Item Three', status: 'active', count: 15 },
  { id: '4', name: 'Item Four', status: 'pending', count: 8 },
]

const mockColumns: ColumnDef<TestData>[] = [
  {
    accessorKey: 'name',
    header: 'Name',
  },
  {
    accessorKey: 'status',
    header: 'Status',
  },
  {
    accessorKey: 'count',
    header: 'Count',
  },
]

const filterable = [
  {
    key: 'status',
    title: 'Status',
    options: [
      { label: 'Active', value: 'active' },
      { label: 'Inactive', value: 'inactive' },
      { label: 'Pending', value: 'pending' },
    ],
  },
]

describe('DataTable Component', () => {
  const user = userEvent.setup()

  describe('Basic Rendering', () => {
    it('renders table with data', () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
        />
      )

      // Check if table headers are rendered
      expect(screen.getByText('Name')).toBeInTheDocument()
      expect(screen.getByText('Status')).toBeInTheDocument()
      expect(screen.getByText('Count')).toBeInTheDocument()

      // Check if data rows are rendered
      expect(screen.getByText('Item One')).toBeInTheDocument()
      expect(screen.getByText('Item Two')).toBeInTheDocument()
      expect(screen.getByText('active')).toBeInTheDocument()
      expect(screen.getByText('inactive')).toBeInTheDocument()
    })

    it('renders search input when showSearch is true', () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          showSearch={true}
          searchPlaceholder="Search items..."
        />
      )

      expect(screen.getByPlaceholderText('Search items...')).toBeInTheDocument()
    })

    it('hides search input when showSearch is false', () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          showSearch={false}
        />
      )

      expect(screen.queryByPlaceholderText('Search...')).not.toBeInTheDocument()
    })

    it('renders column toggle when showColumnToggle is true', () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          showColumnToggle={true}
        />
      )

      expect(screen.getByText('Columns')).toBeInTheDocument()
    })

    it('renders export button when onExport is provided', () => {
      const mockOnExport = vi.fn()
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          onExport={mockOnExport}
        />
      )

      expect(screen.getByText('Export')).toBeInTheDocument()
    })
  })

  describe('Search Functionality', () => {
    it('filters data based on search input', async () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          showSearch={true}
        />
      )

      const searchInput = screen.getByRole('textbox')
      await user.type(searchInput, 'Item One')

      // Should show only matching row
      expect(screen.getByText('Item One')).toBeInTheDocument()
      expect(screen.queryByText('Item Two')).not.toBeInTheDocument()
    })

    it('shows clear button when search has value', async () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          showSearch={true}
        />
      )

      const searchInput = screen.getByRole('textbox')
      await user.type(searchInput, 'test')

      // Clear button should appear
      const clearButton = screen.getByRole('button', { name: /clear/i })
      expect(clearButton).toBeInTheDocument()
    })

    it('clears search when clear button is clicked', async () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          showSearch={true}
        />
      )

      const searchInput = screen.getByRole('textbox')
      await user.type(searchInput, 'Item One')
      
      // Click clear button
      const clearButton = screen.getByRole('button', { name: /clear/i })
      await user.click(clearButton)

      // Search should be cleared and all items visible
      expect(searchInput).toHaveValue('')
      expect(screen.getByText('Item One')).toBeInTheDocument()
      expect(screen.getByText('Item Two')).toBeInTheDocument()
    })
  })

  describe('Column Filtering', () => {
    it('renders filter dropdowns for filterable columns', () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          filterable={filterable}
          showFilters={true}
        />
      )

      // Should render status filter dropdown
      expect(screen.getByText('Status')).toBeInTheDocument()
    })

    it('filters data when filter is applied', async () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          filterable={filterable}
          showFilters={true}
        />
      )

      // Open filter dropdown and select "active"
      const filterTrigger = screen.getByText('Status')
      await user.click(filterTrigger)
      
      await waitFor(() => {
        const activeOption = screen.getByText('Active')
        expect(activeOption).toBeInTheDocument()
      })
    })
  })

  describe('Sorting', () => {
    it('sorts data when column header is clicked', async () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
        />
      )

      const nameHeader = screen.getByText('Name')
      await user.click(nameHeader)

      // After clicking, should show sort indicator
      const sortButton = nameHeader.closest('div')
      expect(sortButton).toHaveAttribute('class', expect.stringContaining('cursor-pointer'))
    })

    it('shows sort icons on sortable columns', () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
        />
      )

      // Sort icons should be present (they might be visually hidden initially)
      const headers = screen.getAllByRole('columnheader')
      expect(headers.length).toBeGreaterThan(0)
    })
  })

  describe('Pagination', () => {
    it('shows pagination controls when showPagination is true', () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          showPagination={true}
        />
      )

      expect(screen.getByText('Rows per page')).toBeInTheDocument()
      expect(screen.getByText(/Page \d+ of \d+/)).toBeInTheDocument()
    })

    it('hides pagination when showPagination is false', () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          showPagination={false}
        />
      )

      expect(screen.queryByText('Rows per page')).not.toBeInTheDocument()
    })
  })

  describe('Row Interactions', () => {
    it('calls onRowClick when row is clicked', async () => {
      const mockOnRowClick = vi.fn()
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          onRowClick={mockOnRowClick}
        />
      )

      const firstRow = screen.getByText('Item One').closest('tr')
      await user.click(firstRow!)

      expect(mockOnRowClick).toHaveBeenCalledWith(mockData[0])
    })

    it('adds cursor-pointer class when onRowClick is provided', () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          onRowClick={() => {}}
        />
      )

      const firstRow = screen.getByText('Item One').closest('tr')
      expect(firstRow).toHaveClass('cursor-pointer')
    })
  })

  describe('Export Functionality', () => {
    it('calls onExport when export button is clicked', async () => {
      const mockOnExport = vi.fn()
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          onExport={mockOnExport}
        />
      )

      const exportButton = screen.getByText('Export')
      await user.click(exportButton)

      expect(mockOnExport).toHaveBeenCalled()
    })
  })

  describe('Empty State', () => {
    it('shows "No results found" when data is empty', () => {
      render(
        <DataTable
          columns={mockColumns}
          data={[]}
        />
      )

      expect(screen.getByText('No results found.')).toBeInTheDocument()
    })

    it('shows "No results found" when filtered data is empty', async () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          showSearch={true}
        />
      )

      const searchInput = screen.getByRole('textbox')
      await user.type(searchInput, 'nonexistent')

      expect(screen.getByText('No results found.')).toBeInTheDocument()
    })
  })

  describe('Filter Badges', () => {
    it('shows filter badges when filters are active', async () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          showSearch={true}
        />
      )

      const searchInput = screen.getByRole('textbox')
      await user.type(searchInput, 'test')

      // Search badge should appear
      expect(screen.getByText(/Search: test/)).toBeInTheDocument()
    })

    it('shows clear filters button when filters are active', async () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          showSearch={true}
        />
      )

      const searchInput = screen.getByRole('textbox')
      await user.type(searchInput, 'test')

      // Clear button should appear
      expect(screen.getByText('Clear')).toBeInTheDocument()
    })

    it('clears all filters when clear all is clicked', async () => {
      render(
        <DataTable
          columns={mockColumns}
          data={mockData}
          showSearch={true}
        />
      )

      const searchInput = screen.getByRole('textbox')
      await user.type(searchInput, 'test')

      const clearAllButton = screen.getByText('Clear')
      await user.click(clearAllButton)

      expect(searchInput).toHaveValue('')
      expect(screen.queryByText(/Search: test/)).not.toBeInTheDocument()
    })
  })
})