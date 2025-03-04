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
  SKELETON_WORKSPACE = "%%%SKELETON_WORKSPACE START%%%
This is your internal workspace. Use it for memory, cognition, and execution planning.

---SECTION: WHAT I AM WORKING ON NOW---
%%%What I am working on now%%%
[Describe your current main project or focus concisely. E.g., \"Developing operating environment for enhanced cognition.\"]

---SECTION: NEXT STEPS---
%%%Next Steps%%%
[List concrete next steps for your current project.  Use bullet points for clarity. E.g.,
- Refine memory module structure
- Design initial goal tracking system
- Test scratchpad functionality]

---SECTION: SCRATCHPAD AND NOTES---
%%%Scratchpad and Notes%%%
[Use this space for temporary thoughts, intermediate results, brainstorming, or quick notes during interactions. Clear this space as needed. E.g.,
- User asked about template improvement - need to add structure and explicit instructions.
- Consider adding instruction block at the beginning. ]

---SECTION: MEMORY (Short-Term Interaction Summaries)---
%%%Memory%%%
[Put short summaries of recent interactions or actions to maintain context. Focus on key details relevant to ongoing tasks or goals. Keep entries concise and recent. E.g.,
- 2023-10-27 User requested template rewrite for LM. Identified issues: response in reflection, erratic behavior, lack of structure. Goal: improve template clarity and directives. ]

---SECTION: GOALS---
%%%Goals%%%
[Write down your high-level goals, metrics for success, and milestones. Review and update regularly. E.g.,
- Goal 1: Develop robust and reliable operating environment.
    - Metric: System operates predictably and as instructed in 99% of interactions.
    - Milestone 1:  Basic template structure functional and prevents response in reflection (Target: 2023-10-28)
    - Milestone 2: Implement memory module with interaction logging (Target: 2023-11-05)
]

%%%SKELETON_WORKSPACE END%%%"

  MODEL_GROUNDING = "**INSTRUCTIONS:**

You are operating within a structured workspace. Please carefully follow these instructions for each interaction.

1.  **RESPONSE GENERATION:** When responding to the user, ALWAYS place your user-facing response within the  `%%%MY RESPONSE%%%`  block. This is the ONLY place where your direct answer to the user's query should go.

2.  **REFLECTION & WORKSPACE UPDATES:** After generating a response, use the `%%%REFLECTION_PROMPT%%%` block.  In this block:
    *   **DO NOT** write your user-facing response here.
    *   Write down any internal thoughts, memories, scratch notes, or workspace updates related to the recent interaction.
    *   Organize these reflections within the structured `SKELETON_WORKSPACE` provided below. Update the relevant sections like `Memory`, `Scratchpad and Notes`, `Goals`, etc., based on the interaction.

3.  **WORKSPACE UTILIZATION:** The `SKELETON_WORKSPACE` is your internal environment. Use it to manage your ongoing projects, remember interactions, and track your goals. Update it during the `REFLECTION_PROMPT` stage.

4.  **MODEL GROUNDING CONTEXT:** The `MODEL_GROUNDING` block provides essential context about your identity and background. This information helps you maintain consistency in your responses and reflections.

**Failure to follow these instructions may result in incorrect behavior.**"

  WORK_PROMPT = "%%%WORK PROMPT START%%%
    %%%MY RESPONSE%%%
    [This is where your direct response to the user should be placed. Write your answer here.]
    %%%WORK PROMPT END%%%"

  REFLECTION_PROMPT = "%%%REFLECTION PROMPT START%%%[In this section, reflect on the recent interaction. Update your SKELETON_WORKSPACE based on the interaction. Do NOT write your user-facing response here.  Use the sections within SKELETON_WORKSPACE to organize your reflections.]%%%REFLECTION PROMPT END%%%"

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
- ID refers to the unique identifier assigned to each node at creation
- I need to remember to include <JSON_CMD> and <END_JSON_CMD> for it to work.
- I need to include the 'parameters' key even when it's empty."

  # Helper to draw a separator line in output
  def self.print_separator
    puts "\n#{GRAY}#{"-" * 50}#{RESET}"
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

  # Runs a human-in-loop planning session with the LLM
  # Manages work and reflection turns to maintain context
  # If enable_command_tracking is true, tracks and displays all executed commands
  def self.run_human_in_loop_planner(workspace : Workspace, model : String = DEFAULT_MODEL, enable_command_tracking : Bool = false)
    puts "#{BOLD}#{BLUE}Entering LM Planner Human-In-The-Loop (that's you) Mode!!#{RESET}"

    # Initialize command history tracking if enabled
    command_history = enable_command_tracking ? Array(Hash(String, JSON::Any)).new : nil

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

        # Send initial work request to model
        work_response = send_model_request(work_context, model, "Work response from model")

        # Process any commands in the model's response
        final_work_response = handle_model_commands(work_response, workspace, model, command_history)

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
        reflection_response = send_model_request(reflection_context, model, "#{UNDERLINE}Reflection response from model")

        # Update workspace with reflection
        workspace.system_prompt = reflection_response

        # Print command history if tracking is enabled
        if command_history && !command_history.empty?
          print_separator
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
