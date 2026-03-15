#version 300 es

// Two triangles (6 vertices) cover clip space [-1,1]^2.

in vec2 a_position;

void main() {
    gl_Position = vec4(a_position, 0.0, 1.0);
}
