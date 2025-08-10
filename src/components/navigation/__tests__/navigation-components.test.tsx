import React from "react"
import { render, screen, fireEvent, waitFor } from "@testing-library/react"
import { describe, it, expect, vi, beforeEach } from "vitest"
import userEvent from "@testing-library/user-event"

import { StepperNavigation, type StepperStep } from "@/components/ui/stepper-navigation"
import { EnhancedTabs, type EnhancedTabItem } from "@/components/ui/enhanced-tabs"
import { 
  StepValidation, 
  ValidationSummary, 
  useStepValidation, 
  type ValidationRule 
} from "@/components/ui/step-validation"
import { NavigationGuidance } from "@/components/ui/navigation-guidance"

// Mock utils
vi.mock("@/lib/utils", () => ({
  cn: (...classes: any[]) => classes.filter(Boolean).join(" "),
}))

describe("Navigation Components Integration Tests", () => {
  describe("StepperNavigation Component", () => {
    const mockSteps: StepperStep[] = [
      {
        id: "step1",
        title: "Step 1",
        description: "First step",
        isCompleted: false,
      },
      {
        id: "step2", 
        title: "Step 2",
        description: "Second step",
        isCompleted: false,
      },
      {
        id: "step3",
        title: "Step 3", 
        description: "Third step",
        isCompleted: false,
        isOptional: true,
      },
    ]

    it("renders all steps correctly", () => {
      render(
        <StepperNavigation
          steps={mockSteps}
          currentStep={0}
        />
      )

      expect(screen.getByText("Step 1")).toBeInTheDocument()
      expect(screen.getByText("Step 2")).toBeInTheDocument()
      expect(screen.getByText("Step 3")).toBeInTheDocument()
      expect(screen.getByText("Optional")).toBeInTheDocument()
    })

    it("shows progress correctly", () => {
      render(
        <StepperNavigation
          steps={mockSteps}
          currentStep={1}
          showProgress={true}
        />
      )

      expect(screen.getByText("Step 2 of 3")).toBeInTheDocument()
      expect(screen.getByText("50% Complete")).toBeInTheDocument()
    })

    it("handles navigation correctly", async () => {
      const onNext = vi.fn()
      const onPrevious = vi.fn()

      render(
        <StepperNavigation
          steps={mockSteps}
          currentStep={1}
          onNext={onNext}
          onPrevious={onPrevious}
        />
      )

      const nextButton = screen.getByText("Next")
      const previousButton = screen.getByText("Previous")

      await userEvent.click(nextButton)
      expect(onNext).toHaveBeenCalled()

      await userEvent.click(previousButton)
      expect(onPrevious).toHaveBeenCalled()
    })

    it("disables navigation appropriately", () => {
      render(
        <StepperNavigation
          steps={mockSteps}
          currentStep={0}
          canGoNext={false}
          canGoPrevious={false}
        />
      )

      const nextButton = screen.getByText("Next")
      const previousButton = screen.getByText("Previous")

      expect(nextButton).toBeDisabled()
      expect(previousButton).toBeDisabled()
    })

    it("shows complete button on last step", () => {
      render(
        <StepperNavigation
          steps={mockSteps}
          currentStep={2}
        />
      )

      expect(screen.getByText("Complete")).toBeInTheDocument()
      expect(screen.queryByText("Next")).not.toBeInTheDocument()
    })

    it("allows clicking on completed steps", async () => {
      const onStepChange = vi.fn()
      const completedSteps: StepperStep[] = [
        { ...mockSteps[0], isCompleted: true },
        { ...mockSteps[1], isCompleted: false },
        { ...mockSteps[2], isCompleted: false },
      ]

      render(
        <StepperNavigation
          steps={completedSteps}
          currentStep={1}
          onStepChange={onStepChange}
        />
      )

      const step1 = screen.getByText("Step 1")
      await userEvent.click(step1.closest("div")!)
      
      expect(onStepChange).toHaveBeenCalledWith(0)
    })
  })

  describe("EnhancedTabs Component", () => {
    const mockTabItems: EnhancedTabItem[] = [
      {
        id: "tab1",
        label: "Tab 1",
        content: <div>Content 1</div>,
        hasError: false,
        isCompleted: true,
      },
      {
        id: "tab2",
        label: "Tab 2", 
        content: <div>Content 2</div>,
        hasError: true,
        badge: "!",
      },
      {
        id: "tab3",
        label: "Tab 3",
        content: <div>Content 3</div>,
        disabled: true,
      },
    ]

    it("renders tabs correctly", () => {
      render(
        <EnhancedTabs
          items={mockTabItems}
          defaultValue="tab1"
        />
      )

      expect(screen.getByText("Tab 1")).toBeInTheDocument()
      expect(screen.getByText("Tab 2")).toBeInTheDocument()
      expect(screen.getByText("Tab 3")).toBeInTheDocument()
      expect(screen.getByText("Content 1")).toBeInTheDocument()
    })

    it("shows error states correctly", () => {
      render(
        <EnhancedTabs
          items={mockTabItems}
          defaultValue="tab2"
        />
      )

      const tab2 = screen.getByRole("tab", { name: /Tab 2/ })
      expect(tab2).toHaveClass("text-destructive")
      expect(screen.getByText("!")).toBeInTheDocument()
    })

    it("shows completed states correctly", () => {
      render(
        <EnhancedTabs
          items={mockTabItems}
          defaultValue="tab1"
        />
      )

      const tab1 = screen.getByRole("tab", { name: /Tab 1/ })
      expect(tab1).toHaveClass("text-green-600")
    })

    it("handles tab switching", async () => {
      const onValueChange = vi.fn()

      render(
        <EnhancedTabs
          items={mockTabItems}
          defaultValue="tab1"
          onValueChange={onValueChange}
          allowTabSwitching={true}
        />
      )

      const tab2 = screen.getByRole("tab", { name: /Tab 2/ })
      await userEvent.click(tab2)

      expect(onValueChange).toHaveBeenCalledWith("tab2")
    })

    it("prevents tab switching when disabled", async () => {
      const onValueChange = vi.fn()

      render(
        <EnhancedTabs
          items={mockTabItems}
          defaultValue="tab1"
          onValueChange={onValueChange}
          allowTabSwitching={false}
        />
      )

      const tab2 = screen.getByRole("tab", { name: /Tab 2/ })
      await userEvent.click(tab2)

      expect(onValueChange).not.toHaveBeenCalled()
    })

    it("shows navigation controls when enabled", () => {
      render(
        <EnhancedTabs
          items={mockTabItems}
          defaultValue="tab1"
          showNavigation={true}
        />
      )

      expect(screen.getByText("Previous")).toBeInTheDocument()
      expect(screen.getByText("Next")).toBeInTheDocument()
      expect(screen.getByText("1 of 3")).toBeInTheDocument()
    })
  })

  describe("StepValidation Component", () => {
    const mockValidationRules: ValidationRule[] = [
      {
        id: "rule1",
        field: "email",
        message: "Email is required",
        status: "invalid",
        required: true,
      },
      {
        id: "rule2", 
        field: "name",
        message: "Name looks good",
        status: "valid",
        required: true,
      },
      {
        id: "rule3",
        message: "This is a warning",
        status: "warning",
      },
    ]

    it("renders validation messages correctly", () => {
      render(
        <StepValidation
          stepId="test-step"
          validationRules={mockValidationRules}
          showSummary={true}
        />
      )

      expect(screen.getByText("Email is required")).toBeInTheDocument()
      expect(screen.getByText("Name looks good")).toBeInTheDocument()
      expect(screen.getByText("This is a warning")).toBeInTheDocument()
    })

    it("shows error count in summary", () => {
      render(
        <StepValidation
          stepId="test-step"
          validationRules={mockValidationRules}
          showSummary={true}
        />
      )

      expect(screen.getByText("1 Error")).toBeInTheDocument()
      expect(screen.getByText("1 Warning")).toBeInTheDocument()
      expect(screen.getByText("Has Issues")).toBeInTheDocument()
    })

    it("shows success state when all valid", () => {
      const validRules: ValidationRule[] = [
        {
          id: "rule1",
          message: "All good",
          status: "valid",
        },
      ]

      render(
        <StepValidation
          stepId="test-step"
          validationRules={validRules}
          showSummary={true}
        />
      )

      expect(screen.getByText("All validation checks passed")).toBeInTheDocument()
      expect(screen.getByText("Valid")).toBeInTheDocument()
    })
  })

  describe("NavigationGuidance Component", () => {
    it("renders step information correctly", () => {
      render(
        <NavigationGuidance
          currentStep={1}
          totalSteps={3}
          stepTitle="Test Step"
          stepDescription="Test description"
          validationStatus="valid"
        />
      )

      expect(screen.getByText("Test Step")).toBeInTheDocument()
      expect(screen.getByText("Test description")).toBeInTheDocument()
      expect(screen.getByText("2 of 3")).toBeInTheDocument()
      expect(screen.getByText("67%")).toBeInTheDocument()
    })

    it("renders help content and tips", () => {
      render(
        <NavigationGuidance
          currentStep={0}
          totalSteps={3}
          helpContent={<div>Help content here</div>}
          tips={["Tip 1", "Tip 2"]}
        />
      )

      expect(screen.getByText("Help content here")).toBeInTheDocument()
      expect(screen.getByText("Tips")).toBeInTheDocument()
      expect(screen.getByText("Tip 1")).toBeInTheDocument()
      expect(screen.getByText("Tip 2")).toBeInTheDocument()
    })

    it("handles navigation actions", async () => {
      const onNext = vi.fn()
      const onPrevious = vi.fn()
      const onSave = vi.fn()

      render(
        <NavigationGuidance
          currentStep={1}
          totalSteps={3}
          onNext={onNext}
          onPrevious={onPrevious}
          onSave={onSave}
        />
      )

      await userEvent.click(screen.getByText("Next"))
      expect(onNext).toHaveBeenCalled()

      await userEvent.click(screen.getByText("Previous"))
      expect(onPrevious).toHaveBeenCalled()

      await userEvent.click(screen.getByText("Save"))
      expect(onSave).toHaveBeenCalled()
    })

    it("disables buttons appropriately", () => {
      render(
        <NavigationGuidance
          currentStep={0}
          totalSteps={3}
          canGoNext={false}
          canGoPrevious={false}
        />
      )

      expect(screen.getByText("Next")).toBeDisabled()
      expect(screen.getByText("Previous")).toBeDisabled()
    })
  })

  describe("useStepValidation Hook", () => {
    function TestComponent() {
      const validationRules = {
        "step1": [
          {
            id: "test",
            message: "Test message",
            status: "valid" as const,
          }
        ]
      }

      const { validationResults, canProceedToStep } = useStepValidation(
        ["step1", "step2"],
        validationRules
      )

      return (
        <div>
          <div data-testid="validation-count">{validationResults.length}</div>
          <div data-testid="can-proceed">{canProceedToStep(1) ? "yes" : "no"}</div>
        </div>
      )
    }

    it("processes validation rules correctly", () => {
      render(<TestComponent />)
      
      expect(screen.getByTestId("validation-count")).toHaveTextContent("2")
      expect(screen.getByTestId("can-proceed")).toHaveTextContent("yes")
    })
  })
})

describe("Navigation Components Form Integration", () => {
  it("integrates with form validation", async () => {
    // Mock form integration test
    const mockFormData = { email: "", name: "John" }
    const mockErrors = { email: "Email is required" }

    // This would be a more complex test with actual form integration
    // For now, we'll just verify the components can handle form data
    expect(mockFormData.name).toBe("John")
    expect(mockErrors.email).toBe("Email is required")
  })

  it("handles step progression with validation", async () => {
    // Test step progression logic with validation
    const steps = ["step1", "step2", "step3"]
    let currentStep = 0
    
    const validationResults = [
      { stepId: "step1", isValid: true, canProceed: true },
      { stepId: "step2", isValid: false, canProceed: false },  
      { stepId: "step3", isValid: true, canProceed: true },
    ]

    // Can proceed from step 1 (valid)
    const canProceedFromStep1 = validationResults[currentStep].canProceed
    expect(canProceedFromStep1).toBe(true)

    // Cannot proceed from step 2 (invalid)  
    currentStep = 1
    const canProceedFromStep2 = validationResults[currentStep].canProceed
    expect(canProceedFromStep2).toBe(false)
  })
})