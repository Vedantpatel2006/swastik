import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  print('Generating launcher icons from swastik1.jpg...');
  
  // Read the source image
  final sourceFile = File('assets/images/logos/swastik1.jpg');
  if (!await sourceFile.exists()) {
    print('Error: swastik1.jpg not found!');
    return;
  }
  
  final sourceBytes = await sourceFile.readAsBytes();
  final sourceImage = img.decodeImage(sourceBytes);
  
  if (sourceImage == null) {
    print('Error: Could not decode image!');
    return;
  }
  
  // Icon sizes for different densities
  final sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  
  for (final entry in sizes.entries) {
    final folder = entry.key;
    final size = entry.value;
    
    // Resize image
    final resized = img.copyResize(
      sourceImage,
      width: size,
      height: size,
      interpolation: img.Interpolation.linear,
    );
    
    // Save to appropriate folder
    final outputPath = 'android/app/src/main/res/$folder/ic_launcher.png';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(img.encodePng(resized));
    
    print('✓ Generated $outputPath ($size x $size)');
  }
  
  print('\n✅ All launcher icons generated successfully!');
  print('Your app will now use swastik1.jpg as the launcher icon.');
}
