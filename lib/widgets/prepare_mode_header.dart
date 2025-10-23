import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../screens/profile_menu_screen.dart';
import '../widgets/custom_modals.dart';

class PrepareModeHeader extends StatefulWidget {
  final String branchName;
  final String userName;
  final Map<String, dynamic>? userData;
  final VoidCallback onRefresh;

  const PrepareModeHeader({
    Key? key,
    required this.branchName,
    required this.userName,
    required this.userData,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<PrepareModeHeader> createState() => _PrepareModeHeaderState();
}

class _PrepareModeHeaderState extends State<PrepareModeHeader> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  
  // Cache untuk data yang sudah di-load
  String? _cachedMeja;
  String? _cachedNik;
  ImageProvider? _cachedProfilePhoto;
  bool _isLoadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  void _loadCachedData() async {
    // Load data sekali saja dan cache hasilnya
    if (widget.userData != null) {
      _cachedMeja = widget.userData!['noMeja'] ?? 
                   widget.userData!['NoMeja'] ?? 
                   '010101';
      _cachedNik = widget.userData!['userId'] ?? 
                  widget.userData!['userID'] ?? 
                  '';
    }

    // Load profile photo sekali saja
    if (!_isLoadingPhoto) {
      _isLoadingPhoto = true;
      try {
        final photo = await _profileService.getProfilePhoto();
        if (mounted) {
          setState(() {
            _cachedProfilePhoto = photo;
            _isLoadingPhoto = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoadingPhoto = false;
          });
        }
      }
    }
  }

  void _handleRefreshWithConfirmation() async {
    final confirmed = await CustomModals.showConfirmationModal(
      context: context,
      message: "Apakah kamu yakin ingin refresh data?",
      confirmText: "Ya",
      cancelText: "Tidak",
    );
    if (confirmed) {
      widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTabletOrLandscapeMobile = MediaQuery.of(context).size.width >= 768;
    final isTablet = MediaQuery.of(context).size.width >= 768;
    
    return Container(
      height: isTabletOrLandscapeMobile ? 80 : 70,
      padding: EdgeInsets.symmetric(
        horizontal: isTabletOrLandscapeMobile ? 32.0 : 24.0,
        vertical: isTabletOrLandscapeMobile ? 16.0 : 12.0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Menu button - Green hamburger icon
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: isTabletOrLandscapeMobile ? 48 : 40,
              height: isTabletOrLandscapeMobile ? 48 : 40,
              child: Image.asset(
                'assets/images/back.png',
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  );
                },
              ),
            ),
          ),
          SizedBox(width: isTabletOrLandscapeMobile ? 20 : 16),
          
          // Title
          Text(
            'Prepare Mode',
            style: TextStyle(
              fontSize: isTabletOrLandscapeMobile ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
          ),
          
          const Spacer(),
          
          // Location info
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.branchName,
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              SizedBox(
                width: isTablet ? 100 : 80,
                child: Text(
                  'Meja: ${_cachedMeja ?? '010101'}',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          
          SizedBox(width: isTablet ? 24 : 20),
          
          // CRF_KONSOL button
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 12 : 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              widget.userData?['role'] ?? 'CRF_KONSOL',
              style: TextStyle(
                color: Colors.white,
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          
          SizedBox(width: isTablet ? 16 : 12),
          
          // Refresh button
          GestureDetector(
            onTap: _handleRefreshWithConfirmation,
            child: Container(
              width: isTablet ? 44 : 40,
              height: isTablet ? 44 : 40,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.refresh,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          
          SizedBox(width: isTablet ? 24 : 20),
          
          // User info
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    constraints: BoxConstraints(maxWidth: isTablet ? 150 : 120),
                    child: Text(
                      widget.userName,
                      style: TextStyle(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Text(
                    _cachedNik ?? '',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              SizedBox(width: isTablet ? 12 : 10),
              GestureDetector(
                onTap: () async {
                  final confirmed = await CustomModals.showConfirmationModal(
                    context: context,
                    message: "Apakah kamu yakin ingin pergi ke halaman profile?",
                    confirmText: "Ya",
                    cancelText: "Tidak",
                  );
                  if (confirmed) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileMenuScreen(),
                      ),
                    );
                  }
                },
                child: Container(
                  width: isTablet ? 48 : 44,
                  height: isTablet ? 48 : 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _cachedProfilePhoto != null
                        ? Image(
                            image: _cachedProfilePhoto!,
                            width: isTablet ? 48 : 44,
                            height: isTablet ? 48 : 44,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFF10B981),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: const Color(0xFF10B981),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}