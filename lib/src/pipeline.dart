import "dart:html";
import "dart:typed_data";
import "dart:math" as math;

import "pixel.dart";

typedef PipelineProcess PipelineProcessFactory(CanvasRenderingContext2D context, PixelData source);

class Pipeline {
  Pipeline(this.createProcess);

  PixelData process(CanvasRenderingContext2D context, [ImageData source]) {
    if (source == null) {
      CanvasElement canvas = context.canvas;
      source = context.getImageData(0, 0, canvas.width, canvas.height);
    }
    return createProcess(context, new WrappedImageData(source)).execute();
  }

  PipelineProcessFactory createProcess;
}

abstract class PipelineProcess {
  PipelineProcess(this.context, this.source);

  PixelData execute();

  final CanvasRenderingContext2D context;
  final PixelData source;
}

class CropProcess extends PipelineProcess {
  CropProcess(CanvasRenderingContext2D context, PixelData source)
      : super(context, source);

  bool doCrop = true;
  bool transparentCartoon = false;
  bool gradientCrop = false;
  bool allowDeviation = false;
  int differenceDelta = 0;
  int borderWidth = 0;

  PixelData execute() {
    Uint8ClampedList pixels = source.data;
    Uint8ClampedList ref = pixels.sublist(0, 4);
    Uint32List refColorBuffer = pixels.buffer.asUint32List(0, 1);
    int refColor = refColorBuffer[0];
    int maxX = -1;
    int maxY = -1;
    int minX = source.width;
    int minY = source.height;
    int offset = 0;
    int pitch = source.width * 4;
    PixelEqualityTest isFilled;
    if (differenceDelta > 0)
      isFilled = createFillTest(allowDelta(differenceDelta));
    else
      isFilled = createFillTest();
    if (transparentCartoon) {}
    if (doCrop) {
      Uint8ClampedList cropRef = ref;
      int cropRefWidth = cropRef.length;
      int cropRefPitch = 0;

      if (gradientCrop) {
        cropRef = pixels;
        cropRefWidth = source.width * 4;
        cropRefPitch = 0;
      }

      for (int y = 0; y < source.height; ++y) {
        if (gradientCrop && allowDeviation && y > 0)
          cropRef = pixels.sublist((y - 1) * pitch, pixels.length);
        if (isFilled(pixels.sublist(offset, offset + pitch), cropRef,
            math.min(cropRefWidth, pitch), cropRefWidth, cropRefPitch))
          maxY = y;
        else
          break;
        offset += pitch;
      }

      if (gradientCrop) {
        cropRef = pixels;
        cropRefWidth = 4;
        cropRefPitch = pitch;
      }

      for (int x = 0; x < source.width; ++x) {
        if (gradientCrop && allowDeviation && x > 0)
          cropRef = pixels.sublist((x - 1) * 4, pixels.length);
        if (isFilled(pixels.sublist(x * 4, pixels.length), cropRef, pitch,
            cropRefWidth, cropRefPitch))
          maxX = x;
        else
          break;
      }

      if (gradientCrop) {
        cropRef = pixels.sublist((source.height - 1) * pitch, pixels.length);
        cropRefWidth = source.width * 4;
        cropRefPitch = 0;
      }

      offset = source.width * source.height * 4;
      for (int y = source.height - 1; y >= 0; --y) {
        if (gradientCrop && allowDeviation && y < source.height - 1)
          cropRef = pixels.sublist((y + 1) * pitch, pixels.length);
        offset -= pitch;
        if (isFilled(pixels.sublist(offset, offset + pitch), cropRef,
            math.min(cropRefWidth, pitch), cropRefWidth, cropRefPitch))
          minY = y;
        else
          break;
      }

      if (gradientCrop) {
        cropRef = pixels.sublist((source.width - 1) * 4, pixels.length);
        cropRefWidth = 4;
        cropRefPitch = pitch;
      }

      for (int x = source.width - 1; x >= 0; --x) {
        if (gradientCrop && allowDeviation && x < source.width - 1)
          cropRef = pixels.sublist((x + 1) * 4, pixels.length);
        if (isFilled(pixels.sublist(x * 4, pixels.length), cropRef, pitch,
            cropRefWidth, cropRefPitch))
          minX = x;
        else
          break;
      }

      if (gradientCrop) {
        // gradient crop always crops aways a 1 pixel border,
        // because it compares the row/column to itself
        // if this is all we crop, we don't crop
        if (minX == source.width - 1) ++minX;
        if (minY == source.height - 1) ++minY;
        if (maxX == 0) --maxX;
        if (maxY == 0) --maxY;
      }
    }

    PixelData result = source;
    ++maxX;
    ++maxY;

    if (maxX < minX && maxY < minY) {
      int cropWidth = minX - maxX;
      int cropHeight = minY - maxY;
      int newWidth = cropWidth + borderWidth * 2;
      int newHeight = cropHeight + borderWidth * 2;

      int marginX = borderWidth;
      int marginY = borderWidth;

      if (gradientCrop) {
        int moveLeft = math.min(borderWidth, maxX);
        marginX -= moveLeft;
        cropWidth += moveLeft;
        maxX = math.max(maxX-borderWidth, 0);
        int moveTop = math.min(borderWidth, maxY);
        marginY -= moveTop;
        cropHeight += moveTop;
        maxY = math.max(maxY-borderWidth, 0);

        cropWidth += math.min(minX+borderWidth, source.width)-minX;
        cropHeight += math.min(minY+borderWidth, source.height)-minY;
      }

      result = new PixelDataBuffer(newWidth, newHeight);

      Uint32List all = result.data.buffer.asUint32List();
      if (borderWidth > 0) all.fillRange(0, all.length, refColor);

      Uint32List src = source.data.buffer.asUint32List();
      int srcWidth = source.width;

      int destOffset = marginY * newWidth + marginX;
      int srcOffset = maxY * srcWidth + maxX;

      for (int y = 0; y < cropHeight; ++y) {
        all.setAll(destOffset, src.sublist(srcOffset, srcOffset + cropWidth));
        srcOffset += srcWidth;
        destOffset += newWidth;
      }
    }

    return result;
  }
}