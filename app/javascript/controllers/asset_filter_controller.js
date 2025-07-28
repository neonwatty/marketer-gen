import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typeFilter", "statusFilter", "searchFilter", "assetGrid"]

  connect() {
    this.originalAssets = Array.from(this.assetGridTarget.children)
  }

  filter() {
    const typeFilter = this.typeFilterTarget.value.toLowerCase()
    const statusFilter = this.statusFilterTarget.value.toLowerCase()
    const searchFilter = this.searchFilterTarget.value.toLowerCase()

    let visibleCount = 0

    this.originalAssets.forEach(asset => {
      const assetType = asset.dataset.assetType?.toLowerCase() || ''
      const processingStatus = asset.dataset.processingStatus?.toLowerCase() || ''
      const filename = asset.dataset.filename?.toLowerCase() || ''

      const matchesType = !typeFilter || assetType === typeFilter
      const matchesStatus = !statusFilter || processingStatus === statusFilter
      const matchesSearch = !searchFilter || filename.includes(searchFilter)

      const shouldShow = matchesType && matchesStatus && matchesSearch

      if (shouldShow) {
        asset.classList.remove('hidden')
        visibleCount++
      } else {
        asset.classList.add('hidden')
      }
    })

    // Show/hide empty state
    this.toggleEmptyState(visibleCount === 0)
  }

  toggleEmptyState(show) {
    let emptyState = this.assetGridTarget.querySelector('.empty-state')
    
    if (show && !emptyState) {
      emptyState = this.createEmptyState()
      this.assetGridTarget.appendChild(emptyState)
    } else if (!show && emptyState) {
      emptyState.remove()
    }
  }

  createEmptyState() {
    const emptyState = document.createElement('div')
    emptyState.className = 'empty-state col-span-full text-center py-12'
    emptyState.innerHTML = `
      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
      </svg>
      <h3 class="mt-2 text-sm font-medium text-gray-900">No assets found</h3>
      <p class="mt-1 text-sm text-gray-500">Try adjusting your filters to see more results.</p>
    `
    return emptyState
  }

  clearFilters() {
    this.typeFilterTarget.value = ''
    this.statusFilterTarget.value = ''
    this.searchFilterTarget.value = ''
    this.filter()
  }
}