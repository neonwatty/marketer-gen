import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]
  static values = {
    activeClass: { type: String, default: "active" },
    hideOnScroll: { type: Boolean, default: false }
  }

  connect() {
    // Initialize bottom navigation
    this.initializeBottomNav()
    
    // Handle scroll behavior if enabled
    if (this.hideOnScrollValue) {
      this.initializeScrollBehavior()
    }
    
    // Handle orientation changes
    this.handleOrientationChange = this.handleOrientationChange.bind(this)
    window.addEventListener('orientationchange', this.handleOrientationChange)
    window.addEventListener('resize', this.handleOrientationChange)
  }

  disconnect() {
    window.removeEventListener('orientationchange', this.handleOrientationChange)
    window.removeEventListener('resize', this.handleOrientationChange)
    
    if (this.hideOnScrollValue) {
      window.removeEventListener('scroll', this.handleScroll)
    }
  }

  initializeBottomNav() {
    // Set up ARIA attributes
    this.element.setAttribute('role', 'navigation')
    this.element.setAttribute('aria-label', 'Bottom navigation')
    
    // Initialize touch feedback for nav items
    this.itemTargets.forEach((item, index) => {
      item.setAttribute('role', 'tab')
      item.setAttribute('tabindex', '0')
      item.dataset.index = index
      
      // Add touch feedback
      this.addTouchFeedback(item)
    })
    
    // Set initial active state
    this.updateActiveState()
  }

  addTouchFeedback(element) {
    let touchStartTime = 0
    
    element.addEventListener('touchstart', (e) => {
      touchStartTime = Date.now()
      element.style.transform = 'scale(0.95)'
      element.style.transition = 'transform 0.1s ease-out'
    }, { passive: true })
    
    element.addEventListener('touchend', (e) => {
      const touchDuration = Date.now() - touchStartTime
      
      // Reset transform
      element.style.transform = ''
      
      // If it was a quick tap, trigger the action
      if (touchDuration < 200) {
        this.selectItem(element)
      }
    }, { passive: true })
    
    element.addEventListener('touchcancel', (e) => {
      element.style.transform = ''
    }, { passive: true })
  }

  initializeScrollBehavior() {
    let lastScrollY = window.scrollY
    let isHidden = false
    
    this.handleScroll = () => {
      const currentScrollY = window.scrollY
      const scrollDifference = currentScrollY - lastScrollY
      
      // Hide on scroll down, show on scroll up
      if (scrollDifference > 10 && !isHidden) {
        this.hideBottomNav()
        isHidden = true
      } else if (scrollDifference < -10 && isHidden) {
        this.showBottomNav()
        isHidden = false
      }
      
      lastScrollY = currentScrollY
    }
    
    window.addEventListener('scroll', this.handleScroll, { passive: true })
  }

  hideBottomNav() {
    this.element.style.transform = 'translateY(100%)'
    this.element.style.transition = 'transform 0.3s cubic-bezier(0.4, 0, 0.2, 1)'
  }

  showBottomNav() {
    this.element.style.transform = 'translateY(0)'
    this.element.style.transition = 'transform 0.3s cubic-bezier(0.4, 0, 0.2, 1)'
  }

  selectItem(item) {
    // Remove active class from all items
    this.itemTargets.forEach(navItem => {
      navItem.classList.remove(this.activeClassValue)
      navItem.setAttribute('aria-selected', 'false')
    })
    
    // Add active class to selected item
    item.classList.add(this.activeClassValue)
    item.setAttribute('aria-selected', 'true')
    
    // Dispatch custom event
    this.dispatch('itemSelected', {
      detail: {
        index: parseInt(item.dataset.index),
        element: item,
        href: item.getAttribute('href')
      }
    })
    
    // Handle navigation
    const href = item.getAttribute('href')
    if (href && href !== '#') {
      // Let the browser handle the navigation naturally
      return true
    }
  }

  // Action method for clicking items
  itemClick(event) {
    event.preventDefault()
    this.selectItem(event.currentTarget)
  }

  // Keyboard navigation
  keydown(event) {
    const currentIndex = this.getCurrentActiveIndex()
    let newIndex = currentIndex
    
    switch (event.key) {
      case 'ArrowLeft':
        newIndex = Math.max(0, currentIndex - 1)
        break
      case 'ArrowRight':
        newIndex = Math.min(this.itemTargets.length - 1, currentIndex + 1)
        break
      case 'Home':
        newIndex = 0
        break
      case 'End':
        newIndex = this.itemTargets.length - 1
        break
      case 'Enter':
      case ' ':
        this.selectItem(this.itemTargets[currentIndex])
        event.preventDefault()
        return
      default:
        return
    }
    
    if (newIndex !== currentIndex) {
      this.itemTargets[newIndex].focus()
      event.preventDefault()
    }
  }

  getCurrentActiveIndex() {
    const activeItem = this.itemTargets.find(item => 
      item.classList.contains(this.activeClassValue)
    )
    return activeItem ? parseInt(activeItem.dataset.index) : 0
  }

  updateActiveState() {
    // Update active state based on current URL
    const currentPath = window.location.pathname
    let foundMatch = false
    
    this.itemTargets.forEach(item => {
      const href = item.getAttribute('href')
      const isActive = href && (
        href === currentPath || 
        (href !== '/' && currentPath.startsWith(href))
      )
      
      if (isActive && !foundMatch) {
        item.classList.add(this.activeClassValue)
        item.setAttribute('aria-selected', 'true')
        foundMatch = true
      } else {
        item.classList.remove(this.activeClassValue)
        item.setAttribute('aria-selected', 'false')
      }
    })
    
    // If no match found, activate first item
    if (!foundMatch && this.itemTargets.length > 0) {
      this.itemTargets[0].classList.add(this.activeClassValue)
      this.itemTargets[0].setAttribute('aria-selected', 'true')
    }
  }

  handleOrientationChange() {
    // Adjust bottom nav on orientation change
    setTimeout(() => {
      this.updateSafeAreaPadding()
    }, 100)
  }

  updateSafeAreaPadding() {
    // Update safe area padding for different orientations
    const safeAreaBottom = getComputedStyle(document.documentElement)
      .getPropertyValue('--safe-area-bottom') || '0px'
    
    this.element.style.paddingBottom = `calc(0.5rem + ${safeAreaBottom})`
  }

  // Method to programmatically set active item
  setActiveItem(index) {
    if (index >= 0 && index < this.itemTargets.length) {
      this.selectItem(this.itemTargets[index])
    }
  }

  // Method to add badge/notification to nav item
  addBadge(index, content = '') {
    const item = this.itemTargets[index]
    if (!item) {return}
    
    let badge = item.querySelector('.nav-badge')
    if (!badge) {
      badge = document.createElement('span')
      badge.className = 'nav-badge absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full min-w-[1rem] h-4 flex items-center justify-center'
      badge.setAttribute('aria-label', 'Notification')
      item.style.position = 'relative'
      item.appendChild(badge)
    }
    
    badge.textContent = content
    badge.style.display = content ? 'flex' : 'none'
  }

  // Method to remove badge from nav item
  removeBadge(index) {
    const item = this.itemTargets[index]
    if (!item) {return}
    
    const badge = item.querySelector('.nav-badge')
    if (badge) {
      badge.remove()
    }
  }
}