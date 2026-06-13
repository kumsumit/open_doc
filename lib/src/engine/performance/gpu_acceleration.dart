// ============================================================
// GPU ACCELERATION ENGINE
// ============================================================

/// GPU rendering backend types.
enum DocxGpuBackend { vulkan, metal, openGl, webGpu, software }

/// Configuration for GPU-accelerated rendering.
class DocxGpuConfig {
  final DocxGpuBackend preferredBackend;
  final bool enableMsaa;
  final int msaaSamples;
  final bool enableLayerCaching;
  final bool enableTextureAtlas;
  final int maxTextureCacheBytes;
  final bool enableParallelRasterization;

  const DocxGpuConfig({
    this.preferredBackend = DocxGpuBackend.vulkan,
    this.enableMsaa = true,
    this.msaaSamples = 4,
    this.enableLayerCaching = true,
    this.enableTextureAtlas = true,
    this.maxTextureCacheBytes = 256 * 1024 * 1024, // 256 MB
    this.enableParallelRasterization = true,
  });
}

/// GPU render layer — cached rasterized region of the document.
class DocxGpuLayer {
  final String id;
  final int x;
  final int y;
  final int width;
  final int height;
  final bool isDirty;
  final DateTime lastRendered;

  const DocxGpuLayer({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.isDirty = true,
    required this.lastRendered,
  });

  DocxGpuLayer markDirty() => DocxGpuLayer(
        id: id,
        x: x,
        y: y,
        width: width,
        height: height,
        isDirty: true,
        lastRendered: lastRendered,
      );

  DocxGpuLayer markClean() => DocxGpuLayer(
        id: id,
        x: x,
        y: y,
        width: width,
        height: height,
        isDirty: false,
        lastRendered: DateTime.now(),
      );
}

/// Frame statistics for GPU rendering performance monitoring.
class DocxGpuFrameStats {
  final double fps;
  final Duration frameTime;
  final int drawCalls;
  final int textureUploads;
  final int cacheHits;
  final int cacheMisses;
  final int gpuMemoryUsedBytes;

  const DocxGpuFrameStats({
    required this.fps,
    required this.frameTime,
    required this.drawCalls,
    required this.textureUploads,
    required this.cacheHits,
    required this.cacheMisses,
    required this.gpuMemoryUsedBytes,
  });

  double get cacheHitRate =>
      (cacheHits + cacheMisses) == 0 ? 0 : cacheHits / (cacheHits + cacheMisses);
}

/// Abstract GPU acceleration engine interface.
///
/// Concrete implementations target Vulkan (Android/Desktop), Metal (iOS/macOS),
/// OpenGL ES (legacy), or WebGPU (web). Falls back to software rendering when
/// no GPU backend is available.
abstract class DocxGpuAccelerationEngine {
  DocxGpuConfig get config;
  bool get isAvailable;
  DocxGpuBackend get activeBackend;

  /// Initialise the GPU context and allocate resources.
  Future<void> initialize();

  /// Rasterize a layer to the GPU texture cache.
  Future<DocxGpuLayer> rasterizeLayer(DocxGpuLayer layer, List<int> renderCommands);

  /// Composite all visible layers into the final frame.
  Future<void> compositeFrame(List<DocxGpuLayer> layers, int viewportWidth, int viewportHeight);

  /// Invalidate GPU cache for a specific document node.
  void invalidateNode(String nodeId);

  /// Release all GPU resources.
  void dispose();

  /// Current frame statistics.
  DocxGpuFrameStats get frameStats;
}

/// Software fallback implementation used when no GPU is available.
class DocxSoftwareRenderEngine extends DocxGpuAccelerationEngine {
  final DocxGpuConfig _config;
  final DocxGpuFrameStats _stats = const DocxGpuFrameStats(
    fps: 60,
    frameTime: Duration(microseconds: 16667),
    drawCalls: 0,
    textureUploads: 0,
    cacheHits: 0,
    cacheMisses: 0,
    gpuMemoryUsedBytes: 0,
  );

  DocxSoftwareRenderEngine({this._config = const DocxGpuConfig()});

  @override
  DocxGpuConfig get config => _config;

  @override
  bool get isAvailable => true;

  @override
  DocxGpuBackend get activeBackend => DocxGpuBackend.software;

  @override
  Future<void> initialize() async {}

  @override
  Future<DocxGpuLayer> rasterizeLayer(
      DocxGpuLayer layer, List<int> renderCommands) async {
    return layer.markClean();
  }

  @override
  Future<void> compositeFrame(
      List<DocxGpuLayer> layers, int viewportWidth, int viewportHeight) async {}

  @override
  void invalidateNode(String nodeId) {}

  @override
  void dispose() {}

  @override
  DocxGpuFrameStats get frameStats => _stats;
}

/// Factory that selects the best available GPU backend.
class DocxGpuEngineFactory {
  /// Create the best available GPU engine for the current platform.
  ///
  /// Returns a [DocxSoftwareRenderEngine] when no hardware backend is available.
  static DocxGpuAccelerationEngine create({DocxGpuConfig? config}) {
    // Real implementation: detect platform and instantiate Vulkan/Metal/WebGPU.
    // Fallback to software renderer.
    return DocxSoftwareRenderEngine(config: config ?? const DocxGpuConfig());
  }
}
