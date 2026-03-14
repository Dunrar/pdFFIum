import 'dart:async';

import 'package:pdffium/src/features/pdf/presentation/pdf_document_viewer.dart';
import 'package:pdffium/src/features/pdf/presentation/pdf_document_viewer_scrollbar.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    title: 'Annotate your PDFs',
    home: AnnotatorApp(),
  ));
}

class AnnotatorApp extends StatelessWidget {
  const AnnotatorApp({super.key});

  Future<FilePickerResult?> _pickFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null) return null;

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final PdfDocumentViewController documentController = PdfDocumentViewController();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.green[100],
        appBar: AppBar(
          title: const Text('Home'),
        ),
        body: Center(
          child: MaterialButton(
            onPressed: () async {
              FilePickerResult? filePath = await _pickFile();
              if (context.mounted && filePath != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PdfDocumentViewer(
                        filePath: filePath.files.single.path!,
                        documentController: documentController,
                        cacheExtent: MediaQuery.of(context).size.height,
                        pageMargin: const EdgeInsets.all(5.0),
                        pageDecoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              spreadRadius: 1,
                              blurRadius: 1,
                            ),
                          ],
                        ),
                        viewerOverlayBuilder: (context, size) {
                          return [
                            Align(
                              alignment: Alignment.centerRight,
                              child: PdfDocumentViewerScrollbar(
                                controller: documentController,
                                constraints: BoxConstraints.tight(size),
                              ),
                            ),
                          ];
                        }),
                  ),
                );
              }
            },
            color: Colors.green,
            child: const Text(
              'Pick and open file',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
