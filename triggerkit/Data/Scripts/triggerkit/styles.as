class UIStyle {
    int hue = 140;
    float mainSat = 180.0f;
    float mainVal = 161.0f;
    float areaSat = 124.0f;
    float areaVal = 100.0f;
    float backSat = 49.0f;
    float backVal = 50.0f;
}

void PushStyles() {
    const int hue = style.hue;
    const float col_main_sat = style.mainSat/255.0f;
    const float col_main_val = style.mainVal/255.0f;
    const float col_area_sat = style.areaSat/255.0f;
    const float col_area_val = style.areaVal/255.0f;
    const float col_back_sat = style.backSat/255.0f;
    const float col_back_val = style.backVal/255.0f;

    vec4 col_text = HSV(hue/255.f,  20.f/255.f, 235.f/255.f);
    vec4 col_main = HSV(hue/255.f, col_main_sat, col_main_val);
    vec4 col_back = HSV(hue/255.f, col_back_sat, col_back_val);
    vec4 col_area = HSV(hue/255.f, col_area_sat, col_area_val);

    ImGui_PushStyleColor(ImGuiCol_Text, vec4(col_text.x, col_text.y, col_text.z, 1.00f));
    ImGui_PushStyleColor(ImGuiCol_TextDisabled, vec4(col_text.x, col_text.y, col_text.z, 0.58f));
    ImGui_PushStyleColor(ImGuiCol_WindowBg, vec4(col_back.x, col_back.y, col_back.z, 1.00f));
    ImGui_PushStyleColor(ImGuiCol_ChildWindowBg, vec4(col_area.x, col_area.y, col_area.z, 0.00f));
    ImGui_PushStyleColor(ImGuiCol_Border, vec4(col_text.x, col_text.y, col_text.z, 0.30f));
    ImGui_PushStyleColor(ImGuiCol_BorderShadow, vec4(0.00f, 0.00f, 0.00f, 0.00f));
    ImGui_PushStyleColor(ImGuiCol_FrameBg, vec4(col_area.x, col_area.y, col_area.z, 1.00f));
    ImGui_PushStyleColor(ImGuiCol_FrameBgHovered, vec4(col_main.x, col_main.y, col_main.z, 0.68f));
    ImGui_PushStyleColor(ImGuiCol_FrameBgActive, vec4(col_main.x, col_main.y, col_main.z, 1.00f));
    ImGui_PushStyleColor(ImGuiCol_TitleBg, vec4(col_main.x, col_main.y, col_main.z, 0.45f));
    ImGui_PushStyleColor(ImGuiCol_TitleBgCollapsed, vec4(col_main.x, col_main.y, col_main.z, 0.35f));
    ImGui_PushStyleColor(ImGuiCol_TitleBgActive, vec4(col_main.x, col_main.y, col_main.z, 0.78f));
    ImGui_PushStyleColor(ImGuiCol_MenuBarBg, vec4(col_area.x, col_area.y, col_area.z, 0.57f));
    ImGui_PushStyleColor(ImGuiCol_ScrollbarBg, vec4(col_area.x, col_area.y, col_area.z, 1.00f));
    ImGui_PushStyleColor(ImGuiCol_ScrollbarGrab, vec4(col_main.x, col_main.y, col_main.z, 0.31f));
    ImGui_PushStyleColor(ImGuiCol_ScrollbarGrabHovered, vec4(col_main.x, col_main.y, col_main.z, 0.78f));
    ImGui_PushStyleColor(ImGuiCol_ScrollbarGrabActive, vec4(col_main.x, col_main.y, col_main.z, 1.00f));
    ImGui_PushStyleColor(ImGuiCol_ComboBg, vec4(col_area.x, col_area.y, col_area.z, 1.00f));
    ImGui_PushStyleColor(ImGuiCol_CheckMark, vec4(col_main.x, col_main.y, col_main.z, 0.80f));
    ImGui_PushStyleColor(ImGuiCol_SliderGrab, vec4(col_main.x, col_main.y, col_main.z, 0.24f));
    ImGui_PushStyleColor(ImGuiCol_SliderGrabActive, vec4(col_main.x, col_main.y, col_main.z, 1.00f));
    ImGui_PushStyleColor(ImGuiCol_Button, vec4(col_main.x, col_main.y, col_main.z, 0.44f));
    ImGui_PushStyleColor(ImGuiCol_ButtonHovered, vec4(col_main.x, col_main.y, col_main.z, 0.86f));
    ImGui_PushStyleColor(ImGuiCol_ButtonActive, vec4(col_main.x, col_main.y, col_main.z, 1.00f));
    ImGui_PushStyleColor(ImGuiCol_Header, vec4(col_main.x, col_main.y, col_main.z, 0.76f));
    ImGui_PushStyleColor(ImGuiCol_HeaderHovered, vec4(col_main.x, col_main.y, col_main.z, 0.86f));
    ImGui_PushStyleColor(ImGuiCol_HeaderActive, vec4(col_main.x, col_main.y, col_main.z, 1.00f));
    ImGui_PushStyleColor(ImGuiCol_Column, vec4(col_text.x, col_text.y, col_text.z, 0.32f));
    ImGui_PushStyleColor(ImGuiCol_ColumnHovered, vec4(col_text.x, col_text.y, col_text.z, 0.78f));
    ImGui_PushStyleColor(ImGuiCol_ColumnActive, vec4(col_text.x, col_text.y, col_text.z, 1.00f));
    ImGui_PushStyleColor(ImGuiCol_ResizeGrip, vec4(col_main.x, col_main.y, col_main.z, 0.20f));
    ImGui_PushStyleColor(ImGuiCol_ResizeGripHovered, vec4(col_main.x, col_main.y, col_main.z, 0.78f));
    ImGui_PushStyleColor(ImGuiCol_ResizeGripActive, vec4(col_main.x, col_main.y, col_main.z, 1.00f));
    ImGui_PushStyleColor(ImGuiCol_CloseButton, vec4(col_text.x, col_text.y, col_text.z, 0.16f));
    ImGui_PushStyleColor(ImGuiCol_CloseButtonHovered, vec4(col_text.x, col_text.y, col_text.z, 0.39f));
    ImGui_PushStyleColor(ImGuiCol_CloseButtonActive, vec4(col_text.x, col_text.y, col_text.z, 1.00f));
    ImGui_PushStyleColor(ImGuiCol_PlotLines, vec4(col_text.x, col_text.y, col_text.z, 0.63f));
    ImGui_PushStyleColor(ImGuiCol_PlotLinesHovered, vec4(col_main.x, col_main.y, col_main.z, 1.00f));
    ImGui_PushStyleColor(ImGuiCol_PlotHistogram, vec4(col_text.x, col_text.y, col_text.z, 0.63f));
    ImGui_PushStyleColor(ImGuiCol_PlotHistogramHovered, vec4(col_main.x, col_main.y, col_main.z, 1.00f));
    ImGui_PushStyleColor(ImGuiCol_TextSelectedBg, vec4(col_main.x, col_main.y, col_main.z, 0.43f));
    ImGui_PushStyleColor(ImGuiCol_ModalWindowDarkening, vec4(0.20f, 0.20f, 0.20f, 0.35f));
}

void PopStyles() {
    ImGui_PopStyleColor(42);
}

vec4 HSV(float h, float s, float v, float a = 1.0f) {
    float r,g,b;
    ImGui_ColorConvertHSVtoRGB(h, s, v, r, g, b);
    return vec4(r,g,b,a);
}