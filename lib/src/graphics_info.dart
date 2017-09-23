import "dart:html";
import "dart:typed_data";

class GraphicsInfo {
  const GraphicsInfo._({ this.channels, this.bitOffsets });

  static GraphicsInfo _detect() {
    CanvasElement testCanvas = document.createElement("canvas");
  	testCanvas.width = 1;
  	testCanvas.height = 1;
  	CanvasRenderingContext2D ctx = testCanvas.getContext("2d");
  	ctx.fillStyle = "rgba(10, 20, 30, 1)";
  	ctx.fillRect(0, 0, 1, 1);
  	Uint8ClampedList arr = ctx.getImageData(0, 0, 1, 1).data;
  	List<int> values = [10, 20, 30, 255];
  	List<int> channels = [];
  	List<int> bitOffsets = [];
  	Uint32List uint32Buffer = new Uint32List.view(arr.buffer);
  	int uint32Value = uint32Buffer[0];
  	for (int val in values) {
  		int channel = -1;
  		int minDiff = 256;
  		int minBitOffsetDiff = 256;
  		int bitOffset = -1;
  		for (int i=0; i<arr.length; ++i) {
  			int diff = (arr[i]-val).abs();
  			if (diff < minDiff) {
  				minDiff = diff;
  				channel = i;
  			}
  			diff = (((uint32Value >> (i*8))&0xff)-val).abs();
  			if (diff < minBitOffsetDiff) {
  				minBitOffsetDiff = diff;
  				bitOffset = i*8;
  			}
  		}
  		channels.add(channel);
  		bitOffsets.add(bitOffset);
  	}
  	return new GraphicsInfo._(
  		channels: channels,
  		bitOffsets: bitOffsets
  	);
  }

  static final GraphicsInfo current = _detect();

  String toString() => "[channels: ${channels}, bitOffsets: ${bitOffsets}]";

  final List<int> channels;
  final List<int> bitOffsets;
}
