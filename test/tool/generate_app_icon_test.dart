import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../../tool/generate_app_icon.dart';

void main() {
  test('creates an opaque 1024 square with marble at every edge', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'crown-app-icon-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final outputPath = '${temporaryDirectory.path}/AppIconSquare.png';

    await generateAppIcon(
      sourcePath: 'assets/AppIcon.png',
      outputPath: outputPath,
    );

    final generated = image.decodePng(await File(outputPath).readAsBytes());
    expect(generated, isNotNull);
    expect(generated!.width, 1024);
    expect(generated.height, 1024);
    expect(generated.getPixel(0, 0).a, 255);
    expect(generated.getPixel(1023, 1023).a, 255);

    final borderPixels = <image.Pixel>[
      for (var offset = 0; offset < 1024; offset += 32) ...[
        generated.getPixel(offset, 0),
        generated.getPixel(offset, 1023),
        generated.getPixel(0, offset),
        generated.getPixel(1023, offset),
      ],
    ];
    expect(
      borderPixels.every((pixel) => (pixel.r + pixel.g + pixel.b) / 3 > 150),
      isTrue,
      reason: 'Every generated edge must contain light marble.',
    );
  });

  test(
    'creates a warm ivory marble texture without embedded artwork',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'marble-background-',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));
      final outputPath = '${temporaryDirectory.path}/MarbleBackground.png';
      final sourceBytes = await File('assets/AppIcon.png').readAsBytes();

      await generateMarbleBackground(
        sourcePath: 'assets/AppIcon.png',
        outputPath: outputPath,
      );

      final generated = image.decodePng(await File(outputPath).readAsBytes())!;
      expect((generated.width, generated.height), (1024, 1024));
      expect(await File('assets/AppIcon.png').readAsBytes(), sourceBytes);
      expect(generated.every((pixel) => pixel.a == 255), isTrue);

      final average = _averageChannels(generated);
      expect(average.$1, greaterThan(average.$2));
      expect(average.$2, greaterThan(average.$3));
      expect(average.$3, greaterThan(180));
      expect(_luminanceRange(generated), inInclusiveRange(45, 125));
    },
  );

  test('extracts the unchanged crown onto a transparent 1024 canvas', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'crown-logo-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final iconPath = '${temporaryDirectory.path}/AppIconSquare.png';
    final logoPath = '${temporaryDirectory.path}/CrownLogo.png';

    await generateAppIcon(
      sourcePath: 'assets/AppIcon.png',
      outputPath: iconPath,
    );
    await generateCrownLogo(
      sourcePath: 'assets/AppIcon.png',
      outputPath: logoPath,
    );

    final icon = image.decodePng(await File(iconPath).readAsBytes())!;
    final logo = image.decodePng(await File(logoPath).readAsBytes())!;
    expect(logo.width, 1024);
    expect(logo.height, 1024);
    expect(logo.numChannels, 4);

    for (final (x, y) in [
      (512, 164),
      (173, 367),
      (855, 367),
      (512, 500),
      (512, 810),
    ]) {
      final iconPixel = icon.getPixel(x, y);
      final logoPixel = logo.getPixel(x, y);
      expect(logoPixel.a, 255, reason: 'Expected crown at ($x, $y).');
      expect(
        (logoPixel.r, logoPixel.g, logoPixel.b),
        (iconPixel.r, iconPixel.g, iconPixel.b),
      );
    }

    for (final (x, y) in [
      (0, 0),
      (512, 70),
      (512, 755),
      (512, 890),
      (100, 500),
      (930, 500),
    ]) {
      expect(
        logo.getPixel(x, y).a,
        0,
        reason: 'Expected transparency at ($x, $y).',
      );
    }

    expect(
      logo.any((pixel) => pixel.a > 0 && pixel.a < 255),
      isTrue,
      reason: 'The extracted silhouette must retain antialiased edges.',
    );
  });

  test('creates outward-tilted halves along a diagonal fracture', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'broken-crown-logo-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final logoPath = '${temporaryDirectory.path}/CrownLogo.png';
    final brokenPath = '${temporaryDirectory.path}/BrokenCrownLogo.png';
    await generateCrownLogo(
      sourcePath: 'assets/AppIcon.png',
      outputPath: logoPath,
    );
    final originalBytes = await File(logoPath).readAsBytes();

    await generateBrokenCrownLogo(sourcePath: logoPath, outputPath: brokenPath);

    final logo = image.decodePng(originalBytes)!;
    final broken = image.decodePng(await File(brokenPath).readAsBytes())!;
    expect(broken.width, 1024);
    expect(broken.height, 1024);
    expect(broken.numChannels, 4);
    expect(await File(logoPath).readAsBytes(), orderedEquals(originalBytes));

    for (final (x, y) in [
      (0, 0),
      (1023, 0),
      (0, 1023),
      (1023, 1023),
      (505, 158),
      (540, 493),
      (567, 693),
      (602, 803),
    ]) {
      expect(
        broken.getPixel(x, y).a,
        0,
        reason: 'Expected transparent separation at ($x, $y).',
      );
    }
    expect(broken.getPixel(350, 500).a, greaterThan(200));
    expect(broken.getPixel(674, 500).a, greaterThan(200));
    expect(
      broken.getPixel(445, 158).a,
      greaterThan(200),
      reason: 'The left finial fragment must remain part of the left half.',
    );
    expect(
      broken.getPixel(512, 810).a,
      greaterThan(200),
      reason: 'A diagonal base fracture must sit to the right of center.',
    );
    expect(broken.any((pixel) => pixel.a > 0 && pixel.a < 255), isTrue);

    final originalChroma = _averageChroma(logo);
    final brokenChroma = _averageChroma(broken);
    expect(brokenChroma, greaterThan(1));
    expect(brokenChroma, lessThan(originalChroma * .25));
  });

  test('creates detailed metallic balanced scales for draw outcomes', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'draw-logo-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final logoPath = '${temporaryDirectory.path}/CrownLogo.png';
    final drawPath = '${temporaryDirectory.path}/DrawLogo.png';
    await generateCrownLogo(
      sourcePath: 'assets/AppIcon.png',
      outputPath: logoPath,
    );
    final originalBytes = await File(logoPath).readAsBytes();

    await generateDrawLogo(sourcePath: logoPath, outputPath: drawPath);

    final logo = image.decodePng(originalBytes)!;
    final draw = image.decodePng(await File(drawPath).readAsBytes())!;
    expect((draw.width, draw.height, draw.numChannels), (1024, 1024, 4));
    expect(await File(logoPath).readAsBytes(), orderedEquals(originalBytes));
    for (final (x, y) in [
      (512, 145),
      (512, 230),
      (185, 350),
      (512, 500),
      (270, 610),
      (754, 610),
      (512, 815),
    ]) {
      expect(draw.getPixel(x, y).a, greaterThan(200));
    }
    for (final (x, y) in [(0, 0), (1023, 1023), (512, 910)]) {
      expect(draw.getPixel(x, y).a, 0);
    }
    expect(draw.any((pixel) => pixel.a > 0 && pixel.a < 255), isTrue);
    expect(_averageChroma(draw), greaterThan(_averageChroma(logo) * .5));
    expect(_luminanceRange(draw), greaterThan(140));
  });

  test('rejects a source with unexpected dimensions', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'crown-app-icon-invalid-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final sourcePath = '${temporaryDirectory.path}/source.png';
    await File(sourcePath)
        .writeAsBytes(image.encodePng(image.Image(width: 100, height: 100)));

    expect(
      () => generateAppIcon(
        sourcePath: sourcePath,
        outputPath: '${temporaryDirectory.path}/output.png',
      ),
      throwsStateError,
    );
  });
}

double _averageChroma(image.Image source) {
  var total = 0.0;
  var count = 0;
  for (final pixel in source) {
    if (pixel.a < 200) continue;
    final channels = [
      pixel.r.toDouble(),
      pixel.g.toDouble(),
      pixel.b.toDouble(),
    ]..sort();
    total += channels.last - channels.first;
    count++;
  }
  return total / count;
}

(double, double, double) _averageChannels(image.Image source) {
  var red = 0.0;
  var green = 0.0;
  var blue = 0.0;
  for (final pixel in source) {
    red += pixel.r;
    green += pixel.g;
    blue += pixel.b;
  }
  return (red / source.length, green / source.length, blue / source.length);
}

double _luminanceRange(image.Image source) {
  var darkest = 255.0;
  var lightest = 0.0;
  for (final pixel in source) {
    if (pixel.a < 200) continue;
    final luminance =
        pixel.r.toDouble() * .2126 +
        pixel.g.toDouble() * .7152 +
        pixel.b.toDouble() * .0722;
    darkest = math.min(darkest, luminance);
    lightest = math.max(lightest, luminance);
  }
  return lightest - darkest;
}
