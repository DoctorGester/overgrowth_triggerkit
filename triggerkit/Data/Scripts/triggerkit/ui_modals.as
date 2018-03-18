void draw_globals_modal() {
    if (icon_button("New variable", "variable_add", icons::action_variable)) {
        state.global_variables.insertLast(make_variable(LITERAL_TYPE_NUMBER, "New variable"));
    }

    float window_width = ImGui_GetWindowWidth();

    ImGui_ListBoxHeader("###global_list", size: vec2(-1, -1));

    float right_padding = 100;
    float free_width = window_width - right_padding;

    for (uint variable_index = 0; variable_index < state.global_variables.length(); variable_index++) {
        Variable@ variable = state.global_variables[variable_index];

        ImGui_AlignFirstTextHeightToWidgets();
        ImGui_Image(icons::action_variable, vec2(16, 16));
        ImGui_SameLine();

        ImGui_PushItemWidth(int(free_width * 0.3));

        ImGui_SetTextBuf(variable.name);
        if (ImGui_InputText("###variable_name" + variable_index)) {
            variable.name = ImGui_GetTextBuf();
        }

        ImGui_PopItemWidth();
        ImGui_SameLine();

        {
            ImGui_PushItemWidth(int(free_width * 0.2));
            
            draw_type_selector(variable.type, "###type_selector" + variable_index);

            ImGui_PopItemWidth();
            ImGui_SameLine();
        }

        {
            float cursor_pre_checkbox = ImGui_GetCursorPosX();

            bool a = false;
            ImGui_Checkbox("Is array", a);
            ImGui_SameLine();

            ImGui_SetCursorPosX(cursor_pre_checkbox + free_width * 0.15f);
        }

        {
            ImGui_PushItemWidth(int(free_width * 0.35));
            draw_editable_literal(variable.type, variable.value, "###" + variable_index);
            ImGui_PopItemWidth();
        }

        ImGui_SameLine();
        ImGui_SetCursorPosX(window_width - 40);
        
        if (ImGui_Button("X###" + variable_index)) {
            state.global_variables.removeAt(variable_index);

            if (variable_index > 0) {
                variable_index--;
            }
        }
    }

    ImGui_ListBoxFooter();
}

void set_camera_to_view(Object@ camera_hotspot) {
    camera_hotspot.SetTranslation(camera.GetPos());

    float deg_to_rad = 3.14f / 180.0f;

    mat4 rotation_matrix_x;
    rotation_matrix_x.SetRotationX(camera.GetXRotation() * deg_to_rad);

    mat4 rotation_matrix_y;
    rotation_matrix_y.SetRotationY(camera.GetYRotation() * deg_to_rad);

    quaternion rotation = QuaternionFromMat4(rotation_matrix_y * rotation_matrix_x);

    camera_hotspot.SetRotation(rotation);
}

array<Object@> draw_objects_list_and_return_selected(array<Object@>@ content, Name_Resolver@ name_resolver, TextureAssetRef icon) {
    array<Object@> selected;

    for (uint object_index = 0; object_index < content.length(); object_index++) {
        Object@ object = content[object_index];

        ImGui_SetCursorPosY(ImGui_GetCursorPosY() - 2);
        ImGui_Image(icon, vec2(16, 16));
        ImGui_SameLine();
        ImGui_SetCursorPosY(ImGui_GetCursorPosY() + 2);

        bool is_selected = object.IsSelected();

        if (ImGui_Selectable(name_resolver(object.GetID()), is_selected)) {
            object.SetSelected(!is_selected);
        }

        if (is_selected) {
            selected.insertLast(object);
        }
    }

    return selected;
}

void draw_cameras_window() {
    ImGui_ListBoxHeader("###cameras_list", size: vec2(-1, ImGui_GetWindowHeight() - 160)); // -60 = 1 button exactly

    array<Object@>@ selected_cameras = draw_objects_list_and_return_selected(list_camera_objects(), camera_id_to_camera_name, icons::action_camera);

    ImGui_ListBoxFooter();

    if (icon_button("New camera", "camera_add", icons::action_camera)) {
        int camera_id = CreateObject("Data/Objects/triggerkit/triggerkit_camera.xml", false);

        if (camera_id == -1) {
            Log(error, "Fatal error: was not able to create a camera object");
            return;
        }

        Object@ camera_as_object = ReadObjectFromID(camera_id);
        camera_as_object.SetName("New camera");
        camera_as_object.SetSelectable(true);
        camera_as_object.SetSelected(true);
        camera_as_object.SetCopyable(true);
        camera_as_object.SetDeletable(true);
        camera_as_object.SetScalable(true);
        camera_as_object.SetTranslatable(true);
        camera_as_object.SetRotatable(true);

        set_camera_to_view(camera_as_object);
    }

    bool selected_single_object = selected_cameras.length() == 1;

    if (selected_single_object) {
        Object@ selected_hotspot_as_object = selected_cameras[0];

        if (icon_button("Selected camera to view", "set_camera_to_view", icons::action_camera)) {
            set_camera_to_view(selected_hotspot_as_object);
        }

        if (icon_button("View to selected camera", "set_view_to_camera", icons::action_camera)) {
            // TODO doesn't work!
            const int entity_type_camera = 2;

            array<int>@ object_ids = GetObjectIDsType(entity_type_camera);

            for (uint id_index = 0; id_index < object_ids.length(); id_index++) {
                Object@ camera_object = ReadObjectFromID(object_ids[id_index]);

                // camera_object.SetTranslation(selected_hotspot_as_object.GetTranslation());
            }
            
            // camera.SetPos(selected_hotspot_as_object.GetTranslation());
        }

        if (icon_button("Delete selected camera", "delete_camera", icons::action_camera)) {
            QueueDeleteObjectID(selected_hotspot_as_object.GetID());
        }
    }
}

class Named_Animation {
    string name;
    string path;

    Named_Animation(string name, string path) {
        this.name = name;
        this.path = path;
    }

    string to_full_path() {
        return "Data/Animations/" + path + ".anm";
    }
}

void draw_poses_window() {
    ImGui_ListBoxHeader("###poses_list", size: vec2(-1, ImGui_GetWindowHeight() - 160)); // -60 = 1 button exactly

    array<Object@>@ selected_poses = draw_objects_list_and_return_selected(list_pose_objects(), pose_id_to_pose_name, icons::action_pose);

    ImGui_ListBoxFooter();

    bool selected_single_object = selected_poses.length() == 1;

    const array<Named_Animation@> default_animations = {
        Named_Animation("Idle", "r_actionidle"),
        Named_Animation("Hands on neck", "r_dialogue_2handneck"),
        Named_Animation("Arm check", "r_dialogue_armcheck"),
        Named_Animation("Arm cross", "r_dialogue_armcross"),
        Named_Animation("Facepalm", "r_dialogue_facepalm"),
        Named_Animation("Hands on hips", "r_dialogue_handhips"),
        Named_Animation("Hand on neck", "r_dialogue_handneck"),
        Named_Animation("Jeer", "r_dialogue_jeer"),
        Named_Animation("Kneel fist", "r_dialogue_kneelfist"),
        Named_Animation("Kneeling low", "r_dialogue_kneeling_low"),
        Named_Animation("Point", "r_dialogue_point"),
        Named_Animation("Pole", "r_dialogue_pole"),
        Named_Animation("Shade", "r_dialogue_shade"),
        Named_Animation("Shocked back", "r_dialogue_shockedback"),
        Named_Animation("Stand from front", "r_dialogue_standfromfront"),
        Named_Animation("Thoughtful", "r_dialogue_thoughtful"),
        Named_Animation("Welcome", "r_dialogue_welcome"),
        Named_Animation("Worried 1", "r_dialogue_worriedpose_1"),
        Named_Animation("Worried 2", "r_dialogue_worriedpose_2")
    };

    ImGui_Text("Selected:");
    ImGui_SameLine();

    if (selected_single_object) {
        Object@ selected = selected_poses[0];
        string name = pose_id_to_pose_name(selected.GetID());

        ImGui_Text(name);
        ImGui_SetTextBuf(name);

        if (ImGui_InputText("Name")) {
            selected.SetName(ImGui_GetTextBuf());
        } 

        ScriptParams@ script_params = selected.GetScriptParams();

        string preview_text;
        int selected_index = -1;

        for (uint animation_index = 0; animation_index < default_animations.length(); animation_index++) {
            Named_Animation@ animation = default_animations[animation_index];

            if (get_string_param_or_default(script_params, "Animation") == animation.to_full_path()) {
                preview_text = animation.name;
                selected_index = animation_index;
                break;
            }
        }

        const int ImGuiComboFlags_NoArrowButton = 1 << 5;
        float w = ImGui_GetWindowWidth() - 86;//ImGui_CalcItemWidth();
        float spacing = 4;//style.ItemInnerSpacing.x;
        float button_sz = 28;//ImGui_GetFrameHeight();
        ImGui_PushItemWidth(int(w - spacing * 2.0f - button_sz * 2.0f));

        if (ImGui_BeginCombo("##animation_combo", preview_text, ImGuiComboFlags_NoArrowButton)) {
            for (uint animation_index = 0; animation_index < default_animations.length(); animation_index++) {
                Named_Animation@ animation = default_animations[animation_index];
                string full_animation_path = animation.to_full_path();

                if (ImGui_Selectable(animation.name, full_animation_path == get_string_param_or_default(script_params, "Animation"))) {
                    set_or_add_string_param(script_params, "Animation", full_animation_path);
                }
            }

            ImGui_EndCombo();
        }

        ImGui_PopItemWidth();
        ImGui_SameLine(0, spacing);

        if (ImGui_Button("<") && selected_index > 0) {
            set_or_add_string_param(script_params, "Animation", default_animations[uint(--selected_index)].to_full_path());
        }

        ImGui_SameLine(0, spacing);

        if (ImGui_Button(">") && selected_index < int(default_animations.length()) - 1) {
            set_or_add_string_param(script_params, "Animation", default_animations[uint(++selected_index)].to_full_path());
        }

        ImGui_SameLine(0, spacing);
        ImGui_Text("Animation");
    } else {
        ImGui_Text(selected_poses.length() == 0 ? "None" : selected_poses.length() + " poses");
    }

    if (icon_button("New pose", "pose_add", icons::action_pose)) {
        int pose_id = CreateObject("Data/Objects/triggerkit/triggerkit_dialogue_pose.xml", false);

        if (pose_id == -1) {
            Log(error, "Fatal error: was not able to create a pose object");
            return;
        }

        Object@ pose_as_object = ReadObjectFromID(pose_id);
        pose_as_object.SetName("New pose");
        pose_as_object.SetSelectable(true);
        pose_as_object.SetSelected(true);
        pose_as_object.SetCopyable(true);
        pose_as_object.SetDeletable(true);
        pose_as_object.SetTranslatable(true);
        pose_as_object.SetRotatable(true);
    }
}

void draw_regions_window() {
    
}