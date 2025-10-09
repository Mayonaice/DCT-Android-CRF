import 'package:flutter/material.dart';

class CustomModals {
  // Success Modal
  static Future<void> showSuccessModal({
    required BuildContext context,
    required String message,
    String buttonText = 'Oke',
    Function()? onPressed,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isTablet = screenWidth > 600;
        
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? screenWidth * 0.3 : 40.0, // Fixed padding for mobile
            vertical: 24.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            width: isTablet ? null : screenWidth - 80, // Explicit width for mobile
            constraints: BoxConstraints(
              maxWidth: isTablet ? screenWidth * 0.4 : screenWidth - 80,
              minWidth: isTablet ? 300 : screenWidth - 80,
            ),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Berhasil',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 20),
                      Image.asset(
                        'assets/images/Berhasil Icon.png',
                        width: 112,
                        height: 112,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        alignment: Alignment.center,
                        width: isTablet ? screenWidth * 0.16 : 120, // Fixed width for mobile
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1CAA31),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: onPressed ?? () => Navigator.of(context).pop(),
                          child: Text(buttonText),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Image.asset(
                      'assets/images/Silang Icon.png',
                      width: 36,
                      height: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Confirmation Modal
  static Future<bool> showConfirmationModal({
    required BuildContext context,
    required String message,
    String confirmText = 'Oke',
    String cancelText = 'Tidak',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isTablet = screenWidth > 600;
        
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? screenWidth * 0.3 : 40.0, // Fixed padding for mobile
            vertical: 24.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            width: isTablet ? null : screenWidth - 80, // Explicit width for mobile
            constraints: BoxConstraints(
              maxWidth: isTablet ? screenWidth * 0.4 : screenWidth - 80,
              minWidth: isTablet ? 300 : screenWidth - 80,
            ),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Confirmation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 20),
                      Image.asset(
                        'assets/images/Confirmation Icon.png',
                        width: 112,
                        height: 112,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        alignment: Alignment.center,
                        width: isTablet ? screenWidth * 0.16 : 120, // Fixed width for mobile
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1CAA31),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(confirmText),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        alignment: Alignment.center,
                        width: isTablet ? screenWidth * 0.16 : 120, // Fixed width for mobile
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(cancelText),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Image.asset(
                      'assets/images/Silang Icon.png',
                      width: 36,
                      height: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  // Failed Modal
  static Future<void> showFailedModal({
    required BuildContext context,
    required String message,
    String buttonText = 'Oke',
    Function()? onPressed,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isTablet = screenWidth > 600;
        
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? screenWidth * 0.3 : 40.0, // Fixed padding for mobile
            vertical: 24.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            width: isTablet ? null : screenWidth - 80, // Explicit width for mobile
            constraints: BoxConstraints(
              maxWidth: isTablet ? screenWidth * 0.4 : screenWidth - 80,
              minWidth: isTablet ? 300 : screenWidth - 80,
            ),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Failed',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 20),
                      Image.asset(
                        'assets/images/Failed Icon.png',
                        width: 112,
                        height: 112,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        alignment: Alignment.center,
                        width: isTablet ? screenWidth * 0.16 : 120, // Fixed width for mobile
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: onPressed ?? () => Navigator.of(context).pop(),
                          child: Text(buttonText),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Image.asset(
                      'assets/images/Silang Icon.png',
                      width: 36,
                      height: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Manual Mode Input Modal for Alasan and Remark
  static Future<Map<String, String>?> showManualModeInputModal({
    required BuildContext context,
    required String fieldName,
    String? initialAlasan,
    String? initialRemark,
  }) async {
    final alasanController = TextEditingController(text: initialAlasan ?? '');
    final remarkController = TextEditingController(text: initialRemark ?? '');
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.2, // 20% margin on each side = 60% width
            vertical: 24.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      'Manual Mode - $fieldName',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 20),
                    const Text(
                      'Alasan:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: alasanController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Masukkan alasan manual mode',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Remark:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: remarkController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Masukkan remark',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(null),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1CAA31),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              if (alasanController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Alasan harus diisi'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (remarkController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Remark harus diisi'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              Navigator.of(context).pop({
                                'alasan': alasanController.text.trim(),
                                'remark': remarkController.text.trim(),
                              });
                            },
                            child: const Text('Simpan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(null),
                  child: Image.asset(
                    'assets/images/Silang Icon.png',
                    width: 36,
                    height: 36,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    
    alasanController.dispose();
    remarkController.dispose();
    
    return result;
  }
}