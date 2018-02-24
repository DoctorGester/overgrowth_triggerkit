#include "triggerkit/shared_definitions.as"

void SetParameters() {
}

void Init() {
}

void Dispose() {
}

void HandleEvent(string event, MovementObject @mo){
    if(event == "enter"){
        level.SendMessage(event_type_to_serializeable_string(EVENT_CHARACTER_ENTERS_REGION) + " " + mo.GetID() + " " + hotspot.GetID());
    } else if(event == "exit"){
    }
}

void Update() {
}

string GetTypeString() {
  return HOTSPOT_CAMERA_TYPE;
}

void DrawEditor(){
    Object@ hotspot_as_object = ReadObjectFromID(hotspot.GetID());

    mat4 pos_matrix;
    pos_matrix.SetTranslationPart(hotspot_as_object.GetTranslation());

    // Scale
    pos_matrix[0] = 3;
    pos_matrix[5] = 3;
    pos_matrix[10] = 3;

    mat4 rot_matrix = Mat4FromQuaternion(hotspot_as_object.GetRotation());

    vec4 color = hotspot_as_object.IsSelected() ? vec4(0.2, 0.95, 0.0, 1.0) : vec4(1);

    DebugDrawWireMesh("Data/Models/camera.obj", pos_matrix * rot_matrix, color, _delete_on_draw);
}