enum Event_Type {
    EVENT_CHARACTER_ENTERS_REGION,
    EVENT_LAST
}

const string HOTSPOT_CAMERA_TYPE = "triggerkit_camera";

string event_type_to_serializeable_string(Event_Type event_type) {
    switch (event_type) {
        case EVENT_CHARACTER_ENTERS_REGION: return "EVENT_CHARACTER_ENTERS_REGION";
    }

    return "undefined";
}