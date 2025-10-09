// Stub implementation for platforms that don't support dart:ffi
// This file provides empty implementations for web platform

class Tensor {
  List<int> get shape => [];
}

class Interpreter {
  static Future<Interpreter> fromAsset(String assetName) async {
    throw UnsupportedError('TFLite is not supported on this platform');
  }
  
  void run(dynamic input, dynamic output) {
    throw UnsupportedError('TFLite is not supported on this platform');
  }
  
  Tensor getInputTensor(int index) {
    return Tensor();
  }
  
  Tensor getOutputTensor(int index) {
    return Tensor();
  }
  
  List<int> getInputShape(int index) {
    throw UnsupportedError('TFLite is not supported on this platform');
  }
  
  List<int> getOutputShape(int index) {
    throw UnsupportedError('TFLite is not supported on this platform');
  }
  
  void close() {
    // No-op for stub
  }
}

class TensorType {
  static const float32 = 'float32';
}

class TensorBuffer {
  static TensorBuffer createFixedSize(List<int> shape, String type) {
    throw UnsupportedError('TFLite is not supported on this platform');
  }
  
  void loadArray(List<double> array) {
    throw UnsupportedError('TFLite is not supported on this platform');
  }
  
  List<double> getDoubleArray() {
    throw UnsupportedError('TFLite is not supported on this platform');
  }
}

// Helper function to check if TFLite is supported (always false for stub)
bool get isTFLiteSupported => false;

// Safe wrapper for TFLite operations (stub implementation)
class TFLiteWrapper {
  static Future<Interpreter?> createInterpreter(String assetPath) async {
    return null; // Always return null for unsupported platforms
  }
  
  static bool runInference(Interpreter? interpreter, dynamic input, dynamic output) {
    return false; // Always return false for unsupported platforms
  }
}