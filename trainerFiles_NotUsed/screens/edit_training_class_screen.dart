import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/training_class.dart';
import '../services/class_service.dart';

class EditClassScreen extends StatefulWidget {
  final TrainingClass trainingClass;

  const EditClassScreen({super.key, required this.trainingClass});

  @override
  State<EditClassScreen> createState() => _EditClassScreenState();
}

class _EditClassScreenState extends State<EditClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _classNameController = TextEditingController();
  final _overviewController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;

  // Dynamic tag controllers instead of predefined list
  List<TextEditingController> _tagControllers = [];
  Set<String> _selectedTags = {};

  @override
  void initState() {
    super.initState();
    _initializeFormData();
  }

  void _initializeFormData() {
    final trainingClass = widget.trainingClass;

    _classNameController.text = trainingClass.className;
    _overviewController.text = trainingClass.overview ?? '';
    _address1Controller.text = trainingClass.classLocationAddress1 ?? '';
    _address2Controller.text = trainingClass.classLocationAddress2 ?? '';
    _priceController.text = trainingClass.pricePerClass.toString();
    _capacityController.text = trainingClass.capacity.toString();

    // Parse date and time from startTime
    _selectedDate = trainingClass.startTime;
    _selectedTime = TimeOfDay.fromDateTime(trainingClass.startTime);

    // Initialize selected tags and controllers
    if (trainingClass.classTags != null) {
      _selectedTags = Set<String>.from(trainingClass.classTags!);
      // Create controllers for existing tags
      for (String tag in trainingClass.classTags!) {
        _tagControllers.add(TextEditingController(text: tag));
      }
    }

    // If no existing tags, start with one empty controller
    if (_tagControllers.isEmpty) {
      _tagControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _overviewController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _priceController.dispose();
    _capacityController.dispose();
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
        .toSet();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _updateClass() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Collect tags from text controllers
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

    setState(() {
      _isLoading = true;
    });

    try {
      // Combine date and time
      final combinedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Calculate end time (assuming 1 hour duration)
      final combinedEndDateTime = combinedDateTime.add(
        const Duration(hours: 1),
      );

      final updatedClass = widget.trainingClass.copyWith(
        className: _classNameController.text.trim(),
        overview: _overviewController.text.trim(),
        classLocationAddress1: _address1Controller.text.trim(),
        classLocationAddress2: _address2Controller.text.trim(),
        pricePerClass: double.tryParse(_priceController.text.trim()),
        capacity: int.tryParse(_capacityController.text.trim()),
        startTime: combinedDateTime,
        endTime: combinedEndDateTime,
        classTags: _selectedTags.toList(),
      );

      await ClassService().updateClassWithPayload(
        widget.trainingClass.sessionId,
        updatedClass.toJson(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update class: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Class'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(screenWidth * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Class Name
              TextFormField(
                controller: _classNameController,
                decoration: const InputDecoration(
                  labelText: 'Class Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a class name';
                  }
                  return null;
                },
              ),
              SizedBox(height: screenWidth * 0.04),

              // Class Overview
              TextFormField(
                controller: _overviewController,
                decoration: const InputDecoration(
                  labelText: 'Class Overview *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a class overview';
                  }
                  return null;
                },
              ),
              SizedBox(height: screenWidth * 0.04),

              // Address Line 1
              TextFormField(
                controller: _address1Controller,
                decoration: const InputDecoration(
                  labelText: 'Address Line 1 *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter address line 1';
                  }
                  return null;
                },
              ),
              SizedBox(height: screenWidth * 0.04),

              // Address Line 2
              TextFormField(
                controller: _address2Controller,
                decoration: const InputDecoration(
                  labelText: 'Address Line 2',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: screenWidth * 0.04),

              // Price and Capacity Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price (\$) *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a price';
                        }
                        if (double.tryParse(value.trim()) == null) {
                          return 'Please enter a valid price';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Expanded(
                    child: TextFormField(
                      controller: _capacityController,
                      decoration: const InputDecoration(
                        labelText: 'Capacity *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter capacity';
                        }
                        final capacity = int.tryParse(value.trim());
                        if (capacity == null || capacity <= 0) {
                          return 'Please enter valid capacity';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenWidth * 0.04),

              // Date Selection
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Class Date *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.02),
                    GestureDetector(
                      onTap: _selectDate,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: screenWidth * 0.03,
                          horizontal: screenWidth * 0.02,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenWidth * 0.04),

              // Time Selection
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Class Time *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.02),
                    GestureDetector(
                      onTap: _selectTime,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: screenWidth * 0.03,
                          horizontal: screenWidth * 0.02,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedTime.format(context),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Icon(Icons.access_time, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: screenWidth * 0.04),

              // Tags Section
              const Text(
                'Class Tags',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: screenWidth * 0.02),

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
                            // Allow empty individual tags, but validation handled at submission
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
              SizedBox(height: screenWidth * 0.08),

              // Update Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateClass,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: screenWidth * 0.04),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        )
                      : const Text(
                          'Update Class',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
