#version {{version}}











#extension GL_GOOGLE_include_directive : enable

precision highp float;












uniform vec2 uFramebufferSize;
uniform vec2 uTileSize;
uniform vec2 uViewBoxOrigin;

in ivec2 aTessCoord;
in ivec2 aTileOrigin;
in vec2 aColorTexCoord;

out vec4 vColor;

vec4 getColor();

void computeVaryings(){
    vec2 pixelPosition = vec2(aTileOrigin + aTessCoord)* uTileSize + uViewBoxOrigin;
    vec2 position =(pixelPosition / uFramebufferSize * 2.0 - 1.0)* vec2(1.0, - 1.0);

    vColor = getColor();
    gl_Position = vec4(position, 0.0, 1.0);
}












uniform sampler2D uPaintTexture;
uniform vec2 uPaintTextureSize;

vec4 getColor(){
    return texture(uPaintTexture, aColorTexCoord);
}


void main(){
    computeVaryings();
}

