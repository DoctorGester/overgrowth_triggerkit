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
}