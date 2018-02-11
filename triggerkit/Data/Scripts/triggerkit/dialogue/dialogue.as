namespace dialogue {
    const float kTextLeftMargin = 100;
    const float kTextRightMargin = 100;

    bool is_waiting_for_a_line_to_end = false;
    bool is_waiting_for_a_line_to_get_fully_drawn = true;
    bool is_ready_to_fully_skip = false;
    bool has_cam_control = true;

    float line_start_time = 0.0f;
    float line_progress = 0.0f;
    float speak_sound_time = 0.0f;
    float start_time = 0.0f;
    float voice_preview_time = -100;

    string font_path = "Data/Fonts/Lato-Regular.ttf";
    string name_font_path = "Data/Fonts/edosz.ttf";

    string current_dialogue_name = "";
    string current_dialogue_line = "";

    void dialogue_continue() {
        is_waiting_for_a_line_to_end = false;
    }

    void reset_ui() {
        is_ready_to_fully_skip = false;
        is_waiting_for_a_line_to_end = false;
        current_dialogue_name = "";
        current_dialogue_line = "";
        line_progress = 0.0f;
        start_time = the_time;
    }

    void say(string who, string what) {
        current_dialogue_name = who;
        current_dialogue_line = what;
        is_waiting_for_a_line_to_end = true;

        line_start_time = the_time;
        line_progress = 0.0f;

        is_waiting_for_a_line_to_get_fully_drawn = true;
    }

    int get_font_size() {
        return int(max(18, min(GetScreenHeight() / 30, GetScreenWidth() / 50)));
    }

    int get_active_voice() {
        return 0;
    }

    void play_line_continue_sound() {
        switch(get_active_voice()){
            case 0: PlaySoundGroup("Data/Sounds/concrete_foley/fs_light_concrete_edgecrawl.xml"); break;
            case 1: PlaySoundGroup("Data/Sounds/drygrass_foley/fs_light_drygrass_crouchwalk.xml"); break;
            case 2: PlaySoundGroup("Data/Sounds/cloth_foley/cloth_fabric_crouchwalk.xml"); break;
            case 3: PlaySoundGroup("Data/Sounds/dirtyrock_foley/fs_light_dirtyrock_crouchwalk.xml"); break;
            case 4: PlaySoundGroup("Data/Sounds/cloth_foley/cloth_leather_crouchwalk.xml"); break;
            case 5: PlaySoundGroup("Data/Sounds/grass_foley/fs_light_grass_run.xml", 0.5); break;
            case 6: PlaySoundGroup("Data/Sounds/gravel_foley/fs_light_gravel_crouchwalk.xml"); break;
            case 7: PlaySoundGroup("Data/Sounds/sand_foley/fs_light_sand_crouchwalk.xml", 0.7); break;
            case 8: PlaySoundGroup("Data/Sounds/snow_foley/fs_light_snow_run.xml", 0.5); break;
            case 9: PlaySoundGroup("Data/Sounds/wood_foley/fs_light_wood_crouchwalk.xml", 0.4); break;
            case 10: PlaySoundGroup("Data/Sounds/water_foley/mud_fs_walk.xml", 0.4); break;
            case 11: PlaySoundGroup("Data/Sounds/concrete_foley/fs_heavy_concrete_walk.xml", 0.5); break;
            case 12: PlaySoundGroup("Data/Sounds/drygrass_foley/fs_heavy_drygrass_walk.xml", 0.4); break;
            case 13: PlaySoundGroup("Data/Sounds/dirtyrock_foley/fs_heavy_dirtyrock_walk.xml", 0.5); break;
            case 14: PlaySoundGroup("Data/Sounds/grass_foley/fs_heavy_grass_walk.xml", 0.3); break;
            case 15: PlaySoundGroup("Data/Sounds/gravel_foley/fs_heavy_gravel_walk.xml", 0.3); break;
            case 16: PlaySoundGroup("Data/Sounds/sand_foley/fs_heavy_sand_run.xml", 0.3); break;
            case 17: PlaySoundGroup("Data/Sounds/snow_foley/fs_heavy_snow_crouchwalk.xml", 0.3); break;
            case 18: PlaySoundGroup("Data/Sounds/wood_foley/fs_heavy_wood_walk.xml", 0.3); break;
        }
    }

    void play_line_start_sound() {
        switch (get_active_voice()){
            case 0: PlaySoundGroup("Data/Sounds/concrete_foley/fs_light_concrete_run.xml"); break;
            case 1: PlaySoundGroup("Data/Sounds/drygrass_foley/fs_light_drygrass_walk.xml"); break;
            case 2: PlaySoundGroup("Data/Sounds/cloth_foley/cloth_fabric_choke_move.xml"); break;
            case 3: PlaySoundGroup("Data/Sounds/dirtyrock_foley/fs_light_dirtyrock_run.xml"); break;
            case 4: PlaySoundGroup("Data/Sounds/cloth_foley/cloth_leather_choke_move.xml"); break;
            case 5: PlaySoundGroup("Data/Sounds/grass_foley/bf_grass_medium.xml", 0.5); break;
            case 6: PlaySoundGroup("Data/Sounds/gravel_foley/fs_light_gravel_run.xml"); break;
            case 7: PlaySoundGroup("Data/Sounds/sand_foley/fs_light_sand_run.xml", 0.7); break;
            case 8: PlaySoundGroup("Data/Sounds/snow_foley/bf_snow_light.xml", 0.5); break;
            case 9: PlaySoundGroup("Data/Sounds/wood_foley/fs_light_wood_run.xml", 0.4); break;
            case 10: PlaySoundGroup("Data/Sounds/water_foley/mud_fs_run.xml", 0.4); break;
            case 11: PlaySoundGroup("Data/Sounds/concrete_foley/fs_heavy_concrete_run.xml", 0.5); break;
            case 12: PlaySoundGroup("Data/Sounds/drygrass_foley/fs_heavy_drygrass_run.xml", 0.4); break;
            case 13: PlaySoundGroup("Data/Sounds/dirtyrock_foley/fs_heavy_dirtyrock_run.xml", 0.5); break;
            case 14: PlaySoundGroup("Data/Sounds/grass_foley/fs_heavy_grass_run.xml", 0.3); break;
            case 15: PlaySoundGroup("Data/Sounds/gravel_foley/fs_heavy_gravel_run.xml", 0.3); break;
            case 16: PlaySoundGroup("Data/Sounds/sand_foley/fs_heavy_sand_jump.xml", 0.3); break;
            case 17: PlaySoundGroup("Data/Sounds/snow_foley/fs_heavy_snow_jump.xml", 0.3); break;
            case 18: PlaySoundGroup("Data/Sounds/wood_foley/fs_heavy_wood_run.xml", 0.3); break;
        }
    }

    void draw_ui() {
        int font_size = get_font_size();
        float height_scale = 1.0/75.0;
        vec3 color = vec3(1.0);
        float vert_size = (font_size * 6.8) / 512.0;
        {
            HUDImage @blackout_image = hud.AddImage();
            blackout_image.SetImageFromPath("Data/Textures/ui/dialogue/dialogue_bg.png");
            blackout_image.position.y = GetScreenHeight() * 0.25 - font_size * height_scale * 510.0;
            blackout_image.position.x = GetScreenWidth()*0.2;
            blackout_image.position.z = -2.0f;
            blackout_image.scale = vec3(GetScreenWidth()/32.0f*0.6, vert_size, 1.0f);
            blackout_image.color = vec4(color,0.7f);
        }

        {
            HUDImage @blackout_image = hud.AddImage();
            blackout_image.SetImageFromPath("Data/Textures/ui/dialogue/dialogue_bg-fade.png");
            blackout_image.position.y = GetScreenHeight() * 0.25 - font_size * height_scale * 510.0;
            blackout_image.position.z = -2.0f;
            float width_scale = GetScreenWidth()/2500.0;
            blackout_image.position.x = GetScreenWidth()*0.2-512*width_scale;
            blackout_image.scale = vec3(width_scale, vert_size, 1.0f);
            blackout_image.color = vec4(color,0.7f);
        }

        {
            HUDImage @blackout_image = hud.AddImage();
            blackout_image.SetImageFromPath("Data/Textures/ui/dialogue/dialogue_bg-fade_reverse.png");
            blackout_image.position.y = GetScreenHeight() * 0.25 - font_size * height_scale * 510.0;
            blackout_image.position.z = -2.0f;
            float width_scale = GetScreenWidth()/2500.0;
            blackout_image.position.x = GetScreenWidth()*0.8;
            blackout_image.scale = vec3(width_scale, vert_size, 1.0f);
            blackout_image.color = vec4(color,0.7f);
        }

        {
            HUDImage @name_background = hud.AddImage();
            TextMetrics metrics = GetTextAtlasMetrics(name_font_path, int(get_font_size()*1.8), kSmallLowercase, current_dialogue_name);

            name_background.SetImageFromPath("Data/Textures/ui/menus/main/brushStroke.png");
            name_background.position.y = GetScreenHeight() * 0.25 - font_size * 1.5;
            name_background.position.x = kTextLeftMargin - font_size * 2;
            name_background.position.z = -2.0f;
            name_background.scale = vec3((metrics.bounds_x+font_size*4)/768.0, font_size/40.0, 1.0f);
            name_background.color = vec4(vec3(0.15),1.0f);
        }
    }

    void draw_text() {
        int font_size = get_font_size();
        float height_scale = 1.0/75.0;

        vec3 color = vec3(1.0);

        bool use_keyboard = (max(last_mouse_event_time, last_keyboard_event_time) > last_controller_event_time);
        string continue_string = (use_keyboard?"left mouse button":GetStringDescriptionForBinding("xbox", "attack"))+" to continue"+
                    "\n"+GetStringDescriptionForBinding(use_keyboard?"key":"xbox", "skip_dialogue")+" to skip";

        vec2 pos(kTextLeftMargin, GetScreenHeight() *0.75 + font_size * 1.2);
        DrawTextAtlas(name_font_path, int(font_size*1.8), kSmallLowercase, current_dialogue_name, 
                      int(pos.x), int(pos.y)-int(font_size*0.8), vec4(color, 1.0f));
        //string display_text = dialogue_text.substr(0, int(line_progress));
        DrawTextAtlas2(font_path, font_size, 0, current_dialogue_line, 
                      int(pos.x)+font_size, int(pos.y)+font_size, vec4(vec3(1.0f), 1.0f), int(line_progress));
        TextMetrics test_metrics = GetTextAtlasMetrics2(font_path, get_font_size(), 0, current_dialogue_line, int(line_progress));
        if(!is_waiting_for_a_line_to_get_fully_drawn && test_metrics.bounds_y < get_font_size() * 3){
            TextMetrics metrics = GetTextAtlasMetrics(font_path, get_font_size(), 0, continue_string);
            DrawTextAtlas(font_path, font_size, 0, continue_string, 
                           GetScreenWidth() - int(kTextRightMargin) - metrics.bounds_x, int(pos.y)+font_size*4, vec4(vec3(1.0f), 0.5f));
        }
    }

    void update() {
        uint total_characters_in_a_line = current_dialogue_line.length();

        if(level.WaitingForInput()){
            line_progress = 0.0f;
            speak_sound_time = the_time + 0.1f;
            line_start_time = 0.0f;
            is_ready_to_fully_skip = false; 
        } else if(the_time - start_time > 0.1f && !GetInputDown(controller_id, "skip_dialogue") && !GetInputDown(controller_id, "keypadenter")){
            is_ready_to_fully_skip = true;
        }

        if(is_waiting_for_a_line_to_get_fully_drawn){
            float step = time_step * 40.0f / GetConfigValueFloat("global_time_scale_mult");

            line_progress += step;
            if(GetInputDown(controller_id, "attack")){
                line_progress += step;                
            }
            // Continue dialogue script if we have displayed all the text that we are waiting for
            if(uint32(line_progress) >= total_characters_in_a_line){
                is_waiting_for_a_line_to_get_fully_drawn = false;
               // Play();   
               //dialogue_play();
            }
            if(speak_sound_time < the_time && has_cam_control){
                play_line_continue_sound();
                speak_sound_time = the_time + 0.1 * GetConfigValueFloat("global_time_scale_mult");
            }
        }

        if (voice_preview_time > the_time && speak_sound_time < the_time){
            play_line_continue_sound();
            speak_sound_time = the_time + 0.1;
        }

        if(GetInputPressed(controller_id, "attack") && start_time != the_time){
            if (is_waiting_for_a_line_to_get_fully_drawn){
                line_progress = total_characters_in_a_line;
                is_waiting_for_a_line_to_get_fully_drawn = false;
            } else if (line_start_time < the_time - 0.5){
                dialogue_continue(); 
            } else {
                line_start_time = -1.0;
            }

            play_line_start_sound();
        }
    }
}