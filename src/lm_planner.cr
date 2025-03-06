require "./workspace"
require "./lm_command_processor"
require "./lm_ui"

# Module for planning-related functionality
module LMPlanner
  
  # Helper to process commands from model response, writing to file instead of stdout
  def self.handle_model_commands(
    response : String,
    workspace : Workspace,
    model : String,
    output_file : String,
    command_history : Array(Hash(String, JSON::Any))? = nil,
  ) : String
    final_response = response

    # Check for any commands in the initial response
    if cmd_result = LMCommandProcessor.process_json_commands(response, workspace, command_history)
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
      command_context = LMRoutines.build_model_context(
        workspace,
        {
          :include_grounding => LMRoutines::MODEL_GROUNDING,
          :include_commands  => "yes",
          :include_workspace => "yes",
          :previous_response => "Your response: #{response}\n",
          :command_result    => "%%%COMMAND RESULT%%%\n#{cmd_result}\n",
          :continue_prompt   => "Based on this result, continue the conversation:",
        }
      )

      # Get follow-up response after command execution
      follow_up = LMUI.send_model_request(command_context, model, "Follow-up response from model", output_file)
      final_response = follow_up

      # Process any additional commands in the follow-up response
      # while cmd_result = LMCommandProcessor.process_json_commands(final_response, workspace, command_history)
      #   # Write additional command execution to file
      #   File.open(output_file, "a") do |file|
      #     # Add a cute ASCII divider
      #     file.puts LMUI.get_ascii_divider(:flowers)
      #     file.puts "EXECUTING ADDITIONAL COMMAND:"
      #     file.puts "-" * 80
      #     file.puts cmd_result
      #   end

      #   # Also print a brief notification to terminal
      #   puts "#{LMUI::MAGENTA}Executing additional command (see #{output_file})#{LMUI::RESET}"

      #   # Build context for additional command follow-up
      #   command_context = LMRoutines.build_model_context(
      #     workspace,
      #     {
      #       :include_grounding     => LMRoutines::MODEL_GROUNDING,
      #       :include_commands      => "yes",
      #       :include_workspace     => "yes",
      #       :previous_conversation => "%%%PREVIOUS CONVERSATION%%%\nYour last response: #{final_response}\n",
      #       :command_result        => "%%%COMMAND RESULT%%%\n#{cmd_result}\n",
      #       :continue_prompt       => "Based on this result, continue the conversation:",
      #     }
      #   )

      #   # Get another follow-up response
      #   follow_up = LMUI.send_model_request(command_context, model, "Follow-up response from model", output_file)
      #   final_response = follow_up
      # end
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

    # Initialize command history tracking if enabled
    command_history = enable_command_tracking ? Array(Hash(String, JSON::Any)).new : nil

    # Output file for model responses
    output_file = "model_output.txt"

    loop do
      begin
        # ---------------------------- #
        # STEP 0: User Input and Setup #
        # ---------------------------- #
        puts "#{LMUI::YELLOW}Please provide prompt.#{LMUI::RESET}"
        print "#{LMUI::BOLD}=> #{LMUI::RESET}"
        user_response = gets
        raise LMRoutines::InputError.new("Problem with the user prompt input.") unless user_response.is_a?(String)
        break if user_response == "exit"

        # Initialize workspace if empty
        workspace.system_prompt = LMRoutines::SKELETON_WORKSPACE if workspace.system_prompt.empty?

        # Clear the output file at the start of each loop iteration
        File.write(output_file, "")

        # Write beginning of session to file
        File.open(output_file, "a") do |file|
          file.puts LMUI.get_ascii_divider(:stars)
          file.puts "NEW SESSION: #{Time.utc}"
          file.puts "=" * 80
          file.puts "USER QUERY: #{user_response}"
          file.puts "-" * 80
        end

        # ---------------------------------------------- #
        # STEP 1: Build Work Context - Get Work Response #
        # ---------------------------------------------- #

        # Build initial work context
        work_context = LMRoutines.build_model_context(
          workspace,
          {
            :include_workspace => "yes",
            :include_grounding => LMRoutines::MODEL_GROUNDING,
            :user_query        => "%%%USER QUERY%%%" + user_response + "\n",
            :work_prompt       => LMRoutines::WORK_PROMPT,
          }
        )
        LMUI.log_context(work_context, "Work Context", output_file) # writes context to output_file
        work_response = LMUI.send_model_request(work_context, model, "Work response from model", output_file) # writes result to output_file

        # ------------------------ #
        # STEP 2: Command Response #
        # ------------------------ #
        previous_context = work_context
        previous_context += "%%%COMMAND INSTRUCTIONS%%% Your response to the user is above. Use the JSON commands available to you to emit a single JSON command based on your response. Do not emit more than one command at a time. If there are no applicable commands based on the situation, just say that."
        command_context = LMRoutines.build_model_context(
          workspace,
          {
            :include_grounding => LMRoutines::MODEL_GROUNDING,
            :include_commands => "yes",
            :user_query => previous_context,
            :work_prompt => ""
          }
        )
        LMUI.log_context(command_context, "Command Context", output_file)
        command_response = LMUI.send_model_request(command_context, model, "Command response from model", output_file)

        # ------------------------------- #
        # STEP 3: Command Processing Loop #
        # ------------------------------- #
        final_response = handle_model_commands(command_response, workspace, model, output_file, command_history)

        # Print command history if tracking is enabled and write to file
        if command_history && !command_history.empty?
          puts "#{LMUI::BOLD}#{LMUI::YELLOW}Commands executed - see model_output.txt for details#{LMUI::RESET}"
          File.open(output_file, "a") do |file|
            file.puts LMUI.get_ascii_divider(:hearts)
            file.puts "COMMAND HISTORY:"
            file.puts "-" * 80
            LMCommandProcessor.print_command_history(command_history, file)
          end
        end

        # Notify user that output is available in file
        puts "#{LMUI::CYAN}Complete model output written to #{output_file}#{LMUI::RESET}"

        # 
        # ========================================================================

        # # Process any commands in the model's response
        # final_work_response = handle_model_commands(work_response, workspace, model, output_file, command_history)

        # # Build reflection context
        # reflection_context = LMRoutines.build_model_context(
        #   workspace,
        #   {
        #     :include_workspace => "yes",
        #     :include_grounding => LMRoutines::MODEL_GROUNDING,
        #     :previous_message  => "%%%MY PREVIOUS MESSAGE%%%" + final_work_response + "\n",
        #     :reflection_prompt => LMRoutines::REFLECTION_PROMPT,
        #   }
        # )

        # # Send reflection request to model
        # reflection_response = LMUI.send_model_request(reflection_context, model, "Reflection response from model", output_file)

        # # Update workspace with reflection
        # workspace.system_prompt = reflection_response

        # # Print command history if tracking is enabled and write to file
        # if command_history && !command_history.empty?
        #   puts "#{LMUI::BOLD}#{LMUI::YELLOW}Commands executed - see model_output.txt for details#{LMUI::RESET}"
        #   File.open(output_file, "a") do |file|
        #     file.puts LMUI.get_ascii_divider(:hearts)
        #     file.puts "COMMAND HISTORY:"
        #     file.puts "-" * 80
        #     LMCommandProcessor.print_command_history(command_history, file)
        #   end
        # end

        # # Notify user that output is available in file
        # puts "#{LMUI::CYAN}Complete model output written to #{output_file}#{LMUI::RESET}"
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