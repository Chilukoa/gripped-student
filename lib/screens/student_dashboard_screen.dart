import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/student_service.dart';
import 'login_screen.dart';
import 'update_profile_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StudentService _studentService = StudentService();
  
  // Search tab state
  final _zipCodeController = TextEditingController();
  final _queryController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  DateTime? _selectedDate;
  
  // Enrolled classes tab state
  List<dynamic> _enrolledClasses = [];
  bool _isLoadingEnrolled = false;
  String? _enrolledError;
  
  // Date filtering state for enrolled classes
  DateTime? _enrolledFromDate;
  DateTime? _enrolledToDate;
  bool _showCancelledClasses = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Set default filter to show future classes (today to today+90 days)
    _setEnrolledDateFilter('future');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _zipCodeController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadEnrolledClasses() async {
    setState(() {
      _isLoadingEnrolled = true;
      _enrolledError = null;
    });

    try {
      // Format dates for API (YYYY-MM-DD format)
      String? fromDateStr;
      String? toDateStr;
      
      if (_enrolledFromDate != null) {
        fromDateStr = "${_enrolledFromDate!.year}-${_enrolledFromDate!.month.toString().padLeft(2, '0')}-${_enrolledFromDate!.day.toString().padLeft(2, '0')}";
      }
      
      if (_enrolledToDate != null) {
        toDateStr = "${_enrolledToDate!.year}-${_enrolledToDate!.month.toString().padLeft(2, '0')}-${_enrolledToDate!.day.toString().padLeft(2, '0')}";
      }
      
      final enrolledData = await _studentService.getEnrolledClasses(
        fromDate: fromDateStr,
        toDate: toDateStr,
      );
      
      if (mounted) {
        setState(() {
          List<dynamic> allClasses = enrolledData['classes'] ?? [];
          safePrint('StudentDashboard: Total classes from API: ${allClasses.length}');
          
          // Filter classes based on status and enrollment status
          List<dynamic> filteredClasses = allClasses.where((enrolledClass) {
            final classInfo = enrolledClass['class'] as Map<String, dynamic>;
            final enrollmentInfo = enrolledClass['enrollment'] as Map<String, dynamic>;
            
            final className = classInfo['className'] as String? ?? 'Unknown';
            final classStatus = classInfo['status'] as String? ?? 'ACTIVE';
            final enrollmentStatus = enrollmentInfo['status'] as String? ?? 'UNKNOWN';
            
            safePrint('StudentDashboard: Processing class "$className" - classStatus: $classStatus, enrollmentStatus: $enrollmentStatus');
            
            // If _showCancelledClasses is false, only show ENROLLED enrollments
            if (!_showCancelledClasses) {
              if (enrollmentStatus.toUpperCase() != 'ENROLLED') {
                safePrint('StudentDashboard: Filtering out "$className" - enrollment not ENROLLED');
                return false;
              }
              
              // Also filter out cancelled classes (by trainer) if checkbox is not checked
              if (classStatus.toUpperCase() == 'CANCELLED') {
                safePrint('StudentDashboard: Filtering out "$className" - class cancelled by trainer');
                return false;
              }
            } else {
              // If _showCancelledClasses is true, show ENROLLED, UNENROLLED, and CANCELLED enrollments
              if (enrollmentStatus.toUpperCase() != 'ENROLLED' && 
                  enrollmentStatus.toUpperCase() != 'UNENROLLED' &&
                  enrollmentStatus.toUpperCase() != 'CANCELLED') {
                safePrint('StudentDashboard: Filtering out "$className" - enrollment status not ENROLLED, UNENROLLED, or CANCELLED');
                return false;
              }
            }
            
            safePrint('StudentDashboard: Including class "$className" in results');
            return true;
          }).toList();
          
          // Sort classes by start time (earliest first)
          filteredClasses.sort((a, b) {
            final classA = a['class'] as Map<String, dynamic>;
            final classB = b['class'] as Map<String, dynamic>;
            
            final startTimeA = DateTime.tryParse(classA['startTime'] as String? ?? '');
            final startTimeB = DateTime.tryParse(classB['startTime'] as String? ?? '');
            
            // If both have valid start times, sort by start time
            if (startTimeA != null && startTimeB != null) {
              return startTimeA.compareTo(startTimeB);
            }
            
            // If only one has a valid start time, prioritize the one with time
            if (startTimeA != null && startTimeB == null) {
              return -1; // A comes first
            }
            if (startTimeA == null && startTimeB != null) {
              return 1; // B comes first
            }
            
            // If neither has a valid start time, sort by class name
            final nameA = classA['className'] as String? ?? '';
            final nameB = classB['className'] as String? ?? '';
            return nameA.compareTo(nameB);
          });

          safePrint('StudentDashboard: After filtering, showing ${filteredClasses.length} classes (showCancelled: $_showCancelledClasses)');
          _enrolledClasses = filteredClasses;
          _isLoadingEnrolled = false;
        });
      }
    } catch (e) {
      safePrint('StudentDashboard: Error loading enrolled classes: $e');
      if (mounted) {
        setState(() {
          _enrolledError = e.toString();
          _isLoadingEnrolled = false;
        });
      }
    }
  }

  Future<void> _searchClasses() async {
    if (_zipCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a zip code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_queryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a class type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final results = await _studentService.searchClasses(
        zipCode: _zipCodeController.text.trim(),
        query: _queryController.text.trim(),
        radiusMiles: "30", // Default 30 miles radius
        date: "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}",
      );
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      safePrint('StudentDashboard: Error searching classes: $e');
      if (mounted) {
        setState(() {
          _searchError = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _enrollInClass(String sessionId) async {
    try {
      safePrint('StudentDashboard: Attempting to enroll in session: $sessionId');
      
      // Check if already enrolled in this specific session
      final isAlreadyEnrolled = _enrolledClasses.any((enrolledClass) {
        final classInfo = enrolledClass['class'] as Map<String, dynamic>;
        final enrollmentInfo = enrolledClass['enrollment'] as Map<String, dynamic>;
        final enrolledSessionId = classInfo['sessionId'] as String?;
        final enrollmentStatus = enrollmentInfo['status'] as String? ?? 'UNKNOWN';
        
        return enrolledSessionId == sessionId && 
               enrollmentStatus.toUpperCase() == 'ENROLLED';
      });
      
      if (isAlreadyEnrolled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are already enrolled in this specific class session!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      await _studentService.enrollInClass(sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully enrolled in class!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh enrolled classes
        _loadEnrolledClasses();
      }
    } catch (e) {
      safePrint('StudentDashboard: Error enrolling in class: $e');
      
      // Handle specific enrollment errors with better user experience
      if (e.toString().contains('Student already enrolled in this class')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are already enrolled in this class session!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else if (e.toString().contains('time conflict') || 
                 e.toString().contains('overlapping') ||
                 e.toString().contains('schedule conflict')) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Schedule Conflict'),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This class conflicts with another class you\'re already enrolled in.'),
                  SizedBox(height: 12),
                  Text('You cannot be enrolled in two classes that happen at the same time.'),
                  SizedBox(height: 12),
                  Text('Please check your enrolled classes and choose a different time slot.'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Switch to enrolled classes tab to view conflicts
                    _tabController.animateTo(1);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('View My Classes'),
                ),
              ],
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error enrolling in class: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unenrollFromClass(String sessionId) async {
    final shouldUnenroll = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unenroll from Class'),
        content: const Text(
          'Are you sure you want to unenroll from this class?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unenroll'),
          ),
        ],
      ),
    );

    if (shouldUnenroll == true) {
      try {
        await StudentService().unenrollFromClass(sessionId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully unenrolled from class'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh enrolled classes
          _loadEnrolledClasses();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error unenrolling from class: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _updateProfile() async {
    try {
      final currentProfile = await UserService().getUserProfile();
      if (mounted && currentProfile != null) {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                UpdateProfileScreen(currentProfile: currentProfile),
          ),
        );

        if (result == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await AuthService().signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _setEnrolledDateFilter(String filterType) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    setState(() {
      switch (filterType) {
        case 'future':
          _enrolledFromDate = today;
          _enrolledToDate = today.add(const Duration(days: 90));
          break;
        case 'all':
          _enrolledFromDate = null;
          _enrolledToDate = null;
          break;
        case 'today':
          _enrolledFromDate = today;
          _enrolledToDate = today;
          break;
        case 'this_week':
          final weekStart = today.subtract(Duration(days: today.weekday - 1));
          final weekEnd = weekStart.add(const Duration(days: 6));
          _enrolledFromDate = weekStart;
          _enrolledToDate = weekEnd;
          break;
        case 'this_month':
          _enrolledFromDate = DateTime(today.year, today.month, 1);
          _enrolledToDate = DateTime(today.year, today.month + 1, 0);
          break;
        case 'past':
          _enrolledFromDate = DateTime(2020, 1, 1); // Far past date
          _enrolledToDate = today.subtract(const Duration(days: 1));
          break;
      }
    });
    
    _loadEnrolledClasses();
  }

  void _clearEnrolledDateFilters() {
    setState(() {
      _enrolledFromDate = null;
      _enrolledToDate = null;
    });
    _loadEnrolledClasses();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'updateprofile') {
                _updateProfile();
              } else if (value == 'signout') {
                _signOut();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'updateprofile',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Update Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: Icon(Icons.search),
              text: 'Search Classes',
            ),
            Tab(
              icon: Icon(Icons.class_),
              text: 'My Classes',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchTab(screenWidth, screenHeight),
          _buildEnrolledClassesTab(screenWidth, screenHeight),
        ],
      ),
    );
  }

  Widget _buildSearchTab(double screenWidth, double screenHeight) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Form Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(screenWidth * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find Classes Near You',
                    style: TextStyle(
                      fontSize: screenWidth * 0.05,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.005),
                  Text(
                    'All fields marked with * are required',
                    style: TextStyle(
                      fontSize: screenWidth * 0.032,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  
                  // Zip Code Field
                  TextFormField(
                    controller: _zipCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Zip Code *',
                      hintText: 'e.g., 75454',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  
                  // Search Query Field
                  TextFormField(
                    controller: _queryController,
                    decoration: const InputDecoration(
                      labelText: 'Class Type *',
                      hintText: 'e.g., yoga, strength, pilates',
                      prefixIcon: Icon(Icons.fitness_center),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  
                  // Date Field
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedDate != null 
                                  ? '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}'
                                  : 'Select Date *',
                              style: TextStyle(
                                color: _selectedDate != null ? Colors.black87 : Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (_selectedDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                setState(() {
                                  _selectedDate = null;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  
                  // Search Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSearching ? null : _searchClasses,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                      ),
                      child: _isSearching
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Searching...'),
                              ],
                            )
                          : const Text('Search Classes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: screenHeight * 0.02),
          
          // Search Results
          if (_searchError != null)
            Card(
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.04),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: screenWidth * 0.1,
                      color: Colors.red,
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Text(
                      'Search Error',
                      style: TextStyle(
                        fontSize: screenWidth * 0.045,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Text(
                      _searchError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else if (_searchResults.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search Results (${_searchResults.length})',
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                SizedBox(height: screenHeight * 0.015),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final classResult = _searchResults[index];
                    return _buildSearchResultCard(classResult, screenWidth, screenHeight);
                  },
                ),
              ],
            )
          else if (_zipCodeController.text.isNotEmpty && !_isSearching)
            Card(
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.04),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      size: screenWidth * 0.1,
                      color: Colors.grey,
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Text(
                      'No Classes Found',
                      style: TextStyle(
                        fontSize: screenWidth * 0.045,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Text(
                      'Try searching with a different zip code or class type.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> classResult, double screenWidth, double screenHeight) {
    final classTitle = classResult['classTitle'] as String? ?? 'Unknown Class';
    final trainerName = classResult['trainerName'] as String? ?? 'Unknown Trainer';
    final address = classResult['address'] as String? ?? '';
    final city = classResult['city'] as String? ?? '';
    final state = classResult['state'] as String? ?? '';
    final zipCode = classResult['zip'] as String? ?? '';
    final price = classResult['price'] as num? ?? 0;
    final distanceMiles = classResult['distanceMiles'] as num? ?? 0;
    final startDateTime = classResult['startDateTime'] as String?;
    final endDateTime = classResult['endDateTime'] as String?;
    final sessionId = classResult['sessionId'] as String?;
    final currentStudents = classResult['currentStudents'] as int? ?? 0;
    final maxStudents = classResult['maxStudents'] as int? ?? 0;
    final isClassFull = currentStudents >= maxStudents;

    // Check for time conflicts with enrolled classes
    DateTime? classStartTime;
    DateTime? classEndTime;
    if (startDateTime != null) {
      classStartTime = DateTime.tryParse(startDateTime)?.toLocal();
    }
    if (endDateTime != null) {
      classEndTime = DateTime.tryParse(endDateTime)?.toLocal();
    }

    bool hasTimeConflict = false;
    if (classStartTime != null && classEndTime != null) {
      hasTimeConflict = _enrolledClasses.any((enrolledClass) {
        final classInfo = enrolledClass['class'] as Map<String, dynamic>;
        final enrollmentInfo = enrolledClass['enrollment'] as Map<String, dynamic>;
        final enrollmentStatus = enrollmentInfo['status'] as String? ?? 'UNKNOWN';
        
        if (enrollmentStatus.toUpperCase() != 'ENROLLED') return false;
        
        final enrolledStartTime = DateTime.tryParse(classInfo['startTime'] as String? ?? '')?.toLocal();
        final enrolledEndTime = DateTime.tryParse(classInfo['endTime'] as String? ?? '')?.toLocal();
        
        if (enrolledStartTime == null || enrolledEndTime == null) return false;
        
        // Check for time overlap
        return (classStartTime!.isBefore(enrolledEndTime) && classEndTime!.isAfter(enrolledStartTime));
      });
    }

    return Card(
      margin: EdgeInsets.only(bottom: screenHeight * 0.015),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row - Class Title and Price/Distance
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classTitle,
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.005),
                      Row(
                        children: [
                          Text(
                            'with $trainerName',
                            style: TextStyle(
                              fontSize: screenWidth * 0.04,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          if (hasTimeConflict) ...[
                            SizedBox(width: screenWidth * 0.02),
                            Icon(
                              Icons.schedule_outlined,
                              size: screenWidth * 0.035,
                              color: Colors.red,
                            ),
                          ],
                        ],
                      ),
                      if (hasTimeConflict) ...[
                        SizedBox(height: screenHeight * 0.005),
                        Text(
                          'Conflicts with your schedule',
                          style: TextStyle(
                            fontSize: screenWidth * 0.03,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      '${distanceMiles.toStringAsFixed(1)} mi',
                      style: TextStyle(
                        fontSize: screenWidth * 0.03,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            SizedBox(height: screenHeight * 0.015),
            
            // Time and Location
            if (startDateTime != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: screenWidth * 0.04,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Expanded(
                    child: Text(
                      _formatApiDateTime(startDateTime, endDateTime),
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.01),
            ],
            
            // Location
            if (address.isNotEmpty || city.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: screenWidth * 0.04,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Expanded(
                    child: Text(
                      [address, city, state, zipCode]
                          .where((s) => s.isNotEmpty)
                          .join(', '),
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.01),
            ],
            
            // Capacity
            if (maxStudents > 0) ...[
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: screenWidth * 0.04,
                    color: isClassFull ? Colors.red : Colors.grey[600],
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Text(
                    '$currentStudents/$maxStudents students',
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: isClassFull ? Colors.red : Colors.grey[600],
                      fontWeight: isClassFull ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (isClassFull) ...[
                    SizedBox(width: screenWidth * 0.02),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'FULL',
                        style: TextStyle(
                          fontSize: screenWidth * 0.025,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: screenHeight * 0.01),
            ],
            
            SizedBox(height: screenHeight * 0.01),
            
            // Three Action Buttons Row
            Row(
              children: [
                // View Details button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showClassDetails(classResult),
                    icon: Icon(Icons.info_outline, size: screenWidth * 0.04),
                    label: Text(
                      'Details',
                      style: TextStyle(fontSize: screenWidth * 0.032),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                      side: const BorderSide(color: Colors.deepPurple),
                      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                
                // Book Class button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isClassFull || sessionId == null 
                        ? null 
                        : () => _showBookingConfirmation(classResult),
                    icon: Icon(
                      isClassFull ? Icons.block : Icons.add_circle_outline, 
                      size: screenWidth * 0.04,
                    ),
                    label: Text(
                      isClassFull ? 'Full' : 'Book',
                      style: TextStyle(fontSize: screenWidth * 0.032),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isClassFull ? Colors.grey : Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                
                // Contact button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showContactOptions(classResult),
                    icon: Icon(Icons.contact_phone, size: screenWidth * 0.04),
                    label: Text(
                      'Contact',
                      style: TextStyle(fontSize: screenWidth * 0.032),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                      side: const BorderSide(color: Colors.deepPurple),
                      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
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

  Widget _buildEnrolledClassesTab(double screenWidth, double screenHeight) {
    if (_isLoadingEnrolled) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
        ),
      );
    }

    if (_enrolledError != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: screenWidth * 0.2,
                color: Colors.red,
              ),
              SizedBox(height: screenHeight * 0.02),
              Text(
                'Error Loading Classes',
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              Text(
                _enrolledError!.contains('403')
                    ? 'Authentication error. Please try signing out and back in.'
                    : _enrolledError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: screenHeight * 0.03),
              ElevatedButton(
                onPressed: _loadEnrolledClasses,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_enrolledClasses.isEmpty) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          children: [
            // Show filter controls when filters are active
            if (_enrolledFromDate != null || _enrolledToDate != null) ...[
              // Header and Controls (same as main view)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Classes (0)',
                          style: TextStyle(
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.003),
                        Row(
                          children: [
                            Icon(
                              Icons.sort,
                              size: screenWidth * 0.035,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: screenWidth * 0.01),
                            Text(
                              'Sorted by date & time',
                              style: TextStyle(
                                fontSize: screenWidth * 0.032,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showEnrolledDateFilterDialog(screenWidth, screenHeight),
                    icon: Icon(
                      Icons.filter_list,
                      color: Colors.deepPurple,
                    ),
                    tooltip: 'Filter by date',
                  ),
                ],
              ),
              
              // Quick filter chips
              SizedBox(height: screenHeight * 0.01),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickFilterChip('Future', 'future', screenWidth),
                    SizedBox(width: screenWidth * 0.02),
                    _buildQuickFilterChip('All', 'all', screenWidth),
                    SizedBox(width: screenWidth * 0.02),
                    _buildQuickFilterChip('Today', 'today', screenWidth),
                    SizedBox(width: screenWidth * 0.02),
                    _buildQuickFilterChip('This Week', 'this_week', screenWidth),
                    SizedBox(width: screenWidth * 0.02),
                    _buildQuickFilterChip('This Month', 'this_month', screenWidth),
                    SizedBox(width: screenWidth * 0.02),
                    _buildQuickFilterChip('Past', 'past', screenWidth),
                  ],
                ),
              ),
              
              // Show cancelled classes checkbox in empty state
              CheckboxListTile(
                title: Text(
                  'Show cancelled classes',
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    color: Colors.grey[700],
                  ),
                ),
                value: _showCancelledClasses,
                onChanged: (value) {
                  setState(() {
                    _showCancelledClasses = value ?? false;
                  });
                  _loadEnrolledClasses();
                },
                activeColor: Colors.deepPurple,
                contentPadding: EdgeInsets.zero,
              ),
              
              // Active filter display
              SizedBox(height: screenHeight * 0.015),
              Container(
                padding: EdgeInsets.all(screenWidth * 0.03),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: screenWidth * 0.04,
                      color: Colors.deepPurple,
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Expanded(
                      child: Text(
                        _getFilterDisplayText(),
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _clearEnrolledDateFilters,
                      icon: Icon(
                        Icons.clear,
                        size: screenWidth * 0.04,
                        color: Colors.deepPurple,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: screenHeight * 0.04),
            ],
            
            // Empty state content
            Icon(
              Icons.class_,
              size: screenWidth * 0.2,
              color: Colors.grey[400],
            ),
            SizedBox(height: screenHeight * 0.02),
            Text(
              (_enrolledFromDate != null || _enrolledToDate != null) 
                  ? 'No Classes Found'
                  : 'No Enrolled Classes',
              style: TextStyle(
                fontSize: screenWidth * 0.06,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              (_enrolledFromDate != null || _enrolledToDate != null) 
                  ? 'No classes found for the selected date range.\nTry adjusting your filter or use the Search tab to find new classes!'
                  : 'You haven\'t enrolled in any classes yet.\nUse the Search tab to find classes near you!',
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenHeight * 0.03),
            
            // Action buttons
            if (_enrolledFromDate != null || _enrolledToDate != null) ...[
              // Clear filters button when filters are active
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _clearEnrolledDateFilters,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear Filters'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.015,
                    ),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
            ],
            
            // Search classes button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _tabController.animateTo(0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_enrolledFromDate != null || _enrolledToDate != null) 
                      ? Colors.grey[600] 
                      : Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: screenHeight * 0.015,
                  ),
                ),
                child: Text(
                  'Search Classes',
                  style: TextStyle(fontSize: screenWidth * 0.04),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEnrolledClasses,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header and Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Classes (${_enrolledClasses.length})',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      if (_enrolledClasses.isNotEmpty) ...[
                        SizedBox(height: screenHeight * 0.003),
                        Row(
                          children: [
                            Icon(
                              Icons.sort,
                              size: screenWidth * 0.035,
                              color: Colors.grey[600],
                            ),
                            SizedBox(width: screenWidth * 0.01),
                            Text(
                              'Sorted by date & time',
                              style: TextStyle(
                                fontSize: screenWidth * 0.032,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showEnrolledDateFilterDialog(screenWidth, screenHeight),
                  icon: Icon(
                    Icons.filter_list,
                    color: (_enrolledFromDate != null || _enrolledToDate != null) 
                        ? Colors.deepPurple 
                        : Colors.grey[600],
                  ),
                  tooltip: 'Filter by date',
                ),
              ],
            ),
            
            // Show cancelled classes checkbox
            CheckboxListTile(
              title: Text(
                'Show cancelled classes',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.grey[700],
                ),
              ),
              value: _showCancelledClasses,
              onChanged: (value) {
                safePrint('StudentDashboard: Checkbox changed to ${value ?? false}');
                setState(() {
                  _showCancelledClasses = value ?? false;
                });
                _loadEnrolledClasses();
              },
              activeColor: Colors.deepPurple,
              contentPadding: EdgeInsets.zero,
            ),
            
            // Quick filter chips
            SizedBox(height: screenHeight * 0.01),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickFilterChip('Future', 'future', screenWidth),
                  SizedBox(width: screenWidth * 0.02),
                  _buildQuickFilterChip('All', 'all', screenWidth),
                  SizedBox(width: screenWidth * 0.02),
                  _buildQuickFilterChip('Today', 'today', screenWidth),
                  SizedBox(width: screenWidth * 0.02),
                  _buildQuickFilterChip('This Week', 'this_week', screenWidth),
                  SizedBox(width: screenWidth * 0.02),
                  _buildQuickFilterChip('This Month', 'this_month', screenWidth),
                  SizedBox(width: screenWidth * 0.02),
                  _buildQuickFilterChip('Past', 'past', screenWidth),
                ],
              ),
            ),
            
            // Active filter display
            if (_enrolledFromDate != null || _enrolledToDate != null) ...[
              SizedBox(height: screenHeight * 0.015),
              Container(
                padding: EdgeInsets.all(screenWidth * 0.03),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: screenWidth * 0.04,
                      color: Colors.deepPurple,
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Expanded(
                      child: Text(
                        _getFilterDisplayText(),
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _clearEnrolledDateFilters,
                      icon: Icon(
                        Icons.clear,
                        size: screenWidth * 0.04,
                        color: Colors.deepPurple,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
            
            SizedBox(height: screenHeight * 0.02),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _enrolledClasses.length,
              itemBuilder: (context, index) {
                final enrolledClass = _enrolledClasses[index];
                return _buildEnrolledClassCard(enrolledClass, screenWidth, screenHeight);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrolledClassCard(dynamic enrolledClass, double screenWidth, double screenHeight) {
    final classInfo = enrolledClass['class'] as Map<String, dynamic>;
    final enrollmentInfo = enrolledClass['enrollment'] as Map<String, dynamic>;
    
    final className = classInfo['className'] as String? ?? 'Unknown Class';
    final startTime = DateTime.tryParse(classInfo['startTime'] as String? ?? '')?.toLocal();
    final endTime = DateTime.tryParse(classInfo['endTime'] as String? ?? '')?.toLocal();
    final city = classInfo['city'] as String?;
    final state = classInfo['state'] as String?;
    final pricePerClass = (classInfo['pricePerClass'] as num?)?.toDouble() ?? 0.0;
    final capacity = classInfo['capacity'] as int? ?? 0;
    final countRegistered = classInfo['countRegistered'] as int? ?? 0;
    final sessionId = classInfo['sessionId'] as String?;
    final overview = classInfo['overview'] as String?;
    final classTags = (classInfo['classTags'] as List<dynamic>?)?.cast<String>();
    final enrollmentStatus = enrollmentInfo['status'] as String? ?? 'UNKNOWN';
    final classStatus = classInfo['status'] as String? ?? 'ACTIVE';
    final enrolledAt = enrollmentInfo['enrolledAt'] as String?;

    final isPast = endTime != null && endTime.isBefore(DateTime.now());
    final isClassCancelled = classStatus.toUpperCase() == 'CANCELLED';
    final isStudentUnenrolled = enrollmentStatus.toUpperCase() == 'UNENROLLED';
    final isEnrollmentCancelled = enrollmentStatus.toUpperCase() == 'CANCELLED';

    return Card(
      margin: EdgeInsets.only(bottom: screenHeight * 0.015),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        className,
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (classTags != null && classTags.isNotEmpty) ...[
                        SizedBox(height: screenHeight * 0.005),
                        Text(
                          classTags.join(', '),
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isClassCancelled || isEnrollmentCancelled
                        ? Colors.red
                        : isStudentUnenrolled
                        ? Colors.orange
                        : isPast
                        ? Colors.grey
                        : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isClassCancelled || isEnrollmentCancelled
                        ? 'CLASS CANCELLED'
                        : isStudentUnenrolled
                        ? 'UNENROLLED'
                        : isPast
                        ? 'COMPLETED'
                        : 'ACTIVE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: screenHeight * 0.015),
            
            // Class details
            if (startTime != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: screenWidth * 0.04,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Expanded(
                    child: Text(
                      _formatDateTime(startTime),
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.01),
            ],
            
            if (city != null && state != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: screenWidth * 0.04,
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Expanded(
                    child: Text(
                      '$city, $state',
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.01),
            ],
            
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  size: screenWidth * 0.04,
                  color: Colors.grey[600],
                ),
                SizedBox(width: screenWidth * 0.02),
                Text(
                  '\$${pricePerClass.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(width: screenWidth * 0.04),
                Icon(
                  Icons.people,
                  size: screenWidth * 0.04,
                  color: Colors.grey[600],
                ),
                SizedBox(width: screenWidth * 0.02),
                Text(
                  '$countRegistered/$capacity enrolled',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            if (overview != null) ...[
              SizedBox(height: screenHeight * 0.015),
              Text(
                overview,
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            if (enrolledAt != null) ...[
              SizedBox(height: screenHeight * 0.015),
              Text(
                'Enrolled: ${DateTime.tryParse(enrolledAt)?.toLocal().toString().split('.')[0] ?? enrolledAt}',
                style: TextStyle(
                  fontSize: screenWidth * 0.03,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            
            // Action buttons
            if (!isClassCancelled && !isStudentUnenrolled && !isEnrollmentCancelled && !isPast && sessionId != null) ...[
              SizedBox(height: screenHeight * 0.015),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _unenrollFromClass(sessionId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Unenroll from Class'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final classDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (classDate.isAtSameMomentAs(today)) {
      dateStr = 'Today';
    } else if (classDate.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }

    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');

    return '$dateStr at $displayHour:$displayMinute $period';
  }

  String _formatApiDateTime(String? startDateTime, String? endDateTime) {
    if (startDateTime == null) return 'Time TBD';
    
    try {
      // Parse UTC time strings and convert to local time
      final startTime = DateTime.parse(startDateTime).toLocal();
      final endTime = endDateTime != null ? DateTime.parse(endDateTime).toLocal() : null;
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final classDate = DateTime(startTime.year, startTime.month, startTime.day);

      String dateStr;
      if (classDate.isAtSameMomentAs(today)) {
        dateStr = 'Today';
      } else if (classDate.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
        dateStr = 'Tomorrow';
      } else {
        dateStr = '${startTime.month}/${startTime.day}/${startTime.year}';
      }

      final startHour = startTime.hour;
      final startMinute = startTime.minute;
      final startPeriod = startHour >= 12 ? 'PM' : 'AM';
      final displayStartHour = startHour > 12 ? startHour - 12 : (startHour == 0 ? 12 : startHour);
      final displayStartMinute = startMinute.toString().padLeft(2, '0');

      String timeStr = '$displayStartHour:$displayStartMinute $startPeriod';
      
      if (endTime != null) {
        final endHour = endTime.hour;
        final endMinute = endTime.minute;
        final endPeriod = endHour >= 12 ? 'PM' : 'AM';
        final displayEndHour = endHour > 12 ? endHour - 12 : (endHour == 0 ? 12 : endHour);
        final displayEndMinute = endMinute.toString().padLeft(2, '0');
        timeStr += ' - $displayEndHour:$displayEndMinute $endPeriod';
      }

      return '$dateStr at $timeStr';
    } catch (e) {
      return startDateTime; // Return raw string if parsing fails
    }
  }

  void _showClassDetails(Map<String, dynamic> classResult) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(classResult['classTitle'] ?? 'Class Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (classResult['trainerName'] != null) ...[
                Text('Trainer: ${classResult['trainerName']}', 
                     style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
              ],
              if (classResult['description'] != null) ...[
                Text('Description: ${classResult['description']}'),
                const SizedBox(height: 8),
              ],
              if (classResult['startDateTime'] != null) ...[
                Text('Time: ${_formatApiDateTime(classResult['startDateTime'], classResult['endDateTime'])}'),
                const SizedBox(height: 8),
              ],
              if (classResult['address'] != null) ...[
                Text('Location: ${classResult['address']}'),
                const SizedBox(height: 8),
              ],
              if (classResult['price'] != null) ...[
                Text('Price: \$${classResult['price']}'),
                const SizedBox(height: 8),
              ],
              if (classResult['maxStudents'] != null) ...[
                Text('Capacity: ${classResult['currentStudents'] ?? 0}/${classResult['maxStudents']} enrolled'),
                const SizedBox(height: 8),
              ],
              if (classResult['distanceMiles'] != null) ...[
                Text('Distance: ${classResult['distanceMiles']} miles away'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBookingConfirmation(Map<String, dynamic> classResult) {
    final sessionId = classResult['sessionId'] as String?;
    safePrint('StudentDashboard: Showing booking confirmation for session: $sessionId');
    safePrint('StudentDashboard: Class details: ${classResult.toString()}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Booking Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Class: ${classResult['classTitle'] ?? 'Unknown Class'}'),
            const SizedBox(height: 8),
            Text('Trainer: ${classResult['trainerName'] ?? 'Unknown Trainer'}'),
            const SizedBox(height: 8),
            if (classResult['startDateTime'] != null)
              Text('Time: ${_formatApiDateTime(classResult['startDateTime'], classResult['endDateTime'])}'),
            const SizedBox(height: 8),
            Text('Price: \$${classResult['price'] ?? 0}'),
            if (sessionId != null) ...[
              const SizedBox(height: 8),
              Text('Session ID: $sessionId', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            const SizedBox(height: 16),
            const Text('Would you like to book this class?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (sessionId != null) {
                _enrollInClass(sessionId);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error: No session ID found for this class'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Booking'),
          ),
        ],
      ),
    );
  }

  void _showContactOptions(Map<String, dynamic> classResult) {
    final trainerEmail = classResult['trainerEmail'] as String?;
    final trainerPhone = classResult['trainerPhone'] as String?;
    final trainerName = classResult['trainerName'] ?? 'Trainer';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contact $trainerName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trainerPhone != null && trainerPhone.isNotEmpty) ...[
              ListTile(
                leading: const Icon(Icons.phone, color: Colors.green),
                title: Text(trainerPhone),
                subtitle: const Text('Phone'),
                onTap: () {
                  Navigator.of(context).pop();
                  _makePhoneCall(trainerPhone);
                },
              ),
            ],
            if (trainerEmail != null && trainerEmail.isNotEmpty) ...[
              ListTile(
                leading: const Icon(Icons.email, color: Colors.blue),
                title: Text(trainerEmail),
                subtitle: const Text('Email'),
                onTap: () {
                  Navigator.of(context).pop();
                  _sendEmail(trainerEmail);
                },
              ),
            ],
            if ((trainerPhone == null || trainerPhone.isEmpty) && 
                (trainerEmail == null || trainerEmail.isEmpty)) ...[
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No contact information available for this trainer.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch phone call to $phoneNumber'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching phone call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Inquiry about your fitness class',
        'body': 'Hi! I found your class on the Gripped app and would like to know more.',
      },
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch email to $email'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildQuickFilterChip(String label, String filterType, double screenWidth) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    bool isActive = false;
    switch (filterType) {
      case 'future':
        isActive = _enrolledFromDate?.isAtSameMomentAs(today) == true &&
                   _enrolledToDate?.isAtSameMomentAs(today.add(const Duration(days: 90))) == true;
        break;
      case 'all':
        isActive = _enrolledFromDate == null && _enrolledToDate == null;
        break;
      case 'today':
        isActive = _enrolledFromDate?.isAtSameMomentAs(today) == true &&
                   _enrolledToDate?.isAtSameMomentAs(today) == true;
        break;
      case 'this_week':
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        isActive = _enrolledFromDate?.isAtSameMomentAs(weekStart) == true &&
                   _enrolledToDate?.isAtSameMomentAs(weekEnd) == true;
        break;
      case 'this_month':
        final monthStart = DateTime(today.year, today.month, 1);
        final monthEnd = DateTime(today.year, today.month + 1, 0);
        isActive = _enrolledFromDate?.isAtSameMomentAs(monthStart) == true &&
                   _enrolledToDate?.isAtSameMomentAs(monthEnd) == true;
        break;
      case 'past':
        final yesterday = today.subtract(const Duration(days: 1));
        isActive = _enrolledFromDate?.year == 2020 &&
                   _enrolledToDate?.isAtSameMomentAs(yesterday) == true;
        break;
    }

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: screenWidth * 0.032,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isActive,
      onSelected: (selected) => _setEnrolledDateFilter(filterType),
      selectedColor: Colors.deepPurple.withOpacity(0.2),
      checkmarkColor: Colors.deepPurple,
      backgroundColor: Colors.grey[200],
      elevation: isActive ? 2 : 0,
    );
  }

  String _getFilterDisplayText() {
    if (_enrolledFromDate == null && _enrolledToDate == null) {
      return 'All classes';
    } else if (_enrolledFromDate != null && _enrolledToDate != null) {
      final fromStr = "${_enrolledFromDate!.month}/${_enrolledFromDate!.day}/${_enrolledFromDate!.year}";
      final toStr = "${_enrolledToDate!.month}/${_enrolledToDate!.day}/${_enrolledToDate!.year}";
      return 'From $fromStr to $toStr';
    } else if (_enrolledFromDate != null) {
      final fromStr = "${_enrolledFromDate!.month}/${_enrolledFromDate!.day}/${_enrolledFromDate!.year}";
      return 'From $fromStr';
    } else {
      final toStr = "${_enrolledToDate!.month}/${_enrolledToDate!.day}/${_enrolledToDate!.year}";
      return 'Until $toStr';
    }
  }

  void _showEnrolledDateFilterDialog(double screenWidth, double screenHeight) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Classes by Date'),
        content: SizedBox(
          width: screenWidth * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // From Date
              ListTile(
                leading: const Icon(Icons.date_range),
                title: Text(_enrolledFromDate != null 
                    ? 'From: ${_enrolledFromDate!.month}/${_enrolledFromDate!.day}/${_enrolledFromDate!.year}'
                    : 'From: No start date'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _enrolledFromDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _enrolledFromDate = picked;
                    });
                  }
                },
              ),
              
              // To Date
              ListTile(
                leading: const Icon(Icons.date_range),
                title: Text(_enrolledToDate != null 
                    ? 'To: ${_enrolledToDate!.month}/${_enrolledToDate!.day}/${_enrolledToDate!.year}'
                    : 'To: No end date'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _enrolledToDate ?? DateTime.now().add(const Duration(days: 90)),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _enrolledToDate = picked;
                    });
                  }
                },
              ),
              
              SizedBox(height: screenHeight * 0.02),
              
              // Quick preset buttons
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _setEnrolledDateFilter('future');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Future Classes'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _setEnrolledDateFilter('all');
                    },
                    child: const Text('All Classes'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearEnrolledDateFilters();
            },
            child: const Text('Clear Filters'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _loadEnrolledClasses();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
