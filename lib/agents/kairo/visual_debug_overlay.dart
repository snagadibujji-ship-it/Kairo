import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// State controller for managing visual debug overlay properties.
class VisualDebugOverlayController extends GetxController {
  var isVisible = false.obs;
  var currentGoal = ''.obs;
  var currentStep = ''.obs;
  var lastAction = ''.obs;
  var confidence = 1.0.obs;
  var detectedElementsCount = 0.obs;

  void updateState({
    required String goal,
    required String step,
    required String action,
    required double score,
    required int elementCount,
  }) {
    currentGoal.value = goal;
    currentStep.value = step;
    lastAction.value = action;
    confidence.value = score;
    detectedElementsCount.value = elementCount;
  }

  void show() {
    isVisible.value = true;
  }

  void hide() {
    isVisible.value = false;
  }
}

/// Floating premium visual debug overlay panel for agent execution visibility.
class VisualDebugOverlayWidget extends StatelessWidget {
  const VisualDebugOverlayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(VisualDebugOverlayController());

    return Obx(() {
      if (!controller.isVisible.value) return const SizedBox.shrink();

      return Positioned(
        top: 80.0,
        right: 16.0,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 280.0,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: Colors.blueAccent.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10.0,
                  spreadRadius: 2.0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8.0,
                          height: 8.0,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        const Text(
                          'KAIRO MONITOR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14.0, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => controller.hide(),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 12.0),

                // Goal
                _buildInfoRow('Goal:', controller.currentGoal.value),
                const SizedBox(height: 6.0),

                // Step
                _buildInfoRow('Step:', controller.currentStep.value),
                const SizedBox(height: 6.0),

                // Last Action
                _buildInfoRow('Action:', controller.lastAction.value),
                const SizedBox(height: 6.0),

                // Elements
                _buildInfoRow('Elements Found:', '${controller.detectedElementsCount.value} UI nodes'),
                const SizedBox(height: 6.0),

                // Confidence
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Confidence:',
                      style: TextStyle(color: Colors.grey, fontSize: 11.0),
                    ),
                    Text(
                      '${(controller.confidence.value * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: controller.confidence.value > 0.8
                            ? Colors.greenAccent
                            : controller.confidence.value > 0.5
                                ? Colors.orangeAccent
                                : Colors.redAccent,
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 9.0),
        ),
        const SizedBox(height: 2.0),
        Text(
          value.isEmpty ? 'N/A' : value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
