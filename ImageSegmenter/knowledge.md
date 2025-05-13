# Metal Framework Knowledge Base

## Common Issues and Solutions

### Texture Copy Size Mismatch

#### Problem Description
When copying textures in Metal using `MTLBlitCommandEncoder`, you may encounter an error if the source texture dimensions are larger than the destination texture:

```
-[MTLDebugBlitCommandEncoder internalValidateCopyFromTexture:sourceSlice:sourceLevel:sourceOrigin:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:options:]:496: failed assertion `Copy From Texture Validation
(destinationOrigin.x + destinationSize.width)(1080) must be <= width(270).
(destinationOrigin.y + destinationSize.height)(1920) must be <= height(480).
'
```

This occurs because Metal's blit encoder requires that the source texture region being copied must fit within the destination texture bounds.

#### Solution Approaches

1. **CPU-Based Downsampling**
   The most reliable approach to handle texture size mismatches is to use CPU-based downsampling:
   ```swift
   // Downsample texture using CPU
   private func downsampleTextureCPU(source: MTLTexture, destination: MTLTexture, scale: Int) {
     // Read source data
     let srcBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: srcWidth * srcHeight * bytesPerPixel)
     source.getBytes(srcBytes, bytesPerRow: srcBytesPerRow, from: srcRegion, mipmapLevel: 0)
     
     // Process and scale down
     for y in 0..<dstHeight {
       for x in 0..<dstWidth {
         let srcX = x * scale
         let srcY = y * scale
         // Copy pixel data from source to destination with appropriate scaling
       }
     }
     
     // Write to destination
     destination.replace(region: dstRegion, mipmapLevel: 0, withBytes: dstBytes, bytesPerRow: dstBytesPerRow)
   }
   ```

2. **Metal Performance Shaders (MPS)**
   Use MPS for efficient GPU-based scaling:
   ```swift
   // Note: MPSScaleTransform expects Double parameters
   var transform = MPSScaleTransform()
   transform.scaleX = Double(width) / Double(texture.width)
   transform.scaleY = Double(height) / Double(texture.height)
   
   let lanczosScale = MPSImageLanczosScale(device: device)
   lanczosScale.scaleTransform = withUnsafePointer(to: transform) { $0 }
   lanczosScale.encode(to: commandBuffer, 
                     sourceTexture: sourceTexture,
                     destinationTexture: destinationTexture)
   ```

3. **Core Image Integration**
   For some cases, Core Image can be easier to use:
   ```swift
   if let ciImage = CIImage(mtlTexture: sourceTexture) {
     let scale = CGFloat(destinationWidth) / CGFloat(sourceWidth) 
     let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
     
     ciContext.render(scaledImage, 
                    to: destinationTexture, 
                    commandBuffer: commandBuffer, 
                    bounds: CGRect(x: 0, y: 0, width: destinationWidth, height: destinationHeight), 
                    colorSpace: CGColorSpaceCreateDeviceRGB())
   }
   ```

### Metal Type Conversion Notes

When working with Metal and related frameworks, be aware of type requirements:

- `MPSScaleTransform` properties (`scaleX`, `scaleY`, etc.) require `Double` values, not `Float`
- When converting between integer dimensions and floating-point scales, use explicit type conversion:
  ```swift
  transform.scaleX = Double(width) / Double(texture.width)
  ```

### Debugging Metal Issues

1. **Enable Metal API Validation**
   In your Xcode scheme settings, enable Metal API Validation to catch issues earlier.

2. **Examine Metal Frame Capture**
   Use the Xcode Metal Frame Debugger to capture and analyze Metal commands.

3. **Log Metal Resource States**
   Add debugging code to log texture dimensions and properties:
   ```swift
   print("Source texture: \(sourceTexture.width)×\(sourceTexture.height)")
   print("Destination texture: \(destinationTexture.width)×\(destinationTexture.height)")
   ```

## Best Practices for Metal Texture Operations

1. **Verify Texture Dimensions**
   Always check that source and destination textures have compatible dimensions before copying.

2. **Use Appropriate Copy Methods**
   - For same-sized textures: Use blit encoder's copy methods
   - For different sizes: Use MPS or manual downsampling

3. **Reuse Textures When Possible**
   Create a texture cache system to reuse textures with the same dimensions:
   ```swift
   if let existingTexture = textureCache[key],
      existingTexture.width == requiredWidth,
      existingTexture.height == requiredHeight {
      return existingTexture
   }
   ```

4. **Optimize Memory Usage**
   Be mindful of texture memory consumption, especially when processing high-resolution images. 