import "dart:html";
import "dart:math" as math;

typedef String MappingFunction(String value);

void bindValues(
    InputElement input, Element output, MappingFunction mapper) {
  String prefix = output.getAttribute("data-prefix") ?? "";
  if (mapper == null) mapper = (value) => value;
  var update = (Event e) {
    String value = prefix + mapper(input.value);;
    if (output is OutputElement)
      output.value = value;
    if (output is InputElement)
      output.value = value;
  };
  input.onInput.listen(update);
  update(null);
}

void exponentialSlider(double expOffset, int maxValue, InputElement range,
    InputElement numeric) {
  double offset = math.exp(expOffset);
  double scale = (math.log(maxValue + offset) - expOffset) / num.parse(range.max);
  bindValues(
      numeric,
      range,
      (String e) => ((math.log(num.parse(e) + offset) - expOffset) / scale)
          .round()
          .toString());
  bindValues(
      range,
      numeric,
      (String e) => ((math.exp(num.parse(e) * scale + expOffset) - offset))
          .round()
          .toString());
}
