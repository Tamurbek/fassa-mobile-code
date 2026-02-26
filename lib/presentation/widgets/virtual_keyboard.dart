import 'package:flutter/material.dart';

class VirtualKeyboard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onEnter;

  const VirtualKeyboard({
    super.key,
    required this.controller,
    required this.onEnter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow(['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']),
          const SizedBox(height: 4),
          _buildRow(['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P']),
          const SizedBox(height: 4),
          _buildRow(['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L']),
          const SizedBox(height: 4),
          _buildRow(['Z', 'X', 'C', 'V', 'B', 'N', 'M', '.', '_', '-']),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildKey('SHIFT', () {}, color: Colors.grey.shade400),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 5,
                child: _buildKey('SPACE', () => _input(' ')),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 2,
                child: _buildKey('⌫', _backspace, color: Colors.red.shade100, textColor: Colors.red),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 2,
                child: _buildKey('OK', onEnter, color: Colors.green.shade400, textColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _buildKey(key, () => _input(key)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKey(String label, VoidCallback onTap, {Color? color, Color? textColor}) {
    return Material(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 45,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor ?? Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  void _input(String text) {
    final val = controller.text;
    final selection = controller.selection;
    final newText = val.replaceRange(selection.start, selection.end, text);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + text.length),
    );
  }

  void _backspace() {
    final val = controller.text;
    final selection = controller.selection;
    if (selection.start > 0) {
      final newText = val.replaceRange(selection.start - 1, selection.start, '');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start - 1),
      );
    }
  }
}
