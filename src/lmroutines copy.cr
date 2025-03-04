require "./llamaclient"
require "./workspace"

# Module for LLM-based routines including chat and planning interactions
module LMRoutines
  # Constants for system prompts
  SKELETON_WORKSPACE = "%%%SKELETON_WORKSPACE START%%%
This is your internal workspace. Use it for memory, cognition, and execution planning.

%%%SKELETON_WORKSPACE END%%%"

  MODEL_GROUNDING = "You are operating within a structured workspace. You have tools available to you and some scratch space where you can take notes. Have fun!"

  WORK_PROMPT = "%%%WORK PROMPT START%%%
    %%%MY RESPONSE%%%
    [This is where your direct response to the user should be placed. Write your answer here.]
    %%%WORK PROMPT END%%%"

  REFLECTION_PROMPT = "%%%REFLECTION PROMPT START%%%[In this section, reflect on the recent interaction. Update your SKELETON_WORKSPACE based on the interaction. Do NOT write your user-facing response here.  Use the sections within SKELETON_WORKSPACE to organize your reflections.]%%%REFLECTION PROMPT END%%%"

  # Default model to use for queries
  DEFAULT_MODEL = "command-r7b:latest"

  # Custom errors for routine functions
  class InputError < Exception; end

  class ModelError < Exception; end

  # JSON command pattern to detect and execute commands in model responses
  # Giving the LM a few chances. Ours ain't that smart.
  JSON_CMD_PATTERN  = /<JSON_CMD>(.+?)<END_JSON_CMD>/m
  JSON_CMD_PATTERN2 = /<JSON_CMD>(.+?)<\/JSON_CMD>/m
  JSON_CMD_PATTERN3 = /<JSON_CMD>(.+?)<\/END_JSON_CMD>/m

  # Processes any JSON commands found in the model's response
  # Returns the command result if a command was processed, nil otherwise
  # If command_history is provided, stores the command in the history
  def self.process_json_commands(response : String, workspace : Workspace, command_history : Array(Hash(String, JSON::Any))? = nil) : String?
    match = response.match(JSON_CMD_PATTERN) ||
            response.match(JSON_CMD_PATTERN2) ||
            response.match(JSON_CMD_PATTERN3)
    return nil unless match

    json_str = match[1]
    begin
      cmd_data = JSON.parse(json_str)
      action = cmd_data["action"].as_s
      parameters = cmd_data["parameters"]

      # Add to command history if tracking is enabled
      if command_history
        command_history << {"action" => JSON::Any.new(action), "parameters" => parameters}
      end

      # Execute the requested command based on action type
      result = case action
               when "list_nodes"
                 workspace.dump_nodes_for_human
               when "add_node"
                 name = parameters["name"].as_s
                 description = parameters["description"].as_s
                 new_node = Node.new(name, description)
                 workspace.add_node(new_node)
                 "Node added: #{name}"
               when "get_node"
                 # Handle node retrieval by either index or ID
                 if parameters["index"]?
                   index = parameters["index"].as_i
                   node = workspace.get_node_by_index(index)
                   if node
                     node.to_json
                   else
                     "Node not found at index: #{index}"
                   end
                 elsif parameters["id"]?
                   id = parameters["id"].as_s
                   node = workspace.get_node_by_id(id)
                   if node
                     node.to_json
                   else
                     "Node not found with ID: #{id}"
                   end
                 else
                   "Error: Missing node identifier (index or id)"
                 end
               when "update_node"
                 # Handle node update by either index or ID
                 name = parameters["name"]?.try(&.as_s)
                 description = parameters["description"]?.try(&.as_s)

                 if parameters["index"]?
                   index = parameters["index"].as_i
                   node = workspace.get_node_by_index(index)
                   if node
                     node.name = name if name
                     node.description = description if description
                     workspace.save_config
                     "Node updated at index: #{index}"
                   else
                     "Node not found at index: #{index}"
                   end
                 elsif parameters["id"]?
                   id = parameters["id"].as_s
                   node = workspace.get_node_by_id(id)
                   if node
                     node.name = name if name
                     node.description = description if description
                     workspace.save_config
                     "Node updated with ID: #{id}"
                   else
                     "Node not found with ID: #{id}"
                   end
                 else
                   "Error: Missing node identifier (index or id)"
                 end
               when "delete_node"
                 # Handle node deletion by either index or ID
                 if parameters["index"]?
                   index = parameters["index"].as_i
                   success, message = workspace.remove_node(index)
                   success ? "Node deleted at index: #{index}" : "Failed to delete node: #{message}"
                 elsif parameters["id"]?
                   id = parameters["id"].as_s
                   success, message = workspace.remove_node(id)
                   success ? "Node deleted with ID: #{id}" : "Failed to delete node: #{message}"
                 else
                   "Error: Missing node identifier (index or id)"
                 end
               when "add_relationship"
                 # Handle relationship creation by either indices or IDs
                 if parameters["parent_index"]? && parameters["child_index"]?
                   parent_index = parameters["parent_index"].as_i
                   child_index = parameters["child_index"].as_i

                   parent = workspace.get_node_by_index(parent_index)
                   child = workspace.get_node_by_index(child_index)

                   if parent.nil? || child.nil?
                     "Failed to add relationship: one or both nodes not found at specified indices"
                   else
                     success, message = workspace.create_dependency(parent, child)
                     success ? "Relationship added: #{parent.name} -> #{child.name}" : "Failed to add relationship: #{message}"
                   end
                 elsif parameters["parent_id"]? && parameters["child_id"]?
                   parent_id = parameters["parent_id"].to_s
                   child_id = parameters["child_id"].to_s

                   success, message = workspace.add_relationship(parent_id, child_id)
                   success ? "Relationship added: #{parent_id} -> #{child_id}" : "Failed to add relationship: #{message}"
                 else
                   "Error: Missing relationship identifiers (parent_index & child_index or parent_id & child_id)"
                 end
               when "generate_plan"
                 Planner.generate_execution_plan(workspace)
               when "show_dependencies"
                 Planner.dump_dependency_graph(workspace)
               else
                 "Unknown command: #{action}"
               end

      return "Command result for '#{action}':\n#{result}"
    rescue e
      return "Error processing command: #{e.message}\nJSON: #{json_str}"
    end
  end

  # Define ANSI color codes for terminal output
  CYAN      = "\033[36m"
  GREEN     = "\033[32m"
  YELLOW    = "\033[33m"
  BLUE      = "\033[34m"
  MAGENTA   = "\033[35m"
  RED       = "\033[31m"
  GRAY      = "\033[90m"
  BOLD      = "\033[1m"
  UNDERLINE = "\033[4m"
  RESET     = "\033[0m"

  # Command instructions for the model to use JSON commands
  COMMAND_INSTRUCTIONS = "I can execute commands by including JSON in this format:
<JSON_CMD>{\"action\": \"command_name\", \"parameters\": {\"param1\": \"value1\"}}<END_JSON_CMD>

Available commands:
- list_nodes: Lists all nodes in the workspace
- add_node: Creates a new node (params: name, description)
- get_node: Gets details of a specific node (params: either index or id)
- update_node: Updates a node's properties (params: either index or id, plus name?, description?)
- delete_node: Removes a node (params: either index or id)
- add_relationship: Creates a dependency between nodes (params: either parent_index & child_index or parent_id & child_id)
- generate_plan: Creates an execution plan based on dependencies
- show_dependencies: Shows the dependency graph

Notes:
- Index refers to the display order of nodes (0-based) as shown in the list_nodes output
- ID refers to the unique UUID identifier assigned to each node at creation.
- I need to remember to include <JSON_CMD> and <END_JSON_CMD>.
- I need to include the 'parameters' key even when it's empty.
- Do not include explanations or additional text. Only output the intended command."

  # Helper to draw a separator line in output
  def self.print_separator
    puts "\n#{GRAY}#{"-" * 50}#{RESET}"
  end

  # Returns ASCII art dividers for file output
  # Cycles through multiple divider styles
  def self.get_ascii_divider(divider_type : Symbol = :random) : String
    dividers = {
      cat: "
=^..^=   =^..^=   =^..^=   =^..^=   =^..^=   =^..^=   =^..^=
",
      stars: "
★彡★彡★彡★彡★彡★彡★彡★彡★彡★彡★彡★彡★彡★彡★彡★彡★彡★彡
",
      hearts: "
♥•*¨*•.¸¸♥•*¨*•.¸¸♥•*¨*•.¸¸♥•*¨*•.¸¸♥•*¨*•.¸¸♥•*¨*•.¸¸♥
",
      flowers: "
✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀
",
      bubbles: "
°o○●○o°°o○●○o°°o○●○o°°o○●○o°°o○●○o°°o○●○o°°o○●○o°°o○●○o°
",
    }

    if divider_type == :random
      # Pick a random divider
      divider_keys = dividers.keys
      random_key = divider_keys.sample
      return dividers[random_key]
    elsif dividers.has_key?(divider_type)
      return dividers[divider_type]
    else
      # Default to stars if invalid type provided
      return dividers[:stars]
    end
  end

  # Helper to build context for model queries
  def self.build_model_context(workspace : Workspace, parts : Hash(Symbol, String)) : String
    context = String.new

    # Always include workspace and grounding
    context += "%%%WORKSPACE%%%" + workspace.system_prompt + "\n" if parts.has_key?(:include_workspace)
    context += MODEL_GROUNDING if parts.has_key?(:include_grounding)

    # Add optional components
    context += "\n#{COMMAND_INSTRUCTIONS}\n" if parts.has_key?(:include_commands)

    # Add any specific parts provided
    parts.each do |key, value|
      next if [:include_workspace, :include_grounding, :include_commands].includes?(key)
      context += value
    end

    context
  end

  # Helper to handle model requests and responses
  def self.send_model_request(context : String, model : String, label : String) : String
    response = LlamaClient.send_text(context, model)

    if response.is_a?(String)
      print_separator
      puts "#{BOLD}#{CYAN}#{label}:#{RESET}"
      puts "#{GREEN}#{response}#{RESET}"
      return response
    else
      raise ModelError.new("Problem with response from the model.")
    end
  end

  # Helper to handle model requests and responses, writing to file instead of stdout
  def self.send_model_request_to_file(context : String, model : String, label : String, output_file : String) : String
    response = LlamaClient.send_text(context, model)

    if response.is_a?(String)
      # Write to file instead of printing to terminal
      File.open(output_file, "a") do |file|
        # Add a cute ASCII divider
        file.puts get_ascii_divider()
        file.puts "#{label}:"
        file.puts "-" * 80
        file.puts response
      end

      # Just print a short notification to the terminal
      puts "#{CYAN}Received model response (see #{output_file})#{RESET}"

      return response
    else
      raise ModelError.new("Problem with response from the model.")
    end
  end

  # Helper to process commands from model response
  def self.handle_model_commands(
    response : String,
    workspace : Workspace,
    model : String,
    command_history : Array(Hash(String, JSON::Any))? = nil,
  ) : String
    final_response = response

    # Check for any commands in the initial response
    if cmd_result = process_json_commands(response, workspace, command_history)
      print_separator
      puts "#{BOLD}#{MAGENTA}Executing command:#{RESET}"
      puts "#{YELLOW}#{cmd_result}#{RESET}"

      # Build context for command follow-up
      command_context = build_model_context(
        workspace,
        {
          :include_grounding => MODEL_GROUNDING,
          :include_commands  => "yes",
          :include_workspace => "yes",
          :previous_response => "Your response: #{response}\n",
          :command_result    => "%%%COMMAND RESULT%%%\n#{cmd_result}\n",
          :continue_prompt   => "Based on this result, continue the conversation:",
        }
      )

      # Get follow-up response after command execution
      follow_up = send_model_request(command_context, model, "Follow-up response from model")
      final_response = follow_up

      # Process any additional commands in the follow-up response
      while cmd_result = process_json_commands(final_response, workspace, command_history)
        print_separator
        puts "#{BOLD}#{MAGENTA}Executing additional command:#{RESET}"
        puts "#{YELLOW}#{cmd_result}#{RESET}"

        # Build context for additional command follow-up
        command_context = build_model_context(
          workspace,
          {
            :include_grounding     => MODEL_GROUNDING,
            :include_commands      => "yes",
            :include_workspace     => "yes",
            :previous_conversation => "%%%PREVIOUS CONVERSATION%%%\nYour last response: #{final_response}\n",
            :command_result        => "%%%COMMAND RESULT%%%\n#{cmd_result}\n",
            :continue_prompt       => "Based on this result, continue the conversation:",
          }
        )

        # Get another follow-up response
        follow_up = send_model_request(command_context, model, "Follow-up response from model")
        final_response = follow_up
      end
    end

    final_response
  end

  # Helper to process commands from model response, writing to file instead of stdout
  def self.handle_model_commands_to_file(
    response : String,
    workspace : Workspace,
    model : String,
    output_file : String,
    command_history : Array(Hash(String, JSON::Any))? = nil,
  ) : String
    final_response = response

    # Check for any commands in the initial response
    if cmd_result = process_json_commands(response, workspace, command_history)
      # Write command execution to file
      File.open(output_file, "a") do |file|
        # Add a cute ASCII divider
        file.puts get_ascii_divider(:bubbles)
        file.puts "EXECUTING COMMAND:"
        file.puts "-" * 80
        file.puts cmd_result
      end

      # Also print a brief notification to terminal
      puts "#{MAGENTA}Executing command (see #{output_file})#{RESET}"

      # Build context for command follow-up
      command_context = build_model_context(
        workspace,
        {
          :include_grounding => MODEL_GROUNDING,
          :include_commands  => "yes",
          :include_workspace => "yes",
          :previous_response => "Your response: #{response}\n",
          :command_result    => "%%%COMMAND RESULT%%%\n#{cmd_result}\n",
          :continue_prompt   => "Based on this result, continue the conversation:",
        }
      )

      # Get follow-up response after command execution
      follow_up = send_model_request_to_file(command_context, model, "Follow-up response from model", output_file)
      final_response = follow_up

      # Process any additional commands in the follow-up response
      while cmd_result = process_json_commands(final_response, workspace, command_history)
        # Write additional command execution to file
        File.open(output_file, "a") do |file|
          # Add a cute ASCII divider
          file.puts get_ascii_divider(:flowers)
          file.puts "EXECUTING ADDITIONAL COMMAND:"
          file.puts "-" * 80
          file.puts cmd_result
        end

        # Also print a brief notification to terminal
        puts "#{MAGENTA}Executing additional command (see #{output_file})#{RESET}"

        # Build context for additional command follow-up
        command_context = build_model_context(
          workspace,
          {
            :include_grounding     => MODEL_GROUNDING,
            :include_commands      => "yes",
            :include_workspace     => "yes",
            :previous_conversation => "%%%PREVIOUS CONVERSATION%%%\nYour last response: #{final_response}\n",
            :command_result        => "%%%COMMAND RESULT%%%\n#{cmd_result}\n",
            :continue_prompt       => "Based on this result, continue the conversation:",
          }
        )

        # Get another follow-up response
        follow_up = send_model_request_to_file(command_context, model, "Follow-up response from model", output_file)
        final_response = follow_up
      end
    end

    final_response
  end

  # Runs a human-in-loop planning session with the LLM
  # Manages work and reflection turns to maintain context
  # If enable_command_tracking is true, tracks and displays all executed commands
  # Writes model responses to a file for better debugging
  def self.run_human_in_loop_planner(workspace : Workspace, model : String = DEFAULT_MODEL, enable_command_tracking : Bool = false)
    puts "#{BOLD}#{BLUE}Entering LM Planner Human-In-The-Loop (that's you) Mode!!#{RESET}"
    puts "#{CYAN}Model responses will be written to model_output.txt#{RESET}"

    # Initialize command history tracking if enabled
    command_history = enable_command_tracking ? Array(Hash(String, JSON::Any)).new : nil

    # Output file for model responses
    output_file = "model_output.txt"

    loop do
      begin
        # Get user input
        puts "#{YELLOW}Please provide prompt.#{RESET}"
        print "#{BOLD}=> #{RESET}"
        user_response = gets
        raise InputError.new("Problem with the user prompt input.") unless user_response.is_a?(String)
        break if user_response == "exit"

        # Initialize workspace if empty
        workspace.system_prompt = SKELETON_WORKSPACE if workspace.system_prompt.empty?

        # Clear the output file at the start of each loop iteration
        File.write(output_file, "")

        # Write beginning of session to file
        File.open(output_file, "a") do |file|
          file.puts get_ascii_divider(:stars)
          file.puts "NEW SESSION: #{Time.utc}"
          file.puts "=" * 80
          file.puts "USER QUERY: #{user_response}"
          file.puts "-" * 80
        end

        # Build initial work context
        work_context = build_model_context(
          workspace,
          {
            :include_workspace => "yes",
            :include_grounding => MODEL_GROUNDING,
            :include_commands  => "yes",
            :user_query        => "%%%USER QUERY%%%" + user_response + "\n",
            :work_prompt       => WORK_PROMPT,
          }
        )

        # Send initial work request to model and write to file instead of printing
        work_response = send_model_request_to_file(work_context, model, "Work response from model", output_file)

        # Process any commands in the model's response
        final_work_response = handle_model_commands_to_file(work_response, workspace, model, output_file, command_history)

        # Build reflection context
        reflection_context = build_model_context(
          workspace,
          {
            :include_workspace => "yes",
            :include_grounding => MODEL_GROUNDING,
            :previous_message  => "%%%MY PREVIOUS MESSAGE%%%" + final_work_response + "\n",
            :reflection_prompt => REFLECTION_PROMPT,
          }
        )

        # Send reflection request to model
        reflection_response = send_model_request_to_file(reflection_context, model, "Reflection response from model", output_file)

        # Update workspace with reflection
        workspace.system_prompt = reflection_response

        # Print command history if tracking is enabled and write to file
        if command_history && !command_history.empty?
          puts "#{BOLD}#{YELLOW}Commands executed - see model_output.txt for details#{RESET}"
          File.open(output_file, "a") do |file|
            file.puts get_ascii_divider(:hearts)
            file.puts "COMMAND HISTORY:"
            file.puts "-" * 80
            print_command_history(command_history, file)
          end
        end

        # Notify user that output is available in file
        puts "#{CYAN}Complete model output written to #{output_file}#{RESET}"
      rescue e : InputError
        puts "#{RED}#{BOLD}Input Error:#{RESET} #{e}"
      rescue e : ModelError
        puts "#{RED}#{BOLD}Model Error:#{RESET} #{e}"
      rescue e : Exception
        puts "#{RED}#{BOLD}Unexpected error:#{RESET} #{e.message}"
      ensure
        workspace.save_config
      end
    end
  end

  # Helper method to print command history in a formatted way
  # Can write to a specific IO or defaults to STDOUT
  def self.print_command_history(command_history : Array(Hash(String, JSON::Any)), io : IO = STDOUT)
    io.puts "Command History:"
    command_history.each_with_index do |cmd, index|
      action = cmd["action"].as_s
      params = cmd["parameters"]
      # Format parameters for nicer display
      params_display = params.as_h.map { |k, v| "#{k}: #{v}" }.join(", ")
      io.puts "#{index + 1}. #{action}#{params_display.empty? ? "" : " (#{params_display})"}"
    end
  end

  # Runs a simple chat loop with the LLM
  def self.run_chat_loop(model : String = DEFAULT_MODEL)
    context = String.new
    loop do
      puts "=> "
      input = gets
      if input.is_a?(String)
        case input
        when ""
          next
        when "exit"
          break
        else
          context += input
          model_response = LlamaClient.send_text(context, model)
        end
        if model_response.is_a?(String)
          puts model_response
          context += model_response
        else
          puts "Model error"
        end
      else
        puts "Input error"
      end
    end
  end
end
