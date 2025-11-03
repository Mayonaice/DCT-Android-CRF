import 'package:flutter/material.dart';
import '../services/profile_service.dart';

class TLHeaderWidget extends StatelessWidget {
  final String userName;
  final String branchName;
  final String? greetingText;
  final ProfileService? profileService;

  const TLHeaderWidget({
    Key? key,
    required this.userName,
    required this.branchName,
    this.greetingText,
    this.profileService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ProfileService _profileService = profileService ?? ProfileService();
    final String greeting = greetingText ?? 'Selamat Datang !';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            spreadRadius: 0,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Photo - smaller size
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: FutureBuilder<ImageProvider>(
                future: _profileService.getProfilePhoto(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Image(
                      image: snapshot.data!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[100],
                          child: Icon(
                            Icons.person,
                            size: 24,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                    );
                  }
                  return Container(
                    color: Colors.grey[100],
                    child: Icon(
                      Icons.person,
                      size: 24,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Greeting and Name Section - more compact
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Plain greeting text without background
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                // User name with green background
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                // Branch location - smaller
                Text(
                  branchName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color.fromARGB(255, 29, 29, 29),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // ADVANTAGE Logo - 3x larger size
          Container(
            width: 150, // 3x from 70
            height: 75, // 3x from 35
            child: Image.asset(
              'assets/images/adv-icon.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Text(
                      'ADVANTAGE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21, // 3x from 7
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}