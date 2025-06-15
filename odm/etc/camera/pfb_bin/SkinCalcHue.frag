#version 320 es

precision highp float;
uniform sampler2D ori_img;
uniform sampler2D AI_mask;
uniform sampler2D face_mask;

in vec2 v_texCoord;
out vec3 FragColor; // store [Hue, Lux, R/B]

highp vec3 YUV2RGB(vec3 yuv) {
    highp vec3 rgb;
    rgb.r = yuv.r + 1.370705 * (yuv.b - 0.5);
    rgb.g = yuv.r - 0.698001*(yuv.b - 0.5) - 0.337633*(yuv.g - 0.5);
    rgb.b = yuv.r + 1.732446*(yuv.g - 0.5);
    return rgb;
}

highp vec3 calcHLBR(vec3 rgb) {
    highp float hue = 0.0;
    float R = rgb.r;
    float G = rgb.g;
    float B = rgb.b;
    float max_color = max(R, max(G, B));
    float min_color = min(R, min(G, B));
    max_color = clamp(max_color, 0.0, 1.0);
    min_color = clamp(min_color, 0.0, 1.0);
    float range = max_color - min_color;
    if (max_color != min_color) {
        if (R >= G && R >= B) {
            hue = (G - B) / (range + 0.00001) * 60.0f;
        } else if (G >= R && G >= B) {
            hue = 120.0 + (B - R) / (range + 0.00001) * 60.0f;
        } else {
            hue = 240.0 + (R - G) / (range + 0.00001) * 60.0f;
        }
        if (hue < 0.0) {
            hue = hue + 360.0f;
        }
    }
    hue = hue / 360.0;
    float Lux = max_color;//0.298822 * R + 0.586815 * G + 0.114363 * B;
    float B_R = B / R;

    return vec3(hue, Lux, B_R);
}

void main(void) {
    vec3 center_color = texture(ori_img, v_texCoord).rgb;
    float face_skin = 1.0;//texture(face_mask, v_texCoord).b;
    float ai_mask = texture(AI_mask, v_texCoord).r;
    float face_skin_roi = step(1.99, ai_mask * 255.0) * step(ai_mask * 255.0, 2.01) * step(0.1, face_skin);
    highp vec3 rgb = center_color;//YUV2RGB(center_color);
    if (face_skin_roi > 0.0) {
        highp vec3 HLBR = calcHLBR(rgb);
        FragColor = HLBR;
    } else {
        float Lux = 0.298822 * rgb.r + 0.586815 * rgb.g + 0.114363 * rgb.b;
        FragColor = vec3(0.0, Lux, 0.0);
    }
}
