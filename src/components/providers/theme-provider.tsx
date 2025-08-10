"use client"

import * as React from "react"
import { createTheme, type RuntimeTheme } from "@/lib/theme"

type Theme = "dark" | "light" | "system"

type ThemeProviderProps = {
  children: React.ReactNode
  defaultTheme?: Theme
  storageKey?: string
  enableSystem?: boolean
  disableTransitionOnChange?: boolean
}

type ThemeProviderState = {
  theme: Theme
  setTheme: (theme: Theme) => void
  systemTheme?: "dark" | "light" | undefined
  resolvedTheme?: "dark" | "light" | undefined
  runtimeTheme: RuntimeTheme
}

const initialState: ThemeProviderState = {
  theme: "system",
  setTheme: () => null,
  systemTheme: undefined,
  resolvedTheme: undefined,
  runtimeTheme: createTheme("light"),
}

const ThemeProviderContext = React.createContext<ThemeProviderState>(initialState)

export function ThemeProvider({
  children,
  defaultTheme = "system",
  storageKey = "ui-theme",
  enableSystem = true,
  disableTransitionOnChange = false,
  ...props
}: ThemeProviderProps) {
  const [theme, setTheme] = React.useState<Theme>(() => {
    if (typeof window !== "undefined") {
      return (localStorage.getItem(storageKey) as Theme) || defaultTheme
    }
    return defaultTheme
  })

  const [systemTheme, setSystemTheme] = React.useState<"dark" | "light">("light")
  const [mounted, setMounted] = React.useState(false)

  const resolvedTheme = React.useMemo(() => {
    if (theme === "system") {
      return systemTheme
    }
    return theme
  }, [theme, systemTheme])

  const runtimeTheme = React.useMemo(() => {
    return createTheme(resolvedTheme)
  }, [resolvedTheme])

  React.useEffect(() => {
    const root = window.document.documentElement

    root.classList.remove("light", "dark")

    if (theme === "system" && enableSystem) {
      const systemTheme = window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
      root.classList.add(systemTheme)
      setSystemTheme(systemTheme)
      return
    }

    root.classList.add(theme)
  }, [theme, enableSystem])

  React.useEffect(() => {
    if (!enableSystem) return

    const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")

    const handleChange = () => {
      const newSystemTheme = mediaQuery.matches ? "dark" : "light"
      setSystemTheme(newSystemTheme)

      if (theme === "system") {
        const root = window.document.documentElement
        root.classList.remove("light", "dark")
        root.classList.add(newSystemTheme)
      }
    }

    mediaQuery.addEventListener("change", handleChange)
    handleChange()

    return () => mediaQuery.removeEventListener("change", handleChange)
  }, [theme, enableSystem])

  React.useEffect(() => {
    setMounted(true)
  }, [])

  const value = React.useMemo(
    () => ({
      theme,
      setTheme: (theme: Theme) => {
        localStorage.setItem(storageKey, theme)
        setTheme(theme)
      },
      systemTheme: mounted ? systemTheme : undefined,
      resolvedTheme: mounted ? resolvedTheme : undefined,
      runtimeTheme,
    }),
    [theme, storageKey, mounted, systemTheme, resolvedTheme, runtimeTheme]
  )

  return (
    <ThemeProviderContext.Provider {...props} value={value}>
      {children}
    </ThemeProviderContext.Provider>
  )
}

export const useTheme = () => {
  const context = React.useContext(ThemeProviderContext)

  if (context === undefined)
    throw new Error("useTheme must be used within a ThemeProvider")

  return context
}

// Theme toggle component
export function ThemeToggle() {
  const { theme, setTheme, resolvedTheme } = useTheme()

  const toggleTheme = () => {
    if (theme === "light") {
      setTheme("dark")
    } else if (theme === "dark") {
      setTheme("system")
    } else {
      setTheme("light")
    }
  }

  const getIcon = () => {
    if (theme === "system") {
      return resolvedTheme === "dark" ? "🌙" : "☀️"
    }
    return theme === "dark" ? "🌙" : "☀️"
  }

  const getLabel = () => {
    if (theme === "system") {
      return `System (${resolvedTheme})`
    }
    return theme === "dark" ? "Dark" : "Light"
  }

  return (
    <button
      onClick={toggleTheme}
      className="btn-ghost inline-flex items-center gap-2 px-3 py-2 text-sm font-medium"
      aria-label={`Switch to ${theme === "light" ? "dark" : theme === "dark" ? "system" : "light"} theme`}
    >
      <span className="text-lg" aria-hidden="true">
        {getIcon()}
      </span>
      <span className="hidden sm:inline">{getLabel()}</span>
    </button>
  )
}

// Advanced theme toggle with dropdown
export function ThemeSelector() {
  const { theme, setTheme, systemTheme } = useTheme()
  
  const themes = [
    { value: "light", label: "Light", icon: "☀️" },
    { value: "dark", label: "Dark", icon: "🌙" },
    { value: "system", label: `System ${systemTheme ? `(${systemTheme})` : ""}`, icon: "💻" },
  ] as const

  return (
    <div className="flex items-center gap-1 rounded-lg border border-border bg-background p-1">
      {themes.map(({ value, label, icon }) => (
        <button
          key={value}
          onClick={() => setTheme(value)}
          className={`inline-flex items-center gap-2 rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
            theme === value
              ? "bg-primary text-primary-foreground"
              : "text-muted-foreground hover:bg-muted hover:text-foreground"
          }`}
          aria-label={`Switch to ${label} theme`}
        >
          <span aria-hidden="true">{icon}</span>
          <span className="hidden sm:inline">{label}</span>
        </button>
      ))}
    </div>
  )
}