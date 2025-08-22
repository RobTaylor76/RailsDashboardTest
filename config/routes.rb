Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Dashboard routes
  root "dashboard#index"
  get "dashboard", to: "dashboard#index"
  get "dashboard/refresh", to: "dashboard#refresh"
  get "dashboard/stream", to: "dashboard#stream"
  get "dashboard/stream-test", to: "dashboard#stream_test"
  get "dashboard/sse-test", to: "dashboard#sse_test"
  get "dashboard/trigger-jobs", to: "dashboard#trigger_jobs"
  get "dashboard/test-auto-refresh", to: "dashboard#test_auto_refresh"
  get "dashboard/debug", to: "dashboard#debug"
  get "dashboard/metrics", to: "dashboard#metrics"
end
