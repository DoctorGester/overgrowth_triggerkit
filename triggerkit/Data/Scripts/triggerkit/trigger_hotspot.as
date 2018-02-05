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

void DrawEditor(){
    Object@ obj = ReadObjectFromID(hotspot.GetID());
    DebugDrawBillboard("Data/UI/spawner/thumbs/Hotspot/checkpoint_icon.png",
                       obj.GetTranslation(),
                       obj.GetScale()[1]*2.0,
                       vec4(vec3(0.5), 1.0),
                       _delete_on_draw);
}