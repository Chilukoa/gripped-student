import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:amplify_flutter/amplify_flutter.dart' hide UserProfile;
import '../models/user_profile.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../widgets/s3_image.dart';

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
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  String _selectedGender = 'Male';
  final List<String> _genders = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  bool _isLoading = false;

  // Image handling - store both XFile and bytes for web compatibility
  XFile? _profileImageFile;
  Uint8List? _profileImageBytes;

  @override
  void initState() {
    super.initState();
    _populateFields();
  }

  void _populateFields() {
    safePrint('UpdateProfileScreen: Populating fields');
    safePrint('Profile image key: ${widget.currentProfile.profileImage}');
    
    _firstNameController.text = widget.currentProfile.firstName;
    _lastNameController.text = widget.currentProfile.lastName;
    _displayNameController.text = widget.currentProfile.displayName;
    _phoneController.text = widget.currentProfile.phone;
    _bioController.text = widget.currentProfile.bio;
    _address1Controller.text = widget.currentProfile.address1;
    _address2Controller.text = widget.currentProfile.address2 ?? '';
    _zipCodeController.text = widget.currentProfile.zip;
    _cityController.text = widget.currentProfile.city;
    _stateController.text = widget.currentProfile.state;
    
    _selectedGender = widget.currentProfile.gender.isNotEmpty
        ? widget.currentProfile.gender
        : 'Male';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _zipCodeController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          if (type == 'profile') {
            _profileImageFile = pickedFile;
            _profileImageBytes = bytes;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFullScreenImage(String? imageKey, String title) {
    if (imageKey == null) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: S3Image(
                    imageKey: imageKey,
                    userId: widget.currentProfile.id,
                    fit: BoxFit.contain,
                    loadingWidget: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: const Center(
                      child: Icon(Icons.error, color: Colors.white, size: 50),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? profileImageUrl = widget.currentProfile.profileImage;

      // Handle image uploads if new images were selected (using bytes for web compatibility)
      if (_profileImageBytes != null && _profileImageFile != null) {
        try {
          profileImageUrl = await UserService().uploadSingleImageFromBytes(
            _profileImageBytes!,
            _profileImageFile!.name,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload profile image: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      final updatedProfile = UserProfile(
        id: widget.currentProfile.id,
        role: widget.currentProfile.role,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        phone: _phoneController.text.trim(),
        bio: _bioController.text.trim(),
        specialty: widget.currentProfile.specialty,
        address1: _address1Controller.text.trim(),
        address2: _address2Controller.text.trim().isNotEmpty
            ? _address2Controller.text.trim()
            : null,
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        zip: _zipCodeController.text.trim(),
        gender: _selectedGender,
        profileImage: profileImageUrl,
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
    final cleanedValue = value.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanedValue.length < 10) {
      return 'Please enter a valid 10-digit phone number';
    }
    return null;
  }

  String? _validateZipCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Zip code is required';
    }
    if (value.trim().length != 5) {
      return 'Please enter a valid 5-digit zip code';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final actualWidth = MediaQuery.of(context).size.width;
    final actualHeight = MediaQuery.of(context).size.height;
    final isDesktop = actualWidth >= 800;
    final isTablet = actualWidth >= 600 && actualWidth < 800;
    // Cap the screenWidth for sizing calculations (prevents giant fonts on desktop)
    final screenWidth = isDesktop ? 500.0 : (isTablet ? 450.0 : actualWidth);
    final screenHeight = actualHeight;
    final contentMaxWidth = isDesktop ? 600.0 : (isTablet ? 500.0 : double.infinity);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Update Profile'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'signout') {
                _signOut();
              }
            },
            itemBuilder: (BuildContext context) => [
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
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // Personal Information Card
              Card(
                elevation: 2,
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

                      // First Name
                      TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) => _validateRequired(value, 'First name'),
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Last Name
                      TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) => _validateRequired(value, 'Last name'),
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Display Name
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: 'Display Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge),
                          hintText: 'How you want to be known',
                        ),
                        validator: (value) => _validateRequired(value, 'Display name'),
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Phone
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                          hintText: '(555) 123-4567',
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: _validatePhone,
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Gender Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: _selectedGender,
                        decoration: const InputDecoration(
                          labelText: 'Gender *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_4),
                        ),
                        items: _genders
                            .map(
                              (gender) => DropdownMenuItem(
                                value: gender,
                                child: Text(gender),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value!;
                          });
                        },
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Please select your gender';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              // Profile & ID Images Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Images',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Profile Image Section
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Profile Image',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.01),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Show current profile image if exists
                                  if (widget.currentProfile.profileImage != null) ...[
                                    const Text(
                                      'Current Profile Image:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Image Key: ${widget.currentProfile.profileImage}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () => _showFullScreenImage(
                                        widget.currentProfile.profileImage,
                                        'Current Profile Image',
                                      ),
                                      child: Container(
                                        width: screenWidth * 0.2,
                                        height: screenWidth * 0.2,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: S3Image(
                                            imageKey: widget.currentProfile.profileImage!,
                                            userId: widget.currentProfile.id!,
                                            fit: BoxFit.cover,
                                            loadingWidget: Container(
                                              color: Colors.grey[300],
                                              child: const Center(
                                                child: CircularProgressIndicator(),
                                              ),
                                            ),
                                            errorWidget: Container(
                                              color: Colors.red[100],
                                              child: const Center(
                                                child: Text('Failed to load', style: TextStyle(fontSize: 10)),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'New Profile Image (optional):',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  // New image preview
                                  Container(
                                    width: screenWidth * 0.2,
                                    height: screenWidth * 0.2,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: _profileImageBytes != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.memory(
                                              _profileImageBytes!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.camera_alt,
                                            size: 40,
                                            color: Colors.grey,
                                          ),
                                  ),
                                  SizedBox(height: screenHeight * 0.015),
                                  // Buttons row with flexible layout
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _pickImage('profile'),
                                          icon: const Icon(Icons.photo_library, size: 16),
                                          label: const Text('Choose Image'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.deepPurple,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                          ),
                                        ),
                                      ),
                                      if (_profileImageBytes != null) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                _profileImageFile = null;
                                                _profileImageBytes = null;
                                              });
                                            },
                                            icon: const Icon(Icons.clear, size: 16),
                                            label: const Text('Remove'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Bio
                      TextFormField(
                        controller: _bioController,
                        decoration: const InputDecoration(
                          labelText: 'Bio',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                          hintText: 'Tell us about yourself...',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              // Address Information Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Address Information',
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
                          prefixIcon: Icon(Icons.home),
                          hintText: 'Street address',
                        ),
                        validator: (value) => _validateRequired(value, 'Address'),
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Address Line 2
                      TextFormField(
                        controller: _address2Controller,
                        decoration: const InputDecoration(
                          labelText: 'Address Line 2',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.home_outlined),
                          hintText: 'Apartment, suite, etc. (optional)',
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // City, State, ZIP Row
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _cityController,
                              decoration: const InputDecoration(
                                labelText: 'City *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.location_city),
                              ),
                              validator: (value) => _validateRequired(value, 'City'),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          Expanded(
                            child: TextFormField(
                              controller: _stateController,
                              decoration: const InputDecoration(
                                labelText: 'State *',
                                border: OutlineInputBorder(),
                              ),
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(2),
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z]'),
                                ),
                              ],
                              validator: (value) {
                                if (value?.trim().isEmpty ?? true) {
                                  return 'Required';
                                }
                                if (value!.trim().length != 2) {
                                  return 'State code';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          Expanded(
                            child: TextFormField(
                              controller: _zipCodeController,
                              decoration: const InputDecoration(
                                labelText: 'ZIP *',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(5),
                              ],
                              validator: _validateZipCode,
                            ),
                          ),
                        ],
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
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                      : const Text(
                          'Update Profile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              SizedBox(height: screenHeight * 0.02),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }
}
