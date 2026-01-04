class RakeTasksController < ApplicationController
#   http_basic_authenticate_with name: ENV.fetch("RAKE_TASK_USERNAME"), password: ENV.fetch("RAKE_TASK_PASSWORD")

#   require "rake"
#   Rails.application.load_tasks

#   def show
#     render({ :template => "rake_tasks/show" })
#   end

#   def run_task
#     # Re-enable the task if it has already been executed
#     Rake::Task["sample_data"].reenable
    
#     # Run the rake task
#     Rake::Task["sample_data"].invoke

#     redirect_to("/rake_tasks", { :notice => "Rake task has been run." })
#   end
end
