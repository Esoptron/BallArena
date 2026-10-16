# Death puzzle fragments

Death still hides the body immediately and breaks its actual body and weapons into irregular textured pieces. The image stays on the GPU in a frozen 768×768 SubViewport; production code never calls get_image or scans pixels at death. Shared Voronoi body cells are prepared once, while weapon/fang silhouettes supply their own pieces. Capture jobs are serviced one per rendered frame to avoid simultaneous stalls. Framebuffers are retained until their pieces disappear, then freed.

There are at most 40 pieces per death (usually 26–30 in current hero tests). Rigid pieces use ray CCD and collide with the arena, living heroes and weapon proxies. Fragment-to-fragment contacts are omitted. All pieces fade and disappear after three real seconds. The actual portrait includes fur, tooth colour, wounds and weapon details; HP and ability aura are omitted. Headless balance runs skip this cosmetic capture.

Graphical tests verify UVs and weapon pixels, collisions with surviving bodies/weapons, fade and cleanup for sword, vampire, knife and katana.
