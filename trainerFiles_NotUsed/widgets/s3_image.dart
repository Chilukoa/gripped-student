import 'package:flutter/material.dart';
import '../services/user_service.dart';

class S3Image extends StatefulWidget {
  final String? imageKey;
  final String? userId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;
  final Widget? loadingWidget;

  const S3Image({
    Key? key,
    required this.imageKey,
    required this.userId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
    this.loadingWidget,
  }) : super(key: key);

  @override
  State<S3Image> createState() => _S3ImageState();
}

class _S3ImageState extends State<S3Image> {
  String? _imageUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(S3Image oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageKey != widget.imageKey ||
        oldWidget.userId != widget.userId) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageKey == null || widget.userId == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Try to get presigned download URL first
      final userService = UserService();
      final downloadUrl = await userService.getDownloadUrl(
        widget.imageKey!,
        widget.userId!,
      );

      if (downloadUrl != null) {
        setState(() {
          _imageUrl = downloadUrl;
          _isLoading = false;
        });
      } else {
        // Fallback to constructing direct S3 URL (will likely fail with 403)
        final constructedUrl = _constructS3Url(
          widget.imageKey!,
          widget.userId!,
        );
        setState(() {
          _imageUrl = constructedUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading S3 image: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  String _constructS3Url(String imageKey, String userId) {
    // Construct the full S3 path: profiles/{userId}/{imageId}.jpg
    final fullS3Key = 'profiles/$userId/$imageKey.jpg';

    // Use the correct S3 bucket URL pattern
    return 'https://grippedstack-userphotosbucket4d5de39b-gvc8qfaefzit.s3.us-east-1.amazonaws.com/$fullS3Key';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          );
    }

    if (_hasError || _imageUrl == null) {
      return widget.errorWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[300],
            child: const Icon(Icons.error, color: Colors.red, size: 32),
          );
    }

    return Image.network(
      _imageUrl!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        print('Failed to load image: $_imageUrl');
        print('Error: $error');
        return widget.errorWidget ??
            Container(
              width: widget.width,
              height: widget.height,
              color: Colors.grey[300],
              child: const Icon(Icons.error, color: Colors.red, size: 32),
            );
      },
    );
  }
}
