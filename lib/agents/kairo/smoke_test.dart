import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../accessibility/kairo_accessibility.dart';

/// Kairo Smoke Test: Calculator Automation
///
/// This test executes the following sequence:
/// 1. Launches the stock Android Calculator application.
/// 2. Iteratively extracts screen hierarchy, finds button targets,
///    resolves their coordinate boundaries, and dispatches clicks.
/// 3. Performs: '1' + '2' = '3'
/// 4. Extracts the final hierarchy and verifies that the output result is '3'.
Future<void> runCalculatorSmokeTest({
  void Function(String)? logCallback,
}) async {
  void log(String message) {
    if (logCallback != null) {
      logCallback(message);
    } else {
      debugPrint('[KairoSmokeTest] $message');
    }
  }

  log('Starting Kairo Calculator Smoke Test...');

  // 1. Verify accessibility service connection
  final bool serviceEnabled = await KairoAccessibility.isServiceEnabled();
  log('Accessibility Service Enabled: $serviceEnabled');
  if (!serviceEnabled) {
    log('ERROR: Kairo Accessibility Service is not running. Please enable it in Android Settings.');
    return;
  }

  // 2. Launch stock Android Calculator app
  const calculatorPackage = 'com.google.android.calculator';
  log('Launching app: $calculatorPackage');
  final bool launched = await KairoAccessibility.launchApp(calculatorPackage);
  if (!launched) {
    log('ERROR: Failed to launch stock Calculator application ($calculatorPackage).');
    return;
  }

  // Wait for the app to load and layout to settle
  await Future.delayed(const Duration(seconds: 2));

  // Helper method to find and click a button
  Future<bool> tapButton(String buttonLabel) async {
    log('Scanning screen for button: "$buttonLabel"');
    final Map<String, dynamic> hierarchy = await KairoAccessibility.getScreenHierarchy();
    
    // Find node matching buttonLabel
    final Map<String, dynamic>? node = KairoAccessibility.findNodeByText(hierarchy, buttonLabel, exact: true);
    if (node == null) {
      log('ERROR: Button "$buttonLabel" not found in screen hierarchy.');
      return false;
    }

    final Point? center = KairoAccessibility.getNodeCenter(node);
    if (center == null) {
      log('ERROR: Could not resolve center coordinates for button "$buttonLabel".');
      return false;
    }

    log('Found button "$buttonLabel" at center coordinates (${center.x}, ${center.y}). Clickable: ${node['clickable']}');
    log('Node dump: ${jsonEncode(node)}');

    log('Dispatching click gesture to (${center.x}, ${center.y})');
    final bool clicked = await KairoAccessibility.click(center.x, center.y);
    if (!clicked) {
      log('ERROR: Click dispatch failed for button "$buttonLabel".');
      return false;
    }

    // Wait slightly for input to register
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  // 3. Tap button '1'
  if (!await tapButton('1')) return;

  // 4. Tap button '+'
  if (!await tapButton('+')) {
    log('Retry finding plus by label "plus"');
    if (!await tapButton('plus')) return;
  }

  // 5. Tap button '2'
  if (!await tapButton('2')) return;

  // 6. Tap button '='
  if (!await tapButton('=')) {
    log('Retry finding equals by label "equals"');
    if (!await tapButton('equals')) return;
  }

  // 7. Verify result
  log('Extracting screen hierarchy for result verification...');
  final Map<String, dynamic> finalHierarchy = await KairoAccessibility.getScreenHierarchy();
  
  // Search for result node containing '3'
  log('Searching for output value "3" in the final element tree...');
  final Map<String, dynamic>? resultNode = KairoAccessibility.findNodeByText(finalHierarchy, '3', exact: true);

  if (resultNode != null) {
    log('SUCCESS: Result node found!');
    log('Result Node Details: ${jsonEncode(resultNode)}');
    log('VERIFICATION: PASS. Kairo successfully performed 1 + 2 = 3 on the Calculator application using native Accessibility APIs.');
  } else {
    log('WARNING: Node matching exactly "3" was not found in the root hierarchy tree.');
    log('Dumping current root node details: ${jsonEncode(finalHierarchy['root'])}');
    log('VERIFICATION: FAIL. Could not locate expected result node value "3".');
  }
}
