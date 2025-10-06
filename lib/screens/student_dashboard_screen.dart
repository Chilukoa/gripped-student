import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/training_class.dart';
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
  
  // Search tab state
  final _zipCodeController = TextEditingController();
  final _queryController = TextEditingController();
  List<TrainingClass> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  
  // Enrolled classes tab state
  List<dynamic> _enrolledClasses = [];
  bool _isLoadingEnrolled = false;
  String? _enrolledError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEnrolledClasses();
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
      final enrolledData = await StudentService().getEnrolledClasses();
      if (mounted) {
        setState(() {
          _enrolledClasses = enrolledData['classes'] ?? [];
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

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final results = await StudentService().searchClasses(
        zipCode: _zipCodeController.text.trim(),
        query: _queryController.text.trim().isNotEmpty 
            ? _queryController.text.trim() 
            : null,
        radiusMiles: "30", // Default 30 miles radius
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
      await StudentService().enrollInClass(sessionId);
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
      if (mounted) {
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
                      labelText: 'Class Type (Optional)',
                      hintText: 'e.g., yoga, strength, pilates',
                      prefixIcon: Icon(Icons.fitness_center),
                      border: OutlineInputBorder(),
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
                    final trainingClass = _searchResults[index];
                    return _buildSearchResultCard(trainingClass, screenWidth, screenHeight);
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

  Widget _buildSearchResultCard(TrainingClass trainingClass, double screenWidth, double screenHeight) {
    return Card(
      margin: EdgeInsets.only(bottom: screenHeight * 0.015),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class Name and Price
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trainingClass.name,
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (trainingClass.category.isNotEmpty) ...[
                        SizedBox(height: screenHeight * 0.005),
                        Text(
                          trainingClass.category,
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
                Text(
                  '\$${trainingClass.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: screenHeight * 0.015),
            
            // Time and Location
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
                    _formatDateTime(trainingClass.startTime),
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: screenHeight * 0.01),
            
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
                    trainingClass.location,
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: screenHeight * 0.01),
            
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: screenWidth * 0.04,
                  color: Colors.grey[600],
                ),
                SizedBox(width: screenWidth * 0.02),
                Text(
                  '${trainingClass.participants.length}/${trainingClass.maxParticipants} enrolled',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            if (trainingClass.description.isNotEmpty) ...[
              SizedBox(height: screenHeight * 0.015),
              Text(
                trainingClass.description,
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            SizedBox(height: screenHeight * 0.015),
            
            // Enroll Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: trainingClass.participants.length >= trainingClass.maxParticipants
                    ? null
                    : () => _enrollInClass(trainingClass.id ?? ''),
                style: ElevatedButton.styleFrom(
                  backgroundColor: trainingClass.participants.length >= trainingClass.maxParticipants
                      ? Colors.grey
                      : Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  trainingClass.participants.length >= trainingClass.maxParticipants
                      ? 'Class Full'
                      : 'Enroll in Class',
                ),
              ),
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
      return Center(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.class_,
                size: screenWidth * 0.2,
                color: Colors.grey[400],
              ),
              SizedBox(height: screenHeight * 0.02),
              Text(
                'No Enrolled Classes',
                style: TextStyle(
                  fontSize: screenWidth * 0.06,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              Text(
                'You haven\'t enrolled in any classes yet.\nUse the Search tab to find classes near you!',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: screenHeight * 0.03),
              ElevatedButton(
                onPressed: () => _tabController.animateTo(0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.08,
                    vertical: screenHeight * 0.015,
                  ),
                ),
                child: Text(
                  'Search Classes',
                  style: TextStyle(fontSize: screenWidth * 0.04),
                ),
              ),
            ],
          ),
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
            Text(
              'My Enrolled Classes (${_enrolledClasses.length})',
              style: TextStyle(
                fontSize: screenWidth * 0.05,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
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
    final startTime = DateTime.tryParse(classInfo['startTime'] as String? ?? '');
    final endTime = DateTime.tryParse(classInfo['endTime'] as String? ?? '');
    final city = classInfo['city'] as String?;
    final state = classInfo['state'] as String?;
    final pricePerClass = (classInfo['pricePerClass'] as num?)?.toDouble() ?? 0.0;
    final capacity = classInfo['capacity'] as int? ?? 0;
    final countRegistered = classInfo['countRegistered'] as int? ?? 0;
    final sessionId = classInfo['sessionId'] as String?;
    final overview = classInfo['overview'] as String?;
    final classTags = (classInfo['classTags'] as List<dynamic>?)?.cast<String>();
    final enrollmentStatus = enrollmentInfo['status'] as String? ?? 'UNKNOWN';
    final enrolledAt = enrollmentInfo['enrolledAt'] as String?;

    final isPast = endTime != null && endTime.isBefore(DateTime.now());
    final isCancelled = enrollmentStatus.toUpperCase() == 'CANCELLED';

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
                    color: isCancelled
                        ? Colors.red
                        : isPast
                        ? Colors.grey
                        : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCancelled
                        ? 'CANCELLED'
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
            if (!isCancelled && !isPast && sessionId != null) ...[
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
}
