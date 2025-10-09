import 'package:flutter/material.dart';

class TLSupervisorDialog extends StatefulWidget {
  final Function(String nik, String password) onValidate;
  final VoidCallback onCancel;

  const TLSupervisorDialog({
    Key? key,
    required this.onValidate,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<TLSupervisorDialog> createState() => _TLSupervisorDialogState();
}

class _TLSupervisorDialogState extends State<TLSupervisorDialog> {
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isValidating = false;
  String _errorMessage = '';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nikController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validate() {
    // Basic validation
    if (_nikController.text.isEmpty) {
      setState(() {
        _errorMessage = 'NIK tidak boleh kosong';
      });
      return;
    }

    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Password tidak boleh kosong';
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = '';
    });

    // Call the validation function
    widget.onValidate(_nikController.text, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 768;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: isTablet ? 500 : 320,
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.security,
                  color: Colors.green,
                  size: isTablet ? 28 : 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Validasi TL Supervisor',
                  style: TextStyle(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: isTablet ? 20 : 16),

            // Description
            Text(
              'Masukkan NIK dan Password TL Supervisor untuk melanjutkan proses submit data.',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: isTablet ? 24 : 20),

            // NIK Field
            Text(
              'NIK TL Supervisor',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nikController,
              decoration: InputDecoration(
                hintText: 'Masukkan NIK',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: isTablet ? 16 : 12,
                  horizontal: isTablet ? 16 : 12,
                ),
              ),
              enabled: !_isValidating,
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: isTablet ? 16 : 12),

            // Password Field
            Text(
              'Password',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Masukkan Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: isTablet ? 16 : 12,
                  horizontal: isTablet ? 16 : 12,
                ),
              ),
              enabled: !_isValidating,
            ),
            SizedBox(height: isTablet ? 16 : 12),

            // Error message
            if (_errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: isTablet ? 14 : 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: isTablet ? 24 : 20),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Cancel button
                TextButton(
                  onPressed: _isValidating ? null : widget.onCancel,
                  child: Text(
                    'Batal',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Validate button
                ElevatedButton.icon(
                  onPressed: _isValidating ? null : _validate,
                  icon: _isValidating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.check, size: isTablet ? 18 : 16),
                  label: Text(
                    _isValidating ? 'Memvalidasi...' : 'Validasi',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 16,
                      vertical: isTablet ? 12 : 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}