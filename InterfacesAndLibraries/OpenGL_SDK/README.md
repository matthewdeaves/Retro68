# Apple OpenGL 1.2 SDK for Retro68

This directory contains Apple's OpenGL 1.2 SDK (January 2001) packaged for the
Retro68 PowerPC CFM toolchain so classic-Mac apps can `#include <gl.h>` and
link against `-lOpenGLLibrary` like any other shared system library.

## Layout

```
OpenGL_SDK/
├── Headers/             — C headers (data fork only, plain text)
│   ├── gl.h glu.h glext.h glut.h
│   ├── agl.h aglContext.h aglMacro.h aglRenderers.h
│   └── gliContext.h gliDispatch.h glm.h
└── Libraries/           — CFM stub libraries, MacBinary-wrapped to keep cfrg
    ├── OpenGLLibraryStub.bin      (gl* AND agl* exports, ~440+33 symbols)
    ├── OpenGLMemoryStub.bin       (Apple memory helpers)
    └── OpenGLUtilityStub.bin      (GLU)
```

The stubs are stored MacBinary-encoded because `MakeImport` requires the
`cfrg` resource (which identifies the CFM library) — that resource lives in
the Mac resource fork, and MacBinary is the portable way to carry both forks
through Linux/Windows filesystems.

## Provenance

* **Source**: <https://macintoshgarden.org/apps/opengl-sdk>
* **File**: `OpenGL_SDK_1.2.sit`
* **MD5**: `6c731e1924990fea59c2d94a9eb88cff`
* **OS coverage** per the SDK: Mac OS 8.1 through Mac OS X.
* Extracted via classic Mac (StuffIt Expander in an OS 9.2.2 VM), then
  pulled out as MacBinary using `hcopy -m` so the resource forks survived
  the trip from HFS.

## Install into the toolchain

**You normally don't run this by hand.** `build-toolchain.bash` invokes it
automatically at the end of every PowerPC build, so `./setup.sh`, the Docker
image, and CI all bake OpenGL into the toolchain with no extra step.

To (re)install into an already-built toolchain — e.g. after editing the SDK —
run it directly:

```
RETRO68_TOOLCHAIN=$HOME/Retro68-build/toolchain \
    ./InterfacesAndLibraries/OpenGL_SDK/install.sh
```

That script:

1. Copies all `Headers/*.h` to `$RETRO68/powerpc-apple-macos/include/` and
   also to `.../include/GL/` (the alternate `#include <GL/gl.h>` convention).
2. Runs `MakeImport` on each MacBinary stub, producing
   `libOpenGLLibrary.a`, `libOpenGLMemory.a`, `libOpenGLUtility.a` in
   `$RETRO68/powerpc-apple-macos/lib/`.
3. Self-verifies by compiling and linking a small `agl`/`gl`/`glu` test
   program against all three libraries. This is best-effort: the headers and
   libs are always installed, and a failed smoke test only warns (it does not
   abort the build). It fails under the multiversal interfaces because `agl.h`
   includes `<Quickdraw.h>` and multiversal ships `QuickDraw.h`; build with
   Apple's Universal Interfaces to compile AGL/OpenGL apps.

## Using it from a project

```cmake
add_application(myglapp myglapp.c myglapp.r)
target_link_libraries(myglapp PRIVATE
    "-lOpenGLLibrary"
    "-lOpenGLUtility"   # only if you call glu*
    "-lOpenGLMemory"    # only if you use Apple OpenGL memory helpers
)
```

```c
#include <agl.h>
#include <gl.h>
```

## Targets

The CFM stub at runtime resolves to the system-supplied `OpenGLLibrary`
shared library. That works for **classic CFM (Mac OS 8.x/9.x on PPC)** and
**Carbon CFM (Mac OS 8.6+/9.x with CarbonLib, and Mac OS X)** — the
contract is the same library.

68k Macs never received OpenGL from Apple, so there are no 68k stubs.

## License

Apple's OpenGL SDK was distributed freely to developers; the redistribution
here is for retrocomputing/preservation purposes. If you have a stronger
license claim please open an issue.
