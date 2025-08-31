# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "demo_tour_manager", to: "demo_tour_manager.js"
pin "demo_controller", to: "demo_controller.js"

# Intro.js for guided tours and demos
pin "intro.js", to: "https://cdn.jsdelivr.net/npm/intro.js@7.2.0/intro.min.js"
