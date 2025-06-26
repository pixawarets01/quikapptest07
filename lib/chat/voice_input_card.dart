import 'package:flutter/material.dart';
import 'dart:math' as math;

class VoiceInputCard extends StatefulWidget {
  final bool isListening;
  final String recognizedText;
  final VoidCallback onClose;

  const VoiceInputCard({
    super.key,
    required this.isListening,
    required this.recognizedText,
    required this.onClose, required void Function(String text) onResult,
  });

  @override
  State<VoiceInputCard> createState() => _VoiceInputCardState();
}

class _VoiceInputCardState extends State<VoiceInputCard> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  final List<double> _waveSpeeds = List.generate(6, (index) => (index + 1) * 0.3);
  final List<double> _wavePhases = List.generate(6, (index) => index * math.pi / 4);

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: SizedBox(
          // width: 500,
          height: 700,
          child:  AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.4,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.isListening) ...[
                    ...List.generate(6, (index) => _buildWaveCircle(index)),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic,
                        color: Colors.white,
                        size: 37,
                      ),
                    ),
                  ] else
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mic_off,
                        color: Colors.grey.shade700,
                        size: 37,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                widget.isListening ? 'Listening...' : 'Processing...',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.recognizedText.isNotEmpty)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        widget.recognizedText,
                        style: const TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: widget.onClose,
                child: const Text('Close'),
              ),
            ],
          ),
        ),),
      ),
    );
  }

  Widget _buildWaveCircle(int index) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final value = math.sin(
          _waveController.value * 2 * math.pi * _waveSpeeds[index] + _wavePhases[index]
        ).abs();
        
        return Container(
          width: 80 + (value * 100),
          height: 80 + (value * 100),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.2 - (index * 0.03)),
              width: 2,
            ),
          ),
        );
      },
    );
  }
} 