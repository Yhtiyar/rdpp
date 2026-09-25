import 'package:flutter/material.dart';

import '../../ui/theme.dart';

class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onCompleted, this.enabled = true});
  final ValueChanged<String> onCompleted;
  final bool enabled;
  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _value = '';
  void _press(String digit) {
    if (!widget.enabled) {
      return;
    }
    setState(() {
      if (digit == 'delete') {
        if (_value.isNotEmpty) {
          _value = _value.substring(0, _value.length - 1);
        }
      } else if (_value.length < 6) {
        _value += digit;
      }
    });
    if (_value.length == 6) {
      final value = _value;
      setState(() => _value = '');
      widget.onCompleted(value);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        label: '${_value.length} of 6 digits entered',
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            6,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 23,
              height: 23,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _value.length ? WinTheme.purple : WinTheme.lavender,
                border: Border.all(color: const Color(0xFFE7DEFC), width: 2),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 22),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.9,
        children:
            ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'delete']
                .map(
                  (digit) => digit.isEmpty
                      ? const SizedBox()
                      : Material(
                          color: WinTheme.lavender,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: widget.enabled ? () => _press(digit) : null,
                            borderRadius: BorderRadius.circular(20),
                            child: Center(
                              child: digit == 'delete'
                                  ? const Icon(
                                      Icons.backspace_outlined,
                                      semanticLabel: 'Delete digit',
                                      color: WinTheme.ink,
                                    )
                                  : Text(
                                      digit,
                                      style: const TextStyle(
                                        fontSize: 25,
                                        color: WinTheme.ink,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                )
                .toList(),
      ),
    ],
  );
}
