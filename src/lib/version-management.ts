import { ContentVersion } from "@/components/forms/VersionHistory"
import * as Diff from "diff"

export interface VersionDiff {
  added: number
  removed: number
  modified: boolean
  changes: Array<{
    type: 'add' | 'remove' | 'modify'
    content: string
    position: number
  }>
}

export class VersionManager {
  private versions: Map<string, ContentVersion> = new Map()

  constructor(initialVersions: ContentVersion[] = []) {
    initialVersions.forEach(version => {
      this.versions.set(version.id, version)
    })
  }

  // Add a new version
  addVersion(version: Omit<ContentVersion, 'version' | 'id' | 'createdAt'>): ContentVersion {
    const existingVersions = Array.from(this.versions.values())
    const maxVersion = existingVersions.length > 0 
      ? Math.max(...existingVersions.map(v => v.version))
      : 0
    
    const newVersion: ContentVersion = {
      ...version,
      id: `version-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      version: maxVersion + 1,
      createdAt: new Date(),
    }

    this.versions.set(newVersion.id, newVersion)
    return newVersion
  }

  // Get version by ID
  getVersion(id: string): ContentVersion | undefined {
    return this.versions.get(id)
  }

  // Get all versions sorted by creation date (newest first)
  getAllVersions(): ContentVersion[] {
    return Array.from(this.versions.values())
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
  }

  // Get latest version
  getLatestVersion(): ContentVersion | undefined {
    const versions = this.getAllVersions()
    return versions.length > 0 ? versions[0] : undefined
  }

  // Compare two versions and return diff information
  compareVersions(version1Id: string, version2Id: string): VersionDiff | null {
    const v1 = this.getVersion(version1Id)
    const v2 = this.getVersion(version2Id)

    if (!v1 || !v2) return null

    const changes = Diff.diffWords(v1.content, v2.content)
    let added = 0
    let removed = 0
    const diffChanges: VersionDiff['changes'] = []

    changes.forEach((change, index) => {
      if (change.added) {
        added += change.value.length
        diffChanges.push({
          type: 'add',
          content: change.value,
          position: index
        })
      } else if (change.removed) {
        removed += change.value.length
        diffChanges.push({
          type: 'remove',
          content: change.value,
          position: index
        })
      }
    })

    return {
      added,
      removed,
      modified: added > 0 || removed > 0,
      changes: diffChanges
    }
  }

  // Generate change summary between versions
  generateChangeSummary(currentVersion: ContentVersion, previousVersion?: ContentVersion): string {
    if (!previousVersion) return "Initial version"

    const changes: string[] = []
    
    if (currentVersion.title !== previousVersion.title) {
      changes.push("title")
    }
    
    if (currentVersion.content !== previousVersion.content) {
      const diff = this.compareVersions(previousVersion.id, currentVersion.id)
      if (diff) {
        const wordsAdded = Math.ceil(diff.added / 5) // Rough word estimate
        const wordsRemoved = Math.ceil(diff.removed / 5)
        
        if (wordsAdded > 0 && wordsRemoved > 0) {
          changes.push(`content (+${wordsAdded}/-${wordsRemoved} words)`)
        } else if (wordsAdded > 0) {
          changes.push(`content (+${wordsAdded} words)`)
        } else if (wordsRemoved > 0) {
          changes.push(`content (-${wordsRemoved} words)`)
        } else {
          changes.push("content")
        }
      } else {
        changes.push("content")
      }
    }
    
    if (currentVersion.status !== previousVersion.status) {
      changes.push(`status (${previousVersion.status} → ${currentVersion.status})`)
    }

    return changes.length > 0 
      ? `Modified: ${changes.join(", ")}`
      : "No significant changes"
  }

  // Create a restore point (duplicate current version)
  createRestorePoint(sourceVersionId: string, author: string): ContentVersion | null {
    const sourceVersion = this.getVersion(sourceVersionId)
    if (!sourceVersion) return null

    return this.addVersion({
      title: sourceVersion.title,
      content: sourceVersion.content,
      status: 'draft', // Restored versions always start as draft
      author,
      changeDescription: `Restored from version ${sourceVersion.version}`,
      wordCount: sourceVersion.wordCount,
      characterCount: sourceVersion.characterCount,
    })
  }

  // Get version history with change summaries
  getVersionHistoryWithChanges(): Array<ContentVersion & { changeSummary: string }> {
    const versions = this.getAllVersions()
    
    return versions.map((version, index) => {
      const previousVersion = versions[index + 1] // Next item is older
      return {
        ...version,
        changeSummary: this.generateChangeSummary(version, previousVersion)
      }
    })
  }

  // Clean old versions (keep only latest N versions)
  cleanOldVersions(keepCount: number = 10): ContentVersion[] {
    const versions = this.getAllVersions()
    const toDelete = versions.slice(keepCount)
    
    toDelete.forEach(version => {
      this.versions.delete(version.id)
    })
    
    return toDelete
  }

  // Export versions to JSON
  exportVersions(): string {
    return JSON.stringify({
      versions: Array.from(this.versions.values()),
      exportedAt: new Date().toISOString(),
      totalVersions: this.versions.size
    }, null, 2)
  }

  // Import versions from JSON
  importVersions(jsonData: string): boolean {
    try {
      const data = JSON.parse(jsonData)
      if (data.versions && Array.isArray(data.versions)) {
        data.versions.forEach((version: ContentVersion) => {
          // Convert date strings back to Date objects
          version.createdAt = new Date(version.createdAt)
          this.versions.set(version.id, version)
        })
        return true
      }
      return false
    } catch (error) {
      console.error('Failed to import versions:', error)
      return false
    }
  }

  // Get statistics about versions
  getVersionStats() {
    const versions = this.getAllVersions()
    const statusCounts = versions.reduce((acc, version) => {
      acc[version.status] = (acc[version.status] || 0) + 1
      return acc
    }, {} as Record<string, number>)

    const authors = [...new Set(versions.map(v => v.author))]
    
    return {
      totalVersions: versions.length,
      statusCounts,
      authors,
      latestVersion: versions[0],
      oldestVersion: versions[versions.length - 1],
    }
  }
}

// Utility functions for version management
export const createMockVersions = (count: number = 5): ContentVersion[] => {
  const mockVersions: ContentVersion[] = []
  const authors = ['John Doe', 'Jane Smith', 'Mike Johnson', 'Sarah Wilson']
  const statuses: ContentVersion['status'][] = ['draft', 'review', 'approved', 'published']
  
  for (let i = count; i >= 1; i--) {
    const createdAt = new Date()
    createdAt.setDate(createdAt.getDate() - (count - i) * 2) // Space versions 2 days apart
    
    mockVersions.push({
      id: `mock-version-${i}`,
      version: i,
      title: `Marketing Campaign v${i}`,
      content: `<h2>Marketing Campaign Version ${i}</h2><p>This is the content for version ${i} of our marketing campaign. ${i > 1 ? `Updated from version ${i-1} with improvements and new features.` : 'Initial version with basic content.'}</p><p>Key features include: compelling copy, target audience focus, and clear call-to-action.</p>`,
      status: statuses[(i - 1) % statuses.length],
      author: authors[(i - 1) % authors.length],
      createdAt,
      changeDescription: i === 1 ? 'Initial version' : `Updated content and improved messaging`,
      wordCount: 45 + i * 5,
      characterCount: 280 + i * 30,
    })
  }
  
  return mockVersions.reverse() // Return in chronological order
}