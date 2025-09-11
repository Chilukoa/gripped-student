import 'package:flutter/material.dart';
import '../models/training_class.dart';
import '../services/class_service.dart';
import '../services/auth_service.dart';
import 'create_class_screen.dart';
import 'login_screen.dart';

class TrainerDashboardScreen extends StatefulWidget {
  const TrainerDashboardScreen({super.key});

  @override
  State<TrainerDashboardScreen> createState() => _TrainerDashboardScreenState();
}

class _TrainerDashboardScreenState extends State<TrainerDashboardScreen> {
  List<TrainingClass> _classes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final classes = await ClassService().getClassesByTrainer();
      
      if (mounted) {
        setState(() {
          _classes = classes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
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
        title: const Text('Trainer Dashboard'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClasses,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'signout') {
                _signOut();
              }
            },
            itemBuilder: (context) => [
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
      ),
      body: _buildBody(screenWidth, screenHeight),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CreateClassScreen(),
            ),
          ).then((_) => _loadClasses()); // Refresh classes after creating
        },
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Class'),
      ),
    );
  }

  Widget _buildBody(double screenWidth, double screenHeight) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
        ),
      );
    }

    if (_error != null) {
      return _buildErrorState(screenWidth, screenHeight);
    }

    if (_classes.isEmpty) {
      return _buildEmptyState(screenWidth, screenHeight);
    }

    return _buildClassesList(screenWidth, screenHeight);
  }

  Widget _buildErrorState(double screenWidth, double screenHeight) {
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
              _error!,
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenHeight * 0.03),
            ElevatedButton(
              onPressed: _loadClasses,
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

  Widget _buildEmptyState(double screenWidth, double screenHeight) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center,
              size: screenWidth * 0.2,
              color: Colors.grey[400],
            ),
            SizedBox(height: screenHeight * 0.02),
            Text(
              'No Classes Yet',
              style: TextStyle(
                fontSize: screenWidth * 0.06,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              'Create your first training class to get started!',
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenHeight * 0.03),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CreateClassScreen(),
                  ),
                ).then((_) => _loadClasses());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.08,
                  vertical: screenHeight * 0.015,
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(
                'Create First Class',
                style: TextStyle(fontSize: screenWidth * 0.04),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassesList(double screenWidth, double screenHeight) {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(screenWidth * 0.04),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Classes',
                style: TextStyle(
                  fontSize: screenWidth * 0.06,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              SizedBox(height: screenHeight * 0.005),
              Text(
                '${_classes.length} ${_classes.length == 1 ? 'class' : 'classes'} scheduled',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        
        // Classes List
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(screenWidth * 0.04),
            itemCount: _classes.length,
            itemBuilder: (context, index) {
              final trainingClass = _classes[index];
              return _buildClassCard(trainingClass, screenWidth, screenHeight);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClassCard(TrainingClass trainingClass, double screenWidth, double screenHeight) {
    final isActive = trainingClass.status == 'active';
    final isPast = trainingClass.endTime.isBefore(DateTime.now());
    
    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.015),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Class Image and Status
          Stack(
            children: [
              Container(
                height: screenHeight * 0.15,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.deepPurple.withOpacity(0.8),
                      Colors.deepPurple.withOpacity(0.6),
                    ],
                  ),
                ),
                child: trainingClass.imageUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.network(
                          trainingClass.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultClassImage(screenWidth, screenHeight);
                          },
                        ),
                      )
                    : _buildDefaultClassImage(screenWidth, screenHeight),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPast 
                        ? Colors.grey
                        : isActive 
                            ? Colors.green 
                            : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isPast ? 'Completed' : trainingClass.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Class Details
          Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Class Name and Category
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
                
                // Time and Duration
                Row(
                  children: [
                    Icon(Icons.access_time, size: screenWidth * 0.04, color: Colors.grey[600]),
                    SizedBox(width: screenWidth * 0.02),
                    Expanded(
                      child: Text(
                        '${_formatDateTime(trainingClass.startTime)} • ${trainingClass.duration} min',
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: screenHeight * 0.01),
                
                // Location and Participants
                Row(
                  children: [
                    Icon(Icons.location_on, size: screenWidth * 0.04, color: Colors.grey[600]),
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
                    Icon(Icons.people, size: screenWidth * 0.04, color: Colors.grey[600]),
                    SizedBox(width: screenWidth * 0.02),
                    Text(
                      '${trainingClass.participants.length}/${trainingClass.maxParticipants} participants',
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: screenHeight * 0.015),
                
                // Description
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultClassImage(double screenWidth, double screenHeight) {
    return Container(
      height: screenHeight * 0.15,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.withOpacity(0.8),
            Colors.deepPurple.withOpacity(0.6),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.fitness_center,
          size: screenWidth * 0.12,
          color: Colors.white,
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
      dateStr = '${dateTime.month}/${dateTime.day}';
    }
    
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    
    return '$dateStr at $displayHour:$displayMinute $period';
  }
}
