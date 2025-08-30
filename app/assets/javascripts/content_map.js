// Content Map functionality
document.addEventListener('DOMContentLoaded', function() {
  // Add click handlers for content map toggles
  document.addEventListener('click', function(event) {
    if (event.target.closest('.content-map-toggle')) {
      toggleContentSection(event.target.closest('.content-map-toggle'));
    }
  });
});

function toggleContentSection(button) {
  const contentDetails = button.closest('.content-map-platform').querySelector('.content-details');
  const isVisible = contentDetails.style.display !== 'none';
  
  contentDetails.style.display = isVisible ? 'none' : 'block';
  
  const icon = button.querySelector('svg');
  icon.style.transform = isVisible ? 'rotate(0deg)' : 'rotate(180deg)';
}