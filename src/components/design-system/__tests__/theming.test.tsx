import React from "react"
import { render, screen, fireEvent } from "@testing-library/react"
import { describe, it, expect, vi } from "vitest"

import { ThemeProvider, ThemeToggle, useTheme } from "@/components/providers/theme-provider"
import { themeTokens, createTheme } from "@/lib/theme"

// Mock utils
vi.mock("@/lib/utils", () => ({
  cn: (...classes: any[]) => classes.filter(Boolean).join(" "),
}))

// Test component that uses theme
function TestThemeConsumer() {
  const { theme, resolvedTheme, runtimeTheme } = useTheme()
  
  return (
    <div>
      <div data-testid="current-theme">{theme}</div>
      <div data-testid="resolved-theme">{resolvedTheme}</div>
      <div data-testid="runtime-theme-mode">{runtimeTheme.mode}</div>
    </div>
  )
}

describe("Theming System", () => {
  describe("Theme Configuration", () => {
    it("exports theme tokens correctly", () => {
      expect(themeTokens.colors.primary).toBe("hsl(var(--primary))")
      expect(themeTokens.colors.background).toBe("hsl(var(--background))")
      expect(themeTokens.radius.default).toBe("var(--radius)")
      expect(themeTokens.spacing.md).toBe("var(--spacing-md)")
    })

    it("creates runtime theme correctly", () => {
      const lightTheme = createTheme("light")
      const darkTheme = createTheme("dark")

      expect(lightTheme.mode).toBe("light")
      expect(darkTheme.mode).toBe("dark")
      expect(lightTheme.colors.primary).toBe("hsl(var(--primary))")
    })
  })

  describe("ThemeProvider", () => {
    it("provides default theme", () => {
      render(
        <ThemeProvider>
          <TestThemeConsumer />
        </ThemeProvider>
      )

      expect(screen.getByTestId("current-theme")).toHaveTextContent("system")
    })

    it("allows setting custom default theme", () => {
      render(
        <ThemeProvider defaultTheme="dark">
          <TestThemeConsumer />
        </ThemeProvider>
      )

      expect(screen.getByTestId("current-theme")).toHaveTextContent("dark")
    })

    it("provides runtime theme object", () => {
      render(
        <ThemeProvider defaultTheme="light">
          <TestThemeConsumer />
        </ThemeProvider>
      )

      expect(screen.getByTestId("runtime-theme-mode")).toHaveTextContent("light")
    })
  })

  describe("ThemeToggle", () => {
    it("renders theme toggle button", () => {
      render(
        <ThemeProvider>
          <ThemeToggle />
        </ThemeProvider>
      )

      const button = screen.getByRole("button")
      expect(button).toBeInTheDocument()
    })

    it("cycles through themes on click", async () => {
      render(
        <ThemeProvider defaultTheme="light">
          <div>
            <TestThemeConsumer />
            <ThemeToggle />
          </div>
        </ThemeProvider>
      )

      const button = screen.getByRole("button")
      const themeDisplay = screen.getByTestId("current-theme")

      // Initial state
      expect(themeDisplay).toHaveTextContent("light")

      // Click to dark
      fireEvent.click(button)
      expect(themeDisplay).toHaveTextContent("dark")

      // Click to system
      fireEvent.click(button)
      expect(themeDisplay).toHaveTextContent("system")

      // Click back to light
      fireEvent.click(button)
      expect(themeDisplay).toHaveTextContent("light")
    })

    it("shows correct icons and labels", () => {
      render(
        <ThemeProvider defaultTheme="light">
          <ThemeToggle />
        </ThemeProvider>
      )

      const button = screen.getByRole("button")
      expect(button).toHaveTextContent("☀️")
      expect(button).toHaveTextContent("Light")
    })
  })

  describe("CSS Variables Integration", () => {
    it("theme tokens use correct CSS variable format", () => {
      expect(themeTokens.colors.primary).toMatch(/^hsl\(var\(--[\w-]+\)\)$/)
      expect(themeTokens.radius.default).toMatch(/^var\(--[\w-]+\)$/)
      expect(themeTokens.spacing.md).toMatch(/^var\(--[\w-]+\)$/)
    })
  })

  describe("Component Variants", () => {
    it("supports button variant types", () => {
      // Test that our variant types are properly exported
      const variants: Array<import("@/lib/theme").ButtonVariant> = [
        "default",
        "destructive", 
        "outline",
        "secondary",
        "ghost",
        "link"
      ]

      expect(variants).toHaveLength(6)
      expect(variants.includes("default")).toBe(true)
      expect(variants.includes("destructive")).toBe(true)
    })

    it("supports badge variant types", () => {
      const variants: Array<import("@/lib/theme").BadgeVariant> = [
        "default",
        "secondary",
        "destructive", 
        "outline",
        "success",
        "warning",
        "info"
      ]

      expect(variants).toHaveLength(7)
      expect(variants.includes("success")).toBe(true)
      expect(variants.includes("warning")).toBe(true)
    })
  })
})