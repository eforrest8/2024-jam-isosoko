
__kernel void add_vector(__global float* a, __global float* b, __global float* c, int num_els) {
  int idx = get_global_id(0);
  if (idx < num_els) {
    c[idx] = a[idx] + b[idx];
  }
}

typedef struct Drawable {
  float cX, cY, aX, aY, bX, bY;
  int tex_id;
} Drawable;

__kernel void color_at(
  __global uchar* tex,
  __global Drawable* drw,
  int drwCount,
  __global uchar* out,
  int v_width,
  int v_height
) {
  int idx = get_global_id(0);
  if (idx < v_width*v_height) {
    float x = (float)(idx % v_width);
    float y = (float)(idx / v_width);
    int pidx = idx*4;
    out[pidx] = (uchar)255;
    out[pidx+1] = (uchar)0;
    out[pidx+2] = (uchar)255;
    out[pidx+3] = (uchar)255;
    for (int didx = 0; didx < drwCount; didx++) {
      int doff = didx;
      Drawable drwCur = drw[doff];
      float d = ((drwCur.cX - (drwCur.cX + drwCur.bX)) * (y - (y - drwCur.aY)) - (drwCur.cY - (drwCur.cY + drwCur.bY)) * (x - (x - drwCur.aX)));
      float u = ((drwCur.cX - x) * (y - (y - drwCur.aY)) - (drwCur.cY - y) * (x - (x - drwCur.aX))) / d;
      float v = -((drwCur.cX - (drwCur.cX + drwCur.bX)) * (drwCur.cY - y) - (drwCur.cY - (drwCur.cY + drwCur.bY)) * (drwCur.cX - x)) / d;
      if (u >= 0 && 1 > u && v >= 0 && 1 > v) {
        int texelX = trunc(u*3 + 0.5);
        int texelY = trunc(v*3 + 0.5);
        int colIdx = ((drwCur.tex_id*16) + texelX + (texelY*4)) * 4;
        //printf("at x: %f, y: %f with texelX: %d, texelY: %d and tex_id: %d\nmapped to colIdx: %d", x, y, texelX, texelY, drwCur.tex_id, colIdx);
        out[pidx+3] = tex[colIdx];    // A
        out[pidx] = tex[colIdx+1];    // R
        out[pidx+1] = tex[colIdx+2];  // G
        out[pidx+2] = tex[colIdx+3];  // B
        /*out[pidx] = floor(u*255);    // R
        out[pidx+1] = floor(v*255);  // G
        out[pidx+2] = drwCur.tex_id*255;  // B
        out[pidx+3] = 255;    // A*/
        return;
      }
    }
  }
}

/*
func fastLineIntersection(x1,x2,x3,x4, y1,y2,y3,y4: float32): Vec2[float32] =
return (
    x: ((x1-x3) * (y3-y4) - (y1-y3) * (x3-x4)) / ((x1-x2) * (y3-y4) - (y1-y2) * (x3-x4)),
    y: -((x1-x2) * (y1-y3) - (y1-y2) * (x1-x3)) / ((x1-x2) * (y3-y4) - (y1-y2) * (x3-x4)))

func fastLineIntersection(p,r,q,s: Vec2[float32]): Vec2[float32] {.inline.} =
  fastLineIntersection(p.x, r.x, q.x, s.x, p.y, r.y, q.y, s.y)

##[
## Convert a point to quad space, suitable for texture mapping.
]##
func toParallelQuadSpace(point, origin, armA, armB: Vec2[float32]): Vec2[float32] =
  return fastLineIntersection(origin, armB+origin, point, point-armA)
*/
