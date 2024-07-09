
__kernel void add_vector(__global float* a, __global float* b, __global float* c, int num_els) {
  int idx = get_global_id(0);
  if (idx < num_els) {
    c[idx] = a[idx] + b[idx];
  }
}

__kernel void transform_coords_by_parallel_quad(
  __global int* p,
  __global float* out,
  __global float* voxels,
  int num_els
) {
  int idx = get_global_id(0);
  if (idx < num_els) {
    int ui = idx*2;
    int vi = ui+1;
    int voxel = idx*6;
    float c = (p[ui] * (voxels[voxel+3] - voxels[voxel+5])) + (p[vi] * (voxels[voxel+4] - voxels[voxel+2])) + 1.0;
    out[ui] = ((p[ui] * (voxels[voxel+1] - voxels[voxel+3])) + (p[vi] * (voxels[voxel+2] - voxels[voxel+0])) + 1.0) / c;
    out[vi] = ((p[ui] * (voxels[voxel+5] - voxels[voxel+1])) + (p[vi] * (voxels[voxel+0] - voxels[voxel+4])) + 1.0) / c;
  }
}
