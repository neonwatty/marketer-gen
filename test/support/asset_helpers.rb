# Stub asset helpers for tests to avoid compilation issues
module AssetHelpers
  def stub_assets
    # Stub stylesheet_link_tag to return a simple string
    ApplicationController.any_instance.stub(:stylesheet_link_tag) do |*args|
      %(<link rel="stylesheet" href="/assets/test.css">)
    end
    
    # For view tests
    ActionView::Base.any_instance.stub(:stylesheet_link_tag) do |*args|
      %(<link rel="stylesheet" href="/assets/test.css">)
    end
  end
end

# Include in test classes
class ActionDispatch::IntegrationTest
  include AssetHelpers
  
  setup do
    stub_assets if respond_to?(:stub_assets)
  end
end

class ActionController::TestCase
  include AssetHelpers
  
  setup do
    stub_assets if respond_to?(:stub_assets)
  end
end