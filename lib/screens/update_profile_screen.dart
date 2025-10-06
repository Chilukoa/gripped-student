import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart' hide UserProfile;
import '../models/user_profile.dart';
import '../services/user_service.dart';

class UpdateProfileScreen extends StatefulWidget {
  final UserProfile currentProfile;

  const UpdateProfileScreen({
    super.key,
    required this.currentProfile,
  });

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _populateFields();
  }

  void _populateFields() {
    _firstNameController.text = widget.currentProfile.firstName;
    _lastNameController.text = widget.currentProfile.lastName;
    _phoneController.text = widget.currentProfile.phone;
    _bioController.text = widget.currentProfile.bio;
    _zipCodeController.text = widget.currentProfile.zip;
    _cityController.text = widget.currentProfile.city;
    _stateController.text = widget.currentProfile.state;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _zipCodeController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedProfile = UserProfile(
        id: widget.currentProfile.id,
        role: widget.currentProfile.role,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        displayName: '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        phone: _phoneController.text.trim(),
        bio: _bioController.text.trim(),
        specialty: widget.currentProfile.specialty,
        address1: widget.currentProfile.address1,
        address2: widget.currentProfile.address2,
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        zip: _zipCodeController.text.trim(),
        gender: widget.currentProfile.gender,
        profileImage: widget.currentProfile.profileImage,
        idImage: widget.currentProfile.idImage,
        certifications: widget.currentProfile.certifications,
        createdAt: widget.currentProfile.createdAt,
        updatedAt: DateTime.now(),
      );

      await UserService().createOrUpdateUserProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      safePrint('UpdateProfileScreen: Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
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

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]+$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  String? _validateZipCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Zip code is required';
    }
    final zipRegex = RegExp(r'^\d{5}(-\d{4})?$');
    if (!zipRegex.hasMatch(value.trim())) {
      return 'Please enter a valid zip code (e.g., 12345 or 12345-6789)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Update Profile'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Personal Information Section
              Card(
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      
                      TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name *',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => _validateRequired(value, 'First name'),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      
                      TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name *',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => _validateRequired(value, 'Last name'),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone *',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: _validatePhone,
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      
                      TextFormField(
                        controller: _bioController,
                        decoration: const InputDecoration(
                          labelText: 'Bio',
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                          hintText: 'Tell us about yourself...',
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              // Location Information Section
              Card(
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Information',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      
                      TextFormField(
                        controller: _zipCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Zip Code *',
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(),
                          hintText: 'e.g., 12345',
                        ),
                        keyboardType: TextInputType.number,
                        validator: _validateZipCode,
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      
                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'City *',
                          prefixIcon: Icon(Icons.location_city),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => _validateRequired(value, 'City'),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      
                      TextFormField(
                        controller: _stateController,
                        decoration: const InputDecoration(
                          labelText: 'State *',
                          prefixIcon: Icon(Icons.map),
                          border: OutlineInputBorder(),
                          hintText: 'e.g., TX, CA, NY',
                        ),
                        validator: (value) => _validateRequired(value, 'State'),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.03),

              // Update Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            const Text('Updating...'),
                          ],
                        )
                      : Text(
                          'Update Profile',
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: Colors.grey[600],
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
