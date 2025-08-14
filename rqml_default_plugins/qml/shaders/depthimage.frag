#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float width;
    float height;
    int flags; // 0x01 = Invert, 0x02 = Turbo colormap

    float xMin;
    float xMax;
    float yMin;
    float yMax;
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D colormap;

void main() {
    if (qt_TexCoord0.x < xMin || qt_TexCoord0.x > xMax ||
        qt_TexCoord0.y < yMin || qt_TexCoord0.y > yMax) {
        fragColor = vec4(0.0); // Transparent
        return;
    }
    vec4 color = texture(source, qt_TexCoord0);

    bool colorize = (flags & 0x02) == 0x02;

    if (color.r == 0) {
      // 0 = NaN
      float aspect = height > 0 ? width / height : 1;
      float scale = 30.0;
      float checker = mod(floor(qt_TexCoord0.x * scale * aspect) + floor(qt_TexCoord0.y * scale), 2.0);
      // Use gray checker board if colorized, pink otherwise
      vec3 color1 = colorize ? vec3(0.3) : vec3(0.9, 0.5, 0.7);
      vec3 color2 = colorize ? vec3(0.6) : vec3(1.0, 0.8, 0.9);
      fragColor = vec4(mix(color1, color2, checker), 1.0);
      return;
    }
    // Use the red channel for grayscale intensity
    float gray = color.r;

    if ((flags & 0x01) == 0x01) {
      gray = 1.0 - gray;
    }

    if (colorize) {
      vec3 finalColor = texture(colormap, vec2(gray, 0.5)).rgb;
      fragColor = vec4(finalColor, color.a) * qt_Opacity;
    } else {
      fragColor = vec4(vec3(gray), color.a) * qt_Opacity;
    }
}
