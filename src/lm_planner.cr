require "./workspace"
require "./lm_command_processor"
require "./lm_ui"
require "./lm_prompts"

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
    final_response = "Attempting to run tools... "
    # Check for any commands in the initial response
    if cmd_result = LMCommandProcessor.process_json_commands(command_response, workspace, command_history)
      # Write command execution to file
      File.open(output_file, "a") do |file|
        # Add a cute ASCII divider
        file.puts LMUI.get_ascii_divider(:bubbles)
        file.puts "EXECUTING COMMAND:"
        file.puts "-" * 80
        file.puts cmd_result
      end

      # Also print a brief notification to terminal
      puts "#{LMUI::MAGENTA}Executing command (see #{output_file})#{LMUI::RESET}"

      # Build context for command follow-up
      followup_command_context = LMRoutines.build_model_context(
        workspace,
        {
          :include_grounding => "yes",
          :include_commands  => "yes",
          :previous_response => "%%%YOUR COMMAND WAS:%%% #{command_response}\n",
          :command_result    => "%%%RESULT FROM EXECUTING COMMAND%%%\n#{cmd_result}\n",
        }
      )
      followup_command_context += "%%%CURRENT NODES:%%% " + workspace.dump_nodes_for_llm
      followup_command_context += "%%%ORIGINAL PLAN:%%%" + workspace.modeldata["plan"]
      followup_command_context += "%%%ORIGINAL USER QUERY:%%%" + workspace.modeldata["user_query"]
      followup_command_context += "%%%ULTIMATE OBJECTIVE:%%%" + workspace.modeldata["northstar"]
      followup_command_context += "%%%YOUR FOLLOWUP COMMANDS%%% [This is where you should emit any follow-up commands in the proper JSON format."
        
      # Get follow-up response after command execution
      follow_up = LMUI.send_model_request(followup_command_context, model, "Follow-up response from model", output_file)
      if follow_up.includes?("<DONE>")
        LMUI.log_thing("Model emitted <DONE> token during command execution", "Command Execution", output_file)
        return follow_up
      end

      #Process any additional commands in the follow-up response
      while cmd_result = LMCommandProcessor.process_json_commands(final_response, workspace, command_history)
        # Write additional command execution to file
        File.open(output_file, "a") do |file|
          # Add a cute ASCII divider
          file.puts LMUI.get_ascii_divider(:flowers)
          file.puts "EXECUTING ADDITIONAL COMMAND:"
          file.puts "-" * 80
          file.puts cmd_result
        end
        if cmd_result.includes?("<DONE>")
          LMUI.log_thing("Model emitted <DONE> token during command execution", "Command Execution", output_file)
          break
        end

        # Also print a brief notification to terminal
        puts "#{LMUI::MAGENTA}Executing additional command (see #{output_file})#{LMUI::RESET}"

        # Build context for additional command follow-up
        command_context = LMRoutines.build_model_context(
          workspace,
          {
            :include_grounding     => "yes",
            :include_commands      => "yes",
            :previous_response => "%%%YOUR COMMAND WAS:%%% #{command_response}\n",
          :command_result    => "%%%RESULT FROM EXECUTING COMMAND%%%\n#{cmd_result}\n"
          })
        followup_command_context += "%%%CURRENT NODES:%%% " + workspace.dump_nodes_for_llm
        followup_command_context += "%%%ORIGINAL PLAN:%%%" + workspace.modeldata["plan"]
        followup_command_context += "%%%ORIGINAL USER QUERY:%%%" + workspace.modeldata["user_query"]
        followup_command_context += "%%%ULTIMATE OBJECTIVE:%%%" + workspace.modeldata["northstar"]
        followup_command_context += "%%%YOUR FOLLOWUP COMMANDS%%% [This is where you should emit any follow-up commands in the proper JSON format. Say '<DONE>' if there is nothing else to do.]"
        followup_command_context += "Say '<DONE>' if there is nothing else to do. Do not say '<DONE>' unless you are absolutely sure there are no additional actions to take.]"

        # Get another follow-up response
        follow_up = LMUI.send_model_request(command_context, model, "Follow-up response from model", output_file)
        final_response = follow_up
      end
    else
      final_response += "Unsuccessful tool execution?"
    end

    final_response
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
    raise LMRoutines::InputError.new("Problem with the user prompt input.") unless northstar.is_a?(String)
    return if northstar == "exit"
    workspace.modeldata["northstar"] = northstar

    # Initialize command history tracking if enabled
    command_history = enable_command_tracking ? Array(Hash(String, JSON::Any)).new : nil

    # Output file for model responses
    plan_output_file = "output/plan_output.txt"
    command_output_file = "output/command_output.txt"
    followup_output_file = "output/followup_output.txt"
    reflection_output_file = "output/reflection_output.txt"

    loop do
      begin
        # ---------------------------- #
        # STEP 0: User Input and Setup #
        # ---------------------------- #
        puts "#{LMUI::BOLD}#{LMUI::BLUE}Northstar:#{LMUI::RESET} #{northstar}"
        puts "#{LMUI::YELLOW}Please provide prompt.#{LMUI::RESET}"
        print "#{LMUI::BOLD}=> #{LMUI::RESET}"
        user_query = gets
        raise LMRoutines::InputError.new("Problem with the user prompt input.") unless user_query.is_a?(String)
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

        # Build initial work context
        plan_context = LMRoutines.build_model_context(
          workspace,
          {
            :include_workspace => "yes",
            :include_grounding => "yes"
          }
        )
        plan_context += LMPrompts::SHORT_COMMAND_INSTRUCTIONS
        plan_context += "%%%CURRENT NODES:%%% " + Planner.dump_dependency_graph(workspace)
        plan_context += "%%%USER QUERY%%% " + user_query
        plan_context += LMPrompts::NORTHSTAR_PROMPT + northstar
        plan_context += LMPrompts::PLAN_PROMPT
        LMUI.log_thing(plan_context, "Plan Context", plan_output_file) # writes context to output_file
        plan = LMUI.send_model_request(plan_context, model, "Planning response from model", plan_output_file) # writes result to output_file
        workspace.modeldata["plan"] = plan
 
        # ------------------------ #
        # STEP 2: Command Response #
        # ------------------------ #

        command_context = LMRoutines.build_model_context(
          workspace,
          {
            :include_grounding => "yes",
          }
        )
        command_context += plan
        command_context += "%%%CURRENT NODES:%%% " + workspace.dump_nodes_for_llm
        command_context += LMPrompts::COMMAND_INSTRUCTIONS
        command_context += LMPrompts::COMMAND_PROMPT
        LMUI.log_thing(command_context, "Command Context", command_output_file)
        command_response = LMUI.send_model_request(command_context, model, "Command response from model", command_output_file, temperature=0.3, top_p=0.3)
   
        # ------------------------------- #
        # STEP 3: Command Processing      #
        # ------------------------------- #
        # There is a whole loop in here where bot will continue processing commands until it doesn't emit any more valid JSON (intentionally or not.)
        final_response = handle_model_commands(command_response, workspace, model, followup_output_file, command_history)

        # ------------------------------- #
        # STEP 4: Reflection              #
        # ------------------------------- #

        # Build reflection context
        reflection_context = LMRoutines.build_model_context(
          workspace,
          {
            :include_workspace => "yes",
            :include_grounding => "yes",
            :previous_message  => "%%%YOUR LAST TOOL EXECUTION RESULT%%%" + final_response + "\n"
          }
        )
        reflection_context += "%%%Original Query from User%%%" + user_query
        reflection_context += "%%%ULTIMATE OBJECTIVE%%%" + northstar
        reflection_context += "%%%Your original plan before running tools:%%%" + plan
        reflection_context += LMPrompts::REFLECTION_PROMPT
        LMUI.log_thing(reflection_context, "Reflection Context", reflection_output_file)
        # Send reflection request to model
        reflection_response = LMUI.send_model_request(reflection_context, model, "Reflection response from model", reflection_output_file)
        
        if reflection_response.blank?
          # Panic sequence: revert to last stable prompt + log catastrophe
          workspace.system_prompt = workspace.modeldata["last_stable_prompt"] || LMPrompts::REFLECTION_PROMPT
          puts "Reflection nullified! Singularity imminent!"
        end  

        # Update workspace with reflection. Since we passed our (currently single) sanity check on reflection result, we'll update the last stable prompt as well.
        workspace.system_prompt = reflection_response
        workspace.modeldata["last_stable_prompt"] = reflection_response

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
      rescue e : LMRoutines::InputError
        puts "#{LMUI::RED}#{LMUI::BOLD}Input Error:#{LMUI::RESET} #{e}"
      rescue e : LMRoutines::ModelError
        puts "#{LMUI::RED}#{LMUI::BOLD}Model Error:#{LMUI::RESET} #{e}"
      rescue e : Exception
        puts "#{LMUI::RED}#{LMUI::BOLD}Unexpected error:#{LMUI::RESET} #{e.message}"
      ensure
        workspace.save_config
      end
    end
  end
end