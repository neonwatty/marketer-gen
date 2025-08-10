import { render, screen, fireEvent, waitFor } from "@testing-library/react"
import { vi } from "vitest"
import { ContentCard, ProgressBar } from "../"

// Mock clipboard API
Object.defineProperty(navigator, 'clipboard', {
  value: {
    writeText: vi.fn(() => Promise.resolve()),
  },
  configurable: true,
})

describe("ContentCard", () => {
  const mockProps = {
    title: "Test Content",
    content: "This is test content for the card component.",
    description: "Test description",
  }

  it("renders content card with basic props", () => {
    render(<ContentCard {...mockProps} />)
    
    expect(screen.getByText("Test Content")).toBeInTheDocument()
    expect(screen.getByText("This is test content for the card component.")).toBeInTheDocument()
    expect(screen.getByText("Test description")).toBeInTheDocument()
  })

  it("shows loading state", () => {
    render(<ContentCard {...mockProps} isLoading={true} />)
    
    expect(screen.queryByText("Test Content")).not.toBeInTheDocument()
    expect(document.querySelector(".animate-pulse")).toBeInTheDocument()
  })

  it("shows empty state", () => {
    render(<ContentCard {...mockProps} isEmpty={true} />)
    
    expect(screen.getByText("No content available")).toBeInTheDocument()
    expect(screen.getByText("Generate some content to get started")).toBeInTheDocument()
  })

  it("renders metadata", () => {
    const metadata = {
      type: "copy",
      author: "Test Author",
      confidence: 0.95,
      tags: ["marketing", "email", "campaign"],
      createdAt: new Date("2024-01-15"),
    }

    render(<ContentCard {...mockProps} metadata={metadata} />)
    
    expect(screen.getByText("copy")).toBeInTheDocument()
    expect(screen.getByText("Test Author")).toBeInTheDocument()
    expect(screen.getByText("95%")).toBeInTheDocument()
    expect(screen.getByText("marketing")).toBeInTheDocument()
    // Date formatting can vary by environment, so just check it exists as a time element
    const timeElement = document.querySelector("time")
    expect(timeElement).toBeInTheDocument()
  })

  it("handles copy action", async () => {
    const onCopy = vi.fn()
    const actions = { onCopy }

    render(<ContentCard {...mockProps} actions={actions} />)
    
    // Find button by its screen reader text
    const copyButton = screen.getByText("Copy content")
    fireEvent.click(copyButton.closest('button')!)
    
    await waitFor(() => {
      expect(navigator.clipboard.writeText).toHaveBeenCalledWith(mockProps.content)
    })
  })

  it("handles edit and delete actions", () => {
    const onEdit = vi.fn()
    const onDelete = vi.fn()
    const actions = { onEdit, onDelete }

    render(<ContentCard {...mockProps} actions={actions} />)
    
    const editButton = screen.getByText("Edit content").closest('button')
    const deleteButton = screen.getByText("Delete content").closest('button')
    
    fireEvent.click(editButton!)
    fireEvent.click(deleteButton!)
    
    expect(onEdit).toHaveBeenCalledTimes(1)
    expect(onDelete).toHaveBeenCalledTimes(1)
  })
})

describe("ProgressBar", () => {
  it("renders basic progress bar", () => {
    render(<ProgressBar value={50} />)
    
    const progressElement = screen.getByRole("progressbar")
    expect(progressElement).toBeInTheDocument()
  })

  it("displays percentage by default", async () => {
    render(<ProgressBar value={75} label="Test Progress" animate={false} />)
    
    expect(screen.getByText("Test Progress")).toBeInTheDocument()
    expect(screen.getByText("75%")).toBeInTheDocument()
  })

  it("shows values when enabled", () => {
    render(<ProgressBar value={30} max={100} showValues={true} animate={false} />)
    
    expect(screen.getByText("30 / 100")).toBeInTheDocument()
  })

  it("renders with description", () => {
    render(<ProgressBar value={60} description="Campaign completion status" animate={false} />)
    
    expect(screen.getByText("Campaign completion status")).toBeInTheDocument()
  })

  it("handles steps correctly", () => {
    const steps = [
      { label: "Start", value: 0, completed: true },
      { label: "Middle", value: 50, completed: true },
      { label: "End", value: 100, completed: false },
    ]

    render(<ProgressBar value={50} steps={steps} animate={false} />)
    
    expect(screen.getByText("Start")).toBeInTheDocument()
    expect(screen.getByText("Middle")).toBeInTheDocument()
    expect(screen.getByText("End")).toBeInTheDocument()
  })

  it("applies correct status colors", () => {
    const { rerender } = render(<ProgressBar value={50} status="success" animate={false} />)
    
    let statusBar = document.querySelector(".bg-green-500")
    expect(statusBar).toBeInTheDocument()

    rerender(<ProgressBar value={50} status="error" animate={false} />)
    statusBar = document.querySelector(".bg-red-500")
    expect(statusBar).toBeInTheDocument()

    rerender(<ProgressBar value={50} status="warning" animate={false} />)
    statusBar = document.querySelector(".bg-yellow-500")
    expect(statusBar).toBeInTheDocument()
  })

  it("applies different sizes", () => {
    const { rerender } = render(<ProgressBar value={50} size="sm" animate={false} />)
    
    let progressElement = document.querySelector(".h-1\\.5")
    expect(progressElement).toBeInTheDocument()

    rerender(<ProgressBar value={50} size="lg" animate={false} />)
    progressElement = document.querySelector(".h-3")
    expect(progressElement).toBeInTheDocument()
  })
})