enum Event_Type {
    EVENT_CHARACTER_ENTERS_REGION,
    EVENT_LEVEL_START,
    EVENT_LAST
}

const string HOTSPOT_CAMERA_TYPE = "triggerkit_camera";
const string HOTSPOT_REGION_TYPE = "triggerkit_region";

string event_type_to_serializeable_string(Event_Type event_type) {
    switch (event_type) {
        case EVENT_CHARACTER_ENTERS_REGION: return "EVENT_CHARACTER_ENTERS_REGION";
        case EVENT_LEVEL_START: return "EVENT_LEVEL_START";
    }

    return "undefined";
}