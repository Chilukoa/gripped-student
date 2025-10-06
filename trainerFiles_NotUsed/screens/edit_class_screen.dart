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
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();

  bool _isLoading = false;
  String _selectedCurrency = 'USD';
  final List<String> _currencies = ['USD', 'CAD', 'EUR', 'GBP'];
  List<String> _selectedTags = [];

  // Dynamic tag controllers instead of predefined list
  List<TextEditingController> _tagControllers = [];

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    final cls = widget.trainingClass;
    _classNameController.text = cls.className;
    _overviewController.text = cls.overview ?? '';
    _address1Controller.text = cls.classLocationAddress1 ?? '';
    _address2Controller.text = cls.classLocationAddress2 ?? '';
    _cityController.text = cls.city ?? '';
    _stateController.text = cls.state ?? '';
    _zipController.text = cls.zip ?? '';
    _priceController.text = cls.pricePerClass.toString();
    _capacityController.text = cls.capacity.toString();
    _selectedCurrency = cls.currency ?? 'USD';
    _selectedTags = List<String>.from(cls.classTags ?? []);

    // Initialize tag controllers with existing tags
    for (String tag in _selectedTags) {
      _tagControllers.add(TextEditingController(text: tag));
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
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
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
        .toList();
  }

  Future<void> _updateClass() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Collect tags from text controllers
    _collectTags();
    if (_selectedTags.isEmpty) {
      _showError('Please add at least one tag');
      return;
    }

    // Validate that price can be parsed
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      _showError('Please enter a valid price greater than 0');
      return;
    }

    final capacity = int.tryParse(_capacityController.text.trim());
    if (capacity == null || capacity <= 0) {
      _showError('Please enter a valid capacity greater than 0');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare the update payload - only include fields that can be updated
      final updatePayload = {
        'className': _classNameController.text.trim(),
        'overview': _overviewController.text.trim(),
        'classLocationAddress1': _address1Controller.text.trim(),
        'classLocationAddress2': _address2Controller.text.trim().isEmpty
            ? null
            : _address2Controller.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'zip': _zipController.text.trim(),
        'pricePerClass': price,
        'currency': _selectedCurrency,
        'classTags': _selectedTags,
        'capacity': capacity,
      };

      await ClassService().updateClassWithPayload(
        widget.trainingClass.sessionId,
        updatePayload,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(
          context,
          true,
        ); // Return true to indicate successful update
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to update class: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildTagSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Class Tags',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 8),

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
                      // Allow empty individual tags, validation handled at submission
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Edit Class'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Class Details Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Class Information',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Class Name
                      TextFormField(
                        controller: _classNameController,
                        decoration: const InputDecoration(
                          labelText: 'Class Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.fitness_center),
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Please enter a class name';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      // Overview
                      TextFormField(
                        controller: _overviewController,
                        decoration: const InputDecoration(
                          labelText: 'Class Description',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                      ),

                      SizedBox(height: screenHeight * 0.03),

                      // Tags
                      _buildTagSelector(),
                    ],
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              // Location Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Details',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Address Line 1
                      TextFormField(
                        controller: _address1Controller,
                        decoration: const InputDecoration(
                          labelText: 'Address Line 1 *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                          hintText: 'Street address, building name, etc.',
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
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
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                          hintText: 'Suite, unit, floor, etc.',
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      // City, State, Zip Row
                      Row(
                        children: [
                          // City
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _cityController,
                              decoration: const InputDecoration(
                                labelText: 'City *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.location_city),
                              ),
                              validator: (value) {
                                if (value?.trim().isEmpty ?? true) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),

                          SizedBox(width: screenWidth * 0.02),

                          // State
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _stateController,
                              decoration: const InputDecoration(
                                labelText: 'State *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.map),
                              ),
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(2),
                                UpperCaseTextFormatter(),
                              ],
                              validator: (value) {
                                if (value?.trim().isEmpty ?? true) {
                                  return 'Required';
                                }
                                if (value!.length != 2) {
                                  return 'Use 2-letter code';
                                }
                                return null;
                              },
                            ),
                          ),

                          SizedBox(width: screenWidth * 0.02),

                          // Zip
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _zipController,
                              decoration: const InputDecoration(
                                labelText: 'ZIP *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.local_post_office),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(5),
                              ],
                              validator: (value) {
                                if (value?.trim().isEmpty ?? true) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              // Pricing & Capacity Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pricing & Capacity',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      Row(
                        children: [
                          // Price
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(
                                labelText: 'Price per Student *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.attach_money),
                                hintText: '25.00',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                              validator: (value) {
                                if (value?.trim().isEmpty ?? true) {
                                  return 'Please enter a price';
                                }
                                final price = double.tryParse(value!);
                                if (price == null || price <= 0) {
                                  return 'Enter valid price > 0';
                                }
                                return null;
                              },
                            ),
                          ),

                          SizedBox(width: screenWidth * 0.02),

                          // Currency
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: _selectedCurrency,
                              decoration: const InputDecoration(
                                labelText: 'Currency',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.monetization_on),
                              ),
                              items: _currencies.map((currency) {
                                return DropdownMenuItem(
                                  value: currency,
                                  child: Text(currency),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCurrency = value ?? 'USD';
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      // Capacity
                      TextFormField(
                        controller: _capacityController,
                        decoration: const InputDecoration(
                          labelText: 'Maximum Capacity *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.group),
                          hintText: 'Maximum number of students',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Please enter maximum capacity';
                          }
                          final capacity = int.tryParse(value!);
                          if (capacity == null || capacity <= 0) {
                            return 'Enter valid capacity > 0';
                          }
                          if (capacity > 100) {
                            return 'Capacity cannot exceed 100';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.04),

              // Update Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateClass,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
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
                            SizedBox(width: 10),
                            Text('Updating Class...'),
                          ],
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

// Custom formatter to convert text to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
