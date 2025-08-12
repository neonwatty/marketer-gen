import type { JourneyStage, JourneyTemplate } from "./journey-builder"

// Validation error types
export interface ValidationError {
  id: string
  type: "error" | "warning" | "info"
  level: "journey" | "stage"
  stageId?: string
  title: string
  message: string
  suggestion?: string
  fixable?: boolean
}

// Journey validation result
export interface JourneyValidationResult {
  isValid: boolean
  errors: ValidationError[]
  warnings: ValidationError[]
  completeness: number // 0-100 percentage
  readiness: "draft" | "incomplete" | "ready" | "optimized"
  suggestions: ValidationError[]
}

// Stage flow validation rules
const STAGE_FLOW_RULES = {
  // Valid transitions between stage types
  validTransitions: {
    awareness: ["consideration", "conversion"], // awareness can go to consideration or direct to conversion
    consideration: ["conversion", "retention"], // consideration typically leads to conversion or retention (for existing customers)
    conversion: ["retention"], // conversion should be followed by retention
    retention: ["consideration", "conversion"], // retention can loop back to consideration for upsells
  },
  
  // Required stages for different journey categories
  requiredStages: {
    "product-launch": ["awareness", "consideration", "conversion"],
    "lead-generation": ["awareness", "consideration"],
    "re-engagement": ["awareness", "consideration", "conversion"],
    "brand-awareness": ["awareness", "consideration"],
  } as Record<string, Array<JourneyStage["type"]>>,
  
  // Optimal stage sequences for different categories
  optimalSequences: {
    "product-launch": ["awareness", "consideration", "conversion", "retention"],
    "lead-generation": ["awareness", "consideration", "conversion"],
    "re-engagement": ["awareness", "consideration", "conversion", "retention"],
    "brand-awareness": ["awareness", "consideration", "conversion"],
  } as Record<string, Array<JourneyStage["type"]>>,
}

// Validation rule functions
export class JourneyValidator {
  
  static validateJourney(
    stages: JourneyStage[], 
    category?: JourneyTemplate["category"]
  ): JourneyValidationResult {
    const errors: ValidationError[] = []
    const warnings: ValidationError[] = []
    const suggestions: ValidationError[] = []

    // Basic validations
    this.validateBasicRequirements(stages, errors)
    this.validateStageConfiguration(stages, errors, warnings)
    this.validateStageFlow(stages, errors, warnings)
    
    // Category-specific validations
    if (category) {
      this.validateCategoryRequirements(stages, category, errors, warnings, suggestions)
    }
    
    // Generate suggestions for optimization
    this.generateOptimizationSuggestions(stages, category, suggestions)
    
    // Calculate completeness and readiness
    const completeness = this.calculateCompleteness(stages)
    const readiness = this.determineReadiness(stages, errors.length, warnings.length, completeness)
    
    return {
      isValid: errors.length === 0,
      errors,
      warnings,
      completeness,
      readiness,
      suggestions,
    }
  }

  private static validateBasicRequirements(stages: JourneyStage[], errors: ValidationError[]) {
    // Must have at least one stage
    if (stages.length === 0) {
      errors.push({
        id: "no-stages",
        type: "error",
        level: "journey",
        title: "No Stages Defined",
        message: "Your journey must have at least one stage to be valid.",
        suggestion: "Add stages by clicking the 'Add Awareness', 'Add Consideration', etc. buttons above.",
        fixable: true,
      })
      return
    }

    // Check for duplicate stage names
    const stageNames = stages.map(s => s.name.toLowerCase())
    const duplicateNames = stageNames.filter((name, index) => stageNames.indexOf(name) !== index)
    
    if (duplicateNames.length > 0) {
      errors.push({
        id: "duplicate-names",
        type: "error",
        level: "journey",
        title: "Duplicate Stage Names",
        message: `Multiple stages have the same name: ${Array.from(new Set(duplicateNames)).join(", ")}`,
        suggestion: "Rename duplicate stages to have unique names for better clarity.",
        fixable: true,
      })
    }

    // Maximum reasonable stages check
    if (stages.length > 10) {
      errors.push({
        id: "too-many-stages",
        type: "warning",
        level: "journey",
        title: "Many Stages",
        message: `Your journey has ${stages.length} stages. Consider consolidating for better user experience.`,
        suggestion: "Complex journeys can be hard to manage. Consider combining similar stages or breaking into multiple journeys.",
      })
    }
  }

  private static validateStageConfiguration(
    stages: JourneyStage[], 
    errors: ValidationError[], 
    warnings: ValidationError[]
  ) {
    stages.forEach((stage) => {
      // Check if stage is configured
      if (!stage.isConfigured) {
        warnings.push({
          id: `stage-${stage.id}-unconfigured`,
          type: "warning",
          level: "stage",
          stageId: stage.id,
          title: "Stage Not Configured",
          message: `${stage.name} needs configuration to be effective.`,
          suggestion: "Click the settings icon to configure channels, content types, and messaging guidance.",
          fixable: true,
        })
      }

      // Check for empty channels
      if (stage.channels.length === 0) {
        errors.push({
          id: `stage-${stage.id}-no-channels`,
          type: "error",
          level: "stage",
          stageId: stage.id,
          title: "No Marketing Channels",
          message: `${stage.name} has no marketing channels selected.`,
          suggestion: "Add at least one marketing channel to reach your audience at this stage.",
          fixable: true,
        })
      }

      // Check for empty content types
      if (stage.contentTypes.length === 0) {
        errors.push({
          id: `stage-${stage.id}-no-content`,
          type: "error",
          level: "stage",
          stageId: stage.id,
          title: "No Content Types",
          message: `${stage.name} has no content types defined.`,
          suggestion: "Specify what type of content you'll create for this stage.",
          fixable: true,
        })
      }

      // Check for very basic stage names
      const basicNames = ["awareness stage", "consideration stage", "conversion stage", "retention stage"]
      if (basicNames.includes(stage.name.toLowerCase())) {
        warnings.push({
          id: `stage-${stage.id}-generic-name`,
          type: "warning",
          level: "stage",
          stageId: stage.id,
          title: "Generic Stage Name",
          message: `"${stage.name}" is quite generic. Consider a more specific name.`,
          suggestion: "Use descriptive names like 'Pre-Launch Awareness' or 'Email Nurture Campaign' for clarity.",
        })
      }

      // Check for empty descriptions
      if (stage.description.includes("Configure your") || stage.description.length < 20) {
        warnings.push({
          id: `stage-${stage.id}-basic-description`,
          type: "info",
          level: "stage",
          stageId: stage.id,
          title: "Basic Description",
          message: `${stage.name} could use a more detailed description.`,
          suggestion: "Add specific goals and tactics to help your team understand this stage's purpose.",
        })
      }
    })
  }

  private static validateStageFlow(
    stages: JourneyStage[], 
    errors: ValidationError[], 
    warnings: ValidationError[]
  ) {
    if (stages.length < 2) return // No flow validation needed for single stage

    // Check for logical stage progression
    for (let i = 0; i < stages.length - 1; i++) {
      const currentStage = stages[i]
      const nextStage = stages[i + 1]
      
      const validNext = STAGE_FLOW_RULES.validTransitions[currentStage.type]
      
      if (validNext && !validNext.includes(nextStage.type)) {
        warnings.push({
          id: `flow-${currentStage.id}-${nextStage.id}`,
          type: "warning",
          level: "journey",
          title: "Unusual Stage Flow",
          message: `${currentStage.type} → ${nextStage.type} is an unusual progression.`,
          suggestion: `Consider if ${currentStage.type} → ${validNext.join(" or ")} would be more effective.`,
        })
      }
    }

    // Check for common stage type patterns
    const stageTypes = stages.map(s => s.type)
    
    // Should typically start with awareness for new customer acquisition
    if (stageTypes.length > 1 && stageTypes[0] !== "awareness" && !stageTypes.includes("awareness")) {
      suggestions.push({
        id: "missing-awareness",
        type: "info",
        level: "journey",
        title: "Consider Adding Awareness",
        message: "Most effective journeys start with an awareness stage to attract new prospects.",
        suggestion: "Add an awareness stage at the beginning to expand your reach.",
      })
    }

    // Should have conversion for business impact
    if (!stageTypes.includes("conversion")) {
      warnings.push({
        id: "missing-conversion",
        type: "warning",
        level: "journey",
        title: "No Conversion Stage",
        message: "Your journey doesn't include a conversion stage.",
        suggestion: "Add a conversion stage to drive business results from your marketing efforts.",
        fixable: true,
      })
    }

    // Check for retention opportunities
    if (stageTypes.includes("conversion") && !stageTypes.includes("retention")) {
      suggestions.push({
        id: "missing-retention",
        type: "info",
        level: "journey",
        title: "Consider Adding Retention",
        message: "Adding retention after conversion can increase customer lifetime value.",
        suggestion: "Include a retention stage to nurture existing customers and drive repeat business.",
      })
    }
  }

  private static validateCategoryRequirements(
    stages: JourneyStage[],
    category: JourneyTemplate["category"],
    errors: ValidationError[],
    warnings: ValidationError[],
    suggestions: ValidationError[]
  ) {
    const requiredStages = STAGE_FLOW_RULES.requiredStages[category]
    const optimalSequence = STAGE_FLOW_RULES.optimalSequences[category]
    const currentTypes = stages.map(s => s.type)

    // Check for required stages
    if (requiredStages) {
      const missingRequired = requiredStages.filter(required => !currentTypes.includes(required))
      
      missingRequired.forEach(stageType => {
        errors.push({
          id: `missing-required-${stageType}`,
          type: "error",
          level: "journey",
          title: `Missing Required ${stageType.charAt(0).toUpperCase() + stageType.slice(1)} Stage`,
          message: `${category.replace("-", " ")} journeys typically require a ${stageType} stage.`,
          suggestion: `Add a ${stageType} stage to complete your ${category.replace("-", " ")} journey.`,
          fixable: true,
        })
      })
    }

    // Check optimal sequence
    if (optimalSequence && currentTypes.length > 1) {
      const isOptimalOrder = this.checkSequenceMatch(currentTypes, optimalSequence)
      
      if (!isOptimalOrder) {
        suggestions.push({
          id: "suboptimal-sequence",
          type: "info",
          level: "journey",
          title: "Consider Reordering Stages",
          message: `The optimal sequence for ${category.replace("-", " ")} is: ${optimalSequence.join(" → ")}`,
          suggestion: "Drag and drop stages to reorder them for better customer flow.",
        })
      }
    }
  }

  private static generateOptimizationSuggestions(
    stages: JourneyStage[],
    category: JourneyTemplate["category"] | undefined,
    suggestions: ValidationError[]
  ) {
    // Suggest parallel channels
    const allChannels = new Set(stages.flatMap(s => s.channels))
    
    if (allChannels.size < 3 && stages.length > 1) {
      suggestions.push({
        id: "diversify-channels",
        type: "info",
        level: "journey",
        title: "Consider Channel Diversity",
        message: "Your journey uses limited marketing channels.",
        suggestion: "Consider adding complementary channels like social media, email, or content marketing for better reach.",
      })
    }

    // Suggest content variety
    const allContentTypes = new Set(stages.flatMap(s => s.contentTypes))
    
    if (allContentTypes.size < 4 && stages.length > 2) {
      suggestions.push({
        id: "diversify-content",
        type: "info",
        level: "journey",
        title: "Content Type Variety",
        message: "Consider diversifying your content types for better engagement.",
        suggestion: "Mix educational content, interactive elements, testimonials, and offers across stages.",
      })
    }

    // Suggest testing opportunities
    if (stages.filter(s => s.isConfigured).length > 2) {
      suggestions.push({
        id: "ab-testing",
        type: "info",
        level: "journey",
        title: "Testing Opportunity",
        message: "Your journey is complex enough to benefit from A/B testing.",
        suggestion: "Consider testing different messaging or content types in key stages to optimize performance.",
      })
    }
  }

  private static calculateCompleteness(stages: JourneyStage[]): number {
    if (stages.length === 0) return 0
    
    let completenessScore = 0
    const maxScore = stages.length * 10 // 10 points per stage max
    
    stages.forEach(stage => {
      // Basic existence: 3 points
      completenessScore += 3
      
      // Has channels: 2 points
      if (stage.channels.length > 0) completenessScore += 2
      
      // Has content types: 2 points
      if (stage.contentTypes.length > 0) completenessScore += 2
      
      // Is configured: 2 points
      if (stage.isConfigured) completenessScore += 2
      
      // Has good name (not default): 1 point
      const defaultNames = ["awareness stage", "consideration stage", "conversion stage", "retention stage"]
      if (!defaultNames.includes(stage.name.toLowerCase())) {
        completenessScore += 1
      }
    })
    
    return Math.round((completenessScore / maxScore) * 100)
  }

  private static determineReadiness(
    stages: JourneyStage[],
    errorCount: number,
    warningCount: number,
    completeness: number
  ): JourneyValidationResult["readiness"] {
    if (stages.length === 0 || errorCount > 0) {
      return "draft"
    }
    
    if (completeness < 50 || warningCount > 3) {
      return "incomplete"
    }
    
    if (completeness < 80 || warningCount > 0) {
      return "ready"
    }
    
    return "optimized"
  }

  private static checkSequenceMatch(
    current: Array<JourneyStage["type"]>, 
    optimal: Array<JourneyStage["type"]>
  ): boolean {
    if (current.length !== optimal.length) return false
    
    // Check if the sequence matches (allowing for some flexibility)
    let matchScore = 0
    for (let i = 0; i < current.length; i++) {
      if (current[i] === optimal[i]) {
        matchScore++
      }
    }
    
    // Consider it a match if at least 70% of positions are correct
    return matchScore / current.length >= 0.7
  }

  // Utility methods for specific validations
  static validateSingleStage(stage: JourneyStage): ValidationError[] {
    const errors: ValidationError[] = []
    
    if (!stage.name.trim()) {
      errors.push({
        id: `stage-${stage.id}-no-name`,
        type: "error",
        level: "stage",
        stageId: stage.id,
        title: "Stage Name Required",
        message: "Every stage must have a name.",
        fixable: true,
      })
    }
    
    if (stage.channels.length === 0) {
      errors.push({
        id: `stage-${stage.id}-no-channels`,
        type: "error",
        level: "stage",
        stageId: stage.id,
        title: "Channels Required",
        message: "At least one marketing channel is required.",
        fixable: true,
      })
    }
    
    return errors
  }

  static canStageBeDeleted(stages: JourneyStage[], stageId: string): { canDelete: boolean; reason?: string } {
    const stage = stages.find(s => s.id === stageId)
    if (!stage) return { canDelete: true }
    
    const remainingStages = stages.filter(s => s.id !== stageId)
    const validation = this.validateJourney(remainingStages)
    
    if (validation.errors.length > 0) {
      return {
        canDelete: false,
        reason: "Removing this stage would create validation errors in your journey."
      }
    }
    
    return { canDelete: true }
  }
}