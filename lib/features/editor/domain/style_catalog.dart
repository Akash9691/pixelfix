import 'dart:typed_data';

/// A style reference image: bundled (asset) or picked from the gallery (bytes).
class StyleSource {
  const StyleSource({required this.id, required this.name, this.asset, this.bytes});
  final String id;
  final String name;
  final String? asset;
  final Uint8List? bytes;
}

/// The six bundled styles (public-domain paintings, 256 px WebP).
const bundledStyles = <StyleSource>[
  StyleSource(id: 'starry', name: 'Starry Night', asset: 'assets/styles/starry.webp'),
  StyleSource(id: 'wave', name: 'Great Wave', asset: 'assets/styles/wave.webp'),
  StyleSource(id: 'scream', name: 'The Scream', asset: 'assets/styles/scream.webp'),
  StyleSource(id: 'kandinsky', name: 'Composition', asset: 'assets/styles/kandinsky.webp'),
  StyleSource(id: 'monet', name: 'Impression', asset: 'assets/styles/monet.webp'),
  StyleSource(id: 'klimt', name: 'The Kiss', asset: 'assets/styles/klimt.webp'),
];
