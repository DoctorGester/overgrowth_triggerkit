enum Event_Type {
    EVENT_CHARACTER_ENTERS_REGION,
    EVENT_LEVEL_START,
    EVENT_LAST
}

const string HOTSPOT_CAMERA_TYPE = "triggerkit_camera";
const string HOTSPOT_REGION_TYPE = "triggerkit_region";
const string HOTSPOT_DIALOGUE_POSE_TYPE = "triggerkit_dialogue_pose";

// TODO I don't really like those uppercase copies, a more sensible name would do
string event_type_to_serializeable_string(Event_Type event_type) {
    switch (event_type) {
        case EVENT_CHARACTER_ENTERS_REGION: return "EVENT_CHARACTER_ENTERS_REGION";
        case EVENT_LEVEL_START: return "EVENT_LEVEL_START";
    }

    return "undefined";
}

void set_from_param_value_or_create_param(ScriptParams@ params, string param, float& value) {
    if (params.HasParam(param)) {
        value = params.GetFloat(param);
    } else {
        params.AddFloat(param, 0.0f);
        params.SetFloat(param, value);
    }
}

void set_param_value(ScriptParams@ params, string param, float value) {
    if (params.HasParam(param)) {
        value = params.SetFloat(param, value);
    } else {
        params.AddFloat(param, 0.0f);
        params.SetFloat(param, value);
    }
}

float get_param_value_or_zero(ScriptParams@ params, string param) {
    if (params.HasParam(param)) {
        return params.GetFloat(param);
    }

    return 0.0f;
}

void set_or_add_string_param(ScriptParams@ script_params, string param_name, string param_value) {
    if (script_params.HasParam(param_name)) {
        script_params.SetString(param_name, param_value);
    } else {
        script_params.AddString(param_name, param_value);
    }
}

string get_string_param_or_default(ScriptParams@ script_params, string param_name, string default_value = "") {
    if (script_params.HasParam(param_name)) {
        return script_params.GetString(param_name);
    }

    return default_value;
}

// I'm not that smart, taken from
// https://stackoverflow.com/questions/5782658/extracting-yaw-from-a-quaternion
quaternion limit_rotation_to_yaw(quaternion& q) {
    q.x = 0;
    q.z = 0;

    float magnitude = sqrt(q.w * q.w + q.y * q.y);

    q.w /= magnitude;
    q.y /= magnitude;

    return q;
}

void set_character_position_and_rotation_from_pose(int character_id, int pose_id) {
    Object@ hotspot_object = ReadObjectFromID(pose_id);
    quaternion rotation = limit_rotation_to_yaw(hotspot_object.GetRotation());

    float sign = rotation.y >= 0.0 ? 1.0 : -1.0;
    float yaw = 2 * acos(rotation.w) * sign;

    const float deg_to_rad = (180.0f / 3.1415f);

    //ReadObjectFromID(character_id).SetTranslationRotationFast(hotspot_object.GetTranslation(), hotspot_object.GetRotation());
    
    MovementObject@ character = ReadCharacterID(character_id);
    vec3 position = hotspot_object.GetTranslation() - vec3(0, 0.5, 0);
    character.ReceiveScriptMessage("set_dialogue_position " + position.x + " " + position.y + " " + position.z);
    character.ReceiveScriptMessage("set_rotation " + (yaw * deg_to_rad));
    character.FixDiscontinuity();
}
