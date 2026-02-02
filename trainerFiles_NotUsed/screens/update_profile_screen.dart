import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/user_profile.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../widgets/s3_image.dart';

class UpdateProfileScreen extends StatefulWidget {
  final UserProfile currentProfile;

  const UpdateProfileScreen({super.key, required this.currentProfile});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form controllers
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late final TextEditingController _phoneController;
  late final TextEditingController _specialtyController;
  late final TextEditingController _address1Controller;
  late final TextEditingController _address2Controller;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _zipController;

  String _selectedGender = 'Male';
  final List<String> _genders = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];
  List<TextEditingController> _certificationControllers = [];
  List<String> get _selectedCertifications => _certificationControllers
      .map((controller) => controller.text.trim())
      .where((text) => text.isNotEmpty)
      .toList();

  // Image handling
  File? _profileImage;
  File? _idImage;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _firstNameController = TextEditingController(
      text: widget.currentProfile.firstName,
    );
    _lastNameController = TextEditingController(
      text: widget.currentProfile.lastName,
    );
    _displayNameController = TextEditingController(
      text: widget.currentProfile.displayName,
    );
    _bioController = TextEditingController(text: widget.currentProfile.bio);
    _phoneController = TextEditingController(text: widget.currentProfile.phone);
    _specialtyController = TextEditingController(
      text: widget.currentProfile.specialty,
    );
    _address1Controller = TextEditingController(
      text: widget.currentProfile.address1,
    );
    _address2Controller = TextEditingController(
      text: widget.currentProfile.address2 ?? '',
    );
    _cityController = TextEditingController(text: widget.currentProfile.city);
    _stateController = TextEditingController(text: widget.currentProfile.state);
    _zipController = TextEditingController(text: widget.currentProfile.zip);

    _selectedGender = widget.currentProfile.gender.isNotEmpty
        ? widget.currentProfile.gender
        : 'Male';
    // Initialize certification controllers with existing certifications
    _certificationControllers = widget.currentProfile.certifications
        .map((cert) => TextEditingController(text: cert))
        .toList();
    // Ensure at least one empty field if no certifications exist
    if (_certificationControllers.isEmpty) {
      _certificationControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _specialtyController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    // Dispose all certification controllers
    for (final controller in _certificationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(String type) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          if (type == 'profile') {
            _profileImage = File(pickedFile.path);
          } else if (type == 'id') {
            _idImage = File(pickedFile.path);
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
      String? idImageUrl = widget.currentProfile.idImage;

      // Handle image uploads if new images were selected
      List<File> imagesToUpload = [];
      if (_profileImage != null) {
        imagesToUpload.add(_profileImage!);
      }
      if (_idImage != null) {
        imagesToUpload.add(_idImage!);
      }

      if (imagesToUpload.isNotEmpty) {
        try {
          final imageUrls = await UserService().uploadImages(imagesToUpload);
          int urlIndex = 0;

          if (_profileImage != null) {
            profileImageUrl = imageUrls[urlIndex++];
          }
          if (_idImage != null) {
            idImageUrl = imageUrls[urlIndex++];
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload images: $e'),
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
        bio: _bioController.text.trim(),
        phone: _phoneController.text.trim(),
        specialty: _specialtyController.text.trim(),
        address1: _address1Controller.text.trim(),
        address2: _address2Controller.text.trim().isNotEmpty
            ? _address2Controller.text.trim()
            : null,
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        zip: _zipController.text.trim(),
        gender: _selectedGender,
        profileImage: profileImageUrl,
        idImage: idImageUrl,
        certifications: _selectedCertifications,
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

  void _addCertification() {
    setState(() {
      _certificationControllers.add(TextEditingController());
    });
  }

  void _removeCertification(int index) {
    if (_certificationControllers.length > 1) {
      setState(() {
        _certificationControllers[index].dispose();
        _certificationControllers.removeAt(index);
      });
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

  Widget _buildCertificationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Certifications',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 8),
        // List of certification text fields
        ..._certificationControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Certification ${index + 1}',
                      border: const OutlineInputBorder(),
                      hintText: 'e.g., NASM, CPR, First Aid',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _removeCertification(index),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Remove certification',
                ),
              ],
            ),
          );
        }).toList(),
        // Add button
        ElevatedButton.icon(
          onPressed: _addCertification,
          icon: const Icon(Icons.add),
          label: const Text('Add Certification'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
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
      body: SingleChildScrollView(
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
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Please enter your first name';
                          }
                          return null;
                        },
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
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Please enter your last name';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Display Name
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: 'Display Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge),
                          hintText: 'How you want to be known to students',
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Please enter your display name';
                          }
                          return null;
                        },
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
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Please enter your phone number';
                          }
                          if (value!.length < 10) {
                            return 'Please enter a valid 10-digit phone number';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Gender Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
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

              // Professional Information Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Professional Information',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Specialty
                      TextFormField(
                        controller: _specialtyController,
                        decoration: const InputDecoration(
                          labelText: 'Specialty',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.fitness_center),
                          hintText: 'e.g., Personal Training, Yoga, Pilates',
                        ),
                        validator: null, // Made optional
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
                                  if (widget.currentProfile.profileImage !=
                                      null) ...[
                                    const Text(
                                      'Current Profile Image:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () => _showFullScreenImage(
                                        widget.currentProfile.profileImage,
                                        'Current Profile Image',
                                      ),
                                      child: Container(
                                        width: screenWidth * 0.15,
                                        height: screenWidth * 0.15,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.deepPurple,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: S3Image(
                                            imageKey: widget
                                                .currentProfile
                                                .profileImage,
                                            userId: widget.currentProfile.id,
                                            width: screenWidth * 0.15,
                                            height: screenWidth * 0.15,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Upload New Profile Image:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  // New image preview
                                  Container(
                                    width: screenWidth * 0.2,
                                    height: screenWidth * 0.2,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: _profileImage != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.file(
                                              _profileImage!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Icon(Icons.person, size: 40),
                                  ),
                                  SizedBox(height: screenHeight * 0.015),
                                  // Buttons row with flexible layout
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _pickImage('profile'),
                                          icon: const Icon(Icons.upload),
                                          label: const Text('Select Image'),
                                        ),
                                      ),
                                      if (_profileImage != null) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _profileImage = null;
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
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

                      // ID Document Section
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ID Document',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.01),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Show current ID document if exists
                                  if (widget.currentProfile.idImage !=
                                      null) ...[
                                    const Text(
                                      'Current ID Document:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () => _showFullScreenImage(
                                        widget.currentProfile.idImage,
                                        'Current ID Document',
                                      ),
                                      child: Container(
                                        width: screenWidth * 0.15,
                                        height: screenWidth * 0.15,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.deepPurple,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: S3Image(
                                            imageKey:
                                                widget.currentProfile.idImage,
                                            userId: widget.currentProfile.id,
                                            width: screenWidth * 0.15,
                                            height: screenWidth * 0.15,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Upload New ID Document:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  // New image preview
                                  Container(
                                    width: screenWidth * 0.2,
                                    height: screenWidth * 0.2,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: _idImage != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.file(
                                              _idImage!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.credit_card,
                                            size: 40,
                                          ),
                                  ),
                                  SizedBox(height: screenHeight * 0.015),
                                  // Buttons row with flexible layout
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _pickImage('id'),
                                          icon: const Icon(Icons.upload),
                                          label: const Text('Select Document'),
                                        ),
                                      ),
                                      if (_idImage != null) ...[
                                        const SizedBox(width: 8),
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _idImage = null;
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
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
                          labelText: 'Bio *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                          hintText:
                              'Tell students about yourself and your approach',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Please enter your bio';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: screenHeight * 0.02),

                      // Certifications
                      _buildCertificationSelector(),
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
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Please enter your address';
                          }
                          return null;
                        },
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
                              validator: (value) {
                                if (value?.trim().isEmpty ?? true) {
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
                              controller: _zipController,
                              decoration: const InputDecoration(
                                labelText: 'ZIP *',
                                border: OutlineInputBorder(),
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
                                if (value!.length != 5) {
                                  return 'Invalid ZIP';
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
    );
  }
}
