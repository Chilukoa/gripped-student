import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/class_service.dart';
import '../services/user_service.dart';
import '../models/class_creation.dart';
import 'update_profile_screen.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Form controllers
  final _classNameController = TextEditingController();
  final _overviewController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _priceController = TextEditingController();

  // Class details
  List<String> _selectedTags = [];
  List<TextEditingController> _tagControllers = [];

  // Session scheduling
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  int _capacity = 15;

  // Recurrence settings
  bool _isRecurring = false;
  String _recurrenceType = 'weekly'; // daily, weekly, monthly
  int _numberOfSessions = 1;

  @override
  void initState() {
    super.initState();
    // Initialize with one tag controller
    _tagControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _overviewController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _priceController.dispose();
    _pageController.dispose();
    // Dispose tag controllers
    for (var controller in _tagControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addTag() {
    setState(() {
      _tagControllers.add(TextEditingController());
    });
  }

  void _removeTag(int index) {
    setState(() {
      _tagControllers[index].dispose();
      _tagControllers.removeAt(index);
    });
  }

  void _collectTags() {
    _selectedTags = _tagControllers
        .map((controller) => controller.text.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
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

  void _nextStep() {
    // Validate current step before advancing
    if (_currentStep == 0) {
      // Validate Step 1: Class Details
      if (!_formKey.currentState!.validate()) {
        return;
      }

      // Collect and validate tags
      _collectTags();
      if (_selectedTags.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one tag'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  List<ClassSession> _generateSessions() {
    print('CreateClass: Generating sessions...');
    List<ClassSession> sessions = [];
    DateTime currentDate = _selectedDate;

    if (!_isRecurring) {
      // Single session
      final startDateTime = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      final endDateTime = DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      sessions.add(
        ClassSession(
          startDateTime: startDateTime,
          endDateTime: endDateTime,
          capacity: _capacity,
        ),
      );
    } else {
      // Recurring sessions
      for (int i = 0; i < _numberOfSessions; i++) {
        DateTime sessionDate = currentDate;

        if (_recurrenceType == 'daily') {
          sessionDate = currentDate.add(Duration(days: i));
        } else if (_recurrenceType == 'weekly') {
          sessionDate = currentDate.add(Duration(days: i * 7));
        } else if (_recurrenceType == 'monthly') {
          sessionDate = DateTime(
            currentDate.year,
            currentDate.month + i,
            currentDate.day,
          );
        }

        final startDateTime = DateTime(
          sessionDate.year,
          sessionDate.month,
          sessionDate.day,
          _startTime.hour,
          _startTime.minute,
        );
        final endDateTime = DateTime(
          sessionDate.year,
          sessionDate.month,
          sessionDate.day,
          _endTime.hour,
          _endTime.minute,
        );

        sessions.add(
          ClassSession(
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            capacity: _capacity,
          ),
        );
      }
    }

    print('CreateClass: Generated ${sessions.length} sessions');
    return sessions;
  }

  Future<void> _createClass() async {
    print('CreateClass: Starting class creation...');

    // Validate required fields manually since form key is only on first step
    if (_classNameController.text.trim().isEmpty ||
        _overviewController.text.trim().isEmpty ||
        _address1Controller.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty ||
        _stateController.text.trim().isEmpty ||
        _zipController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty) {
      print('CreateClass: Validation failed - missing required fields');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Collect and validate tags
    _collectTags();
    if (_selectedTags.isEmpty) {
      print('CreateClass: Validation failed - no tags provided');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one tag'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate price
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      print(
        'CreateClass: Validation failed - invalid price: ${_priceController.text}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid price'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate time range
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes <= startMinutes) {
      print('CreateClass: Validation failed - end time before start time');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print('CreateClass: Validation passed, creating class...');
    setState(() => _isLoading = true);

    try {
      final sessions = _generateSessions();
      final classRequest = ClassCreationRequest(
        className: _classNameController.text.trim(),
        overview: _overviewController.text.trim(),
        classLocationAddress1: _address1Controller.text.trim(),
        classLocationAddress2: _address2Controller.text.trim().isNotEmpty
            ? _address2Controller.text.trim()
            : null,
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        zip: _zipController.text.trim(),
        pricePerClass: double.parse(_priceController.text),
        currency: 'USD',
        classTags: _selectedTags,
        sessions: sessions,
      );

      print('CreateClass: Calling ClassService.createClass...');
      final response = await ClassService().createClass(classRequest);

      print(
        'CreateClass: API call successful, ${response.sessions.length} sessions created',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Class created successfully! ${response.sessions.length} session(s) scheduled.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      print('CreateClass: Error creating class: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating class: $e'),
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Class'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'updateprofile') {
                _updateProfile();
              } else if (value == 'signout') {
                _signOut();
              }
            },
            itemBuilder: (BuildContext context) => [
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
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Sign Out'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Row(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _currentStep
                            ? Colors.deepPurple
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (i < 2) SizedBox(width: screenWidth * 0.02),
                ],
              ],
            ),
          ),

          // Step titles
          Container(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Class Details',
                  style: TextStyle(
                    fontWeight: _currentStep == 0
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _currentStep == 0 ? Colors.deepPurple : Colors.grey,
                  ),
                ),
                Text(
                  'Schedule',
                  style: TextStyle(
                    fontWeight: _currentStep == 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _currentStep == 1 ? Colors.deepPurple : Colors.grey,
                  ),
                ),
                Text(
                  'Review',
                  style: TextStyle(
                    fontWeight: _currentStep == 2
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _currentStep == 2 ? Colors.deepPurple : Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: screenHeight * 0.02),

          // Form content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentStep = index),
              children: [
                _buildClassDetailsStep(screenWidth, screenHeight),
                _buildScheduleStep(screenWidth, screenHeight),
                _buildReviewStep(screenWidth, screenHeight),
              ],
            ),
          ),

          // Navigation buttons
          Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _prevStep,
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentStep > 0) SizedBox(width: screenWidth * 0.04),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_currentStep == 2 ? _createClass : _nextStep),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_currentStep == 2 ? 'Create Class' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassDetailsStep(double screenWidth, double screenHeight) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Class Information',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: screenHeight * 0.02),

            // Class Name
            TextFormField(
              controller: _classNameController,
              decoration: const InputDecoration(
                labelText: 'Class Name',
                hintText: 'e.g., Morning Yoga Flow',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a class name';
                }
                return null;
              },
            ),
            SizedBox(height: screenHeight * 0.02),

            // Overview/Description
            TextFormField(
              controller: _overviewController,
              decoration: const InputDecoration(
                labelText: 'Class Description',
                hintText: 'Describe what students can expect from this class',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a class description';
                }
                return null;
              },
            ),
            SizedBox(height: screenHeight * 0.03),

            Text(
              'Location',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: screenHeight * 0.02),

            // Address Line 1
            TextFormField(
              controller: _address1Controller,
              decoration: const InputDecoration(
                labelText: 'Address Line 1',
                hintText: '123 Fitness Street',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an address';
                }
                return null;
              },
            ),
            SizedBox(height: screenHeight * 0.02),

            // Address Line 2 (Optional)
            TextFormField(
              controller: _address2Controller,
              decoration: const InputDecoration(
                labelText: 'Address Line 2 (Optional)',
                hintText: 'Suite, Unit, etc.',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: screenHeight * 0.02),

            // City, State, Zip
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(
                      labelText: 'State',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: TextFormField(
                    controller: _zipController,
                    decoration: const InputDecoration(
                      labelText: 'ZIP',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.03),

            // Price
            Text(
              'Pricing',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: screenHeight * 0.02),

            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Price per Class (\$)',
                hintText: '25.00',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a price';
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'Please enter a valid price';
                }
                return null;
              },
            ),
            SizedBox(height: screenHeight * 0.03),

            // Tags
            Text(
              'Class Tags',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: screenHeight * 0.02),

            // Dynamic tag input fields
            ..._tagControllers.asMap().entries.map((entry) {
              int index = entry.key;
              TextEditingController controller = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: 'Tag ${index + 1}',
                          hintText: 'e.g., strength, cardio, yoga',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.tag),
                        ),
                        validator: (value) {
                          // Allow empty individual tags, but at least one non-empty tag required overall
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _removeTag(index),
                      icon: const Icon(Icons.delete, color: Colors.red),
                    ),
                  ],
                ),
              );
            }).toList(),

            ElevatedButton.icon(
              onPressed: _addTag,
              icon: const Icon(Icons.add),
              label: const Text('Add Tag'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),

            // Add validation message for tags
            if (_tagControllers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'At least one tag is required',
                  style: TextStyle(color: Colors.red[600], fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleStep(double screenWidth, double screenHeight) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule Your Class',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: screenHeight * 0.02),

          // Date Selection
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.calendar_today,
                color: Colors.deepPurple,
              ),
              title: const Text('Date'),
              subtitle: Text(
                '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
            ),
          ),

          SizedBox(height: screenHeight * 0.02),

          // Time Selection
          Row(
            children: [
              Expanded(
                child: Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.access_time,
                      color: Colors.deepPurple,
                    ),
                    title: const Text('Start Time'),
                    subtitle: Text(_startTime.format(context)),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (time != null) {
                        setState(() => _startTime = time);
                        // Auto-adjust end time to be 1 hour later if it's before start time
                        final startMinutes = time.hour * 60 + time.minute;
                        final endMinutes = _endTime.hour * 60 + _endTime.minute;
                        if (endMinutes <= startMinutes) {
                          final newEndMinutes = startMinutes + 60;
                          _endTime = TimeOfDay(
                            hour: (newEndMinutes ~/ 60) % 24,
                            minute: newEndMinutes % 60,
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.02),
              Expanded(
                child: Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.access_time_filled,
                      color: Colors.deepPurple,
                    ),
                    title: const Text('End Time'),
                    subtitle: Text(_endTime.format(context)),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _endTime,
                      );
                      if (time != null) {
                        setState(() => _endTime = time);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: screenHeight * 0.02),

          // Capacity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.group, color: Colors.deepPurple),
                      const SizedBox(width: 16),
                      Text(
                        'Class Capacity: $_capacity students',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  Slider(
                    value: _capacity.toDouble(),
                    min: 1,
                    max: 50,
                    divisions: 49,
                    label: _capacity.toString(),
                    onChanged: (value) {
                      setState(() => _capacity = value.round());
                    },
                    activeColor: Colors.deepPurple,
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: screenHeight * 0.03),

          // Recurrence Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Recurring Class'),
                    subtitle: const Text('Create multiple sessions'),
                    value: _isRecurring,
                    onChanged: (value) {
                      setState(() => _isRecurring = value);
                    },
                    activeColor: Colors.deepPurple,
                  ),

                  if (_isRecurring) ...[
                    const Divider(),

                    // Recurrence Type
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Repeat',
                        border: OutlineInputBorder(),
                      ),
                      value: _recurrenceType,
                      onChanged: (value) {
                        setState(() => _recurrenceType = value!);
                      },
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                      ],
                    ),

                    SizedBox(height: screenHeight * 0.02),

                    // Number of Sessions
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Number of Sessions',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: _numberOfSessions.toString(),
                      onChanged: (value) {
                        final sessions = int.tryParse(value);
                        if (sessions != null && sessions > 0) {
                          _numberOfSessions = sessions;
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep(double screenWidth, double screenHeight) {
    final sessions = _generateSessions();
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final totalRevenue = sessions.length * price;

    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Create',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: screenHeight * 0.02),

          // Class Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _classNameController.text,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(_overviewController.text),
                  SizedBox(height: screenHeight * 0.02),

                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${_address1Controller.text}, ${_cityController.text}, ${_stateController.text} ${_zipController.text}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.01),

                  // Price and Capacity
                  Row(
                    children: [
                      const Icon(
                        Icons.attach_money,
                        size: 16,
                        color: Colors.grey,
                      ),
                      Flexible(
                        child: Text('\$${_priceController.text} per class'),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.group, size: 16, color: Colors.grey),
                      Flexible(child: Text('$_capacity max students')),
                    ],
                  ),

                  if (_selectedTags.isNotEmpty) ...[
                    SizedBox(height: screenHeight * 0.01),
                    Wrap(
                      spacing: 4,
                      children: _selectedTags.map((tag) {
                        return Chip(
                          label: Text(
                            tag,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.deepPurple.withOpacity(0.1),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(height: screenHeight * 0.02),

          // Sessions Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scheduled Sessions (${sessions.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),

                  ...sessions.take(5).map((session) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${session.startDateTime.month}/${session.startDateTime.day}/${session.startDateTime.year} - ${TimeOfDay.fromDateTime(session.startDateTime).format(context)} to ${TimeOfDay.fromDateTime(session.endDateTime).format(context)}',
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  if (sessions.length > 5)
                    Text(
                      '... and ${sessions.length - 5} more sessions',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),

                  SizedBox(height: screenHeight * 0.02),

                  // Revenue Projection
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.trending_up, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Potential Revenue: \$${totalRevenue.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        Text(
                          '(full capacity)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
