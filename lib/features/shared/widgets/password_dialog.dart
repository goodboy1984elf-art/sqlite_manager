// lib/features/shared/widgets/password_dialog.dart
import 'package:flutter/material.dart';

Future<String?> showPasswordDialog(
  BuildContext context, {
  String title = 'Enter Password',
  bool confirmPassword = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PasswordDialog(
        title: title, confirmPassword: confirmPassword),
  );
}

class _PasswordDialog extends StatefulWidget {
  final String title;
  final bool confirmPassword;

  const _PasswordDialog(
      {required this.title, required this.confirmPassword});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pw1,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility
                    : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) =>
                widget.confirmPassword ? null : _submit(),
          ),
          if (widget.confirmPassword) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _pw2,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style:
                    const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  void _submit() {
    if (_pw1.text.isEmpty) {
      setState(() => _error = 'Password cannot be empty');
      return;
    }
    if (widget.confirmPassword && _pw1.text != _pw2.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    Navigator.of(context).pop(_pw1.text);
  }
}
