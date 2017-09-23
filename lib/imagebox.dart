library imagebox;

import "dart:html";
import "dart:async";

import "package:imagebox/src/graphics_info.dart";
import "package:imagebox/src/drop_listeners.dart";
import "package:imagebox/src/image_document.dart";
import "package:imagebox/src/pipeline.dart";
import "package:imagebox/src/pixel.dart";
import "package:imagebox/src/control.dart";

class InputImageBlobSource {
  InputImageBlobSource(this.inputFileElement) {
    inputFileElement.onChange.listen(_changeHandler);
  }

  void _changeHandler(Event event) {
    List<File> files = (event.target as InputElement).files;
    _onBlob.addStream(new Stream.fromIterable(files));
  }

  StreamController<Blob> _onBlob = new StreamController();
  Stream<Blob> get onBlob => _onBlob.stream;

  final InputElement inputFileElement;
}

class ImageBoxApp {
  void initialize() {
    window.console.log(GraphicsInfo.current.toString());
    viewTemplate = document.querySelector(".view");
    viewTemplate.remove();
    new ImageDropBlobSource(document.body).onBlob.listen(handleBlob);
    new InputImageBlobSource(document.querySelector("#background"))
        .onBlob
        .listen(handleBlob);
    _setupSlider(1.0, 64, "borderWidth");
    _setupSlider(1.0, 255, "differenceDelta");

    differenceDelta = querySelector("#differenceDelta");
    borderWidth = querySelector("#borderWidth");
    disableCrop = querySelector("#disableCrop");
    transparentCartoon = querySelector("#transparentCartoon");
    gradientCrop = querySelector("#gradientCrop");
    allowDeviation = querySelector("#allowDeviation");

    _syncDeviation();

    gradientCrop.addEventListener("input", (_) => _syncDeviation());
    gradientCrop.addEventListener("change", (_) => _syncDeviation());
    differenceDelta.addEventListener("input", (_) => _syncDeviation());
    querySelector("#differenceDeltaRange")
        .addEventListener("input", (_) => _syncDeviation());
  }

  void handleBlob(Blob blob) {
    Pipeline pipeline = new Pipeline(createProcess);
    ImageDocument.load(blob, pipeline).then((ImageDocument doc) async {
      ImageDocumentView docView = new ImageDocumentView(viewTemplate, doc);
      document.body.append(docView.view);
    });
  }

  PipelineProcess createProcess(
          CanvasRenderingContext2D context, PixelData source) =>
      new CropProcess(context, source)
        ..doCrop = !disableCrop.checked
        ..transparentCartoon = transparentCartoon.checked
        ..gradientCrop = gradientCrop.checked
        ..allowDeviation = allowDeviation.checked
        ..borderWidth = int.parse(borderWidth.value)
        ..differenceDelta = int.parse(differenceDelta.value);

  void _syncDeviation() {
    allowDeviation.disabled =
        !gradientCrop.checked || int.parse(differenceDelta.value) == 0;
  }

  void _setupSlider(double expOffset, int maxValue, String idBase) {
    exponentialSlider(expOffset, maxValue, querySelector("#${idBase}Range"),
        querySelector("#${idBase}"));
  }

  Element viewTemplate;

  InputElement differenceDelta;
  InputElement borderWidth;
  InputElement disableCrop;
  InputElement transparentCartoon;
  InputElement gradientCrop;
  InputElement allowDeviation;
}
