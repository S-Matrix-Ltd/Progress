import 'package:flutter/material.dart';
import '../services/i18n.dart';

/// Shadharon calculator — kono backend/package lagbe na, shudhu Dart
/// diye basic +,-,*,/ operation.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
  double _first = 0;
  String? _pendingOp;
  bool _shouldReset = false;

  void _inputDigit(String d) {
    setState(() {
      if (_display == '0' || _shouldReset) {
        _display = d;
        _shouldReset = false;
      } else {
        _display += d;
      }
    });
  }

  void _inputDot() {
    setState(() {
      if (_shouldReset) {
        _display = '0.';
        _shouldReset = false;
        return;
      }
      if (!_display.contains('.')) _display += '.';
    });
  }

  void _chooseOperator(String op) {
    setState(() {
      _first = double.tryParse(_display) ?? 0;
      _pendingOp = op;
      _shouldReset = true;
    });
  }

  void _equals() {
    if (_pendingOp == null) return;
    final second = double.tryParse(_display) ?? 0;
    double result;
    switch (_pendingOp) {
      case '+':
        result = _first + second;
        break;
      case '-':
        result = _first - second;
        break;
      case '×':
        result = _first * second;
        break;
      case '÷':
        result = second == 0 ? 0 : _first / second;
        break;
      default:
        result = second;
    }
    setState(() {
      _display = result == result.roundToDouble() ? result.toInt().toString() : result.toString();
      _pendingOp = null;
      _shouldReset = true;
    });
  }

  void _clear() {
    setState(() {
      _display = '0';
      _first = 0;
      _pendingOp = null;
      _shouldReset = false;
    });
  }

  void _backspace() {
    setState(() {
      if (_display.length <= 1) {
        _display = '0';
      } else {
        _display = _display.substring(0, _display.length - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('calculator')),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
            alignment: Alignment.centerRight,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Text(
              _display,
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _row(['C', '⌫', '÷'], primary),
                  _row(['7', '8', '9', '×'], primary),
                  _row(['4', '5', '6', '-'], primary),
                  _row(['1', '2', '3', '+'], primary),
                  _row(['0', '.', '='], primary, lastWide: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(List<String> keys, Color primary, {bool lastWide = false}) {
    return Expanded(
      child: Row(
        children: keys.map((k) {
          final isOp = ['÷', '×', '-', '+', '='].contains(k);
          final isClear = k == 'C' || k == '⌫';
          return Expanded(
            flex: (lastWide && k == '0') ? 2 : 1,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ElevatedButton(
                onPressed: () => _handleKey(k),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOp ? primary : (isClear ? const Color(0xFFFEE2E2) : Colors.white),
                  foregroundColor: isOp ? Colors.white : (isClear ? const Color(0xFFB91C1C) : const Color(0xFF0F172A)),
                  elevation: 1,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(k, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _handleKey(String k) {
    if (RegExp(r'^[0-9]$').hasMatch(k)) {
      _inputDigit(k);
    } else if (k == '.') {
      _inputDot();
    } else if (k == 'C') {
      _clear();
    } else if (k == '⌫') {
      _backspace();
    } else if (k == '=') {
      _equals();
    } else {
      _chooseOperator(k);
    }
  }
}
