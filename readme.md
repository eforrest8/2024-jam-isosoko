# Unfinished Project for Crossroads Jam 2024

Figured I'd share the code since I have it and all.

My game idea was a 3D-isometric sokoban-type puzzle game where
the gimmick was tornados which could pick up boxes and move them
around. (The jam theme was severe weather, for future reference.)
But of course, I got caught up trying to write my own engine that
I never actually got to the game part of the game.
So, this repo is basically just the engine I was working on. If
you build it (via ```nimble build```) it'll give you an exe that
draws an isometric cube!

There's a bunch of non-functional unused modules in the codebase.
These were just engine bits I couldn't get working and dropped in
favor of being able to draw something simple on the screen.

I'm obsessed with making all of my engine components run in
separate threads, but Nim has weird issues with threading; the
built-in threadpools module is apparently deprecated, and you're
encouraged to used one of several third-party threading libraries:
Weave, Taskpools, or Malebolgia. I thought Weave looked the nicest,
but it doesn't actually seem to work? At the very least the
documentation doesn't match up with what's actually in the library.
Malebolgia seems to work but its implementation of the ```spawn```
statement is slightly ugly; you have to call it like ```m.spawn```.
Not really a big deal I guess, but if it was prettier I might not
have wasted so much time on Weave. Oh well.

I am really happy about the way I managed to render my cubes. I had
been trying to construct the shapes by warping my coordinate space
via affine transforms, but I realized that there's a much simpler
way to think about it. The crucial thing I need to know is which face
of the cube a given point lies on, if any. And I know I can detect
whether a point is in a triangle really easily. As it turns out,
my cubes can be represented by three vectors A, B, and C; one for
each visible edge. If I then add A and B, I get a vector AB which
points at the far corner of the face between A and B. I can than
split the face into two triangles with corners at (0,0), A, AB and
(0,0), AB, B and do the standard math to tell if a point is on that
face.

I think in my case, since my cube's faces are quadrilaterals where
the edges opposite each other are both parallel and of equal length,
I can adjust my method to use the quads directly rather than splitting
them into triangles. I think I just need to know how far the point is
along each side (essentially barycentric coordinates I think, but for
a restricted quad.) This should be extra helpful for mapping textures
onto the faces if it works the way I think it will.

Anyway that's my project!
