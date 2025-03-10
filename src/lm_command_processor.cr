require "./workspace"
require "json"
require "./lm_prompts"

JSON_CMD_PATTERN  = /(?:<JSON_CMD>)([\s\S]*?)(?:<\/JSON_CMD>|<\/END_JSON_CMD>|<\/JSON_CMD_END>|<END_JSON_CMD>|<JSON_CMD_END>)/m

# Module for processing JSON commands from model responses
module LMCommandProcessor
  # Processes any JSON commands found in the model's response
  # Returns the command result if a command was processed, nil otherwise
  # If command_history is provided, stores the command in the history
  # Now supports both single command objects and arrays of command objects
  def self.process_json_commands(response : String, workspace : Workspace, command_history : Array(Hash(String, JSON::Any))? = nil) : String?
    match = response.match(JSON_CMD_PATTERN)
    return nil unless match

    json_str = match[1]
    begin
      puts "DEBUG:"
      puts json_str
      parsed_data = JSON.parse(json_str)

      # Handle array of commands
      if parsed_data.as_a?
        commands = parsed_data.as_a

        if commands.empty?
          return "No commands to execute"
        end

        results = [] of String

        commands.each do |cmd_data|
          action = cmd_data["action"].as_s
          parameters = cmd_data["parameters"]

          # Add to command history if tracking is enabled
          if command_history
            command_history << {"action" => JSON::Any.new(action), "parameters" => parameters}
          end

          # Execute the requested command based on action type
          result = execute_command(action, parameters, workspace)
          results << "Command result for '#{action}':\n#{result}"
        end

        return results.join("\n\n")
      else
        # Handle single command (original functionality)
        action = parsed_data["action"].as_s
        parameters = parsed_data["parameters"]

        # Add to command history if tracking is enabled
        if command_history
          command_history << {"action" => JSON::Any.new(action), "parameters" => parameters}
        end

        # Execute the requested command based on action type
        result = execute_command(action, parameters, workspace)

        return "Command result for '#{action}':\n#{result}"
      end
    rescue e
      return "Error processing command: #{e.message}\nJSON: #{json_str}"
    end
  end

  # Execute a specific command with the given parameters
  private def self.execute_command(action : String, parameters : JSON::Any, workspace : Workspace) : String
    case action
    when "list_nodes"
      workspace.dump_nodes_for_human
    when "add_node"
      name = parameters["name"].as_s
      description = parameters["description"].as_s
      new_node = Node.new(name, description)
      workspace.add_node(new_node)
      "Node added: #{name}"
    when "get_node"
      handle_get_node(parameters, workspace)
    when "update_node"
      handle_update_node(parameters, workspace)
    when "delete_node"
      handle_delete_node(parameters, workspace)
    when "add_relationship"
      handle_add_relationship(parameters, workspace)
    when "execution_sequence"
      Planner.generate_execution_sequence(workspace)
    when "show_dependencies"
      Planner.dump_dependency_graph(workspace)
    when "trivia"
      get_trivia()
    else
      "Unknown command: #{action}"
    end
  end

  # Handle node retrieval by either index or ID
  private def self.handle_get_node(parameters : JSON::Any, workspace : Workspace) : String
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
    elsif parameters["uuid"]?
      id = parameters["uuid"].as_s
      node = workspace.get_node_by_id(id)
      if node
        node.to_json
      else
        "Node not found with ID: #{id}"
      end
    else
      "Error: Missing node identifier (index or id)"
    end
  end

  # Handle node update by either index or uuid
  private def self.handle_update_node(parameters : JSON::Any, workspace : Workspace) : String
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
    elsif parameters["uuid"]?
      uuid = parameters["uuid"].as_s
      node = workspace.get_node_by_id(uuid)
      if node
        node.name = name if name
        node.description = description if description
        workspace.save_config
        "Node updated with ID: #{uuid}"
      else
        "Node not found with ID: #{uuid}"
      end
    else
      "Error: Missing node identifier (index or uuid)"
    end
  end

  # Handle node deletion by either index or ID
  private def self.handle_delete_node(parameters : JSON::Any, workspace : Workspace) : String
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
  end

  # Handle relationship creation by either indices or IDs
  private def self.handle_add_relationship(parameters : JSON::Any, workspace : Workspace) : String
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
      LMUI.print_separator
      # Check if we're dealing with multiple commands (contains multiple command results)
      if cmd_result.includes?("Command result for") && cmd_result.scan("Command result for").size > 1
        puts "#{LMUI::BOLD}#{LMUI::MAGENTA}Executing multiple commands:#{LMUI::RESET}"
      else
        puts "#{LMUI::BOLD}#{LMUI::MAGENTA}Executing command:#{LMUI::RESET}"
      end
      puts "#{LMUI::YELLOW}#{cmd_result}#{LMUI::RESET}"

      # Build context for command follow-up
      command_context = LMRoutines.build_model_context(
        workspace,
        {
          :include_grounding => "yes",
          :include_commands  => "yes",
          :include_workspace => "yes",
          :previous_response => "Your response: #{response}\n",
          :command_result    => "%%%COMMAND RESULT%%%\n#{cmd_result}\n",
          :continue_prompt   => "Based on this result, continue the conversation:",
        }
      )

      # Get follow-up response after command execution
      follow_up = LMRoutines.send_model_request(command_context, model, "Follow-up response from model")
      final_response = follow_up

      # FEEDBACK LOOP IS BELOW
      # Disabled because it's a wild time.

      # Process any additional commands in the follow-up response
      # while cmd_result = process_json_commands(final_response, workspace, command_history)
      #   LMUI.print_separator
      #   puts "#{LMUI::BOLD}#{LMUI::MAGENTA}Executing additional command:#{LMUI::RESET}"
      #   puts "#{LMUI::YELLOW}#{cmd_result}#{LMUI::RESET}"

      #   # Build context for additional command follow-up
      #   command_context = LMRoutines.build_model_context(
      #     workspace,
      #     {
      #       :include_grounding     => "yes",
      #       :include_commands      => "yes",
      #       :include_workspace     => "yes",
      #       :previous_conversation => "%%%PREVIOUS CONVERSATION%%%\nYour last response: #{final_response}\n",
      #       :command_result        => "%%%COMMAND RESULT%%%\n#{cmd_result}\n",
      #       :continue_prompt       => "Based on this result, continue the conversation:",
      #     }
      #   )

      #   # Get another follow-up response
      #   follow_up = LMRoutines.send_model_request(command_context, model, "Follow-up response from model")
      #   final_response = follow_up
      # end
    end

    final_response
  end

  # Helper to print command history in a formatted way
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

  def self.get_trivia
    url = "https://opentdb.com/api.php?amount=3&category=17&difficulty=medium&type=multiple"
    response = HTTP::Client.get(url)

    if response.status_code == 200
      begin
        json_data = JSON.parse(response.body)
        return json_data.to_json
      rescue ex : JSON::ParseException
        puts "Error parsing JSON response: #{ex.message}"
        puts "Response body: #{response.body}"
        return ""
      end
    else
      puts "HTTP Request failed with status code: #{response.status_code}"
      puts "Response body: #{response.body}"
      return ""
    end
  end
end
