import "dart:math" as math;
import "dart:html";
import "dart:typed_data";

import "pixel.dart";
import "graphics_info.dart";

class MaskBufferError extends Error {
  MaskBufferError(this.message);

  @override
  String toString() => "MaskBufferError: $message";

  final String message;
}

/// A MaskBuffer is an 8 bit alpha bitmap with two 12 bit annotation channels
class MaskBuffer {
  MaskBuffer(this.width, this.height)
      : pitch = width,
        backing = new Uint32List(width * height);

  final int width;
  final int height;
  final int pitch;
  final Uint32List backing;

  _checkSize(MaskBuffer otherMaskBuffer) {
    if (width != otherMaskBuffer.width ||
        height != otherMaskBuffer.height ||
        pitch != otherMaskBuffer.pitch)
      throw new MaskBufferError("You can only combine masks of the same size");
  }

  void setValues(int x, int y, int alpha, int anX, int anY) {
    if (x >= 0 && x < width && y >= 0 && y < height) setAtOffset(y * pitch + x, alpha, anX, anY);
  }

  void add(otherMaskBuffer) {
    _checkSize(otherMaskBuffer);
    final int w = width, h = height, p = pitch;
    int base = 0;
    final Uint32List target = backing;
    final Uint32List source = otherMaskBuffer.backing;
    for (int y = 0; y < h; ++y) {
      for (int x = 0; x < w; ++x) {
        int targetAlpha = target[base + x] & 0xff;
        if (targetAlpha >= 0xff) continue;
        int newAlpha = math.max(targetAlpha, source[base + x] & 0xff);
        target[base + x] = (target[base + x] & (~0xff)) | newAlpha;
      }
      base += p;
    }
  }

  void subtract(MaskBuffer otherMaskBuffer) {
    _checkSize(otherMaskBuffer);
    final int w = width, h = height, p = pitch;
    int base = 0;
    final Uint32List target = backing;
    final Uint32List source = otherMaskBuffer.backing;
    for (int y = 0; y < h; ++y) {
      for (int x = 0; x < w; ++x) {
        int targetAlpha = target[base + x] & 0xff;
        if (targetAlpha <= 0) continue;
        int sourceAlpha = source[base + x] & 0xff;
        if (sourceAlpha <= 0) continue;
        int newAlpha = math.min(targetAlpha, 0xff - sourceAlpha);
        target[base + x] = (target[base + x] & ~0xff) | newAlpha;
      }
      base += p;
    }
  }

  void invert() {
    final int w = width, h = height, p = pitch;
    int base = 0;
    final Uint32List target = backing;
    for (int y = 0; y < h; ++y) {
      for (int x = 0; x < w; ++x) {
        int targetAlpha = target[base + x] & 0xff;
        target[base + x] = (target[base + x] & ~0xff) | (0xff - targetAlpha);
      }
      base += p;
    }
  }

  int offset(int x, int y) {
    return y * pitch + x;
  }

  void setAtOffset(int offset, int alpha, int anX, int anY) {
    backing[offset] = (alpha & 0xff) | ((anX & 4095) << 8) | ((anY & 4095) << 20);
  }

  int getAlphaAtOffset(int offset) => backing[offset] & 0xff;
  int getAnnotationXAtOffset(int offset) => (backing[offset] >> 8) & 4095;
  int getAnnotationYAtOffset(int offset) => (backing[offset] >> 20) & 4095;

  static int signAnnotation(int value) => (value & 2048) > 0 ? value | (~4095) : value;
}

typedef bool ColorMatcher(int color);
typedef int ColorTransformer(int color);

class Mask {
  Mask(PixelData image) {
    imageData = image;
  }

  set imageData(PixelData data) {
    _imageData = data;
    imageDataView = data.data.buffer.asUint32List();
    if (maskBuffer == null || maskBuffer.width != data.width || maskBuffer.height != data.height) {
      maskBuffer = new MaskBuffer(data.width, data.height);
      rectangle = null;
    }
    rectangle ??= [-1, -1, -1, -1];
  }

  PixelData get imageData => _imageData;

  int get referenceColor => imageDataView[0];

  ColorMatcher _handlePixelTest(int pixelTest, [int offsetOpt]) {
    int sourcePixel = pixelTest == null ? imageDataView[offsetOpt] : pixelTest;
    return (int pixel) => pixel == sourcePixel;
  }

  void _addPixelSpan(int startX, int endX, int y) {
    // make the rectangle contain this span of pixels
    if (startX < rectangle[0] || rectangle[0] == -1) rectangle[0] = startX;
    if (endX > rectangle[2] || rectangle[2] == -1) rectangle[2] = endX;
    if (y < rectangle[1] || rectangle[1] == -1) rectangle[1] = y;
    if (y >= rectangle[3] || rectangle[3] == -1) rectangle[3] = y + 1;
  }

  bool isSelected(x, y) {
    if (x < 0 || x >= maskBuffer.width || y < 0 || y >= maskBuffer.height) return false;
    int offset = maskBuffer.offset(x, y);
    return maskBuffer.getAlphaAtOffset(offset) > 0;
  }

  Iterable<PixelPosition> selectedPixels() sync* {
    int left = rectangle[0];
    int top = rectangle[1];
    int right = rectangle[2];
    int bottom = rectangle[3];
    int pitch = maskBuffer.pitch;
    int base = top * pitch;
    for (int y = top; y < bottom; ++y, base += pitch) {
      for (int x = left; x < right; ++x) {
        int offset = base + x;
        if (maskBuffer.getAlphaAtOffset(offset) > 0) yield new PixelPosition(x, y);
      }
    }
  }

  Iterable<int> selectedPixelValues() sync* {
    int left = rectangle[0];
    int top = rectangle[1];
    int right = rectangle[2];
    int bottom = rectangle[3];
    int pitch = maskBuffer.pitch;
    int base = top * pitch;
    for (int y = top; y < bottom; ++y, base += pitch) {
      for (int x = left; x < right; ++x) {
        int offset = base + x;
        if (maskBuffer.getAlphaAtOffset(offset) > 0) yield imageDataView[offset];
      }
    }
  }

  void selectAll({ColorMatcher pixelTest, int colorToMatch}) {
    if (pixelTest == null) pixelTest = _handlePixelTest(colorToMatch);
    int left = 0;
    int top = 0;
    int right = maskBuffer.width;
    int bottom = maskBuffer.height;
    int pitch = maskBuffer.pitch;
    int base = top * pitch;
    for (int y = top; y < bottom; ++y, base += pitch) {
      int startX = 0;
      for (int x = left; x < right; ++x) {
        int offset = base + x;
        if (maskBuffer.getAlphaAtOffset(offset) > 0) continue;
        if (pixelTest(imageDataView[offset])) {
          if (startX == -1) startX = x;

          maskBuffer.setAtOffset(offset, 255, 0, 0);
        } else {
          if (startX >= 0) _addPixelSpan(startX, x, y);
          startX = -1;
        }
      }
      if (startX >= 0) _addPixelSpan(startX, right, y);
    }
  }

  void addMask(Mask otherMask) {
    maskBuffer.add(otherMask.maskBuffer);
    List<int> source = otherMask.rectangle;
    List<int> target = rectangle;
    for (int i = 0; i < 4; ++i) {
      if (target[i] == -1) {
        target[i] = source[i];
        continue;
      }
      int diff = source[i] - target[i];
      if (i < 2) diff = -diff;
      if (diff > 0) target[i] = source[i];
    }
  }

  void subtractMask(Mask otherMask) {
    maskBuffer.subtract(otherMask.maskBuffer);
  }

  void invert() {
    maskBuffer.invert();
    _addPixelSpan(0, maskBuffer.width, 0);
    _addPixelSpan(0, maskBuffer.width, maskBuffer.height - 1);
  }

  void fill(x, y, {ColorMatcher pixelTest, int colorToMatch}) {
    final int w = maskBuffer.width;
    if (x < 0 || x >= w || y < 0 || y >= maskBuffer.height) return;
    int offset = maskBuffer.offset(x, y);
    if (pixelTest == null) pixelTest = _handlePixelTest(colorToMatch, offset);
    if (maskBuffer.getAlphaAtOffset(offset) > 0 || !pixelTest(imageDataView[offset])) return;
    int startOffset = offset;
    int startX = x;
    --startOffset;
    --startX;
    while (startX >= 0 && pixelTest(imageDataView[startOffset])) {
      --startOffset;
      --startX;
    }
    ++startX;
    ++startOffset;

    int endOffset = offset;
    int endX = x;
    ++endOffset;
    ++endX;
    while (endX < w && pixelTest(imageDataView[endOffset])) {
      ++endOffset;
      ++endX;
    }

    // make the rectangle contain this span of pixels
    _addPixelSpan(startX, endX, y);

    for (int o = startOffset; o < endOffset; ++o) maskBuffer.setAtOffset(o, 255, 0, 0);
    final int p = maskBuffer.pitch;
    if (y > 0) {
      int currentX = startX;
      for (int o = startOffset; o < endOffset; ++o, ++currentX) {
        if (maskBuffer.getAlphaAtOffset(o - p) <= 0 && pixelTest(imageDataView[o - p]))
          fill(currentX, y - 1, pixelTest: pixelTest);
      }
    }
    if (y < maskBuffer.height - 1) {
      int currentX = startX;
      for (int o = startOffset; o < endOffset; ++o, ++currentX) {
        if (maskBuffer.getAlphaAtOffset(o + p) <= 0 && pixelTest(imageDataView[o + p]))
          fill(currentX, y + 1, pixelTest: pixelTest);
      }
    }
  }

  CanvasElement createHighlightElement([String elementClassOpt]) {
    CanvasElement result = document.createElement("canvas");
    result.width = maskBuffer.width;
    result.height = maskBuffer.height;
    CanvasRenderingContext2D ctx = result.getContext("2d");
    ctx.clearRect(0, 0, result.width, result.height);
    ImageData targetImageData = ctx.getImageData(0, 0, result.width, result.height);
    Uint8ClampedList sourceData = imageData.data;
    Uint8ClampedList data = targetImageData.data;
    GraphicsInfo gi = GraphicsInfo.current;
    int r = gi.channels[0];
    int g = gi.channels[1];
    int b = gi.channels[2];
    int a = gi.channels[3];
    int left = rectangle[0];
    int top = rectangle[1];
    int right = rectangle[2];
    int bottom = rectangle[3];
    int pitch = maskBuffer.pitch;
    int base = top * pitch;
    for (int y = top; y < bottom; ++y, base += pitch) {
      for (int x = left; x < right; ++x) {
        int i = base + x;
        int alpha = maskBuffer.getAlphaAtOffset(i);
        if (alpha > 0) {
          int dataOffset = i * 4;
          int lum = 76 * sourceData[dataOffset + r] +
              149 * sourceData[dataOffset + g] +
              29 * sourceData[dataOffset + b];
          if (lum < 32768)
            lum = 255;
          else
            lum = 0;
          data[dataOffset + r] = lum;
          data[dataOffset + g] = lum;
          data[dataOffset + b] = lum;
          data[dataOffset + a] = alpha;
        }
      }
    }

    ctx.putImageData(targetImageData, 0, 0);

    if (elementClassOpt != null) result.className = elementClassOpt;

    return result;
  }

  void paint({ColorTransformer transformer, int color}) {
    transformer ??= (_) => color;
    int left = rectangle[0];
    int top = rectangle[1];
    int right = rectangle[2];
    int bottom = rectangle[3];
    int pitch = maskBuffer.pitch;
    int base = top * pitch;
    for (int y = top; y < bottom; ++y, base += pitch) {
      for (int x = left; x < right; ++x) {
        int i = base + x;
        int alpha = maskBuffer.getAlphaAtOffset(i);
        if (alpha > 0) {
          imageDataView[i] = transformer(imageDataView[i]);
        }
      }
    }
  }

  PixelData _imageData;
  Uint32List imageDataView;
  MaskBuffer maskBuffer;
  List<int> rectangle;
}
