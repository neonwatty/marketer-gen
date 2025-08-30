// Campaign Plan Progress Tracker
document.addEventListener('DOMContentLoaded', function() {
  // Handle progress tracker completion events
  document.addEventListener('progress-tracker:taskCompleted', function(event) {
    const { status, data } = event.detail;
    
    if (status === 'completed') {
      // Show success notification
      setTimeout(function() {
        window.location.reload();
      }, 2000);
    } else if (status === 'failed') {
      // Show error state
      console.error('Campaign generation failed:', data);
    }
  });
});