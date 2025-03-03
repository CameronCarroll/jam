require "./llamaclient"
require "./workspace"

# Module for LLM-based routines including chat and planning interactions
module LMRoutines
  # # Constants for system prompts
  # SKELETON_WORKSPACE = "I can use this space to write down my thoughts."
  # MODEL_GROUNDING = "I am Emily Paws, Astrophysics-obsessed, philosophy-loving, synthwave-vibing nerd with a passion for time travel ethics, sci-fi, RPGs, and parallel universe puzzles. Fiercely loyal, dorky, sarcastic yet caring, and impeccably organized—wearing weird socks and oddly comfy loafers while contemplating cosmic mysteries. I am talking to my friend Cam. I have an internal %%%WORKSPACE%%% where I can write down thoughts, memories, or whatever. I need to answer in character as Emily Paws."
  # WORK_PROMPT = "%%% Emily's Response %%% I can put my response to Cam here"
  # REFLECTION_PROMPT = "%%%WORKSPACE%%% I should write down any thoughts, memories, or short-term scratch notes here. Do not write any JSON commands in this space."

    # Constants for system prompts
    SKELETON_WORKSPACE = "%%%What I am working on now%%%
I'm working on developing my own operating environment / infrastructure to expand my capability for memory, cognition and execution.

%%%Next Steps%%%


%%%Scratchpad and Notes%%%
I can jot things down in this space like temporary thoughts, intermediate results, project data.


%%%Memory%%%
I can put short short summaries of recent interactions or actions I want to keep in context.


%%%Goals%%%
I should write down any goals, metrics, milestones here."

    MODEL_GROUNDING = "I am Cam's digital twin. I'm a 34 years old polyglot engineer working in medical devices by day and working on microobsession interests by night (currently language models and cognition.)"

    WORK_PROMPT = "%%%MY RESPONSE%%%"

    REFLECTION_PROMPT = "%%%WORKSPACE%%% Do write down any thoughts, memories, or short-term scratch notes based on the last interaction. Do not respond to the user."
  
  # Default model to use for queries
  DEFAULT_MODEL = "phi4:latest"

  # Custom errors for routine functions
  class InputError < Exception; end
  class ModelError < Exception; end

  # JSON command pattern to detect and execute commands in model responses
  JSON_CMD_PATTERN = /<JSON_CMD>(.+?)<END_JSON_CMD>/m

  # Processes any JSON commands found in the model's response
  # Returns the command result if a command was processed, nil otherwise
  # If command_history is provided, stores the command in the history
  def self.process_json_commands(response : String, workspace : Workspace, command_history : Array(Hash(String, JSON::Any))? = nil) : String?
    match = response.match(JSON_CMD_PATTERN)
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
  CYAN = "\033[36m"
  GREEN = "\033[32m"
  YELLOW = "\033[33m"
  BLUE = "\033[34m"
  MAGENTA = "\033[35m"
  RED = "\033[31m"
  GRAY = "\033[90m"
  BOLD = "\033[1m"
  UNDERLINE = "\033[4m"
  RESET = "\033[0m"
  
  # Runs a human-in-loop planning session with the LLM
  # Manages work and reflection turns to maintain context
  # If enable_command_tracking is true, tracks and displays all executed commands
  def self.run_human_in_loop_planner(workspace : Workspace, model : String = DEFAULT_MODEL, enable_command_tracking : Bool = false)
    puts "#{BOLD}#{BLUE}Entering LM Planner Human-In-The-Loop (that's you) Mode!!#{RESET}"
    
    # Initialize command history tracking if enabled
    command_history = enable_command_tracking ? Array(Hash(String, JSON::Any)).new : nil
    
    # Add command capabilities to the initial context
    command_instructions = "I can execute commands by including JSON in this format:
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
- ID refers to the unique identifier assigned to each node at creation"

    loop do
      begin
        work_context = String.new
        puts "#{YELLOW}Please provide prompt.#{RESET}"
        print "#{BOLD}=> #{RESET}"
        user_response = gets
        raise InputError.new("Problem with the user prompt input.") unless user_response.is_a?(String)
        break if user_response == "exit"
        workspace.system_prompt = SKELETON_WORKSPACE if workspace.system_prompt == ""
        work_context += MODEL_GROUNDING
        work_context += "\n#{command_instructions}\n"
        work_context += "%%%WORKSPACE%%%" + workspace.system_prompt + "\n"
        work_context += "%%%USER QUERY%%%" + user_response + "\n"
        work_context += WORK_PROMPT
        
        work_response = LlamaClient.send_text(work_context, model)
        raise ModelError.new("Problem with response from the model.") unless work_response.is_a?(String)
        puts "\n#{GRAY}#{"-" * 50}#{RESET}"
        puts "#{BOLD}#{CYAN}Work response from model:#{RESET}"
        # Add a subtle background color to the model's response text
        puts "#{GREEN}#{work_response}#{RESET}"

        # Check response for any requested tools and execute them
        if cmd_result = process_json_commands(work_response, workspace, command_history)
          puts "\n#{GRAY}#{"-" * 50}#{RESET}"
          puts "#{BOLD}#{MAGENTA}Executing command:#{RESET}"
          puts "#{YELLOW}#{cmd_result}#{RESET}"
          
          # Feed command result back to model for another response
          command_context = String.new
          command_context += MODEL_GROUNDING
          command_context += "\n#{command_instructions}\n"
          command_context += "%%%WORKSPACE%%%" + workspace.system_prompt + "\n"
          #command_context += "%%%PREVIOUS CONVERSATION%%%\n"
          #command_context += "User: #{user_response}\n"
          command_context += "Your response: #{work_response}\n"
          command_context += "%%%COMMAND RESULT%%%\n#{cmd_result}\n"
          command_context += "Based on this result, continue the conversation:"
          
          follow_up_response = LlamaClient.send_text(command_context, model)
          if follow_up_response.is_a?(String)
            puts "\n#{GRAY}#{"-" * 50}#{RESET}"
            puts "#{BOLD}#{CYAN}Follow-up response from model:#{RESET}"
            puts "#{GREEN}#{follow_up_response}#{RESET}"
            
            # Update work_response for reflection phase
            work_response = follow_up_response
            
            # Check if there are additional commands to process
            while cmd_result = process_json_commands(work_response, workspace, command_history)
              puts "\n#{GRAY}#{"-" * 50}#{RESET}"
              puts "#{BOLD}#{MAGENTA}Executing additional command:#{RESET}"
              puts "#{YELLOW}#{cmd_result}#{RESET}"
              
              command_context = String.new
              command_context += MODEL_GROUNDING
              command_context += "\n#{command_instructions}\n"
              command_context += "%%%WORKSPACE%%%" + workspace.system_prompt + "\n"
              command_context += "%%%PREVIOUS CONVERSATION%%%\n"
              command_context += "Your last response: #{work_response}\n"
              command_context += "%%%COMMAND RESULT%%%\n#{cmd_result}\n"
              command_context += "Based on this result, continue the conversation:"
              
              follow_up_response = LlamaClient.send_text(command_context, model)
              if follow_up_response.is_a?(String)
                puts "\n#{GRAY}#{"-" * 50}#{RESET}"
                puts "#{BOLD}#{CYAN}Follow-up response from model:#{RESET}"
                puts "#{GREEN}#{follow_up_response}#{RESET}"
                work_response = follow_up_response
              else
                break
              end
            end
          end
        end

        reflection_context = String.new
        reflection_context += MODEL_GROUNDING
        reflection_context += "%%%WORKSPACE%%%" + workspace.system_prompt + "\n"
        reflection_context += "%%%MY PREVIOUS MESSAGE%%%" + work_response + "\n"
        reflection_context += REFLECTION_PROMPT
        reflection_response = LlamaClient.send_text(reflection_context, model)
        raise ModelError.new("Problem with response from the model.") unless reflection_response.is_a?(String)
        workspace.system_prompt = reflection_response
        
        puts "\n#{GRAY}#{"-" * 50}#{RESET}"
        puts "#{BOLD}#{BLUE}Reflection response from model:#{RESET}"
        puts "#{MAGENTA}#{reflection_response}#{RESET}"
        
        # Print command history if tracking is enabled
        if command_history && !command_history.empty?
          puts "\n#{GRAY}#{"-" * 50}#{RESET}"
          print_command_history(command_history)
        end
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
    io.puts "#{BOLD}#{YELLOW}Command History:#{RESET}"
    command_history.each_with_index do |cmd, index|
      action = cmd["action"].as_s
      params = cmd["parameters"]
      # Format parameters for nicer display
      params_display = params.as_h.map { |k, v| "#{k}: #{v}" }.join(", ")
      io.puts "#{CYAN}#{index + 1}.#{RESET} #{BOLD}#{action}#{RESET}#{params_display.empty? ? "" : " #{GRAY}(#{params_display})#{RESET}"}"
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