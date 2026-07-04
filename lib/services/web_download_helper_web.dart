// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadWebCsv(String csvContent, String fileName) {
  final blob = html.Blob(['\uFEFF', csvContent], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
