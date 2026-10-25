import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/l10n.dart';
import '../services/ocr_service.dart';
import '../services/receipt_parser.dart';
import '../state/app_state.dart';
import 'transaction_editor.dart';

bool get _hasCamera => Platform.isAndroid || Platform.isIOS;

/// The "+" button: scan a receipt, pick an image, paste receipt text, or type it in.
class AddTransactionButton extends StatelessWidget {
  const AddTransactionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => showCaptureSheet(context),
      icon: const Icon(Icons.add),
      label: Text(context.l10n.add),
    );
  }
}

Future<void> showCaptureSheet(BuildContext context) async {
  final l = context.l10n;
  final choice = await showModalBottomSheet<_Source>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasCamera)
            ListTile(
              leading: const Icon(Icons.document_scanner),
              title: Text(l.scanWithCamera),
              onTap: () => Navigator.pop(context, _Source.camera),
            ),
          ListTile(
            leading: const Icon(Icons.image),
            title: Text(_hasCamera ? l.importFromGallery : l.importImage),
            onTap: () => Navigator.pop(context, _Source.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.content_paste),
            title: Text(l.pasteReceiptText),
            onTap: () => Navigator.pop(context, _Source.text),
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(l.addManually),
            onTap: () => Navigator.pop(context, _Source.manual),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  switch (choice) {
    case _Source.camera:
      await _fromImage(context, ImageSource.camera);
    case _Source.gallery:
      await _fromImage(context, ImageSource.gallery);
    case _Source.text:
      await _fromText(context);
    case _Source.manual:
      await openTransactionEditor(context, TransactionDraft());
  }
}

enum _Source { camera, gallery, text, manual }

ReceiptParser _parser() =>
    ReceiptParser(prefersDayFirst: !Platform.localeName.replaceAll('-', '_').startsWith('en_US'));

Future<void> _fromImage(BuildContext context, ImageSource source) async {
  final picked = await ImagePicker().pickImage(source: source, maxWidth: 2000, imageQuality: 85);
  if (picked == null || !context.mounted) return;

  final state = AppScope.of(context);
  final l = context.l10n;
  final ocr = OcrService.forPlatform();
  final navigator = Navigator.of(context);
  ParsedReceipt? receipt;
  String? error;
  String? imagePath;

  _showProgress(context);
  try {
    if (ocr == null) throw OcrException(l.ocrUnavailable);
    receipt = _parser().parseLines(await ocr.recognize(picked.path));
  } catch (e) {
    error = '$e';
  }
  try {
    imagePath = await state.storeReceiptImage(picked.path);
  } catch (_) {
    // Keep going without the image attached.
  } finally {
    navigator.pop(); // progress dialog
  }
  if (!context.mounted) return;

  final draft = receipt != null
      ? TransactionDraft.fromReceipt(receipt, receiptPath: imagePath)
      : TransactionDraft(receiptPath: imagePath, notice: DraftNotice.scanFailed, scanError: error);
  final saved = await openTransactionEditor(context, draft);
  if (!saved && imagePath != null) {
    try {
      await File(imagePath).delete();
    } catch (_) {}
  }
}

Future<void> _fromText(BuildContext context) async {
  final l = context.l10n;
  final controller = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.pasteReceiptText),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: controller,
          autofocus: true,
          minLines: 8,
          maxLines: 16,
          decoration: const InputDecoration(
            hintText: 'Highlands Coffee\n25/10/2026 08:15\nPhin Sữa Đá 29.000\nTổng cộng 29.000',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(l.readText)),
      ],
    ),
  );
  controller.dispose();
  if (text == null || text.trim().isEmpty || !context.mounted) return;
  await openTransactionEditor(context, TransactionDraft.fromReceipt(_parser().parseText(text)));
}

void _showProgress(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Text(context.l10n.readingReceipt),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
