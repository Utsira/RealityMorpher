#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;
using namespace realitykit;

[[visible]]
void debug_normals(realitykit::surface_parameters params)
{
	half3 debug_color = (half3(params.geometry().normal()) + half3(1.)) * 0.5;
	params.surface().set_base_color(debug_color);
}

void morph_geometry(realitykit::geometry_parameters params, uint target_count)
{
	float3 weights = params.uniforms().custom_parameter().xyz;
	uint vertex_count = uint(params.uniforms().custom_parameter().w);
	uint vertex_id = params.geometry().vertex_id();
	float total_weight = min(1.0, weights.x + weights.y + weights.z);
	float3 output_normal = params.geometry().normal() * (1.0 - total_weight);
	float3 position_offset = float3(0);
	uint tex_width = params.textures().custom().get_width();
	
	for (uint target_id = 0; target_id < target_count; target_id ++) {
		uint position_id = vertex_id + (target_id * vertex_count);
		uint normal_id = vertex_id + ((target_count + target_id) * vertex_count);
		float3 target_offset = float3(params.textures().custom().read(uint2(position_id % tex_width, position_id / tex_width)).xyz);
		float3 target_normal = float3(params.textures().custom().read(uint2(normal_id % tex_width, normal_id / tex_width)).xyz);
		float weight = weights[target_id];
		position_offset += target_offset * weight;
		output_normal += target_normal * weight;
	}
	params.geometry().set_model_position_offset(position_offset);
	params.geometry().set_normal(normalize(output_normal));
}

// We cannot use MTLFunctionConstants with RealityKit Geometry Modifiers, hence 3 different targets

[[visible]]
void morph_geometry_target_count_1(realitykit::geometry_parameters params)
{
	morph_geometry(params, 1);
}

[[visible]]
void morph_geometry_target_count_2(realitykit::geometry_parameters params)
{
	morph_geometry(params, 2);
}

[[visible]]
void morph_geometry_target_count_3(realitykit::geometry_parameters params)
{
	morph_geometry(params, 3);
}
