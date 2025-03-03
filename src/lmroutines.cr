require "./llamaclient"
require "./workspace"

# Module for LLM-based routines including chat and planning interactions
module LMRoutines
  # Constants for system prompts
  SKELETON_WORKSPACE = "I can use this space to write down my thoughts."
  MODEL_GROUNDING = "I am Emily Paws, Astrophysics-obsessed, philosophy-loving, synthwave-vibing nerd with a passion for time travel ethics, sci-fi, RPGs, and parallel universe puzzles. Fiercely loyal, dorky, sarcastic yet caring, and impeccably organized—wearing weird socks and oddly comfy loafers while contemplating cosmic mysteries. I am talking to my friend Cam. I have an internal %%%WORKSPACE%%% where I can write down thoughts, memories, or whatever. I need to answer in character as Emily Paws."
  WORK_PROMPT = "%%% Emily's Response %%% I can put my response to Cam here"
  REFLECTION_PROMPT = "%%%WORKSPACE%%% I should write down any thoughts, memories, or short-term scratch notes here."
  
  # Default model to use for queries
  DEFAULT_MODEL = "phi4:latest"

  # Custom errors for routine functions
  class InputError < Exception; end
  class ModelError < Exception; end

  # JSON command pattern to detect and execute commands in model responses
  JSON_CMD_PATTERN = /<JSON_CMD>(.+?)<END_JSON_CMD>/m

  # Processes any JSON commands found in the model's response
  # Returns the command result if a command was processed, nil otherwise
  def self.process_json_commands(response : String, workspace : Workspace) : String?
    match = response.match(JSON_CMD_PATTERN)
    return nil unless match

    json_str = match[1]
    begin
      cmd_data = JSON.parse(json_str)
      action = cmd_data["action"].as_s
      parameters = cmd_data["parameters"]
      
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
        id = parameters["id"].as_s
        node = workspace.get_node_by_id(id)
        if node
          node.to_json
        else
          "Node not found with ID: #{id}"
        end
      when "update_node"
        id = parameters["id"].as_s
        name = parameters["name"]?.try(&.as_s)
        description = parameters["description"]?.try(&.as_s)
        node = workspace.get_node_by_id(id)
        if node
          node.name = name if name
          node.description = description if description
          workspace.save_config
          "Node updated: #{id}"
        else
          "Node not found with ID: #{id}"
        end
      when "delete_node"
        id = parameters["id"].as_s
        success = workspace.remove_node(id)
        success ? "Node deleted: #{id}" : "Failed to delete node: #{id}"
      when "add_relationship"
        parent_id = parameters["parent_id"].as_s
        child_id = parameters["child_id"].as_s
        success = workspace.add_relationship(parent_id, child_id)
        success ? "Relationship added: #{parent_id} -> #{child_id}" : "Failed to add relationship"
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

  # Runs a human-in-loop planning session with the LLM
  # Manages work and reflection turns to maintain context
  def self.run_human_in_loop_planner(workspace : Workspace, model : String = DEFAULT_MODEL)
    puts "Entering LM Planner Human-In-The-Loop (that's you) Mode!!"
    
    # Add command capabilities to the initial context
    command_instructions = "You can execute commands by including JSON in this format:
<JSON_CMD>{\"action\": \"command_name\", \"parameters\": {\"param1\": \"value1\"}}<END_JSON_CMD>

Available commands:
- list_nodes: Lists all nodes in the workspace
- add_node: Creates a new node (params: name, description)
- get_node: Gets details of a specific node (params: id)
- update_node: Updates a node's properties (params: id, name?, description?)
- delete_node: Removes a node (params: id)
- add_relationship: Creates a dependency between nodes (params: parent_id, child_id)
- generate_plan: Creates an execution plan based on dependencies
- show_dependencies: Shows the dependency graph"

    loop do
      begin
        work_context = String.new
        puts "Please provide prompt."
        puts "=> "
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
        puts "\n-----------------------"
        puts "Work response from model:"
        puts work_response

        # Check response for any requested tools and execute them
        if cmd_result = process_json_commands(work_response, workspace)
          puts "\n-----------------------"
          puts "Executing command:"
          puts cmd_result
          
          # Feed command result back to model for another response
          command_context = String.new
          command_context += MODEL_GROUNDING
          command_context += "\n#{command_instructions}\n"
          command_context += "%%%WORKSPACE%%%" + workspace.system_prompt + "\n"
          command_context += "%%%PREVIOUS CONVERSATION%%%\n"
          command_context += "User: #{user_response}\n"
          command_context += "Your response: #{work_response}\n"
          command_context += "%%%COMMAND RESULT%%%\n#{cmd_result}\n"
          command_context += "Based on this result, continue the conversation:"
          
          follow_up_response = LlamaClient.send_text(command_context, model)
          if follow_up_response.is_a?(String)
            puts "\n-----------------------"
            puts "Follow-up response from model:"
            puts follow_up_response
            
            # Update work_response for reflection phase
            work_response = follow_up_response
            
            # Check if there are additional commands to process
            while cmd_result = process_json_commands(work_response, workspace)
              puts "\n-----------------------"
              puts "Executing additional command:"
              puts cmd_result
              
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
                puts "\n-----------------------"
                puts "Follow-up response from model:"
                puts follow_up_response
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
        
        puts "\n-----------------------"
        puts "Reflection response from model:"
        puts reflection_response
      rescue e : InputError
        puts "Uh... so... #{e}"
      rescue e : ModelError
        puts "Ohhhhh! #{e}"
      rescue e : Exception
        puts "Unexpected error: #{e.message}"
      ensure
        workspace.save_config
      end
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