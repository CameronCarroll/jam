require "./workspace"
require "./lm_command_processor"
require "./lm_ui"
require "./lm_prompts"
require "./lm_flow"

# Module for planning-related functionality
module LMPlanner
  # Helper to process commands from model response, writing to file instead of stdout
  def self.handle_model_commands(
    command_response : String,
    workspace : Workspace,
    model : String,
    output_file : String,
    command_history : Array(Hash(String, JSON::Any))? = nil,
  ) : String
    processor = CommandProcessorFlow.new(
      workspace,
      model,
      output_file,
      output_file, # Using same file for followup output
      command_history
    )

    return processor.process_output
  end

  # Runs a human-in-loop planning session with the LLM
  # Manages work and reflection turns to maintain context
  # If enable_command_tracking is true, tracks and displays all executed commands
  # Writes model responses to a file for better debugging
  def self.run_planning_session(workspace : Workspace, model : String, enable_command_tracking : Bool)
    puts "#{LMUI::BOLD}#{LMUI::BLUE}Entering LM Planner Human-In-The-Loop (that's you) Mode!!#{LMUI::RESET}"
    puts "#{LMUI::CYAN}Model responses will be written to model_output.txt#{LMUI::RESET}"

    # Ask user for northstar for the session.
    puts "#{LMUI::YELLOW}Please provide primary objective for our session ('north star').#{LMUI::RESET}"
    print "#{LMUI::BOLD}=> #{LMUI::RESET}"
    northstar = gets
    raise LMFlow::InputError.new("Problem with the user prompt input.") unless northstar.is_a?(String)
    return if northstar == "exit"
    workspace.modeldata["northstar"] = northstar

    # Initialize command history tracking if enabled
    command_history = enable_command_tracking ? Array(Hash(String, JSON::Any)).new : nil

    # Output file paths
    plan_output_file = "output/plan_output.txt"
    command_output_file = "output/command_output.txt"
    followup_output_file = "output/followup_output.txt"
    reflection_output_file = "output/reflection_output.txt"

    # Create flow objects
    planner_flow = PlannerFlow.new(workspace, model, plan_output_file)
    command_flow = CommandGeneratorFlow.new(workspace, model, command_output_file)
    command_processor = CommandProcessorFlow.new(
      workspace,
      model,
      command_output_file,
      followup_output_file,
      command_flow,
      command_history,
    )
    reflection_flow = ReflectionFlow.new(workspace, model, reflection_output_file)

    loop do
      begin
        # ---------------------------- #
        # STEP 0: User Input and Setup #
        # ---------------------------- #
        puts "#{LMUI::BOLD}#{LMUI::BLUE}Northstar:#{LMUI::RESET} #{northstar}"
        puts "#{LMUI::YELLOW}Please provide prompt.#{LMUI::RESET}"
        print "#{LMUI::BOLD}=> #{LMUI::RESET}"
        user_query = gets
        raise LMFlow::InputError.new("Problem with the user prompt input.") unless user_query.is_a?(String)
        break if user_query == "exit"
        workspace.modeldata["user_query"] = user_query

        # Initialize workspace if empty
        workspace.system_prompt = LMPrompts::SKELETON_WORKSPACE if workspace.system_prompt.empty?
        [plan_output_file, command_output_file, followup_output_file, reflection_output_file].each do |file|
          # Clear output from last iteration
          File.write(file, "")

          # Write session header
          File.open(file, "a") do |f|
            f.puts LMUI.get_ascii_divider(:stars)
            f.puts "NEW SESSION: #{Time.utc}"
            f.puts "=" * 80
            f.puts "NORTHSTAR: #{northstar}"
            f.puts "=" * 80
            f.puts "USER QUERY: #{user_query}"
            f.puts "-" * 80
          end
        end

        # ---------------------------------------------- #
        # STEP 1: Build Plan Context - Get Plan          #
        # ---------------------------------------------- #
        plan = planner_flow.run(user_query)

        # ------------------------ #
        # STEP 2: Command Response #
        # ------------------------ #
        command_response = command_flow.run(plan)

        # ------------------------------- #
        # STEP 3: Command Processing      #
        # ------------------------------- #
        # There is a whole loop in here where bot will continue processing commands
        # until it doesn't emit any more valid JSON (intentionally or not.)
        command_processor.output = command_response # Set the output directly
        final_response = command_processor.process_output

        # ------------------------------- #
        # STEP 4: Reflection              #
        # ------------------------------- #
        reflection_response = reflection_flow.run(final_response)

        # Print command history if tracking is enabled and write to file
        if command_history && !command_history.empty?
          puts "#{LMUI::BOLD}#{LMUI::YELLOW}Commands executed - see model_output.txt for details#{LMUI::RESET}"
          File.open(reflection_output_file, "a") do |file|
            file.puts LMUI.get_ascii_divider(:hearts)
            file.puts "COMMAND HISTORY:"
            file.puts "-" * 80
            LMCommandProcessor.print_command_history(command_history, file)
          end
        end

        # Notify user that output is available in file
        puts "#{LMUI::CYAN}All done!#{LMUI::RESET}"
      rescue e : LMFlow::InputError
        puts "#{LMUI::RED}#{LMUI::BOLD}Input Error:#{LMUI::RESET} #{e}"
      rescue e : LMFlow::ModelError
        puts "#{LMUI::RED}#{LMUI::BOLD}Model Error:#{LMUI::RESET} #{e}"
      rescue e : Exception
        puts "#{LMUI::RED}#{LMUI::BOLD}Unexpected error:#{LMUI::RESET} #{e.message}"
      ensure
        workspace.save_config
      end
    end
  end
end
