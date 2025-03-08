# Module containing all prompt constants used by the LLM
module LMPrompts
  # Skeleton workspace template for model reflection
  SKELETON_WORKSPACE = ""

  # Base grounding for the model
  MODEL_GROUNDING = "You are operating within a structured workspace. You have tools available to you."

  # Prompt for work responses
  WORK_PROMPT = "%%%MY RESPONSE%%%
    [This is where your direct response to the user should be placed. Write your answer here.]"

  # Prompt for reflection
  REFLECTION_PROMPT = "%%%REFLECTION PROMPT START%%%[In this section, reflect on the recent interaction. Update your SKELETON_WORKSPACE based on the interaction. Do NOT write your user-facing response here.  Use the sections within SKELETON_WORKSPACE to organize your reflections.]%%%REFLECTION PROMPT END%%%"

  # JSON command patterns for parsing model responses
  JSON_CMD_PATTERN  = /<JSON_CMD>(.+?)<END_JSON_CMD>/m
  JSON_CMD_PATTERN2 = /<JSON_CMD>(.+?)<\/JSON_CMD>/m
  JSON_CMD_PATTERN3 = /<JSON_CMD>(.+?)<\/END_JSON_CMD>/m

  # Command instructions for the model to use JSON commands
  COMMAND_INSTRUCTIONS = "COMMAND INSTRUCTIONS

You can execute commands by wrapping JSON in these tags:
<JSON_CMD>
[
  {\"action\": \"command_name1\", \"parameters\": {...}},
  {\"action\": \"command_name2\", \"parameters\": {...}}
]
<END_JSON_CMD>

EXAMPLES OF MULTI-COMMAND SEQUENCES:

Example 1 - Creating a basic workflow:
<JSON_CMD>
[
  {\"action\": \"add_node\", \"parameters\": {\"name\": \"Design Phase\", \"description\": \"Initial design work\"}},
  {\"action\": \"add_node\", \"parameters\": {\"name\": \"Development\", \"description\": \"Building the system\"}},
  {\"action\": \"add_relationship\", \"parameters\": {\"parent_index\": 0, \"child_index\": 1}}
]
<END_JSON_CMD>

Example 2 - Building and checking a dependency chain:
<JSON_CMD>
[
  {\"action\": \"add_node\", \"parameters\": {\"name\": \"Requirements\", \"description\": \"Gathering requirements\"}},
  {\"action\": \"add_node\", \"parameters\": {\"name\": \"Analysis\", \"description\": \"Analyzing requirements\"}},
  {\"action\": \"add_node\", \"parameters\": {\"name\": \"Implementation\", \"description\": \"Building the solution\"}},
  {\"action\": \"add_relationship\", \"parameters\": {\"parent_index\": 0, \"child_index\": 1}},
  {\"action\": \"add_relationship\", \"parameters\": {\"parent_index\": 1, \"child_index\": 2}},
  {\"action\": \"show_dependencies\", \"parameters\": {}}
]
<END_JSON_CMD>

Example 3 - Updating existing nodes:
<JSON_CMD>
[
  {\"action\": \"list_nodes\", \"parameters\": {}},
  {\"action\": \"update_node\", \"parameters\": {\"index\": 0, \"name\": \"Updated Requirements\"}},
  {\"action\": \"list_nodes\", \"parameters\": {}}
]
<END_JSON_CMD>

AVAILABLE COMMANDS:

1. list_nodes - Lists all nodes
   <JSON_CMD>{\"action\": \"list_nodes\", \"parameters\": {}}<END_JSON_CMD>

2. add_node - Creates a new node
   Required: name, description
   <JSON_CMD>{\"action\": \"add_node\", \"parameters\": {\"name\": \"PCB Design\", \"description\": \"Circuit board layout\"}}<END_JSON_CMD>

3. get_node - Gets node details
   Required: EITHER index OR uuid
   <JSON_CMD>{\"action\": \"get_node\", \"parameters\": {\"index\": 2}}<END_JSON_CMD>

4. update_node - Updates a node
   Required: EITHER index OR uuid, plus at least one of: name, description
   <JSON_CMD>{\"action\": \"update_node\", \"parameters\": {\"index\": 3, \"name\": \"Updated PCB Design\"}}<END_JSON_CMD>

5. delete_node - Removes a node
   Required: EITHER index OR uuid
   <JSON_CMD>{\"action\": \"delete_node\", \"parameters\": {\"index\": 3}}<END_JSON_CMD>

6. add_relationship - Creates dependency
   Required: EITHER parent_index & child_index OR parent_uuid & child_uuid
   <JSON_CMD>{\"action\": \"add_relationship\", \"parameters\": {\"parent_index\": 1, \"child_index\": 2}}<END_JSON_CMD>

7. execution_sequence - Shows execution order
   <JSON_CMD>{\"action\": \"execution_sequence\", \"parameters\": {}}<END_JSON_CMD>

8. show_dependencies - Shows dependency graph
   <JSON_CMD>{\"action\": \"show_dependencies\", \"parameters\": {}}<END_JSON_CMD>

IMPORTANT NOTES:
- Always include the \"parameters\" key, even when empty
- Commands in arrays execute in order
- Include ONLY the command JSON between the tags
- Do not add explanations or text outside the command tags"
end