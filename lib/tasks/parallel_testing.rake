# Custom Rake tasks for selective parallel testing
# Models run in parallel, other test types run sequentially

namespace :test do
  desc "Run model tests in parallel for better performance"
  task :models_parallel => :environment do
    puts "Running model tests in parallel..."
    
    model_files = FileList["test/models/**/*_test.rb"]
    
    if model_files.any?
      # Temporarily modify the model test files to use parallel_test_helper
      original_requires = {}
      
      begin
        # Replace require 'test_helper' with require 'parallel_test_helper' in each model test
        model_files.each do |file|
          content = File.read(file)
          original_requires[file] = content
          
          if content.include?('require "test_helper"') || content.include?("require 'test_helper'")
            new_content = content.gsub(/require ['"]test_helper['"]/, 'require "parallel_test_helper"')
            File.write(file, new_content) if new_content != content
          end
        end
        
        # Run model tests with Rails' built-in test runner
        success = system("rails test #{model_files.join(' ')}")
        exit(1) unless success
        
      ensure
        # Restore original file contents
        original_requires.each do |file, content|
          File.write(file, content)
        end
      end
    else
      puts "No model tests found"
    end
  end
  
  desc "Run controller tests sequentially"
  task :controllers do
    puts "Running controller tests sequentially..."
    
    controller_files = FileList["test/controllers/**/*_test.rb"]
    
    if controller_files.any?
      # Use regular test_helper.rb which disables parallel execution
      system("rails test #{controller_files.join(' ')}") || exit(1)
    else
      puts "No controller tests found"
    end
  end
  
  desc "Run integration tests sequentially"
  task :integration do
    puts "Running integration tests sequentially..."
    
    integration_files = FileList["test/integration/**/*_test.rb"]
    
    if integration_files.any?
      # Use regular test_helper.rb which disables parallel execution
      system("rails test #{integration_files.join(' ')}") || exit(1)
    else
      puts "No integration tests found"
    end
  end
  
  desc "Run system tests sequentially"
  task :system do
    puts "Running system tests sequentially..."
    
    system_files = FileList["test/system/**/*_test.rb"]
    
    if system_files.any?
      # Use regular test_helper.rb which disables parallel execution
      system("rails test:system #{system_files.join(' ')}") || exit(1)
    else
      puts "No system tests found"
    end
  end
  
  desc "Run service tests sequentially"
  task :services do
    puts "Running service tests sequentially..."
    
    service_files = FileList["test/services/**/*_test.rb"]
    
    if service_files.any?
      # Use regular test_helper.rb which disables parallel execution
      system("rails test #{service_files.join(' ')}") || exit(1)
    else
      puts "No service tests found"
    end
  end
  
  desc "Run job tests sequentially"
  task :jobs do
    puts "Running job tests sequentially..."
    
    job_files = FileList["test/jobs/**/*_test.rb"]
    
    if job_files.any?
      # Use regular test_helper.rb which disables parallel execution
      system("rails test #{job_files.join(' ')}") || exit(1)
    else
      puts "No job tests found"
    end
  end
  
  desc "Run mailer tests sequentially"
  task :mailers do
    puts "Running mailer tests sequentially..."
    
    mailer_files = FileList["test/mailers/**/*_test.rb"]
    
    if mailer_files.any?
      # Use regular test_helper.rb which disables parallel execution
      system("rails test #{mailer_files.join(' ')}") || exit(1)
    else
      puts "No mailer tests found"
    end
  end
  
  desc "Run helper tests sequentially"
  task :helpers do
    puts "Running helper tests sequentially..."
    
    helper_files = FileList["test/helpers/**/*_test.rb"]
    
    if helper_files.any?
      # Use regular test_helper.rb which disables parallel execution
      system("rails test #{helper_files.join(' ')}") || exit(1)
    else
      puts "No helper tests found"
    end
  end
  
  desc "Run policy tests sequentially"
  task :policies do
    puts "Running policy tests sequentially..."
    
    policy_files = FileList["test/policies/**/*_test.rb"]
    
    if policy_files.any?
      # Use regular test_helper.rb which disables parallel execution
      system("rails test #{policy_files.join(' ')}") || exit(1)
    else
      puts "No policy tests found"
    end
  end
  
  desc "Run all tests with appropriate execution method (models in parallel, others sequential)"
  task :selective => :environment do
    puts "Running all tests with selective parallel execution..."
    puts "Models will run in parallel, other test types will run sequentially"
    puts ""
    
    # Track overall success
    success = true
    
    # Run model tests in parallel first (they're usually fastest and most isolated)
    success = success && Rake::Task["test:models_parallel"].execute
    
    # Run other test types sequentially
    %w[controllers integration system services jobs mailers helpers policies].each do |test_type|
      task_name = "test:#{test_type}"
      if Rake::Task.task_defined?(task_name)
        puts ""
        success = success && Rake::Task[task_name].execute
      end
    end
    
    puts ""
    if success
      puts "All tests passed! ✅"
    else
      puts "Some tests failed! ❌"
      exit(1)
    end
  end
end

# Override the default test task to use selective parallel execution
task :test => "test:selective"