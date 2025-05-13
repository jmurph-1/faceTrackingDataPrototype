
# Recent Bug Fixes

## Texture Copy Size Mismatch Fix (June 2024)

### Issue Description
When switching to the MultiClass segmentation model, users encountered a critical render failure with the following error:
```
-[MTLDebugBlitCommandEncoder internalValidateCopyFromTexture:sourceSlice:sourceLevel:sourceOrigin:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:options:]:496: failed assertion `Copy From Texture Validation
(destinationOrigin.x + destinationSize.width)(1080) must be <= width(270).
(destinationOrigin.y + destinationSize.height)(1920) must be <= height(480).
```

The error occurred because the application was attempting to copy texture data from a large source texture (1080×1920) to a smaller destination texture (270×480) without properly handling the size difference.

### Solution Implemented
The issue was resolved by implementing a CPU-based downsampling approach that properly handles the texture size mismatch:

1. **Replaced problematic blit operations:** The direct Metal blit encoder copy operation was replaced with a safer CPU-based downsampling method.

2. **Added proper dimension verification:** The code now correctly checks and handles size differences between source and destination textures.

3. **Created a knowledge base document:** A new `knowledge.md` file was created to document this issue and other Metal texture handling best practices for future reference.

This fix ensures that the MultiClass segmentation model can now be used without crashing, allowing users to access the facial feature analysis functionality.

For technical details about this fix and similar Metal texture handling issues, refer to the `knowledge.md` file in the project repository.
