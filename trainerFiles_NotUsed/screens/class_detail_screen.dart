import 'package:flutter/material.dart';
import '../models/training_class.dart';
import '../services/class_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'edit_training_class_screen.dart';
import 'update_profile_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  final TrainingClass trainingClass;

  const ClassDetailScreen({super.key, required this.trainingClass});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  final _messageController = TextEditingController();
  bool _isLoading = false;
  bool _isSendingMessage = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a message'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSendingMessage = true);

    try {
      await ClassService().sendMessage(
        widget.trainingClass.sessionId,
        _messageController.text.trim(),
      );

      if (mounted) {
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingMessage = false);
      }
    }
  }

  Future<void> _cancelClass() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Class'),
        content: const Text(
          'Are you sure you want to cancel this class? This action cannot be undone and all enrolled students will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Class'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Class'),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;

    setState(() => _isLoading = true);

    try {
      await ClassService().cancelClass(widget.trainingClass.sessionId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(
          context,
        ).pop(true); // Return true to indicate refresh needed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling class: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editClass() async {
    // Temporary debug to check if EditClassScreen is accessible
    final editScreen = EditClassScreen(trainingClass: widget.trainingClass);

    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => editScreen));

    // If class was updated, return to dashboard with refresh indicator
    if (result == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(
          context,
        ).pop(true); // Return true to indicate refresh needed
      }
    }
  }

  Future<void> _updateProfile() async {
    try {
      // Get current user profile
      final currentProfile = await UserService().getUserProfile();

      if (mounted && currentProfile != null) {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                UpdateProfileScreen(currentProfile: currentProfile),
          ),
        );

        // If profile was updated successfully, show confirmation
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
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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
      appBar: AppBar(
        title: Text(widget.trainingClass.className),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _editClass();
                  break;
                case 'cancel':
                  _cancelClass();
                  break;
                case 'updateprofile':
                  _updateProfile();
                  break;
                case 'signout':
                  _signOut();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit, color: Colors.blue),
                  title: Text('Edit Class'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'cancel',
                child: ListTile(
                  leading: Icon(Icons.cancel, color: Colors.red),
                  title: Text('Cancel Class'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'updateprofile',
                child: ListTile(
                  leading: Icon(Icons.person, color: Colors.green),
                  title: Text('Update Profile'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'signout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.grey),
                  title: Text('Sign Out'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(screenWidth * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class Header Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.trainingClass.className,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          if (widget.trainingClass.overview != null)
                            Text(
                              widget.trainingClass.overview!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          SizedBox(height: screenHeight * 0.02),

                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                widget.trainingClass.status,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.trainingClass.status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.02),

                  // Class Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Class Details',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: screenHeight * 0.02),

                          // Date & Time
                          _buildDetailRow(
                            Icons.schedule,
                            'Date & Time',
                            _formatDateTime(
                              widget.trainingClass.startTime,
                              widget.trainingClass.endTime,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.015),

                          // Location
                          _buildDetailRow(
                            Icons.location_on,
                            'Location',
                            '${widget.trainingClass.city ?? ''}, ${widget.trainingClass.state ?? ''}',
                          ),
                          SizedBox(height: screenHeight * 0.015),

                          // Price
                          _buildDetailRow(
                            Icons.attach_money,
                            'Price',
                            '\$${widget.trainingClass.pricePerClass.toStringAsFixed(2)} per student',
                          ),
                          SizedBox(height: screenHeight * 0.015),

                          // Capacity
                          _buildDetailRow(
                            Icons.group,
                            'Enrollment',
                            '${widget.trainingClass.countRegistered}/${widget.trainingClass.capacity} students enrolled',
                          ),

                          // Tags
                          if (widget.trainingClass.classTags != null &&
                              widget.trainingClass.classTags!.isNotEmpty) ...[
                            SizedBox(height: screenHeight * 0.015),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.tag,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Tags',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: widget
                                            .trainingClass
                                            .classTags!
                                            .map((tag) {
                                              return Chip(
                                                label: Text(
                                                  tag,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                backgroundColor: Colors
                                                    .deepPurple
                                                    .withOpacity(0.1),
                                              );
                                            })
                                            .toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.02),

                  // Revenue Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Revenue Information',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: screenHeight * 0.02),

                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.trending_up,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Current Revenue',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        '\$${(widget.trainingClass.countRegistered * widget.trainingClass.pricePerClass).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Max Potential',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        '\$${(widget.trainingClass.capacity * widget.trainingClass.pricePerClass).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.02),

                  // Message Students Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Message Students',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: screenHeight * 0.02),

                          TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText:
                                  'Type your message to all enrolled students...',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 4,
                          ),
                          SizedBox(height: screenHeight * 0.02),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSendingMessage
                                  ? null
                                  : _sendMessage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                              ),
                              icon: _isSendingMessage
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: Text(
                                _isSendingMessage
                                    ? 'Sending...'
                                    : 'Send Message',
                              ),
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.01),

                          if (widget.trainingClass.countRegistered == 0)
                            Text(
                              'No students enrolled yet. Messages will be sent to students once they enroll.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          else
                            Text(
                              'Message will be sent to ${widget.trainingClass.countRegistered} enrolled student${widget.trainingClass.countRegistered == 1 ? '' : 's'}.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      case 'COMPLETED':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _formatDateTime(DateTime startTime, DateTime endTime) {
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
    final displayStartHour = startHour > 12
        ? startHour - 12
        : (startHour == 0 ? 12 : startHour);
    final displayStartMinute = startMinute.toString().padLeft(2, '0');

    final endHour = endTime.hour;
    final endMinute = endTime.minute;
    final endPeriod = endHour >= 12 ? 'PM' : 'AM';
    final displayEndHour = endHour > 12
        ? endHour - 12
        : (endHour == 0 ? 12 : endHour);
    final displayEndMinute = endMinute.toString().padLeft(2, '0');

    return '$dateStr, $displayStartHour:$displayStartMinute $startPeriod - $displayEndHour:$displayEndMinute $endPeriod';
  }
}
