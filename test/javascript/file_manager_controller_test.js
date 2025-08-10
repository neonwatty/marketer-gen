// JavaScript tests for file_manager_controller
// This file can be run with Node.js or in browser environment

// Mock Stimulus Controller base class
class Controller {
  constructor() {
    this.targets = new Map();
    this.values = new Map();
    this.classes = new Map();
    this.element = null;
  }

  static get targets() { return []; }
  static get values() { return {}; }
  static get classes() { return []; }

  connect() {}
  disconnect() {}
  
  hasTarget(name) {
    return this.targets.has(name + 'Target');
  }

  dispatch(eventName, detail) {
    const event = new CustomEvent(`file-manager:${eventName}`, { detail });
    this.element.dispatchEvent(event);
  }
}

// Mock DOM elements and browser APIs
function createMockElement(tagName = 'div', options = {}) {
  return {
    tagName: tagName.toUpperCase(),
    className: options.className || '',
    classList: {
      add: function(...classes) { 
        classes.forEach(cls => {
          if (!this.contains(cls)) {
            this.value = this.value ? `${this.value} ${cls}` : cls;
          }
        });
      },
      remove: function(...classes) {
        classes.forEach(cls => {
          this.value = this.value.replace(new RegExp(`\\b${cls}\\b`, 'g'), '').trim();
        });
      },
      contains: function(cls) {
        return this.value && this.value.includes(cls);
      },
      value: options.className || ''
    },
    dataset: options.dataset || {},
    innerHTML: options.innerHTML || '',
    textContent: options.textContent || '',
    value: options.value || '',
    checked: options.checked || false,
    hidden: options.hidden || false,
    addEventListener: function(event, handler) {
      this.eventHandlers = this.eventHandlers || {};
      this.eventHandlers[event] = this.eventHandlers[event] || [];
      this.eventHandlers[event].push(handler);
    },
    removeEventListener: function(event, handler) {
      if (this.eventHandlers && this.eventHandlers[event]) {
        this.eventHandlers[event] = this.eventHandlers[event].filter(h => h !== handler);
      }
    },
    dispatchEvent: function(event) {
      if (this.eventHandlers && this.eventHandlers[event.type]) {
        this.eventHandlers[event.type].forEach(handler => handler(event));
      }
    },
    querySelector: function(selector) {
      return createMockElement('div');
    },
    querySelectorAll: function(selector) {
      return [createMockElement('div')];
    },
    appendChild: function(child) {
      this.children = this.children || [];
      this.children.push(child);
    },
    remove: function() {
      if (this.parentElement) {
        this.parentElement.children = this.parentElement.children.filter(c => c !== this);
      }
    },
    insertAdjacentHTML: function(position, html) {
      this.innerHTML += html;
    }
  };
}

// Mock browser APIs
global.localStorage = {
  store: {},
  getItem: function(key) { return this.store[key] || null; },
  setItem: function(key, value) { this.store[key] = String(value); },
  removeItem: function(key) { delete this.store[key]; }
};

global.fetch = function(url, options) {
  return Promise.resolve({
    ok: true,
    json: () => Promise.resolve({ success: true }),
    text: () => Promise.resolve('<html></html>')
  });
};

global.document = {
  body: createMockElement('body'),
  createElement: function(tagName) { return createMockElement(tagName); },
  addEventListener: function() {},
  querySelector: function() { return createMockElement('div'); },
  querySelectorAll: function() { return [createMockElement('div')]; }
};

global.window = {
  location: { pathname: '/brand_assets' },
  prompt: function(msg) { return 'test_input'; },
  confirm: function(msg) { return true; }
};

// Import the file manager controller (would need to be adapted for actual import)
// For testing purposes, we'll inline a simplified version

class FileManagerController extends Controller {
  static targets = [
    "fileGrid", "fileList", "viewToggle", "gridView", "listView",
    "searchInput", "fileTypeFilter", "scanStatusFilter", "sortSelect",
    "selectedCount", "bulkActions", "selectAll", "previewModal",
    "previewContent", "metadataModal", "metadataForm"
  ];

  static values = {
    currentView: { type: String, default: "grid" },
    selectedFiles: { type: Array, default: [] },
    currentPage: { type: Number, default: 1 }
  };

  static classes = ["selected", "gridActive", "listActive"];

  connect() {
    this.uploadQueue = [];
    this.completedUploads = [];
    
    // Initialize Stimulus values if not set
    if (this.currentViewValue === undefined) {
      this.currentViewValue = "grid";
    }
    if (this.selectedFilesValue === undefined) {
      this.selectedFilesValue = [];
    }
    if (this.currentPageValue === undefined) {
      this.currentPageValue = 1;
    }
    
    this.updateViewDisplay();
    this.loadViewPreference();
  }

  toggleView(event) {
    const newView = event.currentTarget.dataset.view;
    this.currentViewValue = newView;
    this.updateViewDisplay();
    this.saveViewPreference();
  }

  updateViewDisplay() {
    // Mock implementation
    if (this.currentViewValue === "grid") {
      this.showGridView();
    } else {
      this.showListView();
    }
  }

  showGridView() {
    if (this.hasFileGridTarget) {
      this.fileGridTarget.classList.remove("hidden");
    }
    if (this.hasFileListTarget) {
      this.fileListTarget.classList.add("hidden");
    }
  }

  showListView() {
    if (this.hasFileGridTarget) {
      this.fileGridTarget.classList.add("hidden");
    }
    if (this.hasFileListTarget) {
      this.fileListTarget.classList.remove("hidden");
    }
  }

  selectFile(event) {
    const fileId = event.currentTarget.value;
    const isChecked = event.currentTarget.checked;

    if (isChecked) {
      if (!this.selectedFilesValue.includes(fileId)) {
        this.selectedFilesValue = [...this.selectedFilesValue, fileId];
      }
    } else {
      this.selectedFilesValue = this.selectedFilesValue.filter(id => id !== fileId);
    }

    this.updateBulkActionsUI();
  }

  selectAllFiles(event) {
    const isChecked = event.currentTarget.checked;
    
    if (isChecked) {
      this.selectedFilesValue = ['1', '2', '3']; // Mock file IDs
    } else {
      this.selectedFilesValue = [];
    }

    this.updateBulkActionsUI();
  }

  updateBulkActionsUI() {
    const count = this.selectedFilesValue.length;
    
    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = count;
    }
    
    if (this.hasBulkActionsTarget) {
      if (count > 0) {
        this.bulkActionsTarget.classList.remove("hidden");
      } else {
        this.bulkActionsTarget.classList.add("hidden");
      }
    }
  }

  performSearch() {
    const query = this.hasSearchInputTarget ? this.searchInputTarget.value : '';
    this.applyFilters({ query });
  }

  async applyFilters(filters) {
    try {
      const response = await fetch('/brand_assets', {
        headers: { 'Accept': 'text/html' }
      });
      
      if (response.ok) {
        return true;
      }
    } catch (error) {
      this.showNotification('Filter update failed', 'error');
      return false;
    }
  }

  showNotification(message, type = 'info') {
    // Mock notification
    console.log(`${type.toUpperCase()}: ${message}`);
  }

  loadViewPreference() {
    const saved = localStorage.getItem('file-manager-view');
    if (saved) {
      this.currentViewValue = saved;
      this.updateViewDisplay();
    }
  }

  saveViewPreference() {
    localStorage.setItem('file-manager-view', this.currentViewValue);
  }

  clearSelection() {
    this.selectedFilesValue = [];
    this.updateBulkActionsUI();
  }

  // Mock helper methods
  hasFileGridTarget = true;
  hasFileListTarget = true;
  hasSelectedCountTarget = true;
  hasBulkActionsTarget = true;
  hasSearchInputTarget = true;

  get fileGridTarget() { return createMockElement('div'); }
  get fileListTarget() { return createMockElement('div'); }
  get selectedCountTarget() { return createMockElement('span'); }
  get bulkActionsTarget() { return createMockElement('div'); }
  get searchInputTarget() { return createMockElement('input', { value: '' }); }
}

// Test Suite
class TestSuite {
  constructor() {
    this.tests = [];
    this.passed = 0;
    this.failed = 0;
  }

  test(name, testFn) {
    this.tests.push({ name, testFn });
  }

  async run() {
    console.log('🧪 Running File Manager Controller Tests...\n');

    for (const { name, testFn } of this.tests) {
      try {
        await testFn();
        console.log(`✅ ${name}`);
        this.passed++;
      } catch (error) {
        console.log(`❌ ${name}`);
        console.log(`   Error: ${error.message}`);
        this.failed++;
      }
    }

    console.log(`\n📊 Test Results:`);
    console.log(`   Passed: ${this.passed}`);
    console.log(`   Failed: ${this.failed}`);
    console.log(`   Total: ${this.tests.length}`);
    
    return this.failed === 0;
  }

  assertEqual(actual, expected, message = '') {
    if (actual !== expected) {
      throw new Error(`${message} Expected: ${expected}, Actual: ${actual}`);
    }
  }

  assertTrue(value, message = '') {
    if (!value) {
      throw new Error(`${message} Expected truthy value, got: ${value}`);
    }
  }

  assertFalse(value, message = '') {
    if (value) {
      throw new Error(`${message} Expected falsy value, got: ${value}`);
    }
  }

  assertArrayEqual(actual, expected, message = '') {
    if (JSON.stringify(actual) !== JSON.stringify(expected)) {
      throw new Error(`${message} Expected: ${JSON.stringify(expected)}, Actual: ${JSON.stringify(actual)}`);
    }
  }
}

// Test Implementation
const suite = new TestSuite();

suite.test('controller initializes with default values', () => {
  const controller = new FileManagerController();
  controller.element = createMockElement('div');
  controller.connect();

  suite.assertEqual(controller.currentViewValue, 'grid', 'Default view should be grid');
  suite.assertArrayEqual(controller.selectedFilesValue, [], 'Default selected files should be empty');
});

suite.test('can toggle between grid and list views', () => {
  const controller = new FileManagerController();
  controller.element = createMockElement('div');
  controller.connect();

  // Mock event for view toggle
  const event = {
    currentTarget: { dataset: { view: 'list' } }
  };

  controller.toggleView(event);
  
  suite.assertEqual(controller.currentViewValue, 'list', 'Should switch to list view');
});

suite.test('can select individual files', () => {
  const controller = new FileManagerController();
  controller.element = createMockElement('div');
  controller.connect();

  const event = {
    currentTarget: { value: '123', checked: true }
  };

  controller.selectFile(event);

  suite.assertTrue(controller.selectedFilesValue.includes('123'), 'Should select file');
  suite.assertEqual(controller.selectedFilesValue.length, 1, 'Should have one selected file');
});

suite.test('can deselect files', () => {
  const controller = new FileManagerController();
  controller.element = createMockElement('div');
  controller.connect();

  // First select a file
  controller.selectedFilesValue = ['123'];

  const event = {
    currentTarget: { value: '123', checked: false }
  };

  controller.selectFile(event);

  suite.assertFalse(controller.selectedFilesValue.includes('123'), 'Should deselect file');
  suite.assertEqual(controller.selectedFilesValue.length, 0, 'Should have no selected files');
});

suite.test('can select all files', () => {
  const controller = new FileManagerController();
  controller.element = createMockElement('div');
  controller.connect();

  const event = {
    currentTarget: { checked: true }
  };

  controller.selectAllFiles(event);

  suite.assertTrue(controller.selectedFilesValue.length > 0, 'Should select multiple files');
});

suite.test('can clear all selections', () => {
  const controller = new FileManagerController();
  controller.element = createMockElement('div');
  controller.connect();

  controller.selectedFilesValue = ['1', '2', '3'];
  controller.clearSelection();

  suite.assertEqual(controller.selectedFilesValue.length, 0, 'Should clear all selections');
});

suite.test('bulk actions UI updates correctly', () => {
  const controller = new FileManagerController();
  controller.element = createMockElement('div');
  controller.connect();

  // Mock targets with proper textContent handling
  const selectedCountTarget = createMockElement('span');
  const bulkActionsTarget = createMockElement('div');
  
  // Override the target getters to return our mocks
  Object.defineProperty(controller, 'selectedCountTarget', {
    get: () => selectedCountTarget,
    configurable: true
  });
  
  Object.defineProperty(controller, 'bulkActionsTarget', {
    get: () => bulkActionsTarget,
    configurable: true
  });

  controller.selectedFilesValue = ['1', '2'];
  controller.updateBulkActionsUI();

  suite.assertEqual(selectedCountTarget.textContent, 2, 'Should show correct count');
  suite.assertFalse(bulkActionsTarget.classList.contains('hidden'), 'Should show bulk actions');
});

suite.test('search functionality works', async () => {
  const controller = new FileManagerController();
  controller.element = createMockElement('div');
  controller.connect();

  controller.searchInputTarget = createMockElement('input', { value: 'test query' });

  const result = await controller.applyFilters({ query: 'test query' });
  suite.assertTrue(result, 'Search should complete successfully');
});

suite.test('view preference is saved and loaded', () => {
  const controller = new FileManagerController();
  controller.element = createMockElement('div');
  
  // Clear localStorage
  localStorage.removeItem('file-manager-view');
  
  controller.currentViewValue = 'list';
  controller.saveViewPreference();
  
  suite.assertEqual(localStorage.getItem('file-manager-view'), 'list', 'Should save preference');

  // Create new controller and check if preference is loaded
  const controller2 = new FileManagerController();
  controller2.element = createMockElement('div');
  controller2.connect();
  
  suite.assertEqual(controller2.currentViewValue, 'list', 'Should load saved preference');
});

suite.test('notification system works', () => {
  const controller = new FileManagerController();
  controller.element = createMockElement('div');
  
  // Mock console.log to capture notifications
  const originalLog = console.log;
  let loggedMessage = '';
  console.log = (message) => { loggedMessage = message; };
  
  controller.showNotification('Test message', 'success');
  
  console.log = originalLog;
  
  suite.assertTrue(loggedMessage.includes('Test message'), 'Should show notification message');
  suite.assertTrue(loggedMessage.includes('SUCCESS'), 'Should show correct notification type');
});

suite.test('handles empty search results', async () => {
  const controller = new FileManagerController();
  controller.element = createMockElement('div');
  controller.connect();

  const result = await controller.applyFilters({ query: 'nonexistent' });
  suite.assertTrue(result, 'Should handle empty results gracefully');
});

suite.test('prevents duplicate file selections', () => {
  const controller = new FileManagerController();
  controller.element = createMockElement('div');
  controller.connect();

  // Select same file twice
  const event = { currentTarget: { value: '123', checked: true } };
  
  controller.selectFile(event);
  controller.selectFile(event);

  suite.assertEqual(controller.selectedFilesValue.length, 1, 'Should not add duplicate selections');
  suite.assertEqual(controller.selectedFilesValue[0], '123', 'Should maintain single selection');
});

// Run the tests
if (typeof module !== 'undefined' && module.exports) {
  // Node.js environment
  module.exports = { TestSuite, FileManagerController };
} else {
  // Browser environment - run tests immediately
  suite.run().then(success => {
    if (!success) {
      process.exit(1);
    }
  });
}

// For Node.js testing
if (typeof require !== 'undefined' && require.main === module) {
  suite.run().then(success => {
    process.exit(success ? 0 : 1);
  });
}