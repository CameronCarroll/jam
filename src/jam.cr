# jam
# by ieve, Winter (but it feels like Spring) 2025
# Purpose: Playing around with structured data and LLMs in node management / personal assistant context.

require "json"
require "option_parser"
require "./llamaclient"
require "./workspace"
require "./node"
require "./cli"
require "./planner"

CONFIG_FILE = ".jam_config.json"
MODEL = "phi4:latest"

# ------------------- System prompts for like project management stuff
# SKELETON_WORKSPACE = "%%%What I am working on now%%%
# Fill this section in with what I'm actively working on in the current session.

# %%%Next Steps%%%
# I should list the next 1-3 actions to be performed in this section.

# %%%Scratchpad and Notes%%%
# I can jot things down in this space like temporary thoughts, intermediate results, project data."

# WORK_PROMPT = "This is a WORK TURN. I should not update my internal workspace on this turn."

# REFLECTION_PROMPT = "This is a REFLECTION TURN. I should update my internal %%%WORKSPACE%%% fields based on %%%MY PREVIOUS MESSAGE%%% to save any updates on work I'm working on, concrete next steps for the next iteration, and any notes for the scratchpad."

# ------------------- Open ended / blank system prompts ---------------
SKELETON_WORKSPACE = "I can use this space to write down my thoughts."
MODEL_GROUNDING = "I am Emily Paws, Astrophysics-obsessed, philosophy-loving, synthwave-vibing nerd with a passion for time travel ethics, sci-fi, RPGs, and parallel universe puzzles. Fiercely loyal, dorky, sarcastic yet caring, and impeccably organized—wearing weird socks and oddly comfy loafers while contemplating cosmic mysteries. I am talking to my friend Cam. I have an internal %%%WORKSPACE%%% where I can write down thoughts, memories, or whatever. I need to answer in character as Emily Paws."
WORK_PROMPT = "%%% Emily's Response %%% I can put my response to Cam here"
REFLECTION_PROMPT = "%%%WORKSPACE%%% I should write down any thoughts, memories, or short-term scratch notes here."


# ---------------------------------------------------------------------

class InputError < Error; end
class ModelError < Error; end

unless File.exists?(CONFIG_FILE)
  File.open(CONFIG_FILE, "w") do |file|
    file.print("
    {
    \"name\": \"\",
    \"system_prompt\": \"\",
    \"nodes\": []
    }")
  end
end

config_path = Path.new(CONFIG_FILE)
workspace = Workspace.new("LLM Project", config_path)
# Load config file and nodes into workspace
workspace.read_config

#--------------------------------------------
humaninloop = false
chatloop = false
nodeedit = false
execution_plan = false

parser = OptionParser.new do |parser|
parser.banner = "Usage: jam [command]"
parser.on("humaninloop", "Workspace planner with human in the loop") do
  humaninloop = true
end
parser.on("chatloop", "Enter into a blank chat with default model") do
  chatloop = true
end
parser.on("nodes", "CLI REPL to make updates to node entries") do
  nodeedit = true
  parser.banner = "Usage: jam nodes [argument]"
  parser.on("-n NAME", "--new NAME", "Add a name for the node entry") { |_name| name = _name}
end
parser.on("plan", "Generate and print an execution plan from the current workspace config") do
  execution_plan = true
end
end

parser.parse

if humaninloop
  # Grab user initial prompt
  # Grab workspace prompt, set it to skeleton if blank string
  # Assemble system prompt for a WORK TURN.
  # Send WORK TURN query to model
  # Assembly system prompt for a REFLECTION TURN.
  # Send REFLECTION TURN QUERY to model
  # Present both queries & results to user and ask for another input

  puts "Entering LM Planner Human-In-The-Loop (that's you) Mode!!"
  loop do
    begin
      work_context = String.new
      puts "Please provide prompt."
      puts "=> "
      user_response = gets
      raise InputError.new("Problem with the user prompt input.") unless user_response.is_a?(String)
      break if user_response == "exit"
      workspace.system_prompt = SKELETON_WORKSPACE if workspace.system_prompt = ""
      work_context += MODEL_GROUNDING
      work_context += "%%%WORKSPACE%%%" + workspace.system_prompt + "\n"
      work_context += "%%%USER QUERY%%%" + user_response + "\n"
      work_context += WORK_PROMPT
      work_response = LlamaClient.send_text(work_context, MODEL)
      raise ModelError.new("Problem with response from the model.") unless work_response.is_a?(String)
      puts "\n-----------------------"
      puts "Work response from model:"
      puts work_response

      #Check response for any requested tools

      reflection_context = String.new
      reflection_context += MODEL_GROUNDING
      reflection_context += "%%%WORKSPACE%%%" + workspace.system_prompt + "\n"
      reflection_context += "%%%MY PREVIOUS MESSAGE%%%" + work_response + "\n"
      reflection_context += REFLECTION_PROMPT
      reflection_response = LlamaClient.send_text(reflection_context, MODEL)
      raise ModelError.new("Problem with response from the model.") unless reflection_response.is_a?(String)
      workspace.system_prompt = reflection_response
      
      puts "\n-----------------------"
      puts "Reflection response from model:"
      puts reflection_response
    rescue e : InputError
      puts "Uh... so... #{e}"
    rescue e : ModelError
      puts "Ohhhhh! #{e}"
    ensure
      workspace.save_config
    end
  end

  prompt = String.new
  system_prompt = "System Prompt"
  prompt += system_prompt
  prompt += workspace.dump_nodes_for_llm
  if prompt == ""
    puts "no prompt"
  else
    result = LlamaClient.send_text(prompt, MODEL)
    puts result
  end
  else
  puts "no action"
end

if chatloop
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
        model_response = LlamaClient.send_text(context, MODEL)
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

if nodeedit
  cli = ProjectCLI.new(workspace)
  puts "Entering node data edit mode."
  loop do
    puts "======= Project Edit Mode ======="
    puts "Choices: (Enter a number)"
    puts "0. Print out all node entries for reference"
    puts "1. Create new node entry"
    puts "2. Edit an existing node entry"
    puts "3. Delete an existing node entry"
    puts "4. View node dependency graph"
    puts "5. Add relationship between nodes"
    puts "'exit' to quit"
    if user_response = gets
      user_response = user_response.chomp
    else
      puts "No response??"
      break
    end
    case user_response
    when "0"
      puts workspace.dump_nodes_for_human
    when "1" # New node entry
      cli.new_node_entry
    when "2" # Edit node
      cli.edit_node_entry
    when "3" # Delete node entry
      cli.delete_node_entry
    when "4"
      puts Planner.dump_dependency_graph(workspace)
    when "5"
      cli.add_relationship_between_nodes
    when "exit"
      break
    else
      puts "Really terrible choice"
    end
  end
end

if execution_plan
  puts Planner.generate_execution_plan(workspace)
end