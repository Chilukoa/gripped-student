import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../services/user_service.dart';
import '../config/api_config.dart' as config;

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
      safePrint('S3Image: imageKey or userId is null');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    safePrint('S3Image: Loading image with key: ${widget.imageKey}, userId: ${widget.userId}');

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

      safePrint('S3Image: Download URL received: $downloadUrl');

      if (downloadUrl != null) {
        setState(() {
          _imageUrl = downloadUrl;
          _isLoading = false;
        });
      } else {
        safePrint('S3Image: Download URL is null, trying fallback');
        // Fallback to constructing direct S3 URL (will likely fail with 403)
        final constructedUrl = _constructS3Url(
          widget.imageKey!,
          widget.userId!,
        );
        safePrint('S3Image: Fallback URL: $constructedUrl');
        setState(() {
          _imageUrl = constructedUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      safePrint('Error loading S3 image: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  String _constructS3Url(String imageKey, String userId) {
    // Construct the full S3 path: profiles/{userId}/{imageId}.jpg
    final fullS3Key = 'profiles/$userId/$imageKey.jpg';

    // Use the centralized S3 bucket URL from API config
    return '${config.ApiConfig.s3BucketUrl}/$fullS3Key';
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
        safePrint('Failed to load image: $_imageUrl');
        safePrint('Error: $error');
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