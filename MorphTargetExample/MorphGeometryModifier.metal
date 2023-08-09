#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

[[visible]]
void morph_geometry_modifier(realitykit::geometry_parameters params)
{
	float4 weights = params.uniforms().custom_parameter();
	uint vertex_id = params.geometry().vertex_id();
	
	float3 output_normal = params.geometry().normal();
	float3 base_position = params.geometry().model_position();
	float3 position_offset = float3(0);
	
	for (uint target_id = 0; target_id < 4; target_id ++) {
		float3 target_offset = float3(params.textures().custom().read(uint2(vertex_id, target_id)).xyz) - base_position;
		float3 target_normal = float3(params.textures().custom().read(uint2(vertex_id, target_id + 4)).xyz);
		float weight = weights[target_id];
		position_offset = mix(position_offset, target_offset, weight);
		output_normal = mix(output_normal, target_normal, weight);
	}
	params.geometry().set_model_position_offset(position_offset);
	params.geometry().set_normal(normalize(output_normal));
}
