#version {{version}}
// Automatically generated from files in pathfinder/shaders/. Do not edit!












#extension GL_GOOGLE_include_directive : enable











precision highp float;





layout(local_size_x = 64)in;

uniform mat2 uTransform;
uniform vec2 uTranslation;

struct Segment {
    vec4 line;
    uvec4 pathIndex;
};

layout(std430, binding = 0)buffer bComputeIndirectParams {






    restrict uint iComputeIndirectParams[];
};

layout(std430, binding = 1)buffer bPoints {
    restrict readonly vec2 iPoints[];
};

layout(std430, binding = 2)buffer bInputIndices {
    restrict readonly uvec2 iInputIndices[];
};

layout(std430, binding = 3)buffer bOutputSegments {
    restrict Segment iOutputSegments[];
};

void emitLineSegment(vec4 lineSegment, uint pathIndex){
    uint outputSegmentIndex = atomicAdd(iComputeIndirectParams[5], 1);
    if(outputSegmentIndex % 64 == 0)
        atomicAdd(iComputeIndirectParams[0], 1);

    iOutputSegments[outputSegmentIndex]. line = lineSegment;
    iOutputSegments[outputSegmentIndex]. pathIndex . x = pathIndex;
}


bool curveIsFlat(vec4 baseline, vec4 ctrl){
    vec4 uv = vec4(3.0)* ctrl - vec4(2.0)* baseline - baseline . zwxy;
    uv *= uv;
    uv = max(uv, uv . zwxy);
    return uv . x + uv . y <= 16.0 * 0.25 * 0.25;
}

void subdivideCurve(vec4 baseline,
                    vec4 ctrl,
                    float t,
                    out vec4 prevBaseline,
                    out vec4 prevCtrl,
                    out vec4 nextBaseline,
                    out vec4 nextCtrl){
    vec2 p0 = baseline . xy, p1 = ctrl . xy, p2 = ctrl . zw, p3 = baseline . zw;
    vec2 p0p1 = mix(p0, p1, t), p1p2 = mix(p1, p2, t), p2p3 = mix(p2, p3, t);
    vec2 p0p1p2 = mix(p0p1, p1p2, t), p1p2p3 = mix(p1p2, p2p3, t);
    vec2 p0p1p2p3 = mix(p0p1p2, p1p2p3, t);
    prevBaseline = vec4(p0, p0p1p2p3);
    prevCtrl = vec4(p0p1, p0p1p2);
    nextBaseline = vec4(p0p1p2p3, p3);
    nextCtrl = vec4(p1p2p3, p2p3);
}

vec2 getPoint(uint pointIndex){
    return uTransform * iPoints[pointIndex]+ uTranslation;
}

void main(){
    uint inputIndex = gl_GlobalInvocationID . x;
    if(inputIndex >= iComputeIndirectParams[4])
        return;

    uvec2 inputIndices = iInputIndices[inputIndex];
    uint fromPointIndex = inputIndices . x, flagsPathIndex = inputIndices . y;
    uint pathIndex = flagsPathIndex & 0xbfffffffu;

    uint toPointIndex = fromPointIndex;
    if((flagsPathIndex & 0x40000000u)!= 0u)
        toPointIndex += 3;
    else if((flagsPathIndex & 0x80000000u)!= 0u)
        toPointIndex += 2;
    else
        toPointIndex += 1;

    vec4 baseline = vec4(getPoint(fromPointIndex), getPoint(toPointIndex));
    if((flagsPathIndex &(0x40000000u |
                                                             0x80000000u))== 0){
        emitLineSegment(baseline, pathIndex);
        return;
    }


    vec2 ctrl0 = getPoint(fromPointIndex + 1);
    vec4 ctrl;
    if((flagsPathIndex & 0x80000000u)!= 0){
        vec2 ctrl0_2 = ctrl0 * vec2(2.0);
        ctrl =(baseline +(ctrl0 * vec2(2.0)). xyxy)* vec4(1.0 / 3.0);
    } else {
        ctrl = vec4(ctrl0, getPoint(fromPointIndex + 2));
    }

    vec4 baselines[32];
    vec4 ctrls[32];
    int curveStackSize = 1;
    baselines[0]= baseline;
    ctrls[0]= ctrl;

    while(curveStackSize > 0){
        curveStackSize --;
        baseline = baselines[curveStackSize];
        ctrl = ctrls[curveStackSize];
        if(curveIsFlat(baseline, ctrl)|| curveStackSize + 2 >= 32){
            emitLineSegment(baseline, pathIndex);
        } else {
            subdivideCurve(baseline,
                           ctrl,
                           0.5,
                           baselines[curveStackSize + 1],
                           ctrls[curveStackSize + 1],
                           baselines[curveStackSize + 0],
                           ctrls[curveStackSize + 0]);
            curveStackSize += 2;
        }
    }
}

