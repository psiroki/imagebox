import "dart:typed_data";
import "dart:html";

class PixelPosition {
  PixelPosition(this.x, this.y);

  final int x;
  final int y;
}

abstract class PixelData {
  int get width;
  int get height;
  int get pitch => width*4;
  Uint8ClampedList get data;
  ImageData createImageData(CanvasRenderingContext2D context);
}

class WrappedImageData extends PixelData {
  WrappedImageData(this.imageData);

  int get width => imageData.width;
  int get height => imageData.height;

  Uint8ClampedList get data => imageData.data;

  ImageData createImageData(CanvasRenderingContext2D context) => imageData;
  ImageData imageData;
}

class PixelDataBuffer extends PixelData {
  PixelDataBuffer(int width, int height):
    this.width = width,
    this.height = height,
    this.data = new Uint8ClampedList(width*height*4);

  final int width;
  final int height;
  final Uint8ClampedList data;

  ImageData createImageData(CanvasRenderingContext2D context) {
    ImageData result = context.createImageData(width, height);
    result.data.setAll(0, data);
    return result;
  }
}

typedef bool ChannelEqualityPredicate(int a, int b);
typedef bool PixelEqualityTest(
    List<int> arr, List<int> ref, int pitch, int refWidth, int refPitch);

PixelEqualityTest createFillTest([ChannelEqualityPredicate eqPred = strictlyEquals]) {
  return (List<int> arr, List<int> ref, int pitch, int refWidth, int refPitch) {
    if (pitch == null) pitch = ref.length;
    if (refPitch == null) refPitch = 0;
    if (refWidth == null) refWidth = ref.length;
    int l = arr.length;
    int refOffset = 0;
    for (int c = 0; c < l; c += pitch) {
      for (int i = 0; i < refWidth; ++i) {
        if (!eqPred(arr[c + i], ref[refOffset + i])) return false;
      }
      refOffset += refPitch;
    }
    return true;
  };
}

bool strictlyEquals(int a, int b) => a == b;
ChannelEqualityPredicate allowDelta(int delta) =>
    (int a, int b) => (a - b).abs() < delta;

int colorDistance(int a, int b) {
  return ((a & 0xff) - (b & 0xff)).abs() +
      ((a >> 8 & 0xff) - (b >> 8 & 0xff)).abs() +
      ((a >> 16 & 0xff) - (b >> 16 & 0xff)).abs() +
      ((a >> 24 & 0xff) - (b >> 24 & 0xff)).abs();
}

int mix(int a, int b, double f) {
  double fi = 1 - f;
  return ((a & 0xff) * fi + f * (b & 0xff)).round() |
      ((a >> 8 & 0xff) * fi + f * (b >> 8 & 0xff)).round() << 8 |
      ((a >> 16 & 0xff) * fi + f * (b >> 16 & 0xff)).round() << 16 |
      ((a >> 24 & 0xff) * fi + f * (b >> 24 & 0xff)).round() << 24;
}
