import 'dart:convert';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;

import 'receipt_parser.dart';

/// Reads text from a receipt image, on-device.
/// - Android / iOS: Google ML Kit text recognition.
/// - Windows: the built-in Windows.Media.Ocr engine (called through PowerShell).
abstract class OcrService {
  Future<List<OcrLine>> recognize(String imagePath);

  static OcrService? forPlatform() {
    if (Platform.isAndroid || Platform.isIOS) return MlKitOcrService();
    // Vietnamese OCR also reads English; falls back to the user's language if the pack isn't installed.
    if (Platform.isWindows) return WindowsOcrService(language: 'vi');
    return null;
  }
}

class OcrException implements Exception {
  const OcrException(this.message);
  final String message;
  @override
  String toString() => message;
}

class MlKitOcrService implements OcrService {
  @override
  Future<List<OcrLine>> recognize(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
      return [
        for (final block in result.blocks)
          for (final line in block.lines)
            OcrLine(
              line.text,
              left: line.boundingBox.left,
              top: line.boundingBox.top,
              width: line.boundingBox.width,
              height: line.boundingBox.height,
            ),
      ];
    } finally {
      await recognizer.close();
    }
  }
}

class WindowsOcrService implements OcrService {
  /// Optional OCR language, e.g. "vi" (requires the Vietnamese OCR language pack in Windows).
  WindowsOcrService({this.language});

  final String? language;

  @override
  Future<List<OcrLine>> recognize(String imagePath) async {
    final script = File(p.join(Directory.systemTemp.path, 'money_manager_ocr.ps1'));
    await script.writeAsString(_script);

    final result = await Process.run(
      'powershell',
      [
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script.path, //
        // StorageFile rejects mixed separators, so normalize to "C:\...\file.png".
        '-Path', p.normalize(File(imagePath).absolute.path),
        if (language != null) ...['-Lang', language!],
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) {
      throw OcrException('Windows OCR failed: ${(result.stderr as String).trim()}');
    }

    final json = jsonDecode((result.stdout as String).trim()) as Map<String, dynamic>;
    return [
      for (final line in (json['lines'] as List).cast<Map<String, dynamic>>())
        OcrLine(
          line['text'] as String,
          left: (line['x'] as num).toDouble(),
          top: (line['y'] as num).toDouble(),
          width: (line['w'] as num).toDouble(),
          height: (line['h'] as num).toDouble(),
        ),
    ];
  }

  static const _script = r'''
param([Parameter(Mandatory = $true)][string]$Path, [string]$Lang = "")
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType = WindowsRuntime]
$null = [Windows.Globalization.Language, Windows.Globalization, ContentType = WindowsRuntime]

$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1
function Await($op, [Type]$type) {
    $task = $asTask.MakeGenericMethod($type).Invoke($null, @($op))
    $null = $task.Wait(-1)
    $task.Result
}

# Pre-process: apply the EXIF rotation phones use, shrink huge photos (Windows OCR reads
# small thermal-printer text better around this size) and boost grayscale contrast.
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile($Path)
if ($src.PropertyIdList -contains 0x0112) {
    switch ([BitConverter]::ToUInt16($src.GetPropertyItem(0x0112).Value, 0)) {
        3 { $src.RotateFlip('Rotate180FlipNone') }
        6 { $src.RotateFlip('Rotate90FlipNone') }
        8 { $src.RotateFlip('Rotate270FlipNone') }
    }
}
$scale = [Math]::Min(1.0, 2400 / [Math]::Max($src.Width, $src.Height))
$w = [int]($src.Width * $scale); $h = [int]($src.Height * $scale)
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = 'HighQualityBicubic'
$c = 2.0; $t = (1 - $c) / 2
$r = 0.299 * $c; $gr = 0.587 * $c; $b = 0.114 * $c
$matrix = New-Object System.Drawing.Imaging.ColorMatrix (, [single[][]]@(
    [single[]]@($r, $r, $r, 0, 0),
    [single[]]@($gr, $gr, $gr, 0, 0),
    [single[]]@($b, $b, $b, 0, 0),
    [single[]]@(0, 0, 0, 1, 0),
    [single[]]@($t, $t, $t, 0, 1)))
$attributes = New-Object System.Drawing.Imaging.ImageAttributes
$attributes.SetColorMatrix($matrix)
$g.DrawImage($src, (New-Object System.Drawing.Rectangle 0, 0, $w, $h), 0, 0, $src.Width, $src.Height, 'Pixel', $attributes)
$g.Dispose(); $src.Dispose()
$prepared = Join-Path ([IO.Path]::GetTempPath()) 'money_manager_ocr_input.png'
$bmp.Save($prepared, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()

$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($prepared)) ([Windows.Storage.StorageFile])
$stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
$decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
$bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])

$engine = $null
if ($Lang) {
    $wanted = [Windows.Globalization.Language]::new($Lang)
    if ([Windows.Media.Ocr.OcrEngine]::IsLanguageSupported($wanted)) {
        $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($wanted)
    }
}
if (-not $engine) { $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages() }
if (-not $engine) { throw "No Windows OCR language is installed." }

$result = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
$lines = foreach ($line in $result.Lines) {
    $rects = $line.Words | ForEach-Object { $_.BoundingRect }
    $minX = ($rects | ForEach-Object { $_.X } | Measure-Object -Minimum).Minimum
    $minY = ($rects | ForEach-Object { $_.Y } | Measure-Object -Minimum).Minimum
    $maxX = ($rects | ForEach-Object { $_.X + $_.Width } | Measure-Object -Maximum).Maximum
    $maxY = ($rects | ForEach-Object { $_.Y + $_.Height } | Measure-Object -Maximum).Maximum
    [ordered]@{ text = $line.Text; x = $minX; y = $minY; w = $maxX - $minX; h = $maxY - $minY }
}
[ordered]@{ width = $bitmap.PixelWidth; height = $bitmap.PixelHeight; lines = @($lines) } | ConvertTo-Json -Depth 4 -Compress
''';
}
