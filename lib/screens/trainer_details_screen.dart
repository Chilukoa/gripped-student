import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/student_service.dart';
import '../services/payment_service.dart';
import '../config/api_config.dart' as config;
import 'payment_method_screen.dart';

class TrainerDetailsScreen extends StatefulWidget {
  final String trainerId;
  final String trainerName;
  final Map<String, dynamic>? initialTrainerData;

  const TrainerDetailsScreen({
    super.key,
    required this.trainerId,
    required this.trainerName,
    this.initialTrainerData,
  });

  @override
  State<TrainerDetailsScreen> createState() => _TrainerDetailsScreenState();
}

class _TrainerDetailsScreenState extends State<TrainerDetailsScreen> {
  final StudentService _studentService = StudentService();
  final PaymentService _paymentService = PaymentService();

  Map<String, dynamic>? _trainerProfile;
  List<Map<String, dynamic>> _upcomingClasses = [];
  Set<String> _selectedSessionIds = {};
  bool _isLoadingProfile = true;
  bool _isLoadingClasses = true;
  bool _isEnrolling = false;
  String? _profileError;
  String? _classesError;
  int _daysAhead = 90;

  // Rating data
  Map<String, dynamic>? _trainerRating;

  @override
  void initState() {
    super.initState();
    _loadTrainerData();
  }

  Future<void> _loadTrainerData() async {
    await Future.wait([
      _loadTrainerProfile(),
      _loadTrainerClasses(),
      _loadTrainerRating(),
    ]);
  }

  Future<void> _loadTrainerProfile() async {
    try {
      setState(() {
        _isLoadingProfile = true;
        _profileError = null;
      });

      final profile = await _studentService.getTrainerProfile(widget.trainerId);

      if (mounted) {
        setState(() {
          _trainerProfile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      safePrint('TrainerDetailsScreen: Error loading profile: $e');
      if (mounted) {
        setState(() {
          _profileError = e.toString();
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _loadTrainerClasses() async {
    try {
      setState(() {
        _isLoadingClasses = true;
        _classesError = null;
      });

      final result = await _studentService.getTrainerUpcomingClasses(
        widget.trainerId,
        daysAhead: _daysAhead,
      );

      if (mounted) {
        setState(() {
          _upcomingClasses = (result['classes'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              [];
          _isLoadingClasses = false;
        });
      }
    } catch (e) {
      safePrint('TrainerDetailsScreen: Error loading classes: $e');
      if (mounted) {
        setState(() {
          _classesError = e.toString();
          _isLoadingClasses = false;
        });
      }
    }
  }

  Future<void> _loadTrainerRating() async {
    try {
      final rating = await _studentService.getTrainerRating(widget.trainerId);
      if (mounted) {
        setState(() {
          _trainerRating = rating;
        });
      }
    } catch (e) {
      safePrint('TrainerDetailsScreen: Error loading rating: $e');
    }
  }

  void _toggleClassSelection(String sessionId) {
    setState(() {
      if (_selectedSessionIds.contains(sessionId)) {
        _selectedSessionIds.remove(sessionId);
      } else {
        _selectedSessionIds.add(sessionId);
      }
    });
  }

  void _selectAllClasses() {
    setState(() {
      _selectedSessionIds = _upcomingClasses
          .where((c) {
            final capacity = (c['capacity'] as num?)?.toInt() ?? 0;
            final countRegistered = (c['countRegistered'] as num?)?.toInt() ?? 0;
            return countRegistered < capacity;
          })
          .map((c) => c['sessionId'] as String)
          .toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedSessionIds.clear();
    });
  }

  Future<void> _bookSelectedClasses() async {
    if (_selectedSessionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one class to book'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check payment method
    final hasPayment = await _paymentService.hasPaymentMethod();
    if (!hasPayment) {
      if (mounted) {
        _showPaymentRequiredDialog();
      }
      return;
    }

    // Show confirmation dialog
    final shouldBook = await _showBookingConfirmationDialog();
    if (shouldBook != true) return;

    setState(() {
      _isEnrolling = true;
    });

    try {
      final result = await _studentService.batchEnrollInClasses(
        _selectedSessionIds.toList(),
      );

      if (mounted) {
        final successCount = result['successCount'] as int? ?? 0;
        final failedCount = result['failedCount'] as int? ?? 0;

        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                failedCount > 0
                    ? 'Successfully booked $successCount class${successCount > 1 ? 'es' : ''}. $failedCount failed.'
                    : 'Successfully booked $successCount class${successCount > 1 ? 'es' : ''}!',
              ),
              backgroundColor: failedCount > 0 ? Colors.orange : Colors.green,
            ),
          );

          // Clear selection and refresh
          setState(() {
            _selectedSessionIds.clear();
          });
          _loadTrainerClasses();
        } else if (failedCount > 0) {
          // Show detailed error
          final failedEnrollments = result['failedEnrollments'] as List<dynamic>? ?? [];
          String errorMessage = 'Failed to book classes';
          if (failedEnrollments.isNotEmpty) {
            final firstError = failedEnrollments[0] as Map<String, dynamic>;
            errorMessage = firstError['error'] as String? ?? errorMessage;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error booking classes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEnrolling = false;
        });
      }
    }
  }

  void _showPaymentRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.credit_card, color: Colors.orange),
            SizedBox(width: 8),
            Text('Payment Method Required'),
          ],
        ),
        content: const Text(
          'You need to add a payment method before booking classes. Would you like to add one now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PaymentMethodScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Payment Method'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showBookingConfirmationDialog() async {
    // Calculate total cost
    double totalCost = 0;
    for (final sessionId in _selectedSessionIds) {
      final classData = _upcomingClasses.firstWhere(
        (c) => c['sessionId'] == sessionId,
        orElse: () => {},
      );
      final cost = (classData['studentCost'] as num?)?.toDouble() ??
          (classData['pricePerClass'] as num?)?.toDouble() ??
          0;
      totalCost += cost;
    }

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to book ${_selectedSessionIds.length} class${_selectedSessionIds.length > 1 ? 'es' : ''}.'),
            const SizedBox(height: 12),
            Text(
              'Total: \$${totalCost.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your payment method will be charged for each class.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Booking'),
          ),
        ],
      ),
    );
  }

  void _changeDaysAhead(int days) {
    setState(() {
      _daysAhead = days;
      _selectedSessionIds.clear();
    });
    _loadTrainerClasses();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    final effectiveWidth = isDesktop ? 600.0 : screenWidth;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.trainerName),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedSessionIds.isNotEmpty)
            TextButton.icon(
              onPressed: _clearSelection,
              icon: const Icon(Icons.clear, color: Colors.white),
              label: Text(
                'Clear (${_selectedSessionIds.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Center(
        child: SizedBox(
          width: effectiveWidth,
          child: RefreshIndicator(
            onRefresh: _loadTrainerData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileSection(effectiveWidth),
                  _buildClassesSection(effectiveWidth),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _selectedSessionIds.isNotEmpty
          ? _buildBookingBar(effectiveWidth)
          : null,
    );
  }

  Widget _buildDefaultAvatar(String firstName) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.deepPurple[100],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          firstName.isNotEmpty ? firstName[0].toUpperCase() : 'T',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
      ),
    );
  }

  void _showEnlargedPhoto(BuildContext context, String photoUrl, String trainerName) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Photo with pinch-to-zoom using InteractiveViewer
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 48, color: Colors.white),
                          SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            // Close button at top right
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            // Trainer name at bottom
            Positioned(
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  trainerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(double width) {
    if (_isLoadingProfile) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_profileError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text('Error loading profile', style: TextStyle(color: Colors.grey[600])),
              TextButton(
                onPressed: _loadTrainerProfile,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final profile = _trainerProfile ?? widget.initialTrainerData ?? {};
    final firstName = profile['firstName'] as String? ?? '';
    final lastName = profile['lastName'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();
    final bio = profile['bio'] as String? ?? profile['aboutMe'] as String? ?? '';
    final email = profile['email'] as String? ?? '';
    final phone = profile['phone'] as String? ?? '';
    final city = profile['city'] as String? ?? '';
    final state = profile['state'] as String? ?? '';
    
    // Use presigned URL from backend (preferred for viewing other trainers' photos)
    final photoUrls = (profile['photoUrls'] as List<dynamic>?)?.cast<String>() ?? [];
    final profilePhotoUrl = (profile['profilePhotoUrl'] as String?) ?? 
                            (photoUrls.isNotEmpty ? photoUrls.first : null);
    
    final specialties = (profile['specialties'] as List<dynamic>?)?.cast<String>() ?? [];
    final certifications = (profile['certifications'] as List<dynamic>?)?.cast<String>() ?? [];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header with photo
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile photo - use presigned URL from backend
              GestureDetector(
                onTap: profilePhotoUrl != null && profilePhotoUrl.isNotEmpty
                    ? () => _showEnlargedPhoto(context, profilePhotoUrl, fullName)
                    : null,
                child: ClipOval(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: profilePhotoUrl != null && profilePhotoUrl.isNotEmpty
                        ? Image.network(
                            profilePhotoUrl,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              safePrint('TrainerDetailsScreen: Failed to load profile photo: $error');
                              return _buildDefaultAvatar(firstName);
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 100,
                                height: 100,
                                color: Colors.deepPurple[100],
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                          )
                        : _buildDefaultAvatar(firstName),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name and rating
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isNotEmpty ? fullName : widget.trainerName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (city.isNotEmpty || state.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              [city, state].where((s) => s.isNotEmpty).join(', '),
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    if (_trainerRating != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _buildRatingDisplay(),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Bio
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'About',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              bio,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],

          // Specialties
          if (specialties.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Specialties',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: specialties.map((s) => Chip(
                label: Text(s),
                backgroundColor: Colors.deepPurple[50],
              )).toList(),
            ),
          ],

          // Certifications
          if (certifications.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Certifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: certifications.map((c) => Chip(
                avatar: const Icon(Icons.verified, size: 16, color: Colors.green),
                label: Text(c),
                backgroundColor: Colors.green[50],
              )).toList(),
            ),
          ],

          // Contact info
          if (email.isNotEmpty || phone.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Contact',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (email.isNotEmpty)
              InkWell(
                onTap: () => _launchEmail(email),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.email, size: 20, color: Colors.deepPurple[400]),
                      const SizedBox(width: 8),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.deepPurple,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (phone.isNotEmpty)
              InkWell(
                onTap: () => _launchPhone(phone),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.phone, size: 20, color: Colors.deepPurple[400]),
                      const SizedBox(width: 8),
                      Text(
                        phone,
                        style: const TextStyle(
                          color: Colors.deepPurple,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingDisplay() {
    final averageRating = (_trainerRating?['averageRating'] as num?)?.toDouble() ?? 0.0;
    final totalRatings = _trainerRating?['totalRatings'] as int? ?? 0;

    if (totalRatings == 0) {
      return Text(
        'No ratings yet',
        style: TextStyle(color: Colors.grey[500], fontSize: 14),
      );
    }

    return Row(
      children: [
        ...List.generate(5, (index) {
          if (index < averageRating.floor()) {
            return const Icon(Icons.star, color: Colors.amber, size: 20);
          } else if (index < averageRating) {
            return const Icon(Icons.star_half, color: Colors.amber, size: 20);
          } else {
            return const Icon(Icons.star_border, color: Colors.amber, size: 20);
          }
        }),
        const SizedBox(width: 8),
        Text(
          '${averageRating.toStringAsFixed(1)} ($totalRatings ${totalRatings == 1 ? 'review' : 'reviews'})',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildClassesSection(double width) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with filter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upcoming Classes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              PopupMenuButton<int>(
                initialValue: _daysAhead,
                onSelected: _changeDaysAhead,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Next $_daysAhead days'),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 20),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 30, child: Text('Next 30 days')),
                  const PopupMenuItem(value: 60, child: Text('Next 60 days')),
                  const PopupMenuItem(value: 90, child: Text('Next 90 days')),
                  const PopupMenuItem(value: 180, child: Text('Next 180 days')),
                  const PopupMenuItem(value: 365, child: Text('Next 365 days')),
                ],
              ),
            ],
          ),

          // Select all button
          if (_upcomingClasses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _selectedSessionIds.length == _upcomingClasses.where((c) {
                      final capacity = (c['capacity'] as num?)?.toInt() ?? 0;
                      final count = (c['countRegistered'] as num?)?.toInt() ?? 0;
                      return count < capacity;
                    }).length
                        ? _clearSelection
                        : _selectAllClasses,
                    icon: Icon(
                      _selectedSessionIds.length == _upcomingClasses.where((c) {
                        final capacity = (c['capacity'] as num?)?.toInt() ?? 0;
                        final count = (c['countRegistered'] as num?)?.toInt() ?? 0;
                        return count < capacity;
                      }).length
                          ? Icons.deselect
                          : Icons.select_all,
                      size: 18,
                    ),
                    label: Text(
                      _selectedSessionIds.length == _upcomingClasses.where((c) {
                        final capacity = (c['capacity'] as num?)?.toInt() ?? 0;
                        final count = (c['countRegistered'] as num?)?.toInt() ?? 0;
                        return count < capacity;
                      }).length
                          ? 'Deselect All'
                          : 'Select All Available',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_upcomingClasses.length} class${_upcomingClasses.length != 1 ? 'es' : ''}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Classes list
          if (_isLoadingClasses)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_classesError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('Error loading classes', style: TextStyle(color: Colors.grey[600])),
                    TextButton(
                      onPressed: _loadTrainerClasses,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_upcomingClasses.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No upcoming classes in the next $_daysAhead days',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _changeDaysAhead(365),
                      child: const Text('Show next 365 days'),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _upcomingClasses.length,
              itemBuilder: (context, index) {
                return _buildClassCard(_upcomingClasses[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classData) {
    final sessionId = classData['sessionId'] as String? ?? '';
    final className = classData['className'] as String? ?? classData['classTitle'] as String? ?? 'Untitled Class';
    final overview = classData['overview'] as String? ?? '';
    final startTime = classData['startTime'] as String?;
    final endTime = classData['endTime'] as String?;
    final studentCost = (classData['studentCost'] as num?)?.toDouble() ??
        (classData['pricePerClass'] as num?)?.toDouble() ??
        0;
    final capacity = (classData['capacity'] as num?)?.toInt() ?? 0;
    final countRegistered = (classData['countRegistered'] as num?)?.toInt() ?? 0;
    final city = classData['city'] as String? ?? '';
    final state = classData['state'] as String? ?? '';
    final address = classData['classLocationAddress1'] as String? ?? '';
    final classTags = (classData['classTags'] as List<dynamic>?)?.cast<String>() ?? [];

    final isFull = countRegistered >= capacity;
    final isSelected = _selectedSessionIds.contains(sessionId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: Colors.deepPurple, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: isFull ? null : () => _toggleClassSelection(sessionId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Selection checkbox
                  if (!isFull)
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleClassSelection(sessionId),
                      activeColor: Colors.deepPurple,
                    ),
                  if (isFull)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'FULL',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      className,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    '\$${studentCost.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),

              if (overview.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 40),
                  child: Text(
                    overview,
                    style: TextStyle(color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _formatDateTime(startTime, endTime),
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [address, city, state].where((s) => s.isNotEmpty).join(', '),
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.people, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '$countRegistered / $capacity spots filled',
                          style: TextStyle(
                            color: isFull ? Colors.red : Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (classTags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 40),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: classTags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: Colors.deepPurple[700],
                          fontSize: 11,
                        ),
                      ),
                    )).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingBar(double width) {
    // Calculate total
    double totalCost = 0;
    for (final sessionId in _selectedSessionIds) {
      final classData = _upcomingClasses.firstWhere(
        (c) => c['sessionId'] == sessionId,
        orElse: () => {},
      );
      final cost = (classData['studentCost'] as num?)?.toDouble() ??
          (classData['pricePerClass'] as num?)?.toDouble() ??
          0;
      totalCost += cost;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selectedSessionIds.length} class${_selectedSessionIds.length > 1 ? 'es' : ''} selected',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total: \$${totalCost.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _isEnrolling ? null : _bookSelectedClasses,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: _isEnrolling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Book Now',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String? startTime, String? endTime) {
    if (startTime == null) return 'Time TBD';

    try {
      final start = DateTime.parse(startTime).toLocal();
      final end = endTime != null ? DateTime.parse(endTime).toLocal() : null;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final classDate = DateTime(start.year, start.month, start.day);

      String dateStr;
      if (classDate.isAtSameMomentAs(today)) {
        dateStr = 'Today';
      } else if (classDate.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
        dateStr = 'Tomorrow';
      } else {
        dateStr = '${start.month}/${start.day}/${start.year}';
      }

      String formatTime(DateTime dt) {
        final hour = dt.hour;
        final minute = dt.minute;
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
      }

      if (end != null) {
        return '$dateStr, ${formatTime(start)} - ${formatTime(end)}';
      }
      return '$dateStr at ${formatTime(start)}';
    } catch (e) {
      return startTime;
    }
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      }
    } catch (e) {
      safePrint('Error launching email: $e');
    }
  }

  Future<void> _launchPhone(String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    } catch (e) {
      safePrint('Error launching phone: $e');
    }
  }
}
