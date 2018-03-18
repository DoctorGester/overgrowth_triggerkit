#include "triggerkit/shared_definitions.as"

int preview_character_id = -1;
int torso_target_id = -1;
int head_target_id = -1;
int eye_target_id = -1;

quaternion previous_rotation;
vec3 previous_position;
string previous_animation;

void try_queue_delete(int& object_id) {
    if (object_id != -1) {
        QueueDeleteObjectID(object_id);
        object_id = -1;
    }
}

void try_create_dummy_character() {
    if (preview_character_id != -1) {
        return;
    }

    preview_character_id = CreateObject("Data/Objects/IGF_Characters/pale_turner_actor.xml", true);

    Object@ object = ReadObjectFromID(preview_character_id);
    MovementObject@ movement_object = ReadCharacterID(preview_character_id);

    movement_object.static_char = true;
    movement_object.ReceiveScriptMessage("set_dialogue_control true");

    set_character_position_and_rotation_from_pose(preview_character_id, hotspot.GetID());

    object.SetCollisionEnabled(false);
    object.SetTranslation(ReadObjectFromID(hotspot.GetID()).GetTranslation());
    object.SetScale(0);
    object.SetSelectable(false);
    object.SetTranslatable(false);
    object.SetCopyable(false);
    object.SetDeletable(false);
    object.SetRotatable(false);
    object.SetScalable(false);
}

void try_create_and_set_placeholder_object(int& object_id, const string billdboard_path, const string string_name, vec3 initial_offset) {
    if (object_id != -1) {
        return;
    }

    object_id = CreateObject("Data/Objects/placeholder/empty_placeholder.xml", true);

    Object@ parent_object = ReadObjectFromID(hotspot.GetID());
    Object@ object = ReadObjectFromID(object_id);

    ScriptParams@ parent_script_params = parent_object.GetScriptParams();

    set_from_param_value_or_create_param(parent_script_params, string_name + "_x", initial_offset.x);
    set_from_param_value_or_create_param(parent_script_params, string_name + "_y", initial_offset.y);
    set_from_param_value_or_create_param(parent_script_params, string_name + "_z", initial_offset.z);

    object.SetTranslation(parent_object.GetTranslation() + (parent_object.GetRotation() * initial_offset));
    object.SetScale(0.5f);

    PlaceholderObject@ placeholder_object = cast<PlaceholderObject@>(object);
    placeholder_object.SetBillboard(billdboard_path);

    ScriptParams@ script_params = object.GetScriptParams();
    script_params.AddIntCheckbox("No Save", true);

    object.SetSelectable(true);
    object.SetTranslatable(true);

    object.SetCopyable(false);
    object.SetDeletable(false);
    object.SetRotatable(false);
    object.SetScalable(false);
}

void update_object_by_id(int& object_id, const string string_name, const string message_name) {
    Object@ parent_object = ReadObjectFromID(hotspot.GetID());
    Object@ object = ReadObjectFromID(object_id);

    quaternion parent_rotation = parent_object.GetRotation();
    vec3 parent_position = parent_object.GetTranslation();
    vec3 child_position = object.GetTranslation();
    vec3 relative_position = invert(parent_rotation) * (child_position - parent_position);

    DebugDrawLine(child_position, parent_position, vec4(vec3(1.0), 0.1), vec4(vec3(1.0), 0.1), _delete_on_update);

    ScriptParams@ parent_script_params = parent_object.GetScriptParams();

    set_param_value(parent_script_params, string_name + "_x", relative_position.x);
    set_param_value(parent_script_params, string_name + "_y", relative_position.y);
    set_param_value(parent_script_params, string_name + "_z", relative_position.z);

    ReadCharacterID(preview_character_id)
        .ReceiveScriptMessage(message_name + " " + child_position.x + " " + child_position.y + " " + child_position.z + " 1");
}

void update_child_position_from_parent(int object_id, string string_name) {
    Object@ parent_object = ReadObjectFromID(hotspot.GetID());
    ScriptParams@ parent_script_params = parent_object.GetScriptParams();

    vec3 parent_position = parent_object.GetTranslation();
    quaternion parent_rotation = parent_object.GetRotation();

    vec3 relative_position;

    relative_position.x = get_param_value_or_zero(parent_script_params, string_name + "_x");
    relative_position.y = get_param_value_or_zero(parent_script_params, string_name + "_y");
    relative_position.z = get_param_value_or_zero(parent_script_params, string_name + "_z");

    Object@ object = ReadObjectFromID(object_id);
    object.SetTranslation(parent_position + (parent_rotation * relative_position));
}

void Init() {
    Object@ hotspot_object = ReadObjectFromID(hotspot.GetID());

    hotspot_object.SetScale(vec3(0.2f, 0.5f, 0.2f));
    hotspot_object.SetScalable(false);

    level.ReceiveLevelEvents(hotspot.GetID());
}

void try_delete_placeholder_objects() {
    try_queue_delete(torso_target_id);
    try_queue_delete(head_target_id);
    try_queue_delete(eye_target_id);
}

bool is_selected_safe(int object_id) {
    if (object_id == -1) {
        return false;
    }

    return ReadObjectFromID(object_id).IsSelected();
}

void Dispose() {
    try_delete_placeholder_objects();
    try_queue_delete(preview_character_id);
    previous_animation = "";

    level.StopReceivingLevelEvents(hotspot.GetID());
}

void PreDraw(float game_time) {
    Object@ hotspot_object = ReadObjectFromID(hotspot.GetID());

    bool is_anything_related_selected =
        hotspot_object.IsSelected() ||
        is_selected_safe(torso_target_id) ||
        is_selected_safe(head_target_id) ||
        is_selected_safe(eye_target_id);

    if (preview_character_id != -1) {
        ReadCharacterID(preview_character_id).visible = is_anything_related_selected;
    }

    if (!EditorModeActive()) {
        try_delete_placeholder_objects();
        try_queue_delete(preview_character_id);
        previous_animation = "";

        return;
    }

    try_create_dummy_character();

    try_create_and_set_placeholder_object(torso_target_id, "Data/Textures/ui/torso_widget.tga", "torso", vec3(2, 0, 2));
    try_create_and_set_placeholder_object(head_target_id, "Data/Textures/ui/head_widget.tga", "head", vec3(0, 0, 2));
    try_create_and_set_placeholder_object(eye_target_id, "Data/Textures/ui/eye_widget.tga", "eye", vec3(-2, 0, 2));

    vec3 current_position = hotspot_object.GetTranslation();
    quaternion current_rotation = hotspot_object.GetRotation();

    if (current_position != previous_position || current_rotation != previous_rotation) {
        previous_rotation = current_rotation;
        previous_position = current_position;

        hotspot_moved();
    }

    update_object_by_id(torso_target_id, "torso", "set_torso_target");
    update_object_by_id(head_target_id, "head", "set_head_target");
    update_object_by_id(eye_target_id, "eye", "set_eye_dir");

    ScriptParams@ hotspot_params = hotspot_object.GetScriptParams();
    string current_animation;

    if (hotspot_params.HasParam("Animation")) {
        current_animation = hotspot_params.GetString("Animation");
    }

    if (current_animation != previous_animation) {
        previous_animation = current_animation;

        ReadCharacterID(preview_character_id).ReceiveScriptMessage("set_animation \"" + current_animation + "\"");
    }
}

void hotspot_moved() {
    Object@ hotspot_object = ReadObjectFromID(hotspot.GetID());
    quaternion limited_rotation = limit_rotation_to_yaw(hotspot_object.GetRotation());

    set_character_position_and_rotation_from_pose(preview_character_id, hotspot.GetID());

    hotspot_object.SetRotation(limited_rotation);

    update_child_position_from_parent(torso_target_id, "torso");
    update_child_position_from_parent(head_target_id, "head");
    update_child_position_from_parent(eye_target_id, "eye");
}

void ReceiveMessage(string message) {
    CustomTokenIterator iterator(message);

    string first_word;

    if (!iterator.find_next(first_word)) {
        return;
    }

    if (first_word == "level_event") {
        string event_name;

        if (!iterator.find_next(event_name)) {
            return;
        }

        if (event_name == "moved_objects") {
            Log(info, message);

            string id_as_text;

            if (!iterator.find_next(id_as_text)) {
                return;
            }

            int id = atoi(id_as_text);

            if (id == hotspot.GetID()) {
                // TODO does not always trigger, unreliable
                // hotspot_moved();
            }
        }
    }

}

string GetTypeString() {
  return HOTSPOT_DIALOGUE_POSE_TYPE;
}

void SetParameters() {
}

void HandleEvent(string event, MovementObject @mo){
}

void Update() {
}

void DrawEditor(){
}

class CustomTokenIterator {
    TokenIterator iterator;
    string text;

    CustomTokenIterator(string text) {
        iterator.Init();

        this.text = text;
    }

    bool has_next() {
        return iterator.FindNextToken(text);
    }

    bool find_next(string& target) {
        if (has_next()) {
            target = iterator.GetToken(text);
            return true;
        }

        return false;
    }
}